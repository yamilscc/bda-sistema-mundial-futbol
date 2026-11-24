/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-15
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Stored procedures ABM del módulo de eventos, uno por operación y tabla:
          - eventos.SP_ALTA_ReglaSuspension, SP_MODIFICACION_ReglaSuspension y SP_BAJA_ReglaSuspension
          - eventos.SP_ALTA_TipoGol, SP_MODIFICACION_TipoGol y SP_BAJA_TipoGol
          - eventos.SP_ALTA_Periodo, SP_MODIFICACION_Periodo y SP_BAJA_Periodo
          - eventos.SP_ALTA_Tarjeta, SP_MODIFICACION_Tarjeta y SP_BAJA_Tarjeta
          - eventos.SP_ALTA_Gol, SP_MODIFICACION_Gol y SP_BAJA_Gol
          - eventos.SP_ALTA_Amonestacion, SP_MODIFICACION_Amonestacion y SP_BAJA_Amonestacion
          Las validaciones que comparten el alta y la modificación (y la modificación con la baja)
          están en funciones eventos.fn_Validar*: no hay código repetido entre los SP.
          Requiere ejecutados los scripts 01 a 12.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- FUNCIONES DE VALIDACIÓN COMPARTIDAS
-- Cada una devuelve el texto de las condiciones incumplidas (cada línea empieza con "- " y
-- termina con CHAR(13) + CHAR(10)); cadena vacía si todo está bien. @idExcluido es el registro
-- que se está modificando (NULL en el alta), para no compararlo consigo mismo.
-- =========================================================================

-- Alta y modificación de ReglaSuspension.
CREATE OR ALTER FUNCTION eventos.fn_ValidarReglaSuspension
(
    @idExcluido         INT,
    @criterio           VARCHAR(40),
    @cantidadAmarillas  INT,
    @partidosSuspension INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @criterio IS NULL OR @criterio NOT IN ('Acumulacion Amarillas', 'Doble Amarilla', 'Roja Directa')
        SET @errores += N'- El criterio es obligatorio y debe ser: Acumulacion Amarillas, Doble Amarilla o Roja Directa.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM eventos.ReglaSuspension
                    WHERE Criterio = @criterio
                      AND (@idExcluido IS NULL OR IdReglaSuspension <> @idExcluido))
        SET @errores += N'- Ya existe otra regla de suspensión para ese criterio.' + @salto;

    IF @partidosSuspension IS NULL OR @partidosSuspension <= 0
        SET @errores += N'- La cantidad de partidos de suspensión es obligatoria y debe ser mayor a cero.' + @salto;

    IF @criterio = 'Acumulacion Amarillas' AND (@cantidadAmarillas IS NULL OR @cantidadAmarillas < 2)
        SET @errores += N'- Para Acumulacion Amarillas la cantidad de amarillas debe ser al menos 2.' + @salto;

    IF @criterio IS NOT NULL AND @criterio <> 'Acumulacion Amarillas' AND @cantidadAmarillas IS NOT NULL
        SET @errores += N'- CantidadAmarillas debe ser NULL cuando el criterio no es Acumulacion Amarillas.' + @salto;

    RETURN @errores;
END;
GO

-- Alta y modificación de TipoGol.
CREATE OR ALTER FUNCTION eventos.fn_ValidarTipoGol (@idExcluido INT, @descripcion VARCHAR(30))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @descripcion IS NULL
       OR @descripcion NOT IN ('Jugada', 'Penal', 'Tiro Libre', 'Cabezazo', 'En contra')
        SET @errores += N'- La descripción es obligatoria y debe ser: Jugada, Penal, Tiro Libre, Cabezazo o En contra.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM eventos.TipoGol
                    WHERE Descripcion = @descripcion
                      AND (@idExcluido IS NULL OR IdTipoGol <> @idExcluido))
        SET @errores += N'- Ya existe otro tipo de gol con esa descripción.' + @salto;

    RETURN @errores;
END;
GO

-- Alta y modificación de Periodo.
CREATE OR ALTER FUNCTION eventos.fn_ValidarPeriodo (@idExcluido INT, @descripcion VARCHAR(30))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @descripcion IS NULL
       OR @descripcion NOT IN ('Primer Tiempo', 'Segundo Tiempo', 'Adicional PT', 'Adicional ST',
                               'Alargue PT', 'Alargue ST', 'Definicion por Penales')
        SET @errores += N'- La descripción del período no es válida.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM eventos.Periodo
                    WHERE Descripcion = @descripcion
                      AND (@idExcluido IS NULL OR IdPeriodo <> @idExcluido))
        SET @errores += N'- Ya existe otro período con esa descripción.' + @salto;

    RETURN @errores;
END;
GO

-- Alta y modificación de Tarjeta.
CREATE OR ALTER FUNCTION eventos.fn_ValidarTarjeta (@idExcluido INT, @tipo VARCHAR(30))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @tipo IS NULL
       OR @tipo NOT IN ('Amarilla', 'Roja por doble amarilla', 'Roja directa')
        SET @errores += N'- El tipo de tarjeta debe ser: Amarilla, Roja por doble amarilla o Roja directa.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM eventos.Tarjeta
                    WHERE Tipo = @tipo
                      AND (@idExcluido IS NULL OR IdTarjeta <> @idExcluido))
        SET @errores += N'- Ya existe otra tarjeta con ese tipo.' + @salto;

    RETURN @errores;
END;
GO

