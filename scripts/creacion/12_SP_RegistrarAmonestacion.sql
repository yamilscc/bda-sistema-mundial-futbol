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
Objetivo: Stored procedure eventos.SP_REGISTRAR_AMONESTACION: registra una tarjeta a un jugador o a un
          miembro del staff técnico y calcula la suspensión (acumulación de amarillas, doble
          amarilla y roja directa) según eventos.ReglaSuspension. Requiere ejecutados los
          scripts 01 a 10. Test correspondiente: 12_Test_SP_RegistrarAmonestacion.sql.
*/

USE MundialFutbol;
GO

CREATE OR ALTER PROCEDURE eventos.SP_REGISTRAR_AMONESTACION
    @idPartido           INT,
    @tipoTarjeta         VARCHAR(30),
    @minuto              INT,
    @motivo              VARCHAR(200),
    @idJugador           INT = NULL,
    @idStaffTecnico      INT = NULL,
    @permitirFechaFutura BIT = 0,
    @idAmonestacion      INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores            NVARCHAR(MAX),
            @mensaje            NVARCHAR(2048),
            @salto              NVARCHAR(2) = CHAR(13) + CHAR(10),
            @tipoFinal          VARCHAR(30) = @tipoTarjeta,
            @idTarjetaFinal     INT,
            @partidosSuspension INT = 0;

    -- Todas las validaciones están en eventos.fn_ValidarAmonestacion (la comparte SP_MODIFICACION_Amonestacion).
    SET @errores = eventos.fn_ValidarAmonestacion(@idPartido, @tipoTarjeta, @minuto, @motivo, @idJugador,
                                                  @idStaffTecnico, @permitirFechaFutura, NULL);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_REGISTRAR_AMONESTACION - No se pudo registrar la tarjeta:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Tipo de tarjeta final y suspensión (segunda amarilla, acumulación, roja directa).
        SELECT @tipoFinal = s.TipoFinal, @partidosSuspension = s.PartidosSuspension
        FROM eventos.fn_CalcularSancion(@idPartido, @idJugador, @idStaffTecnico, @tipoTarjeta, NULL) AS s;

        SELECT @idTarjetaFinal = t.IdTarjeta FROM eventos.Tarjeta AS t WHERE t.Tipo = @tipoFinal;

        INSERT INTO eventos.Amonestacion (IdPartido, IdTarjeta, IdJugador, IdStaffTecnico, Minuto, Motivo, PartidosSuspension)
        VALUES (@idPartido, @idTarjetaFinal, @idJugador, @idStaffTecnico, @minuto, LTRIM(RTRIM(@motivo)), @partidosSuspension);

        SET @idAmonestacion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT a.IdAmonestacion, a.IdPartido, t.Tipo AS Tarjeta, a.IdJugador, a.IdStaffTecnico,
           a.Minuto, a.Motivo, a.PartidosSuspension
    FROM eventos.Amonestacion AS a
    INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
    WHERE a.IdAmonestacion = @idAmonestacion;
END;
GO