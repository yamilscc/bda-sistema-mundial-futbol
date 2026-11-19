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
    @idConfederacion INT         = NULL OUTPUT,
    @nombre          VARCHAR(60) = NULL,
    @sigla           VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombre    = LTRIM(RTRIM(@nombre));
    SET @sigla     = UPPER(LTRIM(RTRIM(@sigla)));

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
            INSERT INTO nucleo.Confederacion (Nombre, Sigla)
            VALUES (@nombre, @sigla);

            SET @idConfederacion = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Confederacion
            SET Nombre = @nombre,
                Sigla  = @sigla
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
    @operacion       VARCHAR(12),
    @idPais          INT           = NULL OUTPUT,
    @nombre          VARCHAR(80)   = NULL,
    @codigoISO2      CHAR(2)       = NULL,
    @codigoISO3      CHAR(3)       = NULL,
    @idConfederacion INT           = NULL,
    @zonaHoraria     VARCHAR(60)   = NULL,
    @pbiPerCapita    DECIMAL(12,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion   = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombre      = LTRIM(RTRIM(@nombre));
    SET @codigoISO2  = UPPER(LTRIM(RTRIM(@codigoISO2)));
    SET @codigoISO3  = UPPER(LTRIM(RTRIM(@codigoISO3)));
    SET @zonaHoraria = LTRIM(RTRIM(@zonaHoraria));

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

        IF @codigoISO2 IS NULL OR LEN(@codigoISO2) <> 2
            SET @errores += N'- El código ISO2 es obligatorio y debe tener exactamente 2 caracteres.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Pais
                        WHERE CodigoISO2 = @codigoISO2
                          AND (@operacion = 'ALTA' OR IdPais <> @idPais))
            SET @errores += N'- Ya existe otro país con ese código ISO2.' + @salto;

        IF @codigoISO3 IS NULL OR LEN(@codigoISO3) <> 3
            SET @errores += N'- El código ISO3 es obligatorio y debe tener exactamente 3 caracteres.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Pais
                        WHERE CodigoISO3 = @codigoISO3
                          AND (@operacion = 'ALTA' OR IdPais <> @idPais))
            SET @errores += N'- Ya existe otro país con ese código ISO3.' + @salto;

        IF @idConfederacion IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Confederacion WHERE IdConfederacion = @idConfederacion)
            SET @errores += N'- La confederación indicada no existe.' + @salto;

        IF @zonaHoraria IS NULL
           OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @zonaHoraria)
            SET @errores += N'- La zona horaria no es válida (debe existir en sys.time_zone_info).' + @salto;

        IF @pbiPerCapita IS NOT NULL AND @pbiPerCapita < 0
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
            INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, ZonaHoraria, PBIPerCapita)
            VALUES (@nombre, @codigoISO2, @codigoISO3, @idConfederacion, @zonaHoraria, @pbiPerCapita);

            SET @idPais = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Pais
            SET Nombre          = @nombre,
                CodigoISO2      = @codigoISO2,
                CodigoISO3      = @codigoISO3,
                IdConfederacion = @idConfederacion,
                ZonaHoraria     = @zonaHoraria,
                PBIPerCapita    = @pbiPerCapita
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
    @operacion VARCHAR(12),
    @idCiudad  INT         = NULL OUTPUT,
    @nombre    VARCHAR(80) = NULL,
    @idPais    INT         = NULL
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
            INSERT INTO nucleo.Ciudad (Nombre, IdPais)
            VALUES (@nombre, @idPais);

            SET @idCiudad = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Ciudad
            SET Nombre = @nombre,
                IdPais = @idPais
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
    @descripcion    VARCHAR(30) = NULL,
    @orden          INT         = NULL,
    @esEliminatoria BIT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion   = UPPER(LTRIM(RTRIM(@operacion)));
    SET @descripcion = LTRIM(RTRIM(@descripcion));

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
        IF @descripcion IS NULL
           OR @descripcion NOT IN ('Grupos', 'Dieciseisavos', 'Octavos', 'Cuartos', 'Semifinal', 'Tercer puesto', 'Final')
            SET @errores += N'- La descripción es obligatoria y debe ser: Grupos, Dieciseisavos, Octavos, Cuartos, Semifinal, Tercer puesto o Final.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Fase
                        WHERE Descripcion = @descripcion
                          AND (@operacion = 'ALTA' OR IdFase <> @idFase))
            SET @errores += N'- Ya existe otra fase con esa descripción.' + @salto;

        IF @orden IS NULL OR @orden <= 0
            SET @errores += N'- El orden es obligatorio y debe ser mayor a cero.' + @salto;
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
            INSERT INTO nucleo.Fase (Descripcion, Orden, EsEliminatoria)
            VALUES (@descripcion, @orden, @esEliminatoria);

            SET @idFase = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Fase
            SET Descripcion    = @descripcion,
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
    SET @nombre    = LTRIM(RTRIM(@nombre));

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
        IF @nombre IS NULL OR @nombre = ''
            SET @errores += N'- El nombre del grupo es obligatorio.' + @salto;
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
    @idSeleccion INT = NULL OUTPUT,
    @idPais      INT = NULL,
    @idGrupo     INT = NULL
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
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idSeleccion IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccion)
            SET @errores += N'- La selección indicada no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @idPais IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
            SET @errores += N'- El país indicado no existe.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Seleccion
                        WHERE IdPais = @idPais
                          AND (@operacion = 'ALTA' OR IdSeleccion <> @idSeleccion))
            SET @errores += N'- Ya existe otra selección registrada para ese país.' + @salto;

        IF @idGrupo IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE IdGrupo = @idGrupo)
            SET @errores += N'- El grupo indicado no existe.' + @salto;
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
            INSERT INTO nucleo.Seleccion (IdPais, IdGrupo)
            VALUES (@idPais, @idGrupo);

            SET @idSeleccion = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Seleccion
            SET IdPais  = @idPais,
                IdGrupo = @idGrupo
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
-- Respeta el índice único filtrado UQ_StaffTecnico_DirectorTecnico (un solo DT por selección).
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_StaffTecnico
    @operacion      VARCHAR(12),
    @idStaffTecnico INT         = NULL OUTPUT,
    @idSeleccion    INT         = NULL,
    @nombre         VARCHAR(60) = NULL,
    @apellido       VARCHAR(60) = NULL,
    @documento      VARCHAR(20) = NULL,
    @rol            VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombre    = LTRIM(RTRIM(@nombre));
    SET @apellido  = LTRIM(RTRIM(@apellido));
    SET @documento = LTRIM(RTRIM(@documento));
    SET @rol       = LTRIM(RTRIM(@rol));

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

        IF @nombre IS NULL OR @nombre = ''
            SET @errores += N'- El nombre es obligatorio.' + @salto;

        IF @apellido IS NULL OR @apellido = ''
            SET @errores += N'- El apellido es obligatorio.' + @salto;

        IF @documento IS NULL OR @documento = ''
            SET @errores += N'- El documento es obligatorio.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.StaffTecnico
                        WHERE Documento = @documento
                          AND (@operacion = 'ALTA' OR IdStaffTecnico <> @idStaffTecnico))
            SET @errores += N'- Ya existe otro integrante del staff técnico con ese documento.' + @salto;

        IF @rol IS NULL OR @rol NOT IN ('Director Tecnico', 'Ayudante')
            SET @errores += N'- El rol es obligatorio y debe ser: Director Tecnico o Ayudante.' + @salto;
        ELSE IF @rol = 'Director Tecnico'
                AND @idSeleccion IS NOT NULL
                AND EXISTS (SELECT 1
                            FROM nucleo.StaffTecnico
                            WHERE IdSeleccion = @idSeleccion
                              AND Rol = 'Director Tecnico'
                              AND (@operacion = 'ALTA' OR IdStaffTecnico <> @idStaffTecnico))
            SET @errores += N'- La selección ya tiene asignado un Director Tecnico.' + @salto;
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
            INSERT INTO nucleo.StaffTecnico (IdSeleccion, Nombre, Apellido, Documento, Rol)
            VALUES (@idSeleccion, @nombre, @apellido, @documento, @rol);

            SET @idStaffTecnico = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.StaffTecnico
            SET IdSeleccion = @idSeleccion,
                Nombre      = @nombre,
                Apellido    = @apellido,
                Documento   = @documento,
                Rol         = @rol
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
    @idIdioma  INT         = NULL OUTPUT,
    @nombre    VARCHAR(40) = NULL
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
    @idCategoria INT         = NULL OUTPUT,
    @descripcion VARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion   = UPPER(LTRIM(RTRIM(@operacion)));
    SET @descripcion = LTRIM(RTRIM(@descripcion));

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
        IF @descripcion IS NULL OR @descripcion = ''
            SET @errores += N'- La descripción de la categoría es obligatoria.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Categoria
                        WHERE Descripcion = @descripcion
                          AND (@operacion = 'ALTA' OR IdCategoria <> @idCategoria))
            SET @errores += N'- Ya existe otra categoría con esa descripción.' + @salto;
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
            INSERT INTO nucleo.Categoria (Descripcion)
            VALUES (@descripcion);

            SET @idCategoria = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Categoria
            SET Descripcion = @descripcion
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
    @idArbitro       INT         = NULL OUTPUT,
    @nombre          VARCHAR(60) = NULL,
    @apellido        VARCHAR(60) = NULL,
    @documento       VARCHAR(20) = NULL,
    @fechaNacimiento DATE        = NULL,
    @idPais          INT         = NULL,
    @idCategoria     INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombre    = LTRIM(RTRIM(@nombre));
    SET @apellido  = LTRIM(RTRIM(@apellido));
    SET @documento = LTRIM(RTRIM(@documento));

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
        IF @nombre IS NULL OR @nombre = ''
            SET @errores += N'- El nombre del árbitro es obligatorio.' + @salto;

        IF @apellido IS NULL OR @apellido = ''
            SET @errores += N'- El apellido del árbitro es obligatorio.' + @salto;

        IF @documento IS NULL OR @documento = ''
            SET @errores += N'- El documento del árbitro es obligatorio.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM nucleo.Arbitro
                        WHERE Documento = @documento
                          AND (@operacion = 'ALTA' OR IdArbitro <> @idArbitro))
            SET @errores += N'- Ya existe otro árbitro con ese documento.' + @salto;

        IF @fechaNacimiento IS NOT NULL AND @fechaNacimiento > CAST(GETDATE() AS DATE)
            SET @errores += N'- La fecha de nacimiento no puede ser futura.' + @salto;

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
            INSERT INTO nucleo.Arbitro (Nombre, Apellido, Documento, FechaNacimiento, IdPais, IdCategoria)
            VALUES (@nombre, @apellido, @documento, @fechaNacimiento, @idPais, @idCategoria);

            SET @idArbitro = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Arbitro
            SET Nombre          = @nombre,
                Apellido        = @apellido,
                Documento       = @documento,
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
    @operacion     VARCHAR(12),
    @idDesignacion INT          = NULL OUTPUT,
    @idPartido     INT          = NULL,
    @idArbitro     INT          = NULL,
    @rol           VARCHAR(15)  = NULL,
    @advertencia   VARCHAR(200) = NULL OUTPUT
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

        SELECT @idDesignacion = d.IdDesignacion
        FROM nucleo.DesignacionArbitral AS d
        WHERE d.IdPartido = @idPartido
          AND d.IdArbitro = @idArbitro;
        RETURN;
    END;

    DECLARE @errores         NVARCHAR(MAX) = N'',
            @mensaje         NVARCHAR(2048),
            @salto           NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartidoActual INT,
            @estadoActual    VARCHAR(10),
            @idFaseDestino   INT,
            @descFaseDestino VARCHAR(50),
            @estadoDestino   VARCHAR(10),
            @idPaisArbitro   INT,
            @rolValido       BIT = 0,
            @maxPorRol       INT;

    SELECT @idPartidoActual = d.IdPartido,
           @estadoActual    = p.Estado
    FROM nucleo.DesignacionArbitral AS d
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido
    WHERE d.IdDesignacion = @idDesignacion;

    -- ---- Validaciones ----------------------------------------------------
    IF @idPartidoActual IS NULL
        SET @errores += N'- La designación arbitral indicada no existe.' + @salto;
    ELSE IF @estadoActual = 'Finalizado'
        SET @errores += N'- El partido de la designación ya está finalizado: no se puede modificar ni eliminar.' + @salto;

    IF @operacion = 'MODIFICACION'
    BEGIN
        SELECT @idFaseDestino   = p.IdFase,
               @descFaseDestino = f.Descripcion,
               @estadoDestino   = p.Estado
        FROM nucleo.Partido AS p
        INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
        WHERE p.IdPartido = @idPartido;

        SELECT @idPaisArbitro = a.IdPais
        FROM nucleo.Arbitro AS a
        WHERE a.IdArbitro = @idArbitro;

        IF @rol IS NULL OR @rol NOT IN ('Principal', 'Asistente', 'Cuarto', 'VAR')
            SET @errores += N'- Rol inválido. Valores permitidos: Principal, Asistente, Cuarto, VAR.' + @salto;
        ELSE
            SET @rolValido = 1;

        IF @idFaseDestino IS NULL
            SET @errores += N'- El partido indicado no existe.' + @salto;
        ELSE IF @estadoDestino = 'Finalizado' AND (@idPartidoActual IS NULL OR @idPartido <> @idPartidoActual)
            SET @errores += N'- El partido destino ya está finalizado.' + @salto;

        IF @idPaisArbitro IS NULL
            SET @errores += N'- El árbitro indicado no existe.' + @salto;

        IF @idFaseDestino IS NOT NULL AND @idPaisArbitro IS NOT NULL
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM jugadores.fn_SeleccionesDelPartido(@idPartido) AS sp
                INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion
                WHERE s.IdPais = @idPaisArbitro
            )
                SET @errores += N'- Designación rechazada: el país del árbitro coincide con el de una de las selecciones del partido.' + @salto;

            IF EXISTS (
                SELECT 1
                FROM nucleo.DesignacionArbitral AS d
                WHERE d.IdPartido = @idPartido
                  AND d.IdArbitro = @idArbitro
                  AND d.IdDesignacion <> @idDesignacion
            )
                SET @errores += N'- El árbitro ya está designado en ese partido.' + @salto;
        END;

        IF @idFaseDestino IS NOT NULL AND @rolValido = 1
        BEGIN
            SET @maxPorRol = CASE @rol WHEN 'Asistente' THEN 2 ELSE 1 END;

            IF (
                SELECT COUNT(*)
                FROM nucleo.DesignacionArbitral AS d
                WHERE d.IdPartido = @idPartido
                  AND d.Rol = @rol
                  AND d.IdDesignacion <> @idDesignacion
            ) >= @maxPorRol
                SET @errores += N'- El partido ya tiene cubiertos los lugares para ese rol.' + @salto;
        END;
    END
    ELSE IF @operacion = 'BAJA' AND @idPartidoActual IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM nucleo.Sancion WHERE IdDesignacion = @idDesignacion)
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
            WHERE IdDesignacion = @idDesignacion;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.DesignacionArbitral
            WHERE IdDesignacion = @idDesignacion;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    IF @operacion = 'MODIFICACION'
       AND @descFaseDestino IN ('Dieciseisavos', 'Octavos', 'Cuartos', 'Semifinal', 'Tercer puesto', 'Final')
       AND EXISTS (
            SELECT 1
            FROM nucleo.Partido AS p
            CROSS APPLY jugadores.fn_SeleccionesDelPartido(p.IdPartido) AS sp
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
    @operacion     VARCHAR(12),
    @idSancion     INT          = NULL OUTPUT,
    @idDesignacion INT          = NULL,
    @tipo          VARCHAR(20)  = NULL,
    @descripcion   VARCHAR(500) = NULL,
    @fecha         DATE         = NULL
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
        SELECT @fechaPartido = CAST(p.FechaHoraLocal AS DATE)
        FROM nucleo.DesignacionArbitral AS d
        INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido
        WHERE d.IdDesignacion = @idDesignacion;

        IF @fechaPartido IS NULL
            SET @errores += N'- La designación arbitral indicada no existe.' + @salto;
        ELSE IF @fechaEfectiva < @fechaPartido
            SET @errores += N'- La fecha de la sanción/informe no puede ser anterior a la fecha del partido.' + @salto;

        IF @tipo IS NULL OR @tipo NOT IN ('Informe', 'Advertencia', 'Multa', 'Suspension')
            SET @errores += N'- El tipo es obligatorio y debe ser: Informe, Advertencia, Multa o Suspension.' + @salto;

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
            INSERT INTO nucleo.Sancion (IdDesignacion, Tipo, Descripcion, Fecha)
            VALUES (@idDesignacion, @tipo, @descripcion, @fechaEfectiva);

            SET @idSancion = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Sancion
            SET IdDesignacion = @idDesignacion,
                Tipo          = @tipo,
                Descripcion   = @descripcion,
                Fecha         = @fechaEfectiva
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