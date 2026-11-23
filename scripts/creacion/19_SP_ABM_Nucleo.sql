/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner
Fecha: 2026-11-19
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Stored procedures ABM restantes del módulo núcleo:
          1.  nucleo.SP_ABM_Confederacion
          2.  nucleo.SP_ABM_Pais
          3.  nucleo.SP_ABM_Ciudad
          4.  nucleo.SP_ABM_Fase
          5.  nucleo.SP_ABM_Grupo
          6.  nucleo.SP_ABM_Seleccion
          7.  nucleo.SP_ABM_StaffTecnico
          8.  nucleo.SP_ABM_Idioma
          9.  nucleo.SP_ABM_Categoria
          10. nucleo.SP_ABM_Arbitro
          11. nucleo.SP_ABM_ArbitroIdioma
          12. nucleo.SP_ABM_DesignacionArbitral
          13. nucleo.SP_ABM_Sancion
          Requiere ejecutados los scripts 01 a 18.
          Test correspondiente: testing/19_Test_SP_ABM_Nucleo.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. SP_ABM_Confederacion
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Confederacion
    @operacion       VARCHAR(12),
    @idConfederacion INT          = NULL OUTPUT,
    @nombre          VARCHAR(100) = NULL,
    @sigla           VARCHAR(8)   = NULL,
    @region          VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombre    = LTRIM(RTRIM(@nombre));
    SET @sigla     = UPPER(LTRIM(RTRIM(@sigla)));
    SET @region    = NULLIF(LTRIM(RTRIM(@region)), '');

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idConfederacion IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Confederacion WHERE IdConfederacion = @idConfederacion)
            SET @errores += N'- La confederación indicada no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombre IS NULL OR @nombre = ''
            SET @errores += N'- El nombre de la confederación es obligatorio.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Confederacion
                        WHERE Nombre = @nombre
                          AND (@operacion = 'ALTA' OR IdConfederacion <> @idConfederacion))
            SET @errores += N'- Ya existe otra confederación con ese nombre.' + @salto;

        IF @sigla IS NULL OR @sigla = ''
            SET @errores += N'- La sigla de la confederación es obligatoria.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Confederacion
                        WHERE Sigla = @sigla
                          AND (@operacion = 'ALTA' OR IdConfederacion <> @idConfederacion))
            SET @errores += N'- Ya existe otra confederación con esa sigla.' + @salto;
    END;

    IF @operacion = 'BAJA'
       AND EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdConfederacion = @idConfederacion)
        SET @errores += N'- La confederación tiene países asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Confederacion (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Confederacion (Nombre, Sigla, Region)
            VALUES (@nombre, @sigla, @region);

            SET @idConfederacion = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Confederacion
            SET Nombre = @nombre,
                Sigla  = @sigla,
                Region = @region
            WHERE IdConfederacion = @idConfederacion;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Confederacion
            WHERE IdConfederacion = @idConfederacion;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- 2. SP_ABM_Pais
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Pais
    @operacion            VARCHAR(12),
    @idPais               INT           = NULL OUTPUT,
    @nombre               VARCHAR(50)   = NULL,
    @codigoISO2           CHAR(2)       = NULL,
    @codigoISO3           CHAR(3)       = NULL,
    @idConfederacion      INT           = NULL,
    @husoHorarioComercial VARCHAR(50)   = NULL,
    @pbiPerCapitaUSD      DECIMAL(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion            = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombre               = LTRIM(RTRIM(@nombre));
    SET @codigoISO2           = UPPER(LTRIM(RTRIM(@codigoISO2)));
    SET @codigoISO3           = UPPER(LTRIM(RTRIM(@codigoISO3)));
    SET @husoHorarioComercial = LTRIM(RTRIM(@husoHorarioComercial));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idPais IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
            SET @errores += N'- El país indicado no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombre IS NULL OR @nombre = ''
            SET @errores += N'- El nombre del país es obligatorio.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Pais
                        WHERE Nombre = @nombre
                          AND (@operacion = 'ALTA' OR IdPais <> @idPais))
            SET @errores += N'- Ya existe otro país con ese nombre.' + @salto;

        IF @codigoISO2 IS NULL OR @codigoISO2 NOT LIKE '[A-Z][A-Z]'
            SET @errores += N'- El código ISO2 es obligatorio y debe tener exactamente 2 letras (A-Z).' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Pais
                        WHERE CodigoISO2 = @codigoISO2
                          AND (@operacion = 'ALTA' OR IdPais <> @idPais))
            SET @errores += N'- Ya existe otro país con ese código ISO2.' + @salto;

        IF @codigoISO3 IS NULL OR @codigoISO3 NOT LIKE '[A-Z][A-Z][A-Z]'
            SET @errores += N'- El código ISO3 es obligatorio y debe tener exactamente 3 letras (A-Z).' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Pais
                        WHERE CodigoISO3 = @codigoISO3
                          AND (@operacion = 'ALTA' OR IdPais <> @idPais))
            SET @errores += N'- Ya existe otro país con ese código ISO3.' + @salto;

        IF @idConfederacion IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Confederacion WHERE IdConfederacion = @idConfederacion)
            SET @errores += N'- La confederación indicada no existe.' + @salto;

        IF @husoHorarioComercial IS NULL OR @husoHorarioComercial = ''
           OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @husoHorarioComercial)
            SET @errores += N'- El huso horario comercial no es válido (debe existir en sys.time_zone_info).' + @salto;

        IF @pbiPerCapitaUSD IS NOT NULL AND @pbiPerCapitaUSD < 0
            SET @errores += N'- El PBI per cápita no puede ser negativo.' + @salto;
    END;

    IF @operacion = 'BAJA'
    BEGIN
        IF EXISTS (SELECT 1 FROM nucleo.Ciudad WHERE IdPais = @idPais)
            SET @errores += N'- El país tiene ciudades asociadas y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdPais = @idPais)
            SET @errores += N'- El país tiene una selección registrada y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdPais = @idPais)
            SET @errores += N'- El país tiene árbitros asociados y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE IdPais = @idPais)
            SET @errores += N'- El país tiene anunciantes asociados y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM publicidad.OrientacionPais WHERE IdPais = @idPais)
            SET @errores += N'- El país está asociado a orientaciones de piezas publicitarias y no puede eliminarse.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Pais (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, HusoHorarioComercial, PBIPerCapitaUSD)
            VALUES (@nombre, @codigoISO2, @codigoISO3, @idConfederacion, @husoHorarioComercial, @pbiPerCapitaUSD);

            SET @idPais = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Pais
            SET Nombre               = @nombre,
                CodigoISO2           = @codigoISO2,
                CodigoISO3           = @codigoISO3,
                IdConfederacion      = @idConfederacion,
                HusoHorarioComercial = @husoHorarioComercial,
                PBIPerCapitaUSD      = @pbiPerCapitaUSD
            WHERE IdPais = @idPais;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Pais
            WHERE IdPais = @idPais;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- 3. SP_ABM_Ciudad
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Ciudad
    @operacion   VARCHAR(12),
    @idCiudad    INT          = NULL OUTPUT,
    @nombre      VARCHAR(100) = NULL,
    @idPais      INT          = NULL,
    @husoHorario VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores             NVARCHAR(MAX) = N'',
            @mensaje             NVARCHAR(2048),
            @salto               NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @husoHorarioEfectivo VARCHAR(50);

    SET @operacion   = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombre      = LTRIM(RTRIM(@nombre));
    SET @husoHorario = LTRIM(RTRIM(@husoHorario));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idCiudad IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Ciudad WHERE IdCiudad = @idCiudad)
            SET @errores += N'- La ciudad indicada no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombre IS NULL OR @nombre = ''
            SET @errores += N'- El nombre de la ciudad es obligatorio.' + @salto;

        IF @idPais IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
            SET @errores += N'- El país indicado no existe.' + @salto;
        ELSE
            SET @husoHorarioEfectivo = COALESCE(@husoHorario, (SELECT HusoHorarioComercial FROM nucleo.Pais WHERE IdPais = @idPais));

        IF @husoHorario IS NOT NULL AND (@husoHorario = '' OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @husoHorario))
            SET @errores += N'- El huso horario de la ciudad no es válido (debe existir en sys.time_zone_info).' + @salto;
        ELSE IF @idPais IS NOT NULL AND (@husoHorarioEfectivo IS NULL OR @husoHorarioEfectivo = '')
            SET @errores += N'- El huso horario de la ciudad es obligatorio.' + @salto;

        IF @nombre IS NOT NULL AND @nombre <> '' AND @idPais IS NOT NULL
           AND EXISTS (SELECT 1
                       FROM nucleo.Ciudad
                       WHERE IdPais = @idPais
                         AND Nombre = @nombre
                         AND (@operacion = 'ALTA' OR IdCiudad <> @idCiudad))
            SET @errores += N'- Ya existe otra ciudad con ese nombre en el mismo país.' + @salto;
    END;

    IF @operacion = 'BAJA'
       AND EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdCiudad = @idCiudad)
        SET @errores += N'- La ciudad tiene sedes asociadas y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Ciudad (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
            VALUES (@nombre, @husoHorarioEfectivo, @idPais);

            SET @idCiudad = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Ciudad
            SET Nombre      = @nombre,
                HusoHorario = @husoHorarioEfectivo,
                IdPais      = @idPais
            WHERE IdCiudad = @idCiudad;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Ciudad
            WHERE IdCiudad = @idCiudad;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- 4. SP_ABM_Fase
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Fase
    @operacion      VARCHAR(12),
    @idFase         INT         = NULL OUTPUT,
    @nombre         VARCHAR(28) = NULL,
    @orden          INT         = NULL,
    @esEliminatoria BIT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombre    = LTRIM(RTRIM(@nombre));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idFase IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE IdFase = @idFase)
            SET @errores += N'- La fase indicada no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombre IS NULL
           OR @nombre NOT IN (
               'Fase de grupos',
               'Dieciseisavos de final',
               'Octavos de final',
               'Cuartos de final',
               'Semifinal',
               'Tercer puesto',
               'Final'
           )
            SET @errores += N'- El nombre es obligatorio y debe ser: Fase de grupos, Dieciseisavos de final, Octavos de final, Cuartos de final, Semifinal, Tercer puesto o Final.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Fase
                        WHERE Nombre = @nombre
                          AND (@operacion = 'ALTA' OR IdFase <> @idFase))
            SET @errores += N'- Ya existe otra fase con ese nombre.' + @salto;

        IF @orden IS NULL OR @orden NOT BETWEEN 1 AND 7
            SET @errores += N'- El orden es obligatorio y debe estar entre 1 y 7.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Fase
                        WHERE Orden = @orden
                          AND (@operacion = 'ALTA' OR IdFase <> @idFase))
            SET @errores += N'- Ya existe otra fase con ese número de orden.' + @salto;

        IF @esEliminatoria IS NULL
            SET @errores += N'- Debe indicar si la fase es eliminatoria (0 o 1).' + @salto;
    END;

    IF @operacion = 'BAJA'
       AND EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdFase = @idFase)
        SET @errores += N'- La fase tiene partidos asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Fase (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Fase (Nombre, Orden, EsEliminatoria)
            VALUES (@nombre, @orden, @esEliminatoria);

            SET @idFase = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Fase
            SET Nombre         = @nombre,
                Orden          = @orden,
                EsEliminatoria = @esEliminatoria
            WHERE IdFase = @idFase;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Fase
            WHERE IdFase = @idFase;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- 5. SP_ABM_Grupo
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Grupo
    @operacion VARCHAR(12),
    @idGrupo   INT         = NULL OUTPUT,
    @nombre    VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombre    = UPPER(LTRIM(RTRIM(@nombre)));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idGrupo IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE IdGrupo = @idGrupo)
            SET @errores += N'- El grupo indicado no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombre IS NULL OR @nombre NOT LIKE '[A-Z]'
            SET @errores += N'- El nombre del grupo es obligatorio y debe ser una única letra (A-Z).' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Grupo
                        WHERE Nombre = @nombre
                          AND (@operacion = 'ALTA' OR IdGrupo <> @idGrupo))
            SET @errores += N'- Ya existe otro grupo con ese nombre.' + @salto;
    END;

    IF @operacion = 'BAJA'
       AND EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdGrupo = @idGrupo)
        SET @errores += N'- El grupo tiene selecciones asignadas y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Grupo (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Grupo (Nombre)
            VALUES (@nombre);

            SET @idGrupo = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Grupo
            SET Nombre = @nombre
            WHERE IdGrupo = @idGrupo;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Grupo
            WHERE IdGrupo = @idGrupo;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- 6. SP_ABM_Seleccion
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Seleccion
    @operacion   VARCHAR(12),
    @idSeleccion INT      = NULL OUTPUT,
    @codigoFIFA  CHAR(3)  = NULL,
    @rankingFIFA SMALLINT = NULL,
    @esAnfitrion BIT      = 0,
    @idPais      INT      = NULL,
    @idGrupo     INT      = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion   = UPPER(LTRIM(RTRIM(@operacion)));
    SET @codigoFIFA  = UPPER(LTRIM(RTRIM(@codigoFIFA)));
    SET @esAnfitrion = ISNULL(@esAnfitrion, 0);

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idSeleccion IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccion)
            SET @errores += N'- La selección indicada no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @codigoFIFA IS NULL OR @codigoFIFA NOT LIKE '[A-Z][A-Z][A-Z]'
            SET @errores += N'- El código FIFA es obligatorio y debe tener exactamente 3 letras (A-Z).' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Seleccion
                        WHERE CodigoFIFA = @codigoFIFA
                          AND (@operacion = 'ALTA' OR IdSeleccion <> @idSeleccion))
            SET @errores += N'- Ya existe otra selección con ese código FIFA.' + @salto;

        IF @rankingFIFA IS NULL OR @rankingFIFA <= 0
            SET @errores += N'- El ranking FIFA es obligatorio y debe ser mayor a cero.' + @salto;

        IF @idPais IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
            SET @errores += N'- El país indicado no existe.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Seleccion
                        WHERE IdPais = @idPais
                          AND (@operacion = 'ALTA' OR IdSeleccion <> @idSeleccion))
            SET @errores += N'- Ya existe otra selección registrada para ese país.' + @salto;

        IF @idGrupo IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE IdGrupo = @idGrupo)
            SET @errores += N'- El grupo es obligatorio y debe existir.' + @salto;
    END;

    IF @operacion = 'BAJA'
    BEGIN
        IF EXISTS (SELECT 1 FROM nucleo.StaffTecnico WHERE IdSeleccion = @idSeleccion)
            SET @errores += N'- La selección tiene cuerpo técnico registrado y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdSeleccionLocal = @idSeleccion OR IdSeleccionVisitante = @idSeleccion)
            SET @errores += N'- La selección tiene partidos asociados y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM jugadores.Convocatoria WHERE IdSeleccion = @idSeleccion)
            SET @errores += N'- La selección tiene jugadores convocados y no puede eliminarse.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Seleccion (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
            VALUES (@codigoFIFA, @rankingFIFA, @esAnfitrion, @idPais, @idGrupo);

            SET @idSeleccion = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Seleccion
            SET CodigoFIFA  = @codigoFIFA,
                RankingFIFA = @rankingFIFA,
                EsAnfitrion = @esAnfitrion,
                IdPais      = @idPais,
                IdGrupo     = @idGrupo
            WHERE IdSeleccion = @idSeleccion;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Seleccion
            WHERE IdSeleccion = @idSeleccion;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- 7. SP_ABM_StaffTecnico
