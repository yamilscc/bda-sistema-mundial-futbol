/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-14
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Funciones del módulo de eventos de partido:
          - eventos.fn_ResultadoPartido(@idPartido): resultado calculado a partir de los goles
            cargados (goles en juego y definición por penales).
          - eventos.fn_EstaSuspendido(@idJugador, @idPartido): indica si un jugador está
            suspendido para disputar un partido, según las sanciones de eventos.Amonestacion.
*/

USE MundialFutbol;
GO

/*
fn_ResultadoPartido
Devuelve UNA fila (0 filas si el partido no existe) con los goles de cada selección.
Criterios:
  - Un gol suma a la selección del autor (jugadores.Convocatoria), salvo el tipo 'En contra',
    que suma a la selección rival.
  - Los goles del período 'Definicion por Penales' no son goles del partido: se cuentan
    aparte como penales. Si no hay tanda, PenalesLocal y PenalesVisitante son NULL
    (mismo criterio que nucleo.Partido).
  - Un gol cuyo autor no está convocado no se cuenta (no se puede saber a qué selección suma).
*/
CREATE OR ALTER FUNCTION eventos.fn_ResultadoPartido (@idPartido INT)
RETURNS TABLE
AS
RETURN
(
    SELECT p.IdPartido,
           CAST(ISNULL(SUM(CASE WHEN ga.EsTanda = 0 AND ga.IdSeleccionFavor = p.IdSeleccionLocal
                                THEN 1 ELSE 0 END), 0) AS INT) AS GolesLocal,
           CAST(ISNULL(SUM(CASE WHEN ga.EsTanda = 0 AND ga.IdSeleccionFavor = p.IdSeleccionVisitante
                                THEN 1 ELSE 0 END), 0) AS INT) AS GolesVisitante,
           CASE WHEN SUM(CASE WHEN ga.EsTanda = 1 THEN 1 ELSE 0 END) > 0
                THEN SUM(CASE WHEN ga.EsTanda = 1 AND ga.IdSeleccionFavor = p.IdSeleccionLocal
                              THEN 1 ELSE 0 END)
           END AS PenalesLocal,
           CASE WHEN SUM(CASE WHEN ga.EsTanda = 1 THEN 1 ELSE 0 END) > 0
                THEN SUM(CASE WHEN ga.EsTanda = 1 AND ga.IdSeleccionFavor = p.IdSeleccionVisitante
                              THEN 1 ELSE 0 END)
           END AS PenalesVisitante
    FROM nucleo.Partido AS p
    LEFT JOIN (
        SELECT g.IdPartido,
               CASE WHEN tg.Descripcion = 'En contra'
                    THEN CASE WHEN c.IdSeleccion = pp.IdSeleccionLocal
                              THEN pp.IdSeleccionVisitante
                              ELSE pp.IdSeleccionLocal END
                    ELSE c.IdSeleccion
               END AS IdSeleccionFavor,
               CASE WHEN pe.Descripcion = 'Definicion por Penales' THEN 1 ELSE 0 END AS EsTanda
        FROM eventos.Gol AS g
        INNER JOIN nucleo.Partido        AS pp ON pp.IdPartido = g.IdPartido
        INNER JOIN jugadores.Convocatoria AS c  ON c.IdJugador  = g.IdJugadorAutor
        INNER JOIN eventos.TipoGol       AS tg ON tg.IdTipoGol  = g.IdTipoGol
        INNER JOIN eventos.Periodo       AS pe ON pe.IdPeriodo  = g.IdPeriodo
        WHERE g.IdPartido = @idPartido
    ) AS ga ON ga.IdPartido = p.IdPartido
    WHERE p.IdPartido = @idPartido
    GROUP BY p.IdPartido
);
GO

/*
fn_EstaSuspendido
Devuelve 1 si el jugador no puede jugar @idPartido por una sanción previa, 0 en caso contrario.
Criterios:
  - La sanción sale de eventos.Amonestacion.PartidosSuspension (> 0), que calcula el SP de
    registro de tarjetas a partir de eventos.ReglaSuspension.
  - Cumple la sanción en los próximos N partidos de SU selección, contados por FechaHoraUTC
    a partir del partido de la tarjeta (ese partido no cuenta).
  - Si @idPartido no lo juega la selección del jugador, o el jugador / partido no existen,
    devuelve 0.
*/
CREATE OR ALTER FUNCTION eventos.fn_EstaSuspendido (@idJugador INT, @idPartido INT)
RETURNS BIT
AS
BEGIN
    DECLARE @idSeleccion INT,
            @fechaUTC    DATETIME2(0),
            @resultado   BIT = 0;

    SELECT @idSeleccion = c.IdSeleccion
    FROM jugadores.Convocatoria AS c
    WHERE c.IdJugador = @idJugador;

    SELECT @fechaUTC = p.FechaHoraUTC
    FROM nucleo.Partido AS p
    WHERE p.IdPartido = @idPartido
      AND @idSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante);

    IF @idSeleccion IS NOT NULL AND @fechaUTC IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM eventos.Amonestacion AS a
            INNER JOIN nucleo.Partido AS po ON po.IdPartido = a.IdPartido
            WHERE a.IdJugador = @idJugador
              AND a.PartidosSuspension > 0
              AND po.FechaHoraUTC < @fechaUTC
              AND (SELECT COUNT(*)
                   FROM nucleo.Partido AS pm
                   WHERE @idSeleccion IN (pm.IdSeleccionLocal, pm.IdSeleccionVisitante)
                     AND pm.FechaHoraUTC >  po.FechaHoraUTC
                     AND pm.FechaHoraUTC <= @fechaUTC) <= a.PartidosSuspension
       )
        SET @resultado = 1;

    RETURN @resultado;
END;
GO
