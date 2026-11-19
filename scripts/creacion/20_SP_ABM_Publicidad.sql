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
Objetivo: Stored procedures ABM del módulo de publicidad:
          1. publicidad.SP_ABM_Moneda
          2. publicidad.SP_ABM_Anunciante
          3. publicidad.SP_ABM_Pieza
          4. publicidad.SP_ABM_OrientacionPais
          5. publicidad.SP_ABM_EspacioPublicitario
          Requiere ejecutados los scripts 01 a 19.
          Test correspondiente: testing/20_Test_SP_ABM_Publicidad.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. SP_ABM_Moneda
-- Valida el código ISO 4217 con collation binaria (3 letras mayúsculas A-Z).
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_ABM_Moneda
    @operacion VARCHAR(12),
    @idMoneda  INT         = NULL OUTPUT,
    @codigo    CHAR(3)     = NULL,
    @nombre    VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @codigo    = UPPER(LTRIM(RTRIM(@codigo)));
    SET @nombre    = LTRIM(RTRIM(@nombre));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idMoneda IS NULL
           OR NOT EXISTS (SELECT 1 FROM publicidad.Moneda WHERE IdMoneda = @idMoneda)
            SET @errores += N'- La moneda indicada no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @codigo IS NULL
           OR LEN(@codigo) <> 3
           OR @codigo COLLATE Latin1_General_BIN2 NOT LIKE '[A-Z][A-Z][A-Z]'
            SET @errores += N'- El código ISO 4217 es obligatorio y debe tener 3 letras mayúsculas (ej. USD, ARS, EUR).' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM publicidad.Moneda
                        WHERE Codigo = @codigo
                          AND (@operacion = 'ALTA' OR IdMoneda <> @idMoneda))
            SET @errores += N'- Ya existe otra moneda con ese código.' + @salto;

        IF @nombre IS NULL OR @nombre = ''
            SET @errores += N'- El nombre de la moneda es obligatorio.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM publicidad.Moneda
                        WHERE Nombre = @nombre
                          AND (@operacion = 'ALTA' OR IdMoneda <> @idMoneda))
            SET @errores += N'- Ya existe otra moneda con ese nombre.' + @salto;
    END;

    IF @operacion = 'BAJA'
       AND EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdMoneda = @idMoneda)
        SET @errores += N'- La moneda está asociada a espacios publicitarios facturados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Moneda (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO publicidad.Moneda (Codigo, Nombre)
            VALUES (@codigo, @nombre);

            SET @idMoneda = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE publicidad.Moneda
            SET Codigo = @codigo,
                Nombre = @nombre
            WHERE IdMoneda = @idMoneda;
        END
        ELSE
        BEGIN
            DELETE FROM publicidad.Moneda
            WHERE IdMoneda = @idMoneda;
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
-- 2. SP_ABM_Anunciante
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_ABM_Anunciante
    @operacion    VARCHAR(12),
    @idAnunciante INT          = NULL OUTPUT,
    @nombre       VARCHAR(100) = NULL,
    @idPais       INT          = NULL
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
        IF @idAnunciante IS NULL
           OR NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE IdAnunciante = @idAnunciante)
            SET @errores += N'- El anunciante indicado no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombre IS NULL OR @nombre = ''
            SET @errores += N'- El nombre del anunciante es obligatorio.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM publicidad.Anunciante
                        WHERE Nombre = @nombre
                          AND (@operacion = 'ALTA' OR IdAnunciante <> @idAnunciante))
            SET @errores += N'- Ya existe otro anunciante con ese nombre.' + @salto;

        IF @idPais IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
            SET @errores += N'- El país de origen indicado no existe.' + @salto;
    END;

    IF @operacion = 'BAJA'
       AND EXISTS (SELECT 1 FROM publicidad.Pieza WHERE IdAnunciante = @idAnunciante)
        SET @errores += N'- El anunciante tiene piezas publicitarias asociadas y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Anunciante (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO publicidad.Anunciante (Nombre, IdPais)
            VALUES (@nombre, @idPais);

            SET @idAnunciante = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE publicidad.Anunciante
            SET Nombre = @nombre,
                IdPais = @idPais
            WHERE IdAnunciante = @idAnunciante;
        END
        ELSE
        BEGIN
            DELETE FROM publicidad.Anunciante
            WHERE IdAnunciante = @idAnunciante;
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
-- 3. SP_ABM_Pieza
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_ABM_Pieza
    @operacion    VARCHAR(12),
    @idPieza      INT          = NULL OUTPUT,
    @idAnunciante INT          = NULL,
    @idIdioma     INT          = NULL,
    @titulo       VARCHAR(100) = NULL,
    @descripcion  VARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion   = UPPER(LTRIM(RTRIM(@operacion)));
    SET @titulo      = LTRIM(RTRIM(@titulo));
    SET @descripcion = LTRIM(RTRIM(@descripcion));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idPieza IS NULL
           OR NOT EXISTS (SELECT 1 FROM publicidad.Pieza WHERE IdPieza = @idPieza)
            SET @errores += N'- La pieza publicitaria indicada no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @idAnunciante IS NULL
           OR NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE IdAnunciante = @idAnunciante)
            SET @errores += N'- El anunciante indicado no existe.' + @salto;

        IF @idIdioma IS NULL
           OR NOT EXISTS (SELECT 1 FROM nucleo.Idioma WHERE IdIdioma = @idIdioma)
            SET @errores += N'- El idioma indicado no existe.' + @salto;

        IF @titulo IS NULL OR @titulo = ''
            SET @errores += N'- El título de la pieza publicitaria es obligatorio.' + @salto;

        IF @idAnunciante IS NOT NULL AND @idIdioma IS NOT NULL AND @titulo IS NOT NULL AND @titulo <> ''
           AND EXISTS (SELECT 1
                       FROM publicidad.Pieza
                       WHERE IdAnunciante = @idAnunciante
                         AND Titulo       = @titulo
                         AND IdIdioma     = @idIdioma
                         AND (@operacion = 'ALTA' OR IdPieza <> @idPieza))
            SET @errores += N'- Ya existe otra pieza de ese anunciante con el mismo título e idioma.' + @salto;
    END;

    IF @operacion = 'BAJA'
    BEGIN
        IF EXISTS (SELECT 1 FROM publicidad.OrientacionPais WHERE IdPieza = @idPieza)
            SET @errores += N'- La pieza tiene países de orientación asociados y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdPieza = @idPieza)
            SET @errores += N'- La pieza ya fue exhibida/asignada en espacios publicitarios y no puede eliminarse.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Pieza (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO publicidad.Pieza (IdAnunciante, IdIdioma, Titulo, Descripcion)
            VALUES (@idAnunciante, @idIdioma, @titulo, @descripcion);

            SET @idPieza = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE publicidad.Pieza
            SET IdAnunciante = @idAnunciante,
                IdIdioma     = @idIdioma,
                Titulo       = @titulo,
                Descripcion  = @descripcion
            WHERE IdPieza = @idPieza;
        END
        ELSE
        BEGIN
            DELETE FROM publicidad.Pieza
            WHERE IdPieza = @idPieza;
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
-- 4. SP_ABM_OrientacionPais
-- Tabla asociativa (PK compuesta IdPieza, IdPais): admite ALTA y BAJA.
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_ABM_OrientacionPais
    @operacion VARCHAR(12),
    @idPieza   INT,
    @idPais    INT
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
        SET @errores += N'- La relación OrientacionPais no admite modificación; realice una baja y un alta.' + @salto;

    IF @idPieza IS NULL OR NOT EXISTS (SELECT 1 FROM publicidad.Pieza WHERE IdPieza = @idPieza)
        SET @errores += N'- La pieza publicitaria indicada no existe.' + @salto;

    IF @idPais IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
        SET @errores += N'- El país indicado no existe.' + @salto;

    IF @operacion = 'ALTA'
       AND @idPieza IS NOT NULL AND @idPais IS NOT NULL
       AND EXISTS (SELECT 1 FROM publicidad.OrientacionPais WHERE IdPieza = @idPieza AND IdPais = @idPais)
        SET @errores += N'- La pieza publicitaria ya está orientada a ese país.' + @salto;

    IF @operacion = 'BAJA'
       AND @idPieza IS NOT NULL AND @idPais IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM publicidad.OrientacionPais WHERE IdPieza = @idPieza AND IdPais = @idPais)
        SET @errores += N'- La pieza publicitaria no tiene asociada la orientación a ese país.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_OrientacionPais (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO publicidad.OrientacionPais (IdPieza, IdPais)
            VALUES (@idPieza, @idPais);
        END
        ELSE
        BEGIN
            DELETE FROM publicidad.OrientacionPais
            WHERE IdPieza = @idPieza
              AND IdPais  = @idPais;
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
-- 5. SP_ABM_EspacioPublicitario
-- Entidad débil de Partido (PK compuesta IdPartido, NumeroEspacio entre 1 y 4).
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_ABM_EspacioPublicitario
    @operacion          VARCHAR(12),
    @idPartido          INT,
    @numeroEspacio      TINYINT,
    @idPieza            INT           = NULL,
    @tarifaPublicitaria DECIMAL(12,2) = NULL,
    @idMoneda           INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores       NVARCHAR(MAX) = N'',
            @mensaje       NVARCHAR(2048),
            @salto         NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @existePartido BIT           = 0;

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @idPartido IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @idPartido)
        SET @errores += N'- El partido indicado no existe.' + @salto;
    ELSE
        SET @existePartido = 1;

    IF @numeroEspacio IS NULL OR @numeroEspacio NOT BETWEEN 1 AND 4
        SET @errores += N'- El número de espacio publicitario es obligatorio y debe estar entre 1 y 4.' + @salto;

    IF @existePartido = 1 AND @numeroEspacio BETWEEN 1 AND 4
    BEGIN
        IF @operacion = 'ALTA'
           AND EXISTS (SELECT 1
                       FROM publicidad.EspacioPublicitario
                       WHERE IdPartido = @idPartido AND NumeroEspacio = @numeroEspacio)
            SET @errores += N'- Ese número de espacio ya está ocupado en el partido.' + @salto;

        IF @operacion IN ('MODIFICACION', 'BAJA')
           AND NOT EXISTS (SELECT 1
                           FROM publicidad.EspacioPublicitario
                           WHERE IdPartido = @idPartido AND NumeroEspacio = @numeroEspacio)
            SET @errores += N'- El espacio publicitario indicado no existe para ese partido.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @idPieza IS NULL
           OR NOT EXISTS (SELECT 1 FROM publicidad.Pieza WHERE IdPieza = @idPieza)
            SET @errores += N'- La pieza publicitaria indicada no existe.' + @salto;
        ELSE IF @existePartido = 1
                AND EXISTS (SELECT 1
                            FROM publicidad.EspacioPublicitario
                            WHERE IdPartido = @idPartido
                              AND IdPieza   = @idPieza
                              AND (@operacion = 'ALTA' OR NumeroEspacio <> @numeroEspacio))
            SET @errores += N'- La pieza publicitaria ya está asignada a otro espacio del mismo partido.' + @salto;

        IF @tarifaPublicitaria IS NULL OR @tarifaPublicitaria < 0
            SET @errores += N'- La tarifa publicitaria es obligatoria y no puede ser negativa.' + @salto;

        IF @idMoneda IS NULL
           OR NOT EXISTS (SELECT 1 FROM publicidad.Moneda WHERE IdMoneda = @idMoneda)
            SET @errores += N'- La moneda indicada no existe.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_EspacioPublicitario (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
            VALUES (@idPartido, @numeroEspacio, @idPieza, @tarifaPublicitaria, @idMoneda);
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE publicidad.EspacioPublicitario
            SET IdPieza            = @idPieza,
                TarifaPublicitaria = @tarifaPublicitaria,
                IdMoneda           = @idMoneda
            WHERE IdPartido     = @idPartido
              AND NumeroEspacio = @numeroEspacio;
        END
        ELSE
        BEGIN
            DELETE FROM publicidad.EspacioPublicitario
            WHERE IdPartido     = @idPartido
              AND NumeroEspacio = @numeroEspacio;
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