-- Respeta la restricción única UQ_StaffTecnico_IdSeleccion_Rol (un integrante por rol y selección).
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_StaffTecnico
    @operacion      VARCHAR(12),
    @idStaffTecnico INT          = NULL OUTPUT,
    @idSeleccion    INT          = NULL,
    @nombreApellido VARCHAR(200) = NULL,
    @rol            VARCHAR(25)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion      = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombreApellido = LTRIM(RTRIM(@nombreApellido));
    SET @rol            = LTRIM(RTRIM(@rol));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idStaffTecnico IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.StaffTecnico WHERE IdStaffTecnico = @idStaffTecnico)
            SET @errores += N'- El integrante del cuerpo técnico indicado no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @idSeleccion IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccion)
            SET @errores += N'- La selección indicada no existe.' + @salto;

        IF @nombreApellido IS NULL OR @nombreApellido = ''
            SET @errores += N'- El nombre y apellido es obligatorio.' + @salto;

        IF @rol IS NULL OR @rol NOT IN ('Director Técnico', 'Ayudante de campo 1', 'Ayudante de campo 2')
            SET @errores += N'- El rol es obligatorio y debe ser: Director Técnico, Ayudante de campo 1 o Ayudante de campo 2.' + @salto;
        ELSE IF @idSeleccion IS NOT NULL
                AND EXISTS (SELECT 1
                            FROM nucleo.StaffTecnico
                            WHERE IdSeleccion = @idSeleccion
                              AND Rol = @rol
                              AND (@operacion = 'ALTA' OR IdStaffTecnico <> @idStaffTecnico))
            SET @errores += N'- La selección ya tiene asignado un integrante para ese rol.' + @salto;
    END;

    IF @operacion = 'BAJA'
       AND EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdStaffTecnico = @idStaffTecnico)
        SET @errores += N'- El integrante del staff técnico registra amonestaciones y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_StaffTecnico (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.StaffTecnico (IdSeleccion, NombreApellido, Rol)
            VALUES (@idSeleccion, @nombreApellido, @rol);

            SET @idStaffTecnico = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.StaffTecnico
            SET IdSeleccion    = @idSeleccion,
                NombreApellido = @nombreApellido,
                Rol            = @rol
            WHERE IdStaffTecnico = @idStaffTecnico;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.StaffTecnico
            WHERE IdStaffTecnico = @idStaffTecnico;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- 8. SP_ABM_Idioma
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Idioma
    @operacion VARCHAR(12),
    @idIdioma  INT          = NULL OUTPUT,
    @nombre    VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombre    = LTRIM(RTRIM(@nombre));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idIdioma IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Idioma WHERE IdIdioma = @idIdioma)
            SET @errores += N'- El idioma indicado no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombre IS NULL OR @nombre = ''
            SET @errores += N'- El nombre del idioma es obligatorio.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Idioma
                        WHERE Nombre = @nombre
                          AND (@operacion = 'ALTA' OR IdIdioma <> @idIdioma))
            SET @errores += N'- Ya existe otro idioma con ese nombre.' + @salto;
    END;

    IF @operacion = 'BAJA'
    BEGIN
        IF EXISTS (SELECT 1 FROM nucleo.ArbitroIdioma WHERE IdIdioma = @idIdioma)
            SET @errores += N'- El idioma está asociado a árbitros y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM publicidad.Pieza WHERE IdIdioma = @idIdioma)
            SET @errores += N'- El idioma está asociado a piezas publicitarias y no puede eliminarse.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Idioma (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Idioma (Nombre)
            VALUES (@nombre);

            SET @idIdioma = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Idioma
            SET Nombre = @nombre
            WHERE IdIdioma = @idIdioma;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Idioma
            WHERE IdIdioma = @idIdioma;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- 9. SP_ABM_Categoria
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Categoria
    @operacion   VARCHAR(12),
    @idCategoria INT          = NULL OUTPUT,
    @nombre      VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombre    = LTRIM(RTRIM(@nombre));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idCategoria IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Categoria WHERE IdCategoria = @idCategoria)
            SET @errores += N'- La categoría indicada no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombre IS NULL OR @nombre = ''
            SET @errores += N'- El nombre de la categoría es obligatorio.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Categoria
                        WHERE Nombre = @nombre
                          AND (@operacion = 'ALTA' OR IdCategoria <> @idCategoria))
            SET @errores += N'- Ya existe otra categoría con ese nombre.' + @salto;
    END;

    IF @operacion = 'BAJA'
       AND EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdCategoria = @idCategoria)
        SET @errores += N'- La categoría tiene árbitros asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Categoria (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Categoria (Nombre)
            VALUES (@nombre);

            SET @idCategoria = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Categoria
            SET Nombre = @nombre
            WHERE IdCategoria = @idCategoria;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Categoria
            WHERE IdCategoria = @idCategoria;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- 10. SP_ABM_Arbitro
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Arbitro
    @operacion       VARCHAR(12),
    @idArbitro       INT          = NULL OUTPUT,
    @nombreApellido  VARCHAR(200) = NULL,
    @sexo            CHAR(1)      = NULL,
    @estaHabilitado  CHAR(1)      = 'Y',
    @fechaNacimiento DATE         = NULL,
    @idPais          INT          = NULL,
    @idCategoria     INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion      = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombreApellido = LTRIM(RTRIM(@nombreApellido));
    SET @sexo           = NULLIF(UPPER(LTRIM(RTRIM(@sexo))), '');
    SET @estaHabilitado = UPPER(LTRIM(RTRIM(ISNULL(@estaHabilitado, 'Y'))));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idArbitro IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdArbitro = @idArbitro)
            SET @errores += N'- El árbitro indicado no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombreApellido IS NULL OR @nombreApellido = ''
            SET @errores += N'- El nombre y apellido del árbitro es obligatorio.' + @salto;

        IF @sexo IS NOT NULL AND @sexo NOT IN ('M', 'F')
            SET @errores += N'- El sexo debe ser M o F.' + @salto;

        IF @estaHabilitado NOT IN ('Y', 'N')
            SET @errores += N'- El estado de habilitación debe ser Y o N.' + @salto;

        IF @fechaNacimiento IS NULL
            SET @errores += N'- La fecha de nacimiento es obligatoria.' + @salto;
        ELSE IF @fechaNacimiento < '1930-01-01' OR @fechaNacimiento >= CAST(GETDATE() AS DATE)
            SET @errores += N'- La fecha de nacimiento debe ser mayor o igual a 1930-01-01 y anterior a hoy.' + @salto;

        IF @idPais IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
            SET @errores += N'- El país indicado no existe.' + @salto;

        IF @idCategoria IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Categoria WHERE IdCategoria = @idCategoria)
            SET @errores += N'- La categoría indicada no existe.' + @salto;
    END;

    IF @operacion = 'BAJA'
    BEGIN
        IF EXISTS (SELECT 1 FROM nucleo.DesignacionArbitral WHERE IdArbitro = @idArbitro)
            SET @errores += N'- El árbitro tiene designaciones arbitrales registradas y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM nucleo.ArbitroIdioma WHERE IdArbitro = @idArbitro)
            SET @errores += N'- El árbitro tiene idiomas asociados y no puede eliminarse.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Arbitro (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Arbitro (NombreApellido, Sexo, EstaHabilitado, FechaNacimiento, IdPais, IdCategoria)
            VALUES (@nombreApellido, @sexo, @estaHabilitado, @fechaNacimiento, @idPais, @idCategoria);

            SET @idArbitro = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Arbitro
            SET NombreApellido  = @nombreApellido,
                Sexo            = @sexo,
                EstaHabilitado  = @estaHabilitado,
                FechaNacimiento = @fechaNacimiento,
                IdPais          = @idPais,
                IdCategoria     = @idCategoria
            WHERE IdArbitro = @idArbitro;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Arbitro
            WHERE IdArbitro = @idArbitro;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- 11. SP_ABM_ArbitroIdioma
