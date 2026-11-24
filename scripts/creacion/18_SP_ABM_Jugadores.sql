/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-16
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Stored procedures ABM del módulo de jugadores, uno por operación y tabla
          (SP_ALTA_<Tabla>, SP_MODIFICACION_<Tabla> y SP_BAJA_<Tabla>) para:
          1. ReglaConvocados   2. ReglaCambios   3. Club   4. Jugador   5. Convocatoria
          6. Baja              7. Formacion      8. FormacionJugador     9. Sustitucion
          Las validaciones que comparten el alta y la modificación (o la modificación y la baja)
          están en funciones jugadores.fn_Validar*: no hay código repetido entre los SP.
          Requiere ejecutados los scripts 01 a 17.
          Test correspondiente: testing/18_Test_SP_ABM_Jugadores.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- FUNCIONES DE VALIDACIÓN COMPARTIDAS
-- Cada una devuelve el texto de las condiciones incumplidas (cada línea empieza con "- " y
-- termina con CHAR(13) + CHAR(10)); cadena vacía si todo está bien. @idExcluido es el registro
-- que se está modificando (NULL en el alta), para no compararlo consigo mismo.
-- =========================================================================

-- Alta y modificación de ReglaConvocados.
CREATE OR ALTER FUNCTION jugadores.fn_ValidarReglaConvocados (@minimo INT, @maximo INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @minimo IS NULL OR @minimo <= 0
        SET @errores += N'- El mínimo de convocados es obligatorio y debe ser mayor a cero.' + @salto;
    IF @maximo IS NULL OR @maximo <= 0
        SET @errores += N'- El máximo de convocados es obligatorio y debe ser mayor a cero.' + @salto;
    IF @minimo IS NOT NULL AND @maximo IS NOT NULL AND @maximo < @minimo
        SET @errores += N'- El máximo de convocados debe ser mayor o igual al mínimo.' + @salto;

    RETURN @errores;
END;
GO

-- Alta y modificación de ReglaCambios.
CREATE OR ALTER FUNCTION jugadores.fn_ValidarReglaCambios
(
    @maxCambiosRegular        INT,
    @maxVentanasRegular       INT,
    @maxCambiosSuplementario  INT,
    @maxVentanasSuplementario INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @maxCambiosRegular IS NULL OR @maxCambiosRegular < 0
        SET @errores += N'- MaxCambiosRegular es obligatorio y no puede ser negativo.' + @salto;
    IF @maxVentanasRegular IS NULL OR @maxVentanasRegular < 0
        SET @errores += N'- MaxVentanasRegular es obligatorio y no puede ser negativo.' + @salto;
    IF @maxCambiosSuplementario IS NULL OR @maxCambiosSuplementario < 0
        SET @errores += N'- MaxCambiosSuplementario es obligatorio y no puede ser negativo.' + @salto;
    IF @maxVentanasSuplementario IS NULL OR @maxVentanasSuplementario < 0
        SET @errores += N'- MaxVentanasSuplementario es obligatorio y no puede ser negativo.' + @salto;

    RETURN @errores;
END;
GO

-- Alta y modificación de Club.
CREATE OR ALTER FUNCTION jugadores.fn_ValidarClub (@idExcluido INT, @nombre VARCHAR(100))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombre IS NULL OR @nombre = ''
        SET @errores += N'- El nombre del club es obligatorio.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM jugadores.Club
                    WHERE Nombre = @nombre
                      AND (@idExcluido IS NULL OR IdClub <> @idExcluido))
        SET @errores += N'- Ya existe otro club con ese nombre.' + @salto;

    RETURN @errores;
END;
GO

-- Alta y modificación de Jugador.
CREATE OR ALTER FUNCTION jugadores.fn_ValidarJugador
(
    @idExcluido      INT,
    @nombre          VARCHAR(60),
    @apellido        VARCHAR(60),
    @documento       VARCHAR(20),
    @fechaNacimiento DATE,
    @sexo            CHAR(1),
    @posicion        VARCHAR(20),
    @idClub          INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombre IS NULL OR @nombre = ''
        SET @errores += N'- El nombre del jugador es obligatorio.' + @salto;
    IF @apellido IS NULL OR @apellido = ''
        SET @errores += N'- El apellido del jugador es obligatorio.' + @salto;

    IF @documento IS NULL OR @documento = ''
        SET @errores += N'- El documento del jugador es obligatorio.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM jugadores.Jugador
                    WHERE Documento = @documento
                      AND (@idExcluido IS NULL OR IdJugador <> @idExcluido))
        SET @errores += N'- Ya existe otro jugador con ese documento.' + @salto;

    IF @fechaNacimiento IS NOT NULL AND @fechaNacimiento > CAST(GETDATE() AS DATE)
        SET @errores += N'- La fecha de nacimiento no puede ser futura.' + @salto;

    IF @sexo IS NULL OR @sexo NOT IN ('M', 'F')
        SET @errores += N'- El sexo debe ser M o F.' + @salto;

    IF @posicion IS NULL OR @posicion NOT IN ('Arquero', 'Defensor', 'Mediocampista', 'Delantero')
        SET @errores += N'- La posición debe ser: Arquero, Defensor, Mediocampista o Delantero.' + @salto;

    IF @idClub IS NOT NULL AND NOT EXISTS (SELECT 1 FROM jugadores.Club WHERE IdClub = @idClub)
        SET @errores += N'- El club indicado no existe.' + @salto;

    RETURN @errores;
END;
GO

-- Modificación y baja de Formacion: la formación existe y su partido no está finalizado.
CREATE OR ALTER FUNCTION jugadores.fn_ValidarFormacionEditable (@idFormacion INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartActual INT,
            @estadoActual VARCHAR(10);

    SELECT @idPartActual = f.IdPartido,
           @estadoActual = p.Estado
    FROM jugadores.Formacion AS f
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = f.IdPartido
    WHERE f.IdFormacion = @idFormacion;

    IF @idPartActual IS NULL
        SET @errores += N'- La formación indicada no existe.' + @salto;
    ELSE IF @estadoActual = 'Finalizado'
        SET @errores += N'- El partido de la formación ya está finalizado: no se puede modificar ni eliminar.' + @salto;

    RETURN @errores;
END;
GO

-- =========================================================================
-- 1. ReglaConvocados
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_ALTA_ReglaConvocados
    @idRegla INT = NULL OUTPUT,
    @minimo  INT = NULL,
    @maximo  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @errores = jugadores.fn_ValidarReglaConvocados(@minimo, @maximo);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_ReglaConvocados - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO jugadores.ReglaConvocados (Minimo, Maximo) VALUES (@minimo, @maximo);
        SET @idRegla = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_MODIFICACION_ReglaConvocados
    @idRegla INT = NULL,
    @minimo  INT = NULL,
    @maximo  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idRegla IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.ReglaConvocados WHERE IdRegla = @idRegla)
        SET @errores += N'- La regla de convocados indicada no existe.' + @salto;

    SET @errores += jugadores.fn_ValidarReglaConvocados(@minimo, @maximo);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_ReglaConvocados - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE jugadores.ReglaConvocados
        SET Minimo = @minimo, Maximo = @maximo
        WHERE IdRegla = @idRegla;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_BAJA_ReglaConvocados
    @idRegla INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idRegla IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.ReglaConvocados WHERE IdRegla = @idRegla)
        SET @errores += N'- La regla de convocados indicada no existe.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_ReglaConvocados - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM jugadores.ReglaConvocados WHERE IdRegla = @idRegla;
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
-- 2. ReglaCambios
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_ALTA_ReglaCambios
    @idRegla                  INT = NULL OUTPUT,
    @maxCambiosRegular        INT = NULL,
    @maxVentanasRegular       INT = NULL,
    @maxCambiosSuplementario  INT = NULL,
    @maxVentanasSuplementario INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @errores = jugadores.fn_ValidarReglaCambios(@maxCambiosRegular, @maxVentanasRegular,
                                                    @maxCambiosSuplementario, @maxVentanasSuplementario);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_ReglaCambios - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO jugadores.ReglaCambios (
            MaxCambiosRegular, MaxVentanasRegular, MaxCambiosSuplementario, MaxVentanasSuplementario
        )
        VALUES (
            @maxCambiosRegular, @maxVentanasRegular, @maxCambiosSuplementario, @maxVentanasSuplementario
        );
        SET @idRegla = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_MODIFICACION_ReglaCambios
    @idRegla                  INT = NULL,
    @maxCambiosRegular        INT = NULL,
    @maxVentanasRegular       INT = NULL,
    @maxCambiosSuplementario  INT = NULL,
    @maxVentanasSuplementario INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idRegla IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.ReglaCambios WHERE IdRegla = @idRegla)
        SET @errores += N'- La regla de cambios indicada no existe.' + @salto;

    SET @errores += jugadores.fn_ValidarReglaCambios(@maxCambiosRegular, @maxVentanasRegular,
                                                     @maxCambiosSuplementario, @maxVentanasSuplementario);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_ReglaCambios - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE jugadores.ReglaCambios
        SET MaxCambiosRegular        = @maxCambiosRegular,
            MaxVentanasRegular       = @maxVentanasRegular,
            MaxCambiosSuplementario  = @maxCambiosSuplementario,
            MaxVentanasSuplementario = @maxVentanasSuplementario
        WHERE IdRegla = @idRegla;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_BAJA_ReglaCambios
    @idRegla INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idRegla IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.ReglaCambios WHERE IdRegla = @idRegla)
        SET @errores += N'- La regla de cambios indicada no existe.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_ReglaCambios - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM jugadores.ReglaCambios WHERE IdRegla = @idRegla;
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
-- 3. Club
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_ALTA_Club
    @idClub INT          = NULL OUTPUT,
    @nombre VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = LTRIM(RTRIM(@nombre));

    SET @errores = jugadores.fn_ValidarClub(NULL, @nombre);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Club - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO jugadores.Club (Nombre) VALUES (@nombre);
        SET @idClub = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_MODIFICACION_Club
    @idClub INT          = NULL,
    @nombre VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = LTRIM(RTRIM(@nombre));

    IF @idClub IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.Club WHERE IdClub = @idClub)
        SET @errores += N'- El club indicado no existe.' + @salto;

    SET @errores += jugadores.fn_ValidarClub(@idClub, @nombre);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Club - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE jugadores.Club SET Nombre = @nombre WHERE IdClub = @idClub;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_BAJA_Club
    @idClub INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idClub IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.Club WHERE IdClub = @idClub)
        SET @errores += N'- El club indicado no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM jugadores.Jugador WHERE IdClub = @idClub)
        SET @errores += N'- El club tiene jugadores asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Club - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM jugadores.Club WHERE IdClub = @idClub;
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
-- 4. Jugador
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_ALTA_Jugador
    @idJugador       INT         = NULL OUTPUT,
    @nombre          VARCHAR(60) = NULL,
    @apellido        VARCHAR(60) = NULL,
    @documento       VARCHAR(20) = NULL,
    @fechaNacimiento DATE        = NULL,
    @sexo            CHAR(1)     = NULL,
    @posicion        VARCHAR(20) = NULL,
    @idClub          INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre    = LTRIM(RTRIM(@nombre));
    SET @apellido  = LTRIM(RTRIM(@apellido));
    SET @documento = LTRIM(RTRIM(@documento));
    SET @sexo      = UPPER(LTRIM(RTRIM(@sexo)));
    SET @posicion  = LTRIM(RTRIM(@posicion));

    SET @errores = jugadores.fn_ValidarJugador(NULL, @nombre, @apellido, @documento, @fechaNacimiento,
                                               @sexo, @posicion, @idClub);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Jugador - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, FechaNacimiento, Sexo, Posicion, IdClub)
        VALUES (@nombre, @apellido, @documento, @fechaNacimiento, @sexo, @posicion, @idClub);
        SET @idJugador = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_MODIFICACION_Jugador
    @idJugador       INT         = NULL,
    @nombre          VARCHAR(60) = NULL,
    @apellido        VARCHAR(60) = NULL,
    @documento       VARCHAR(20) = NULL,
    @fechaNacimiento DATE        = NULL,
    @sexo            CHAR(1)     = NULL,
    @posicion        VARCHAR(20) = NULL,
    @idClub          INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre    = LTRIM(RTRIM(@nombre));
    SET @apellido  = LTRIM(RTRIM(@apellido));
    SET @documento = LTRIM(RTRIM(@documento));
    SET @sexo      = UPPER(LTRIM(RTRIM(@sexo)));
    SET @posicion  = LTRIM(RTRIM(@posicion));

    IF @idJugador IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.Jugador WHERE IdJugador = @idJugador)
        SET @errores += N'- El jugador indicado no existe.' + @salto;

    SET @errores += jugadores.fn_ValidarJugador(@idJugador, @nombre, @apellido, @documento, @fechaNacimiento,
                                                @sexo, @posicion, @idClub);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Jugador - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE jugadores.Jugador
        SET Nombre          = @nombre,
            Apellido        = @apellido,
            Documento       = @documento,
            FechaNacimiento = @fechaNacimiento,
            Sexo            = @sexo,
            Posicion        = @posicion,
            IdClub          = @idClub
        WHERE IdJugador = @idJugador;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_BAJA_Jugador
    @idJugador INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idJugador IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.Jugador WHERE IdJugador = @idJugador)
        SET @errores += N'- El jugador indicado no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM jugadores.Convocatoria WHERE IdJugador = @idJugador)
        SET @errores += N'- El jugador tiene una convocatoria asociada y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM jugadores.FormacionJugador WHERE IdJugador = @idJugador)
        SET @errores += N'- El jugador figura en formaciones de partidos y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM jugadores.Sustitucion WHERE IdJugadorSaliente = @idJugador OR IdJugadorEntrante = @idJugador)
        SET @errores += N'- El jugador registra sustituciones y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM eventos.Gol WHERE IdJugadorAutor = @idJugador OR IdJugadorAsistencia = @idJugador)
        SET @errores += N'- El jugador registra goles o asistencias y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdJugador = @idJugador)
        SET @errores += N'- El jugador registra amonestaciones y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Jugador - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM jugadores.Jugador WHERE IdJugador = @idJugador;
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
-- 5. Convocatoria
-- El alta delega en jugadores.SP_CONVOCAR_JUGADOR; la modificación usa las mismas reglas del alta
-- (jugadores.fn_ValidarConvocatoria).
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_ALTA_Convocatoria
    @idConvocatoria INT  = NULL OUTPUT,
    @idSeleccion    INT  = NULL,
    @idJugador      INT  = NULL,
    @dorsal         INT  = NULL,
    @fechaAlta      DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    EXEC jugadores.SP_CONVOCAR_JUGADOR
        @idSeleccion    = @idSeleccion,
        @idJugador      = @idJugador,
        @dorsal         = @dorsal,
        @fechaAlta      = @fechaAlta,
        @idConvocatoria = @idConvocatoria OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_MODIFICACION_Convocatoria
    @idConvocatoria INT  = NULL,
    @idSeleccion    INT  = NULL,
    @idJugador      INT  = NULL,
    @dorsal         INT  = NULL,
    @fechaAlta      DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores           NVARCHAR(MAX) = N'',
            @mensaje           NVARCHAR(2048),
            @salto             NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @fechaAltaEfectiva DATE          = ISNULL(@fechaAlta, CAST(GETDATE() AS DATE));

    IF NOT EXISTS (SELECT 1 FROM jugadores.Convocatoria WHERE IdConvocatoria = @idConvocatoria)
        SET @errores += N'- La convocatoria indicada no existe.' + @salto;

    SET @errores += jugadores.fn_ValidarConvocatoria(@idSeleccion, @idJugador, @dorsal, @fechaAltaEfectiva, @idConvocatoria);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Convocatoria - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE jugadores.Convocatoria
        SET IdSeleccion = @idSeleccion,
            IdJugador   = @idJugador,
            Dorsal      = @dorsal,
            FechaAlta   = @fechaAltaEfectiva
        WHERE IdConvocatoria = @idConvocatoria;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_BAJA_Convocatoria
    @idConvocatoria INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores         NVARCHAR(MAX) = N'',
            @mensaje         NVARCHAR(2048),
            @salto           NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idJugadorActual INT;

    SELECT @idJugadorActual = c.IdJugador
    FROM jugadores.Convocatoria AS c
    WHERE c.IdConvocatoria = @idConvocatoria;

    IF @idJugadorActual IS NULL
        SET @errores += N'- La convocatoria indicada no existe.' + @salto;
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM jugadores.Baja WHERE IdConvocatoria = @idConvocatoria)
            SET @errores += N'- La convocatoria tiene una baja registrada asociada y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM jugadores.FormacionJugador WHERE IdJugador = @idJugadorActual)
            SET @errores += N'- El jugador ya participó en formaciones de partidos y no puede borrarse su convocatoria.' + @salto;
        IF EXISTS (SELECT 1 FROM eventos.Gol WHERE IdJugadorAutor = @idJugadorActual OR IdJugadorAsistencia = @idJugadorActual)
            SET @errores += N'- El jugador tiene goles o asistencias registrados.' + @salto;
        IF EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdJugador = @idJugadorActual)
            SET @errores += N'- El jugador tiene amonestaciones registradas.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Convocatoria - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM jugadores.Convocatoria WHERE IdConvocatoria = @idConvocatoria;
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
-- 6. Baja (de una convocatoria)
-- El alta delega en jugadores.SP_REGISTRAR_BAJA_CONVOCATORIA.
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_ALTA_Baja
    @idBaja         INT          = NULL OUTPUT,
    @idConvocatoria INT          = NULL,
    @fechaBaja      DATE         = NULL,
    @motivo         VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    EXEC jugadores.SP_REGISTRAR_BAJA_CONVOCATORIA
        @idConvocatoria = @idConvocatoria,
        @motivo         = @motivo,
        @fechaBaja      = @fechaBaja,
        @idBaja         = @idBaja OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_MODIFICACION_Baja
    @idBaja         INT          = NULL,
    @idConvocatoria INT          = NULL,
    @fechaBaja      DATE         = NULL,
    @motivo         VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores           NVARCHAR(MAX) = N'',
            @mensaje           NVARCHAR(2048),
            @salto             NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @fechaAltaConv     DATE,
            @fechaBajaEfectiva DATE          = ISNULL(@fechaBaja, CAST(GETDATE() AS DATE));

    IF NOT EXISTS (SELECT 1 FROM jugadores.Baja WHERE IdBaja = @idBaja)
        SET @errores += N'- La baja indicada no existe.' + @salto;

    SELECT @fechaAltaConv = c.FechaAlta
    FROM jugadores.Convocatoria AS c
    WHERE c.IdConvocatoria = @idConvocatoria;

    IF @fechaAltaConv IS NULL
        SET @errores += N'- La convocatoria indicada no existe.' + @salto;
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM jugadores.Baja WHERE IdConvocatoria = @idConvocatoria AND IdBaja <> @idBaja)
            SET @errores += N'- Esa convocatoria ya tiene otra baja registrada.' + @salto;
        IF @fechaBajaEfectiva < @fechaAltaConv
            SET @errores += N'- La fecha de baja no puede ser anterior a la fecha de alta de la convocatoria.' + @salto;
    END;

    IF @motivo IS NULL OR LEN(LTRIM(RTRIM(@motivo))) = 0
        SET @errores += N'- El motivo de la baja es obligatorio.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Baja - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE jugadores.Baja
        SET IdConvocatoria = @idConvocatoria,
            FechaBaja      = @fechaBajaEfectiva,
            Motivo         = LTRIM(RTRIM(@motivo))
        WHERE IdBaja = @idBaja;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_BAJA_Baja
    @idBaja INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores           NVARCHAR(MAX) = N'',
            @mensaje           NVARCHAR(2048),
            @salto             NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idConvActual      INT,
            @idSeleccion       INT,
            @maxConvocados     INT,
            @convocadosActivos INT;

    SELECT @idConvActual = b.IdConvocatoria,
           @idSeleccion  = c.IdSeleccion
    FROM jugadores.Baja AS b
    INNER JOIN jugadores.Convocatoria AS c ON c.IdConvocatoria = b.IdConvocatoria
    WHERE b.IdBaja = @idBaja;

    IF @idConvActual IS NULL
        SET @errores += N'- La baja indicada no existe.' + @salto;
    ELSE
    BEGIN
        -- Si se elimina la baja, el jugador vuelve a estar activo: validar que no supere el tope de ReglaConvocados.
        SELECT TOP (1) @maxConvocados = r.Maximo FROM jugadores.ReglaConvocados AS r ORDER BY r.IdRegla;

        SELECT @convocadosActivos = COUNT(*)
        FROM jugadores.Convocatoria AS c
        WHERE c.IdSeleccion = @idSeleccion
          AND NOT EXISTS (SELECT 1 FROM jugadores.Baja AS b WHERE b.IdConvocatoria = c.IdConvocatoria);

        IF @maxConvocados IS NOT NULL AND @convocadosActivos >= @maxConvocados
            SET @errores += N'- No se puede anular la baja porque la selección ya tiene cubierto el cupo máximo de convocados activos ('
                            + CAST(@maxConvocados AS NVARCHAR(10)) + N').' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Baja - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM jugadores.Baja WHERE IdBaja = @idBaja;
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
-- 7. Formacion
-- El alta delega en jugadores.SP_REGISTRAR_FORMACION; la modificación y la baja exigen que el
-- partido no esté finalizado (jugadores.fn_ValidarFormacionEditable).
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_ALTA_Formacion
    @idFormacion    INT         = NULL OUTPUT,
    @idPartido      INT         = NULL,
    @localia        VARCHAR(9)  = NULL,
    @esquemaTactico VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    EXEC jugadores.SP_REGISTRAR_FORMACION
        @idPartido      = @idPartido,
        @localia        = @localia,
        @esquemaTactico = @esquemaTactico,
        @idFormacion    = @idFormacion OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_MODIFICACION_Formacion
    @idFormacion    INT         = NULL,
    @idPartido      INT         = NULL,
    @localia        VARCHAR(9)  = NULL,
    @esquemaTactico VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores       NVARCHAR(MAX),
            @mensaje       NVARCHAR(2048),
            @salto         NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartActual  INT,
            @estadoDestino VARCHAR(10);

    SET @errores = jugadores.fn_ValidarFormacionEditable(@idFormacion);

    SELECT @idPartActual = f.IdPartido FROM jugadores.Formacion AS f WHERE f.IdFormacion = @idFormacion;
    SELECT @estadoDestino = p.Estado FROM nucleo.Partido AS p WHERE p.IdPartido = @idPartido;

    IF @estadoDestino IS NULL
        SET @errores += N'- El partido indicado no existe.' + @salto;
    ELSE IF @estadoDestino = 'Finalizado' AND (@idPartActual IS NULL OR @idPartido <> @idPartActual)
        SET @errores += N'- El partido destino ya está finalizado.' + @salto;

    IF @localia IS NULL OR @localia NOT IN ('Local', 'Visitante')
        SET @errores += N'- La localía debe ser Local o Visitante.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM jugadores.Formacion
                    WHERE IdPartido = @idPartido
                      AND Localia = @localia
                      AND IdFormacion <> @idFormacion)
        SET @errores += N'- Ya existe otra formación para esa localía en el partido.' + @salto;

    IF @esquemaTactico IS NULL OR jugadores.fn_EsquemaValido(@esquemaTactico) = 0
        SET @errores += N'- El esquema táctico debe tener formato válido y sus líneas deben sumar 10.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Formacion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE jugadores.Formacion
        SET IdPartido      = @idPartido,
            Localia        = @localia,
            EsquemaTactico = @esquemaTactico
        WHERE IdFormacion = @idFormacion;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_BAJA_Formacion
    @idFormacion INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @errores = jugadores.fn_ValidarFormacionEditable(@idFormacion);

    IF EXISTS (SELECT 1 FROM jugadores.FormacionJugador WHERE IdFormacion = @idFormacion)
        SET @errores += N'- La formación tiene jugadores cargados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Formacion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM jugadores.Formacion WHERE IdFormacion = @idFormacion;
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
-- 8. FormacionJugador
-- El alta delega en jugadores.SP_AGREGAR_JUGADOR_FORMACION; la modificación usa las mismas reglas
-- del alta (jugadores.fn_ValidarFormacionJugador).
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_ALTA_FormacionJugador
    @idFormacion       INT,
    @idJugador         INT,
    @estadoTitularidad VARCHAR(8)  = NULL,
    @posicionEnCampo   VARCHAR(20) = NULL,
    @dorsal            INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    EXEC jugadores.SP_AGREGAR_JUGADOR_FORMACION
        @idFormacion       = @idFormacion,
        @idJugador         = @idJugador,
        @estadoTitularidad = @estadoTitularidad,
        @posicionEnCampo   = @posicionEnCampo,
        @dorsal            = @dorsal;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_MODIFICACION_FormacionJugador
    @idFormacion       INT,
    @idJugador         INT,
    @estadoTitularidad VARCHAR(8)  = NULL,
    @posicionEnCampo   VARCHAR(20) = NULL,
    @dorsal            INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores        NVARCHAR(MAX) = N'',
            @mensaje        NVARCHAR(2048),
            @salto          NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @dorsalEfectivo INT           = @dorsal;

    IF NOT EXISTS (SELECT 1 FROM jugadores.FormacionJugador WHERE IdFormacion = @idFormacion AND IdJugador = @idJugador)
        SET @errores += N'- El jugador indicado no forma parte de esa formación.' + @salto;

    IF @dorsalEfectivo IS NULL
        SELECT @dorsalEfectivo = c.Dorsal
        FROM jugadores.Convocatoria AS c
        WHERE c.IdJugador = @idJugador;

    SET @errores += jugadores.fn_ValidarFormacionJugador(
        @idFormacion,
        @idJugador,
        @estadoTitularidad,
        @posicionEnCampo,
        @dorsalEfectivo,
        1
    );

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_FormacionJugador - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE jugadores.FormacionJugador
        SET EstadoTitularidad = @estadoTitularidad,
            PosicionEnCampo   = @posicionEnCampo,
            Dorsal            = @dorsalEfectivo
        WHERE IdFormacion = @idFormacion
          AND IdJugador   = @idJugador;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_BAJA_FormacionJugador
    @idFormacion INT,
    @idJugador   INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores       NVARCHAR(MAX) = N'',
            @mensaje       NVARCHAR(2048),
            @salto         NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartido     INT,
            @estadoPartido VARCHAR(10);

    SELECT @idPartido     = f.IdPartido,
           @estadoPartido = p.Estado
    FROM jugadores.FormacionJugador AS fj
    INNER JOIN jugadores.Formacion AS f ON f.IdFormacion = fj.IdFormacion
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = f.IdPartido
    WHERE fj.IdFormacion = @idFormacion
      AND fj.IdJugador   = @idJugador;

    IF @idPartido IS NULL
        SET @errores += N'- El jugador indicado no forma parte de esa formación.' + @salto;
    ELSE
    BEGIN
        IF @estadoPartido = 'Finalizado'
            SET @errores += N'- El partido ya está finalizado: no se puede eliminar al jugador de la formación.' + @salto;

        IF EXISTS (SELECT 1
                   FROM jugadores.Sustitucion
                   WHERE IdPartido = @idPartido
                     AND (IdJugadorSaliente = @idJugador OR IdJugadorEntrante = @idJugador))
            SET @errores += N'- El jugador participa en una sustitución del partido y no puede quitarse de la formación.' + @salto;

        IF EXISTS (SELECT 1
                   FROM eventos.Gol
                   WHERE IdPartido = @idPartido
                     AND (IdJugadorAutor = @idJugador OR IdJugadorAsistencia = @idJugador))
            SET @errores += N'- El jugador registra goles o asistencias en el partido.' + @salto;

        IF EXISTS (SELECT 1
                   FROM eventos.Amonestacion
                   WHERE IdPartido = @idPartido
                     AND IdJugador = @idJugador)
            SET @errores += N'- El jugador registra tarjetas en el partido.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_FormacionJugador - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM jugadores.FormacionJugador
        WHERE IdFormacion = @idFormacion
          AND IdJugador   = @idJugador;
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
-- 9. Sustitucion
-- El alta delega en jugadores.SP_REGISTRAR_SUSTITUCION; la modificación usa las mismas reglas del
-- alta (jugadores.fn_ValidarSustitucion).
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_ALTA_Sustitucion
    @idSustitucion       INT         = NULL OUTPUT,
    @idPartido           INT         = NULL,
    @idJugadorSaliente   INT         = NULL,
    @idJugadorEntrante   INT         = NULL,
    @minuto              INT         = NULL,
    @periodo             VARCHAR(13) = NULL,
    @motivo              VARCHAR(10) = NULL,
    @permitirFechaFutura BIT         = 0
