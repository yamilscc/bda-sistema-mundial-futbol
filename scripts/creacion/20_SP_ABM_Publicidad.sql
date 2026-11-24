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
Objetivo: Stored procedures ABM del módulo de publicidad, uno por operación y tabla
          (SP_ALTA_<Tabla>, SP_MODIFICACION_<Tabla> y SP_BAJA_<Tabla>) para:
          1. Moneda   2. Anunciante   3. Pieza   4. OrientacionPais   5. EspacioPublicitario
          OrientacionPais es una tabla asociativa (PK compuesta): solo tiene alta y baja, no modificación.
          Las validaciones que comparten el alta y la modificación (y la baja) están en funciones
          publicidad.fn_Validar*: no hay código repetido entre los SP.
          Requiere ejecutados los scripts 01 a 19.
          Test correspondiente: testing/20_Test_SP_ABM_Publicidad.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- FUNCIONES DE VALIDACIÓN COMPARTIDAS
-- Cada una devuelve el texto de las condiciones incumplidas (cada línea empieza con "- " y
-- termina con CHAR(13) + CHAR(10)); cadena vacía si todo está bien. @idExcluido es el registro
-- que se está modificando (NULL en el alta), para no compararlo consigo mismo.
-- =========================================================================

-- Moneda (alta y modificación). Valida el código ISO 4217 con collation binaria (3 letras mayúsculas A-Z).
CREATE OR ALTER FUNCTION publicidad.fn_ValidarMoneda (@idExcluido INT, @codigo CHAR(3), @nombre VARCHAR(50))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @codigo IS NULL
       OR LEN(@codigo) <> 3
       OR @codigo COLLATE Latin1_General_BIN2 NOT LIKE '[A-Z][A-Z][A-Z]'
        SET @errores += N'- El código ISO 4217 es obligatorio y debe tener 3 letras mayúsculas (ej. USD, ARS, EUR).' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM publicidad.Moneda
                    WHERE Codigo = @codigo
                      AND (@idExcluido IS NULL OR IdMoneda <> @idExcluido))
        SET @errores += N'- Ya existe otra moneda con ese código.' + @salto;

    IF @nombre IS NULL OR @nombre = ''
        SET @errores += N'- El nombre de la moneda es obligatorio.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM publicidad.Moneda
                    WHERE Nombre = @nombre
                      AND (@idExcluido IS NULL OR IdMoneda <> @idExcluido))
        SET @errores += N'- Ya existe otra moneda con ese nombre.' + @salto;

    RETURN @errores;
END;
GO

-- Anunciante (alta y modificación).
CREATE OR ALTER FUNCTION publicidad.fn_ValidarAnunciante (@idExcluido INT, @nombre VARCHAR(100), @idPais INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombre IS NULL OR @nombre = ''
        SET @errores += N'- El nombre del anunciante es obligatorio.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM publicidad.Anunciante
                    WHERE Nombre = @nombre
                      AND (@idExcluido IS NULL OR IdAnunciante <> @idExcluido))
        SET @errores += N'- Ya existe otro anunciante con ese nombre.' + @salto;

    IF @idPais IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
        SET @errores += N'- El país de origen indicado no existe.' + @salto;

    RETURN @errores;
END;
GO

-- Pieza (alta y modificación).
CREATE OR ALTER FUNCTION publicidad.fn_ValidarPieza (@idExcluido INT, @idAnunciante INT, @idIdioma INT, @titulo VARCHAR(100))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

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
                     AND (@idExcluido IS NULL OR IdPieza <> @idExcluido))
        SET @errores += N'- Ya existe otra pieza de ese anunciante con el mismo título e idioma.' + @salto;

    RETURN @errores;
END;
GO