-- Tabla asociativa (PK compuesta IdArbitro, IdIdioma): admite ALTA y BAJA.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_ArbitroIdioma
    @operacion VARCHAR(12),
    @idArbitro INT,
    @idIdioma  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion = 'MODIFICACION'
        SET @errores += N'- La relación ArbitroIdioma no admite modificación; realice una baja y un alta.' + @salto;

    IF @idArbitro IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdArbitro = @idArbitro)
        SET @errores += N'- El árbitro indicado no existe.' + @salto;

    IF @idIdioma IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Idioma WHERE IdIdioma = @idIdioma)
        SET @errores += N'- El idioma indicado no existe.' + @salto;

    IF @operacion = 'ALTA'
       AND @idArbitro IS NOT NULL AND @idIdioma IS NOT NULL
       AND EXISTS (SELECT 1 FROM nucleo.ArbitroIdioma WHERE IdArbitro = @idArbitro AND IdIdioma = @idIdioma)
        SET @errores += N'- El árbitro ya tiene registrado ese idioma.' + @salto;

    IF @operacion = 'BAJA'
       AND @idArbitro IS NOT NULL AND @idIdioma IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM nucleo.ArbitroIdioma WHERE IdArbitro = @idArbitro AND IdIdioma = @idIdioma)
        SET @errores += N'- El árbitro no tiene asociado ese idioma.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_ArbitroIdioma (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.ArbitroIdioma (IdArbitro, IdIdioma)
            VALUES (@idArbitro, @idIdioma);
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.ArbitroIdioma
            WHERE IdArbitro = @idArbitro
              AND IdIdioma  = @idIdioma;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- 12. SP_ABM_DesignacionArbitral