AS
BEGIN
    SET NOCOUNT ON;

    EXEC jugadores.SP_REGISTRAR_SUSTITUCION
        @idPartido           = @idPartido,
        @idJugadorSaliente   = @idJugadorSaliente,
        @idJugadorEntrante   = @idJugadorEntrante,
        @minuto              = @minuto,
        @periodo             = @periodo,
        @motivo              = @motivo,
        @permitirFechaFutura = @permitirFechaFutura,
        @idSustitucion       = @idSustitucion OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_MODIFICACION_Sustitucion
    @idSustitucion       INT         = NULL,
    @idPartido           INT         = NULL,
    @idJugadorSaliente   INT         = NULL,
    @idJugadorEntrante   INT         = NULL,
    @minuto              INT         = NULL,
    @periodo             VARCHAR(13) = NULL,
    @motivo              VARCHAR(10) = NULL,
    @permitirFechaFutura BIT         = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores         NVARCHAR(MAX) = N'',
            @mensaje         NVARCHAR(2048),
            @salto           NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartidoActual INT,
            @estadoActual    VARCHAR(10);

    SELECT @idPartidoActual = s.IdPartido,
           @estadoActual    = p.Estado
    FROM jugadores.Sustitucion AS s
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = s.IdPartido
    WHERE s.IdSustitucion = @idSustitucion;

    IF @idPartidoActual IS NULL
        SET @errores += N'- La sustitución indicada no existe.' + @salto;
    ELSE IF @estadoActual = 'Finalizado' AND @idPartido <> @idPartidoActual
        SET @errores += N'- El partido de la sustitución ya está finalizado: no se puede modificar ni eliminar.' + @salto;

    SET @errores += jugadores.fn_ValidarSustitucion(
        @idPartido,
        @idJugadorSaliente,
        @idJugadorEntrante,
        @minuto,
        @periodo,
        @motivo,
        @permitirFechaFutura,
        @idSustitucion
    );

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Sustitucion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE jugadores.Sustitucion
        SET IdPartido         = @idPartido,
            IdJugadorSaliente = @idJugadorSaliente,
            IdJugadorEntrante = @idJugadorEntrante,
            Minuto            = @minuto,
            Periodo           = @periodo,
            Motivo            = @motivo
        WHERE IdSustitucion = @idSustitucion;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_BAJA_Sustitucion
    @idSustitucion INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores          NVARCHAR(MAX) = N'',
            @mensaje          NVARCHAR(2048),
            @salto            NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartidoActual  INT,
            @idEntranteActual INT,
            @estadoActual     VARCHAR(10);

    SELECT @idPartidoActual  = s.IdPartido,
           @idEntranteActual = s.IdJugadorEntrante,
           @estadoActual     = p.Estado
    FROM jugadores.Sustitucion AS s
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = s.IdPartido
    WHERE s.IdSustitucion = @idSustitucion;

    IF @idPartidoActual IS NULL
        SET @errores += N'- La sustitución indicada no existe.' + @salto;
    ELSE
    BEGIN
        IF @estadoActual = 'Finalizado'
            SET @errores += N'- El partido de la sustitución ya está finalizado: no se puede modificar ni eliminar.' + @salto;

        IF EXISTS (SELECT 1
                   FROM jugadores.Sustitucion AS s2
                   WHERE s2.IdPartido = @idPartidoActual
                     AND s2.IdJugadorSaliente = @idEntranteActual)
            SET @errores += N'- No se puede eliminar la sustitución porque el jugador entrante fue posteriormente reemplazado.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Sustitucion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM jugadores.Sustitucion WHERE IdSustitucion = @idSustitucion;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
