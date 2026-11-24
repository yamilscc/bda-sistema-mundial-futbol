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
Objetivo: Stored procedure eventos.SP_REGISTRAR_GOL: registra un gol de un partido validando partido,
          jugadores y período. Requiere ejecutados los scripts 01 a 10.
          Test correspondiente: 11_Test_SP_RegistrarGol.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- SP_REGISTRAR_GOL
-- Registra un gol de un partido y devuelve la fila insertada.
-- Validaciones (se informan todas juntas en un único mensaje):
--   - Partido existente, con ambas selecciones definidas, no finalizado y ya jugado
--     (@permitirFechaFutura = 1 lo habilita para pruebas).
--   - Tipo de gol y período existentes; minuto entre 1 y 135.
--   - La definición por penales solo admite goles de tipo 'Penal' y solo en eliminación directa.
--   - El gol 'En contra', el penal y los goles de la tanda no admiten asistencia.
--   - Autor y asistente: convocados en una selección del partido, sin baja, no suspendidos
--     para ese partido y no expulsados antes del minuto del gol; el asistente debe ser de la
--     misma selección que el autor y distinto de él.
-- El resultado del partido se deriva de los goles con eventos.fn_ResultadoPartido; el partido
-- se cierra con nucleo.SP_FINALIZAR_PARTIDO (script 26).
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_REGISTRAR_GOL
    @idPartido           INT,
    @idJugadorAutor      INT,
    @tipoGol             VARCHAR(30),
    @periodo             VARCHAR(30),
    @minuto              INT,
    @idJugadorAsistencia INT = NULL,
    @permitirFechaFutura BIT = 0,
    @idGol               INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores   NVARCHAR(MAX),
            @mensaje   NVARCHAR(2048),
            @salto     NVARCHAR(2) = CHAR(13) + CHAR(10),
            @idTipoGol INT,
            @idPeriodo INT;

    -- Todas las validaciones están en eventos.fn_ValidarGol (la comparte SP_MODIFICACION_Gol).
    SET @errores = eventos.fn_ValidarGol(@idPartido, @idJugadorAutor, @tipoGol, @periodo, @minuto,
                                         @idJugadorAsistencia, @permitirFechaFutura);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_REGISTRAR_GOL - No se pudo registrar el gol:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    SELECT @idTipoGol = t.IdTipoGol FROM eventos.TipoGol AS t WHERE t.Descripcion = @tipoGol;
    SELECT @idPeriodo = pe.IdPeriodo FROM eventos.Periodo AS pe WHERE pe.Descripcion = @periodo;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
        VALUES (@idPartido, @idJugadorAutor, @idJugadorAsistencia, @idTipoGol, @idPeriodo, @minuto);

        SET @idGol = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT g.IdGol, g.IdPartido, g.IdJugadorAutor, g.IdJugadorAsistencia,
           tg.Descripcion AS TipoGol, pe.Descripcion AS Periodo, g.Minuto
    FROM eventos.Gol AS g
    INNER JOIN eventos.TipoGol AS tg ON tg.IdTipoGol = g.IdTipoGol
    INNER JOIN eventos.Periodo AS pe ON pe.IdPeriodo = g.IdPeriodo
    WHERE g.IdGol = @idGol;
END;
GO
