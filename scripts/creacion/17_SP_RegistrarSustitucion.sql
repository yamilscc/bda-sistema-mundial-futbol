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
Objetivo: Stored procedure jugadores.SP_REGISTRAR_SUSTITUCION: registra un cambio durante un
          partido validando formación, jugadores en cancha, expulsiones y límites de cambios
          y ventanas (tiempo regular y suplementario) según jugadores.ReglaCambios.
          Requiere ejecutados los scripts 01 a 16.
          Test correspondiente: testing/17_Test_SP_RegistrarSustitucion.sql.
*/

USE MundialFutbol;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_REGISTRAR_SUSTITUCION
    @idPartido           INT,
    @idJugadorSaliente   INT,
    @idJugadorEntrante   INT,
    @minuto              INT,
    @periodo             VARCHAR(13),
    @motivo              VARCHAR(10),
    @permitirFechaFutura BIT = 0,
    @idSustitucion       INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2) = CHAR(13) + CHAR(10);

    SET @periodo = LTRIM(RTRIM(@periodo));
    SET @motivo  = LTRIM(RTRIM(@motivo));

    -- Todas las validaciones están en jugadores.fn_ValidarSustitucion (la comparte SP_ABM_Sustitucion).
    SET @errores = jugadores.fn_ValidarSustitucion(
        @idPartido,
        @idJugadorSaliente,
        @idJugadorEntrante,
        @minuto,
        @periodo,
        @motivo,
        @permitirFechaFutura,
        NULL
    );

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_REGISTRAR_SUSTITUCION - No se pudo registrar la sustitución:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO jugadores.Sustitucion (
            IdPartido, IdJugadorSaliente, IdJugadorEntrante, Minuto, Periodo, Motivo
        )
        VALUES (
            @idPartido, @idJugadorSaliente, @idJugadorEntrante, @minuto, @periodo, @motivo
        );

        SET @idSustitucion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT s.IdSustitucion,
           s.IdPartido,
           s.IdJugadorSaliente,
           jSal.Apellido AS ApellidoSaliente,
           s.IdJugadorEntrante,
           jEnt.Apellido AS ApellidoEntrante,
           s.Minuto,
           s.Periodo,
           s.Motivo
    FROM jugadores.Sustitucion AS s
    INNER JOIN jugadores.Jugador AS jSal ON jSal.IdJugador = s.IdJugadorSaliente
    INNER JOIN jugadores.Jugador AS jEnt ON jEnt.IdJugador = s.IdJugadorEntrante
    WHERE s.IdSustitucion = @idSustitucion;
END;
GO