-- En ALTA delega en nucleo.SP_CONTROL_ARBITRAL (mismo patrón que SP_ABM_Gol).
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_DesignacionArbitral
    @operacion             VARCHAR(12),
    @idDesignacionArbitral INT          = NULL OUTPUT,
    @idPartido             INT          = NULL,
    @idArbitro             INT          = NULL,
    @rol                   VARCHAR(15)  = NULL,
    @advertencia           VARCHAR(200) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @advertencia = NULL;

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @rol       = LTRIM(RTRIM(@rol));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- En ALTA se reutiliza íntegramente SP_CONTROL_ARBITRAL.
    IF @operacion = 'ALTA'
    BEGIN
        EXEC nucleo.SP_CONTROL_ARBITRAL
            @idPartido   = @idPartido,
            @idArbitro   = @idArbitro,
            @rol         = @rol,
            @advertencia = @advertencia OUTPUT;

        SELECT @idDesignacionArbitral = d.IdDesignacionArbitral
        FROM nucleo.DesignacionArbitral AS d
        WHERE d.IdPartido = @idPartido
          AND d.IdArbitro = @idArbitro;
        RETURN;
    END;

    DECLARE @errores           NVARCHAR(MAX) = N'',
            @mensaje           NVARCHAR(2048),
            @salto             NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartidoActual   INT,
            @estadoActual      VARCHAR(10),
            @idFaseDestino     INT,
            @nombreFaseDestino VARCHAR(50),
            @estadoDestino     VARCHAR(10),
            @idPaisArbitro     INT,
            @estaHabilitado    CHAR(1),
            @rolValido         BIT = 0,
            @maxPorRol         INT;

    SELECT @idPartidoActual = d.IdPartido,
           @estadoActual    = p.Estado
    FROM nucleo.DesignacionArbitral AS d
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido
    WHERE d.IdDesignacionArbitral = @idDesignacionArbitral;

    -- ---- Validaciones ----------------------------------------------------
    IF @idPartidoActual IS NULL
        SET @errores += N'- La designación arbitral indicada no existe.' + @salto;
    ELSE IF @estadoActual = 'Finalizado'
        SET @errores += N'- El partido de la designación ya está finalizado: no se puede modificar ni eliminar.' + @salto;

    IF @operacion = 'MODIFICACION'
    BEGIN
        SELECT @idFaseDestino     = p.IdFase,
               @nombreFaseDestino = f.Nombre,
               @estadoDestino     = p.Estado
        FROM nucleo.Partido AS p
        INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
        WHERE p.IdPartido = @idPartido;

        SELECT @idPaisArbitro  = a.IdPais,
               @estaHabilitado = a.EstaHabilitado
        FROM nucleo.Arbitro AS a
        WHERE a.IdArbitro = @idArbitro;

        IF @rol IS NULL OR @rol NOT IN ('Principal', 'Asistente 1', 'Asistente 2', 'Cuarto', 'VAR')
            SET @errores += N'- Rol inválido. Valores permitidos: Principal, Asistente 1, Asistente 2, Cuarto, VAR.' + @salto;
        ELSE
            SET @rolValido = 1;

        IF @idFaseDestino IS NULL
            SET @errores += N'- El partido indicado no existe.' + @salto;
        ELSE IF @estadoDestino = 'Finalizado' AND (@idPartidoActual IS NULL OR @idPartido <> @idPartidoActual)
            SET @errores += N'- El partido destino ya está finalizado.' + @salto;

        IF @idPaisArbitro IS NULL
            SET @errores += N'- El árbitro indicado no existe.' + @salto;
        ELSE IF @estaHabilitado <> 'Y'
            SET @errores += N'- El árbitro no está habilitado para ser designado.' + @salto;

        IF @idFaseDestino IS NOT NULL AND @idPaisArbitro IS NOT NULL
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM nucleo.fn_SeleccionesDelPartido(@idPartido) AS sp
                INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion
                WHERE s.IdPais = @idPaisArbitro
            )
                SET @errores += N'- Designación rechazada: el país del árbitro coincide con el de una de las selecciones del partido.' + @salto;

            IF EXISTS (
                SELECT 1
                FROM nucleo.DesignacionArbitral AS d
                WHERE d.IdPartido = @idPartido
                  AND d.IdArbitro = @idArbitro
                  AND d.IdDesignacionArbitral <> @idDesignacionArbitral
            )
                SET @errores += N'- El árbitro ya está designado en ese partido.' + @salto;
        END;

        IF @idFaseDestino IS NOT NULL AND @rolValido = 1
        BEGIN
            SET @maxPorRol = 1;

            IF (
                SELECT COUNT(*)
                FROM nucleo.DesignacionArbitral AS d
                WHERE d.IdPartido = @idPartido
                  AND d.Rol = @rol
                  AND d.IdDesignacionArbitral <> @idDesignacionArbitral
            ) >= @maxPorRol
                SET @errores += N'- El partido ya tiene cubiertos los lugares para ese rol.' + @salto;
        END;
    END
    ELSE IF @operacion = 'BAJA' AND @idPartidoActual IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM nucleo.Sancion WHERE IdDesignacionArbitral = @idDesignacionArbitral)
            SET @errores += N'- La designación tiene sanciones o informes asociados y no puede eliminarse.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_DesignacionArbitral (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.DesignacionArbitral
            SET IdPartido = @idPartido,
                IdArbitro = @idArbitro,
                Rol       = @rol
            WHERE IdDesignacionArbitral = @idDesignacionArbitral;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.DesignacionArbitral
            WHERE IdDesignacionArbitral = @idDesignacionArbitral;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    IF @operacion = 'MODIFICACION'
       AND @nombreFaseDestino IN ('Dieciseisavos de final', 'Octavos de final', 'Cuartos de final', 'Semifinal', 'Tercer puesto', 'Final')
       AND EXISTS (
            SELECT 1
            FROM nucleo.Partido AS p
            CROSS APPLY nucleo.fn_SeleccionesDelPartido(p.IdPartido) AS sp
            INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion
            WHERE p.IdFase = @idFaseDestino
              AND p.IdPartido <> @idPartido
              AND s.IdPais = @idPaisArbitro
       )
    BEGIN
        SET @advertencia = 'Advertencia: el país del árbitro tiene una selección que podría cruzarse con las de este partido.';
        PRINT @advertencia;
    END;