-- OrientacionPais (alta y baja): la pieza y el país existen.
CREATE OR ALTER FUNCTION publicidad.fn_ValidarOrientacionPais (@idPieza INT, @idPais INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idPieza IS NULL OR NOT EXISTS (SELECT 1 FROM publicidad.Pieza WHERE IdPieza = @idPieza)
        SET @errores += N'- La pieza publicitaria indicada no existe.' + @salto;

    IF @idPais IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
        SET @errores += N'- El país indicado no existe.' + @salto;

    RETURN @errores;
END;
GO

-- EspacioPublicitario, clave (alta, modificación y baja): el partido y el número de espacio (entre 1 y 4) existen o
-- son válidos y, según @debeExistir, el espacio ya está cargado (modificación y baja) o todavía no (alta).
CREATE OR ALTER FUNCTION publicidad.fn_ValidarEspacioClave (@idPartido INT, @numeroEspacio TINYINT, @debeExistir BIT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores       NVARCHAR(MAX) = N'',
            @salto         NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @existePartido BIT           = 0;

    IF @idPartido IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @idPartido)
        SET @errores += N'- El partido indicado no existe.' + @salto;
    ELSE
        SET @existePartido = 1;

    IF @numeroEspacio IS NULL OR @numeroEspacio NOT BETWEEN 1 AND 4
        SET @errores += N'- El número de espacio publicitario es obligatorio y debe estar entre 1 y 4.' + @salto;

    IF @existePartido = 1 AND @numeroEspacio BETWEEN 1 AND 4
    BEGIN
        IF @debeExistir = 0
           AND EXISTS (SELECT 1
                       FROM publicidad.EspacioPublicitario
                       WHERE IdPartido = @idPartido AND NumeroEspacio = @numeroEspacio)
            SET @errores += N'- Ese número de espacio ya está ocupado en el partido.' + @salto;

        IF @debeExistir = 1
           AND NOT EXISTS (SELECT 1
                           FROM publicidad.EspacioPublicitario
                           WHERE IdPartido = @idPartido AND NumeroEspacio = @numeroEspacio)
            SET @errores += N'- El espacio publicitario indicado no existe para ese partido.' + @salto;
    END;

    RETURN @errores;
END;
GO

-- EspacioPublicitario, datos (alta y modificación): pieza, tarifa y moneda. @numeroExcluido es el espacio que se está
-- modificando (NULL en el alta), para que la pieza no se compare con su propio espacio.
CREATE OR ALTER FUNCTION publicidad.fn_ValidarEspacioDatos
(
    @idPartido          INT,
    @numeroExcluido     TINYINT,
    @idPieza            INT,
    @tarifaPublicitaria DECIMAL(12,2),
    @idMoneda           INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idPieza IS NULL
       OR NOT EXISTS (SELECT 1 FROM publicidad.Pieza WHERE IdPieza = @idPieza)
        SET @errores += N'- La pieza publicitaria indicada no existe.' + @salto;
    ELSE IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @idPartido)
            AND EXISTS (SELECT 1
                        FROM publicidad.EspacioPublicitario
                        WHERE IdPartido = @idPartido
                          AND IdPieza   = @idPieza
                          AND (@numeroExcluido IS NULL OR NumeroEspacio <> @numeroExcluido))
        SET @errores += N'- La pieza publicitaria ya está asignada a otro espacio del mismo partido.' + @salto;

    IF @tarifaPublicitaria IS NULL OR @tarifaPublicitaria < 0
        SET @errores += N'- La tarifa publicitaria es obligatoria y no puede ser negativa.' + @salto;

    IF @idMoneda IS NULL
       OR NOT EXISTS (SELECT 1 FROM publicidad.Moneda WHERE IdMoneda = @idMoneda)
        SET @errores += N'- La moneda indicada no existe.' + @salto;

    RETURN @errores;
END;
GO

-- =========================================================================
-- 1. Moneda
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_ALTA_Moneda
    @idMoneda INT         = NULL OUTPUT,
    @codigo   CHAR(3)     = NULL,
    @nombre   VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @codigo = UPPER(LTRIM(RTRIM(@codigo)));
    SET @nombre = LTRIM(RTRIM(@nombre));

    SET @errores = publicidad.fn_ValidarMoneda(NULL, @codigo, @nombre);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Moneda - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO publicidad.Moneda (Codigo, Nombre) VALUES (@codigo, @nombre);
        SET @idMoneda = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.SP_MODIFICACION_Moneda
    @idMoneda INT         = NULL,
    @codigo   CHAR(3)     = NULL,
    @nombre   VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @codigo = UPPER(LTRIM(RTRIM(@codigo)));
    SET @nombre = LTRIM(RTRIM(@nombre));

    IF @idMoneda IS NULL
       OR NOT EXISTS (SELECT 1 FROM publicidad.Moneda WHERE IdMoneda = @idMoneda)
        SET @errores += N'- La moneda indicada no existe.' + @salto;

    SET @errores += publicidad.fn_ValidarMoneda(@idMoneda, @codigo, @nombre);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Moneda - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE publicidad.Moneda
        SET Codigo = @codigo,
            Nombre = @nombre
        WHERE IdMoneda = @idMoneda;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.SP_BAJA_Moneda
    @idMoneda INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idMoneda IS NULL
       OR NOT EXISTS (SELECT 1 FROM publicidad.Moneda WHERE IdMoneda = @idMoneda)
        SET @errores += N'- La moneda indicada no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdMoneda = @idMoneda)
        SET @errores += N'- La moneda está asociada a espacios publicitarios facturados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Moneda - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM publicidad.Moneda WHERE IdMoneda = @idMoneda;
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
-- 2. Anunciante
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_ALTA_Anunciante
    @idAnunciante INT          = NULL OUTPUT,
    @nombre       VARCHAR(100) = NULL,
    @idPais       INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = LTRIM(RTRIM(@nombre));

    SET @errores = publicidad.fn_ValidarAnunciante(NULL, @nombre, @idPais);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Anunciante - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO publicidad.Anunciante (Nombre, IdPais) VALUES (@nombre, @idPais);
        SET @idAnunciante = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.SP_MODIFICACION_Anunciante
    @idAnunciante INT          = NULL,
    @nombre       VARCHAR(100) = NULL,
    @idPais       INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = LTRIM(RTRIM(@nombre));

    IF @idAnunciante IS NULL
       OR NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE IdAnunciante = @idAnunciante)
        SET @errores += N'- El anunciante indicado no existe.' + @salto;

    SET @errores += publicidad.fn_ValidarAnunciante(@idAnunciante, @nombre, @idPais);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Anunciante - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE publicidad.Anunciante
        SET Nombre = @nombre,
            IdPais = @idPais
        WHERE IdAnunciante = @idAnunciante;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.SP_BAJA_Anunciante
    @idAnunciante INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idAnunciante IS NULL
       OR NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE IdAnunciante = @idAnunciante)
        SET @errores += N'- El anunciante indicado no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM publicidad.Pieza WHERE IdAnunciante = @idAnunciante)
        SET @errores += N'- El anunciante tiene piezas publicitarias asociadas y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Anunciante - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM publicidad.Anunciante WHERE IdAnunciante = @idAnunciante;
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
-- 3. Pieza
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_ALTA_Pieza
    @idPieza      INT          = NULL OUTPUT,
    @idAnunciante INT          = NULL,
    @idIdioma     INT          = NULL,
    @titulo       VARCHAR(100) = NULL,
    @descripcion  VARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @titulo      = LTRIM(RTRIM(@titulo));
    SET @descripcion = LTRIM(RTRIM(@descripcion));

    SET @errores = publicidad.fn_ValidarPieza(NULL, @idAnunciante, @idIdioma, @titulo);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Pieza - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO publicidad.Pieza (IdAnunciante, IdIdioma, Titulo, Descripcion)
        VALUES (@idAnunciante, @idIdioma, @titulo, @descripcion);
        SET @idPieza = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.SP_MODIFICACION_Pieza
    @idPieza      INT          = NULL,
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

    SET @titulo      = LTRIM(RTRIM(@titulo));
    SET @descripcion = LTRIM(RTRIM(@descripcion));

    IF @idPieza IS NULL
       OR NOT EXISTS (SELECT 1 FROM publicidad.Pieza WHERE IdPieza = @idPieza)
        SET @errores += N'- La pieza publicitaria indicada no existe.' + @salto;

    SET @errores += publicidad.fn_ValidarPieza(@idPieza, @idAnunciante, @idIdioma, @titulo);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Pieza - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE publicidad.Pieza
        SET IdAnunciante = @idAnunciante,
            IdIdioma     = @idIdioma,
            Titulo       = @titulo,
            Descripcion  = @descripcion
        WHERE IdPieza = @idPieza;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.SP_BAJA_Pieza
    @idPieza INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idPieza IS NULL
       OR NOT EXISTS (SELECT 1 FROM publicidad.Pieza WHERE IdPieza = @idPieza)
        SET @errores += N'- La pieza publicitaria indicada no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM publicidad.OrientacionPais WHERE IdPieza = @idPieza)
        SET @errores += N'- La pieza tiene países de orientación asociados y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdPieza = @idPieza)
        SET @errores += N'- La pieza ya fue exhibida/asignada en espacios publicitarios y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Pieza - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM publicidad.Pieza WHERE IdPieza = @idPieza;
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
-- 4. OrientacionPais
-- Tabla asociativa (PK compuesta IdPieza, IdPais): solo tiene alta y baja (no hay nada que modificar:
-- para cambiar un país se da de baja y de alta).
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_ALTA_OrientacionPais
    @idPieza INT,
    @idPais  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @errores = publicidad.fn_ValidarOrientacionPais(@idPieza, @idPais);

    IF @idPieza IS NOT NULL AND @idPais IS NOT NULL
       AND EXISTS (SELECT 1 FROM publicidad.OrientacionPais WHERE IdPieza = @idPieza AND IdPais = @idPais)
        SET @errores += N'- La pieza publicitaria ya está orientada a ese país.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_OrientacionPais - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO publicidad.OrientacionPais (IdPieza, IdPais) VALUES (@idPieza, @idPais);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.SP_BAJA_OrientacionPais
    @idPieza INT,
    @idPais  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @errores = publicidad.fn_ValidarOrientacionPais(@idPieza, @idPais);

    IF @idPieza IS NOT NULL AND @idPais IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM publicidad.OrientacionPais WHERE IdPieza = @idPieza AND IdPais = @idPais)
        SET @errores += N'- La pieza publicitaria no tiene asociada la orientación a ese país.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_OrientacionPais - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM publicidad.OrientacionPais
        WHERE IdPieza = @idPieza
          AND IdPais  = @idPais;
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
-- 5. EspacioPublicitario
-- Entidad débil de Partido (PK compuesta IdPartido, NumeroEspacio entre 1 y 4).
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_ALTA_EspacioPublicitario
    @idPartido          INT,
    @numeroEspacio      TINYINT,
    @idPieza            INT           = NULL,
    @tarifaPublicitaria DECIMAL(12,2) = NULL,
    @idMoneda           INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @errores = publicidad.fn_ValidarEspacioClave(@idPartido, @numeroEspacio, 0)
                 + publicidad.fn_ValidarEspacioDatos(@idPartido, NULL, @idPieza, @tarifaPublicitaria, @idMoneda);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_EspacioPublicitario - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
        VALUES (@idPartido, @numeroEspacio, @idPieza, @tarifaPublicitaria, @idMoneda);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.SP_MODIFICACION_EspacioPublicitario
    @idPartido          INT,
    @numeroEspacio      TINYINT,
    @idPieza            INT           = NULL,
    @tarifaPublicitaria DECIMAL(12,2) = NULL,
    @idMoneda           INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @errores = publicidad.fn_ValidarEspacioClave(@idPartido, @numeroEspacio, 1)
                 + publicidad.fn_ValidarEspacioDatos(@idPartido, @numeroEspacio, @idPieza, @tarifaPublicitaria, @idMoneda);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_EspacioPublicitario - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE publicidad.EspacioPublicitario
        SET IdPieza            = @idPieza,
            TarifaPublicitaria = @tarifaPublicitaria,
            IdMoneda           = @idMoneda
        WHERE IdPartido     = @idPartido
          AND NumeroEspacio = @numeroEspacio;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.SP_BAJA_EspacioPublicitario
    @idPartido     INT,
    @numeroEspacio TINYINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @errores = publicidad.fn_ValidarEspacioClave(@idPartido, @numeroEspacio, 1);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_EspacioPublicitario - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM publicidad.EspacioPublicitario
        WHERE IdPartido     = @idPartido
          AND NumeroEspacio = @numeroEspacio;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