-- Modificación y baja de Gol: el gol existe y su partido no está finalizado.
CREATE OR ALTER FUNCTION eventos.fn_ValidarGolEditable (@idGol INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartidoActual INT,
            @estadoActual    VARCHAR(10);

    SELECT @idPartidoActual = g.IdPartido,
           @estadoActual    = p.Estado
    FROM eventos.Gol AS g
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = g.IdPartido
    WHERE g.IdGol = @idGol;

    IF @idPartidoActual IS NULL
        SET @errores += N'- El gol indicado no existe.' + @salto;
    ELSE IF @estadoActual = 'Finalizado'
        SET @errores += N'- El partido del gol ya está finalizado: no se puede modificar ni eliminar.' + @salto;

    RETURN @errores;
END;
GO

-- Modificación y baja de Amonestacion: la amonestación existe y su partido no está finalizado.
CREATE OR ALTER FUNCTION eventos.fn_ValidarAmonestacionEditable (@idAmonestacion INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartidoActual INT,
            @estadoActual    VARCHAR(10);

    SELECT @idPartidoActual = a.IdPartido,
           @estadoActual    = p.Estado
    FROM eventos.Amonestacion AS a
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = a.IdPartido
    WHERE a.IdAmonestacion = @idAmonestacion;

    IF @idPartidoActual IS NULL
        SET @errores += N'- La amonestación indicada no existe.' + @salto;
    ELSE IF @estadoActual = 'Finalizado'
        SET @errores += N'- El partido de la amonestación ya está finalizado: no se puede modificar ni eliminar.' + @salto;

    RETURN @errores;
END;
GO

-- =========================================================================
-- 1. ReglaSuspension
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_ALTA_ReglaSuspension
    @idReglaSuspension  INT         = NULL OUTPUT,
    @criterio           VARCHAR(40) = NULL,
    @cantidadAmarillas  INT         = NULL,
    @partidosSuspension INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @criterio = LTRIM(RTRIM(@criterio));

    SET @errores = eventos.fn_ValidarReglaSuspension(NULL, @criterio, @cantidadAmarillas, @partidosSuspension);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_ReglaSuspension - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO eventos.ReglaSuspension (Criterio, CantidadAmarillas, PartidosSuspension)
        VALUES (@criterio, @cantidadAmarillas, @partidosSuspension);

        SET @idReglaSuspension = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE eventos.SP_MODIFICACION_ReglaSuspension
    @idReglaSuspension  INT         = NULL,
    @criterio           VARCHAR(40) = NULL,
    @cantidadAmarillas  INT         = NULL,
    @partidosSuspension INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @criterio = LTRIM(RTRIM(@criterio));

    IF @idReglaSuspension IS NULL
       OR NOT EXISTS (SELECT 1 FROM eventos.ReglaSuspension WHERE IdReglaSuspension = @idReglaSuspension)
        SET @errores += N'- La regla de suspensión indicada no existe.' + @salto;

    SET @errores += eventos.fn_ValidarReglaSuspension(@idReglaSuspension, @criterio, @cantidadAmarillas, @partidosSuspension);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_ReglaSuspension - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE eventos.ReglaSuspension
        SET Criterio           = @criterio,
            CantidadAmarillas  = @cantidadAmarillas,
            PartidosSuspension = @partidosSuspension
        WHERE IdReglaSuspension = @idReglaSuspension;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE eventos.SP_BAJA_ReglaSuspension
    @idReglaSuspension INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idReglaSuspension IS NULL
       OR NOT EXISTS (SELECT 1 FROM eventos.ReglaSuspension WHERE IdReglaSuspension = @idReglaSuspension)
        SET @errores += N'- La regla de suspensión indicada no existe.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_ReglaSuspension - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM eventos.ReglaSuspension
        WHERE IdReglaSuspension = @idReglaSuspension;

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
-- 2. TipoGol
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_ALTA_TipoGol
    @idTipoGol   INT         = NULL OUTPUT,
    @descripcion VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @descripcion = LTRIM(RTRIM(@descripcion));

    SET @errores = eventos.fn_ValidarTipoGol(NULL, @descripcion);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_TipoGol - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO eventos.TipoGol (Descripcion)
        VALUES (@descripcion);

        SET @idTipoGol = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE eventos.SP_MODIFICACION_TipoGol
    @idTipoGol   INT         = NULL,
    @descripcion VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @descripcion = LTRIM(RTRIM(@descripcion));

    IF @idTipoGol IS NULL
       OR NOT EXISTS (SELECT 1 FROM eventos.TipoGol WHERE IdTipoGol = @idTipoGol)
        SET @errores += N'- El tipo de gol indicado no existe.' + @salto;

    SET @errores += eventos.fn_ValidarTipoGol(@idTipoGol, @descripcion);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_TipoGol - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE eventos.TipoGol
        SET Descripcion = @descripcion
        WHERE IdTipoGol = @idTipoGol;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE eventos.SP_BAJA_TipoGol
    @idTipoGol INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idTipoGol IS NULL
       OR NOT EXISTS (SELECT 1 FROM eventos.TipoGol WHERE IdTipoGol = @idTipoGol)
        SET @errores += N'- El tipo de gol indicado no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM eventos.Gol WHERE IdTipoGol = @idTipoGol)
        SET @errores += N'- El tipo de gol tiene goles asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_TipoGol - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM eventos.TipoGol
        WHERE IdTipoGol = @idTipoGol;

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
-- 3. Periodo
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_ALTA_Periodo
    @idPeriodo   INT         = NULL OUTPUT,
    @descripcion VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @descripcion = LTRIM(RTRIM(@descripcion));

    SET @errores = eventos.fn_ValidarPeriodo(NULL, @descripcion);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Periodo - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO eventos.Periodo (Descripcion)
        VALUES (@descripcion);

        SET @idPeriodo = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE eventos.SP_MODIFICACION_Periodo
    @idPeriodo   INT         = NULL,
    @descripcion VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @descripcion = LTRIM(RTRIM(@descripcion));

    IF @idPeriodo IS NULL
       OR NOT EXISTS (SELECT 1 FROM eventos.Periodo WHERE IdPeriodo = @idPeriodo)
        SET @errores += N'- El período indicado no existe.' + @salto;

    SET @errores += eventos.fn_ValidarPeriodo(@idPeriodo, @descripcion);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Periodo - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE eventos.Periodo
        SET Descripcion = @descripcion
        WHERE IdPeriodo = @idPeriodo;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE eventos.SP_BAJA_Periodo
    @idPeriodo INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idPeriodo IS NULL
       OR NOT EXISTS (SELECT 1 FROM eventos.Periodo WHERE IdPeriodo = @idPeriodo)
        SET @errores += N'- El período indicado no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM eventos.Gol WHERE IdPeriodo = @idPeriodo)
        SET @errores += N'- El período tiene goles asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Periodo - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM eventos.Periodo
        WHERE IdPeriodo = @idPeriodo;

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
-- 4. Tarjeta
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_ALTA_Tarjeta
    @idTarjeta INT         = NULL OUTPUT,
    @tipo      VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @tipo = LTRIM(RTRIM(@tipo));

    SET @errores = eventos.fn_ValidarTarjeta(NULL, @tipo);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Tarjeta - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO eventos.Tarjeta (Tipo)
        VALUES (@tipo);

        SET @idTarjeta = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE eventos.SP_MODIFICACION_Tarjeta
    @idTarjeta INT         = NULL,
    @tipo      VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @tipo = LTRIM(RTRIM(@tipo));

    IF @idTarjeta IS NULL
       OR NOT EXISTS (SELECT 1 FROM eventos.Tarjeta WHERE IdTarjeta = @idTarjeta)
        SET @errores += N'- La tarjeta indicada no existe.' + @salto;

    SET @errores += eventos.fn_ValidarTarjeta(@idTarjeta, @tipo);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Tarjeta - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE eventos.Tarjeta
        SET Tipo = @tipo
        WHERE IdTarjeta = @idTarjeta;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE eventos.SP_BAJA_Tarjeta
    @idTarjeta INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idTarjeta IS NULL
       OR NOT EXISTS (SELECT 1 FROM eventos.Tarjeta WHERE IdTarjeta = @idTarjeta)
        SET @errores += N'- La tarjeta indicada no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdTarjeta = @idTarjeta)
        SET @errores += N'- La tarjeta tiene amonestaciones asociadas y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Tarjeta - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM eventos.Tarjeta
        WHERE IdTarjeta = @idTarjeta;

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
-- 5. Gol
-- El alta delega en eventos.SP_REGISTRAR_GOL. La modificación aplica las mismas reglas del alta
-- (eventos.fn_ValidarGol); la modificación y la baja exigen que el partido no esté finalizado
-- (eventos.fn_ValidarGolEditable).
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_ALTA_Gol
    @idGol               INT         = NULL OUTPUT,
    @idPartido           INT         = NULL,
    @idJugadorAutor      INT         = NULL,
    @tipoGol             VARCHAR(30) = NULL,
    @periodo             VARCHAR(30) = NULL,
    @minuto              INT         = NULL,
    @idJugadorAsistencia INT         = NULL,
    @permitirFechaFutura BIT         = 0
AS
BEGIN
    SET NOCOUNT ON;

    EXEC eventos.SP_REGISTRAR_GOL
        @idPartido           = @idPartido,
        @idJugadorAutor      = @idJugadorAutor,
        @tipoGol             = @tipoGol,
        @periodo             = @periodo,
        @minuto              = @minuto,
        @idJugadorAsistencia = @idJugadorAsistencia,
        @permitirFechaFutura = @permitirFechaFutura,
        @idGol               = @idGol OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE eventos.SP_MODIFICACION_Gol
    @idGol               INT         = NULL,
    @idPartido           INT         = NULL,
    @idJugadorAutor      INT         = NULL,
    @tipoGol             VARCHAR(30) = NULL,
    @periodo             VARCHAR(30) = NULL,
    @minuto              INT         = NULL,
    @idJugadorAsistencia INT         = NULL,
    @permitirFechaFutura BIT         = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores   NVARCHAR(MAX),
            @mensaje   NVARCHAR(2048),
            @salto     NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idTipoGol INT,
            @idPeriodo INT;

    SET @errores = eventos.fn_ValidarGolEditable(@idGol)
                 + eventos.fn_ValidarGol(@idPartido, @idJugadorAutor, @tipoGol, @periodo, @minuto,
                                         @idJugadorAsistencia, @permitirFechaFutura);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Gol - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @idTipoGol = t.IdTipoGol FROM eventos.TipoGol AS t WHERE t.Descripcion = @tipoGol;
        SELECT @idPeriodo = pe.IdPeriodo FROM eventos.Periodo AS pe WHERE pe.Descripcion = @periodo;

        UPDATE eventos.Gol
        SET IdPartido           = @idPartido,
            IdJugadorAutor      = @idJugadorAutor,
            IdJugadorAsistencia = @idJugadorAsistencia,
            IdTipoGol           = @idTipoGol,
            IdPeriodo           = @idPeriodo,
            Minuto              = @minuto
        WHERE IdGol = @idGol;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE eventos.SP_BAJA_Gol
    @idGol INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @errores = eventos.fn_ValidarGolEditable(@idGol);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Gol - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM eventos.Gol
        WHERE IdGol = @idGol;

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
-- 6. Amonestacion
-- El alta delega en eventos.SP_REGISTRAR_AMONESTACION. La modificación aplica las mismas reglas
-- del alta (eventos.fn_ValidarAmonestacion); la modificación y la baja exigen que el partido no
-- esté finalizado (eventos.fn_ValidarAmonestacionEditable).
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_ALTA_Amonestacion
    @idAmonestacion      INT          = NULL OUTPUT,
    @idPartido           INT          = NULL,
    @tipoTarjeta         VARCHAR(30)  = NULL,
    @minuto              INT          = NULL,
    @motivo              VARCHAR(200) = NULL,
    @idJugador           INT          = NULL,
    @idStaffTecnico      INT          = NULL,
    @permitirFechaFutura BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    EXEC eventos.SP_REGISTRAR_AMONESTACION
        @idPartido           = @idPartido,
        @tipoTarjeta         = @tipoTarjeta,
        @minuto              = @minuto,
        @motivo              = @motivo,
        @idJugador           = @idJugador,
        @idStaffTecnico      = @idStaffTecnico,
        @permitirFechaFutura = @permitirFechaFutura,
        @idAmonestacion      = @idAmonestacion OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE eventos.SP_MODIFICACION_Amonestacion
    @idAmonestacion      INT          = NULL,
    @idPartido           INT          = NULL,
    @tipoTarjeta         VARCHAR(30)  = NULL,
    @minuto              INT          = NULL,
    @motivo              VARCHAR(200) = NULL,
    @idJugador           INT          = NULL,
    @idStaffTecnico      INT          = NULL,
    @permitirFechaFutura BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores            NVARCHAR(MAX),
            @mensaje            NVARCHAR(2048),
            @salto              NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @tipoFinal          VARCHAR(30) = @tipoTarjeta,
            @idTarjetaFinal     INT,
            @partidosSuspension INT = 0;

    SET @errores = eventos.fn_ValidarAmonestacionEditable(@idAmonestacion)
                 + eventos.fn_ValidarAmonestacion(@idPartido, @tipoTarjeta, @minuto, @motivo, @idJugador,
                                                  @idStaffTecnico, @permitirFechaFutura, @idAmonestacion);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Amonestacion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Tipo de tarjeta final y suspensión (segunda amarilla, acumulación, roja directa).
        SELECT @tipoFinal = s.TipoFinal, @partidosSuspension = s.PartidosSuspension
        FROM eventos.fn_CalcularSancion(@idPartido, @idJugador, @idStaffTecnico, @tipoTarjeta, @idAmonestacion) AS s;

        SELECT @idTarjetaFinal = t.IdTarjeta FROM eventos.Tarjeta AS t WHERE t.Tipo = @tipoFinal;

        UPDATE eventos.Amonestacion
        SET IdPartido          = @idPartido,
            IdTarjeta          = @idTarjetaFinal,
            IdJugador          = @idJugador,
            IdStaffTecnico     = @idStaffTecnico,
            Minuto             = @minuto,
            Motivo             = LTRIM(RTRIM(@motivo)),
            PartidosSuspension = @partidosSuspension
        WHERE IdAmonestacion = @idAmonestacion;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE eventos.SP_BAJA_Amonestacion
    @idAmonestacion INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores         NVARCHAR(MAX),
            @mensaje         NVARCHAR(2048),
            @salto           NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartidoActual INT,
            @idJugadorActual INT,
            @tipoActual      VARCHAR(30);

    SET @errores = eventos.fn_ValidarAmonestacionEditable(@idAmonestacion);

    SELECT @idPartidoActual = a.IdPartido,
           @idJugadorActual = a.IdJugador,
           @tipoActual      = t.Tipo
    FROM eventos.Amonestacion AS a
    INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
    WHERE a.IdAmonestacion = @idAmonestacion;

    IF @idPartidoActual IS NOT NULL
       AND @tipoActual = 'Amarilla'
       AND @idJugadorActual IS NOT NULL
       AND EXISTS (SELECT 1
                   FROM eventos.Amonestacion AS r
                   INNER JOIN eventos.Tarjeta AS tr ON tr.IdTarjeta = r.IdTarjeta
                   WHERE r.IdPartido = @idPartidoActual
                     AND r.IdJugador = @idJugadorActual
                     AND tr.Tipo = 'Roja por doble amarilla')
        SET @errores += N'- No se puede eliminar la primera amarilla mientras exista una roja por doble amarilla del jugador en ese partido.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Amonestacion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM eventos.Amonestacion
        WHERE IdAmonestacion = @idAmonestacion;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