END;
GO

-- =========================================================================
-- 13. SP_ABM_Sancion
-- Sanciones e informes post-partido recibidos por un árbitro.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Sancion
    @operacion             VARCHAR(12),
    @idSancion             INT          = NULL OUTPUT,
    @idDesignacionArbitral INT          = NULL,
    @tipo                  VARCHAR(20)  = NULL,
    @descripcion           VARCHAR(300) = NULL,
    @fecha                 DATE         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores       NVARCHAR(MAX) = N'',
            @mensaje       NVARCHAR(2048),
            @salto         NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @fechaEfectiva DATE          = ISNULL(@fecha, CAST(GETDATE() AS DATE)),
            @fechaPartido  DATE;

    SET @operacion   = UPPER(LTRIM(RTRIM(@operacion)));
    SET @tipo        = LTRIM(RTRIM(@tipo));
    SET @descripcion = LTRIM(RTRIM(@descripcion));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idSancion IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Sancion WHERE IdSancion = @idSancion)
            SET @errores += N'- La sanción indicada no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        SELECT @fechaPartido = CAST(p.FechaHoraUTC AS DATE)
        FROM nucleo.DesignacionArbitral AS d
        INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido
        WHERE d.IdDesignacionArbitral = @idDesignacionArbitral;

        IF @fechaPartido IS NULL
            SET @errores += N'- La designación arbitral indicada no existe.' + @salto;
        ELSE IF @fechaEfectiva < @fechaPartido
            SET @errores += N'- La fecha de la sanción/informe no puede ser anterior a la fecha del partido.' + @salto;

        IF @tipo IS NULL OR @tipo NOT IN ('Suspension Temporal', 'Inhabilitacion', 'Multa', 'Advertencia', 'Informe')
            SET @errores += N'- El tipo es obligatorio y debe ser: Suspension Temporal, Inhabilitacion, Multa, Advertencia o Informe.' + @salto;

        IF @descripcion IS NULL OR @descripcion = ''
            SET @errores += N'- La descripción de la sanción o informe es obligatoria.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Sancion (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Sancion (IdDesignacionArbitral, Tipo, Descripcion, Fecha)
            VALUES (@idDesignacionArbitral, @tipo, @descripcion, @fechaEfectiva);

            SET @idSancion = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Sancion
            SET IdDesignacionArbitral = @idDesignacionArbitral,
                Tipo                  = @tipo,
                Descripcion           = @descripcion,
                Fecha                 = @fechaEfectiva
            WHERE IdSancion = @idSancion;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Sancion
            WHERE IdSancion = @idSancion;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO