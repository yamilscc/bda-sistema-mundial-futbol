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
--     (@permitirFechaFutura = 1 lo habilita para pruebas, igual que el SP de resultado).
--   - Tipo de gol y período existentes; minuto entre 1 y 135.
--   - La definición por penales solo admite goles de tipo 'Penal' y solo en eliminación directa.
--   - El gol 'En contra', el penal y los goles de la tanda no admiten asistencia.
--   - Autor y asistente: convocados en una selección del partido, sin baja, no suspendidos
--     para ese partido y no expulsados antes del minuto del gol; el asistente debe ser de la
--     misma selección que el autor y distinto de él.
-- El resultado final del partido se carga con nucleo.SP_REGISTRAR_RESULTADO_PARTIDO
-- (se puede contrastar con eventos.fn_ResultadoPartido).
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

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @existe          BIT = 0,
            @estado          VARCHAR(10),
            @esEliminatoria  BIT,
            @idLocal         INT,
            @idVisitante     INT,
            @fechaHoraUTC    DATETIME2(0),
            @fechaLocal      DATE,
            @idTipoGol       INT,
            @idPeriodo       INT,
            @idSelAutor      INT,
            @idSelAsistente  INT;

    SELECT @existe         = 1,
           @estado         = p.Estado,
           @esEliminatoria = f.EsEliminatoria,
           @idLocal        = p.IdSeleccionLocal,
           @idVisitante    = p.IdSeleccionVisitante,
           @fechaHoraUTC   = p.FechaHoraUTC,
           @fechaLocal     = CAST(p.FechaHoraLocal AS DATE)
    FROM nucleo.Partido AS p
    INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
    WHERE p.IdPartido = @idPartido;

    SELECT @idTipoGol = t.IdTipoGol FROM eventos.TipoGol AS t WHERE t.Descripcion = @tipoGol;
    SELECT @idPeriodo = pe.IdPeriodo FROM eventos.Periodo AS pe WHERE pe.Descripcion = @periodo;
    SELECT @idSelAutor     = c.IdSeleccion FROM jugadores.Convocatoria AS c WHERE c.IdJugador = @idJugadorAutor;
    SELECT @idSelAsistente = c.IdSeleccion FROM jugadores.Convocatoria AS c WHERE c.IdJugador = @idJugadorAsistencia;

    -- ---- Validaciones ----------------------------------------------------
    IF @existe = 0
        SET @errores += N'- El partido indicado no existe.' + @salto;
    ELSE
    BEGIN
        IF @idLocal IS NULL OR @idVisitante IS NULL
            SET @errores += N'- El partido no tiene definidas ambas selecciones.' + @salto;

        IF @estado = 'Finalizado'
            SET @errores += N'- El partido ya está finalizado: no se pueden registrar más goles.' + @salto;

        IF @permitirFechaFutura = 0 AND @fechaHoraUTC > SYSUTCDATETIME()
            SET @errores += N'- No se pueden registrar goles de un partido que todavía no se jugó.' + @salto;
    END;

    IF @idTipoGol IS NULL
        SET @errores += N'- El tipo de gol indicado no existe.' + @salto;

    IF @idPeriodo IS NULL
        SET @errores += N'- El período indicado no existe.' + @salto;

    IF @minuto IS NULL OR @minuto NOT BETWEEN 1 AND 135
        SET @errores += N'- El minuto debe estar entre 1 y 135.' + @salto;

    IF @periodo = 'Definicion por Penales'
    BEGIN
        IF @tipoGol <> 'Penal'
            SET @errores += N'- En la definición por penales solo se pueden registrar goles de tipo Penal.' + @salto;

        IF @existe = 1 AND @esEliminatoria = 0
            SET @errores += N'- En fase de grupos no hay definición por penales.' + @salto;
    END;

    IF @idJugadorAsistencia IS NOT NULL
       AND (@tipoGol IN ('En contra', 'Penal') OR @periodo = 'Definicion por Penales')
        SET @errores += N'- Este tipo de gol no admite asistencia.' + @salto;

    -- Autor
    IF @idJugadorAutor IS NULL
       OR NOT EXISTS (SELECT 1 FROM jugadores.Jugador AS j WHERE j.IdJugador = @idJugadorAutor)
        SET @errores += N'- El jugador autor del gol no existe.' + @salto;
    ELSE IF @idSelAutor IS NULL
        SET @errores += N'- El jugador autor del gol no está convocado.' + @salto;
    ELSE IF @existe = 1 AND @idSelAutor NOT IN (ISNULL(@idLocal, -1), ISNULL(@idVisitante, -1))
        SET @errores += N'- El jugador autor del gol no pertenece a ninguna de las selecciones del partido.' + @salto;
    ELSE IF @existe = 1
    BEGIN
        IF EXISTS (SELECT 1
                   FROM jugadores.Convocatoria AS c
                   INNER JOIN jugadores.Baja AS b ON b.IdConvocatoria = c.IdConvocatoria
                   WHERE c.IdJugador = @idJugadorAutor AND b.FechaBaja <= @fechaLocal)
            SET @errores += N'- El jugador autor del gol está dado de baja de la convocatoria.' + @salto;

        IF eventos.fn_EstaSuspendido(@idJugadorAutor, @idPartido) = 1
            SET @errores += N'- El jugador autor del gol está suspendido para este partido.' + @salto;

        IF @minuto IS NOT NULL
           AND EXISTS (SELECT 1
                       FROM eventos.Amonestacion AS a
                       INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                       WHERE a.IdPartido = @idPartido AND a.IdJugador = @idJugadorAutor
                         AND t.Tipo IN ('Roja por doble amarilla', 'Roja directa')
                         AND a.Minuto <= @minuto)
            SET @errores += N'- El jugador autor del gol ya estaba expulsado en ese minuto.' + @salto;
    END;

    -- Asistente (opcional)
    IF @idJugadorAsistencia IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM jugadores.Jugador AS j WHERE j.IdJugador = @idJugadorAsistencia)
            SET @errores += N'- El jugador que asiste no existe.' + @salto;
        ELSE IF @idJugadorAsistencia = @idJugadorAutor
            SET @errores += N'- El autor del gol no puede ser también quien asiste.' + @salto;
        ELSE IF @idSelAsistente IS NULL
            SET @errores += N'- El jugador que asiste no está convocado.' + @salto;
        ELSE IF @idSelAutor IS NOT NULL AND @idSelAsistente <> @idSelAutor
            SET @errores += N'- El jugador que asiste debe ser de la misma selección que el autor.' + @salto;
        ELSE IF @existe = 1 AND @idSelAsistente NOT IN (ISNULL(@idLocal, -1), ISNULL(@idVisitante, -1))
            SET @errores += N'- El jugador que asiste no pertenece a ninguna de las selecciones del partido.' + @salto;
        ELSE IF @existe = 1
        BEGIN
            IF EXISTS (SELECT 1
                       FROM jugadores.Convocatoria AS c
                       INNER JOIN jugadores.Baja AS b ON b.IdConvocatoria = c.IdConvocatoria
                       WHERE c.IdJugador = @idJugadorAsistencia AND b.FechaBaja <= @fechaLocal)
                SET @errores += N'- El jugador que asiste está dado de baja de la convocatoria.' + @salto;

            IF eventos.fn_EstaSuspendido(@idJugadorAsistencia, @idPartido) = 1
                SET @errores += N'- El jugador que asiste está suspendido para este partido.' + @salto;

            IF @minuto IS NOT NULL
               AND EXISTS (SELECT 1
                           FROM eventos.Amonestacion AS a
                           INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                           WHERE a.IdPartido = @idPartido AND a.IdJugador = @idJugadorAsistencia
                             AND t.Tipo IN ('Roja por doble amarilla', 'Roja directa')
                             AND a.Minuto <= @minuto)
                SET @errores += N'- El jugador que asiste ya estaba expulsado en ese minuto.' + @salto;
        END;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_REGISTRAR_GOL - No se pudo registrar el gol:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

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
