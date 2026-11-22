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
Objetivo: Stored procedures de gestión de convocatorias y bajas:
          - jugadores.SP_CONVOCAR_JUGADOR: alta de jugador en la lista de convocados de una
            selección respetando el tope máximo de jugadores.ReglaConvocados.
          - jugadores.SP_REGISTRAR_BAJA_CONVOCATORIA: registra la baja de un convocado en
            jugadores.Baja y permite dar de alta opcionalmente a su reemplazante en la misma
            transacción.
          Requiere ejecutados los scripts 01 a 14.
          Test correspondiente: testing/15_Test_SP_Convocatoria_Baja.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. SP_CONVOCAR_JUGADOR
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_CONVOCAR_JUGADOR
    @idSeleccion    INT,
    @idJugador      INT,
    @dorsal         INT,
    @fechaAlta      DATE = NULL,
    @idConvocatoria INT  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores          NVARCHAR(MAX),
            @mensaje          NVARCHAR(2048),
            @salto            NVARCHAR(2) = CHAR(13) + CHAR(10),
            @fechaAltaEfectiva DATE       = ISNULL(@fechaAlta, CAST(GETDATE() AS DATE));

    SET @errores = jugadores.fn_ValidarConvocatoria(@idSeleccion, @idJugador, @dorsal, @fechaAltaEfectiva, NULL);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_CONVOCAR_JUGADOR - No se pudo convocar al jugador:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal, FechaAlta)
        VALUES (@idSeleccion, @idJugador, @dorsal, @fechaAltaEfectiva);

        SET @idConvocatoria = SCOPE_IDENTITY();

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
-- 2. SP_REGISTRAR_BAJA_CONVOCATORIA
-- Registra la baja de un jugador convocado y, si se informan @idJugadorReemplazante
-- y @dorsalReemplazante, incorpora al reemplazante en la misma transacción.
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_REGISTRAR_BAJA_CONVOCATORIA
    @idConvocatoria          INT,
    @motivo                  VARCHAR(200),
    @fechaBaja               DATE = NULL,
    @idJugadorReemplazante   INT  = NULL,
    @dorsalReemplazante      INT  = NULL,
    @idBaja                  INT  = NULL OUTPUT,
    @idConvocatoriaReemplazo INT  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores           NVARCHAR(MAX) = N'',
            @mensaje           NVARCHAR(2048),
            @salto             NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idSeleccion       INT,
            @fechaAltaOriginal DATE,
            @fechaBajaEfectiva DATE          = ISNULL(@fechaBaja, CAST(GETDATE() AS DATE)),
            @maxConvocados     INT,
            @convocadosActivos INT;

    SET @idConvocatoriaReemplazo = NULL;

    SELECT @idSeleccion       = c.IdSeleccion,
           @fechaAltaOriginal = c.FechaAlta
    FROM jugadores.Convocatoria AS c
    WHERE c.IdConvocatoria = @idConvocatoria;

    -- ---- Validaciones de la baja -----------------------------------------
    IF @idSeleccion IS NULL
        SET @errores += N'- La convocatoria indicada no existe.' + @salto;
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM jugadores.Baja AS b WHERE b.IdConvocatoria = @idConvocatoria)
            SET @errores += N'- El jugador ya fue dado de baja previamente.' + @salto;

        IF @fechaBajaEfectiva < @fechaAltaOriginal
            SET @errores += N'- La fecha de baja no puede ser anterior a la fecha de alta de la convocatoria.' + @salto;
    END;

    IF @motivo IS NULL OR LEN(LTRIM(RTRIM(@motivo))) = 0
        SET @errores += N'- El motivo de la baja es obligatorio.' + @salto;

    -- ---- Validaciones del reemplazante (opcional) ------------------------
    IF (@idJugadorReemplazante IS NOT NULL AND @dorsalReemplazante IS NULL)
       OR (@idJugadorReemplazante IS NULL AND @dorsalReemplazante IS NOT NULL)
        SET @errores += N'- Para registrar un reemplazo deben informarse tanto el jugador reemplazante como su dorsal.' + @salto;
    ELSE IF @idJugadorReemplazante IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM jugadores.Jugador AS j WHERE j.IdJugador = @idJugadorReemplazante)
            SET @errores += N'- El jugador reemplazante indicado no existe.' + @salto;
        ELSE IF EXISTS (SELECT 1 FROM jugadores.Convocatoria AS c WHERE c.IdJugador = @idJugadorReemplazante)
            SET @errores += N'- El jugador reemplazante ya figura convocado.' + @salto;

        IF @dorsalReemplazante NOT BETWEEN 1 AND 99
            SET @errores += N'- El dorsal del reemplazante debe estar entre 1 y 99.' + @salto;
        ELSE IF @idSeleccion IS NOT NULL
                AND EXISTS (SELECT 1
                            FROM jugadores.Convocatoria AS c
                            WHERE c.IdSeleccion = @idSeleccion
                              AND c.Dorsal = @dorsalReemplazante)
            SET @errores += N'- El dorsal del reemplazante ya está utilizado en la convocatoria de la selección.' + @salto;

        SELECT TOP (1) @maxConvocados = r.Maximo
        FROM jugadores.ReglaConvocados AS r
        ORDER BY r.IdRegla;

        IF @maxConvocados IS NULL
            SET @errores += N'- Falta parametrizar la regla de cupos en jugadores.ReglaConvocados.' + @salto;
        ELSE IF @idSeleccion IS NOT NULL
        BEGIN
            -- Al dar de baja a @idConvocatoria queda 1 lugar libre respecto al conteo actual sin baja.
            SELECT @convocadosActivos = COUNT(*)
            FROM jugadores.Convocatoria AS c
            WHERE c.IdSeleccion = @idSeleccion
              AND c.IdConvocatoria <> @idConvocatoria
              AND NOT EXISTS (SELECT 1 FROM jugadores.Baja AS b WHERE b.IdConvocatoria = c.IdConvocatoria);

            IF @convocadosActivos >= @maxConvocados
                SET @errores += N'- La selección ya supera el máximo de convocados activos permitido.' + @salto;
        END;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_REGISTRAR_BAJA_CONVOCATORIA - No se pudo registrar la baja:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO jugadores.Baja (IdConvocatoria, FechaBaja, Motivo)
        VALUES (@idConvocatoria, @fechaBajaEfectiva, LTRIM(RTRIM(@motivo)));

        SET @idBaja = SCOPE_IDENTITY();

        IF @idJugadorReemplazante IS NOT NULL
        BEGIN
            INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal, FechaAlta)
            VALUES (@idSeleccion, @idJugadorReemplazante, @dorsalReemplazante, @fechaBajaEfectiva);

            SET @idConvocatoriaReemplazo = SCOPE_IDENTITY();
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