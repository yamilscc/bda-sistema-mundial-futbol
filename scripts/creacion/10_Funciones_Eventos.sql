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
Objetivo: Funciones del módulo de eventos de partido:
          - eventos.fn_ResultadoPartido(@idPartido): resultado calculado a partir de los goles
            cargados (goles en juego y definición por penales).
          - eventos.fn_EstaSuspendido(@idJugador, @idPartido): indica si un jugador está
            suspendido para disputar un partido, según las sanciones de eventos.Amonestacion.
          - eventos.fn_ValidarGol y eventos.fn_ValidarAmonestacion: validaciones compartidas por
            los SP de alta y de modificación (devuelven el texto de las condiciones incumplidas).
          - eventos.fn_CalcularSancion: tipo de tarjeta final y suspensión que corresponde.
          Test correspondiente: testing/10_Test_Funciones_Eventos.sql.
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

-- =========================================================================
-- fn_ValidarGol
-- Devuelve el texto con todas las condiciones que no cumple un gol (una línea por condición,
-- cada una empieza con '- ') o una cadena vacía si es válido. Lo usan SP_REGISTRAR_GOL (alta)
-- y SP_MODIFICACION_Gol (modificación), así las reglas viven en un solo lugar.
-- =========================================================================
CREATE OR ALTER FUNCTION eventos.fn_ValidarGol
(
    @idPartido           INT,
    @idJugadorAutor      INT,
    @tipoGol             VARCHAR(30),
    @periodo             VARCHAR(30),
    @minuto              INT,
    @idJugadorAsistencia INT,
    @permitirFechaFutura BIT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores        NVARCHAR(MAX) = N'',
            @salto          NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @existe         BIT = 0,
            @estado         VARCHAR(10),
            @esEliminatoria BIT,
            @idLocal        INT,
            @idVisitante    INT,
            @fechaHoraUTC   DATETIME2(0),
            @fechaLocal     DATE,
            @idTipoGol      INT,
            @idPeriodo      INT,
            @idSelAutor     INT,
            @idSelAsistente INT;

    SELECT @existe         = 1,
           @estado         = p.Estado,
           @esEliminatoria = f.EsEliminatoria,
           @idLocal        = p.IdSeleccionLocal,
           @idVisitante    = p.IdSeleccionVisitante,
           @fechaHoraUTC   = p.FechaHoraUTC,
           -- Fecha local de la sede (huso de su ciudad), no la fecha UTC.
           @fechaLocal     = CAST((p.FechaHoraUTC AT TIME ZONE 'UTC') AT TIME ZONE c.HusoHorario AS DATE)
    FROM nucleo.Partido AS p
    INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
    INNER JOIN nucleo.Sede AS s ON s.IdSede = p.IdSede
    INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = s.IdCiudad
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

    RETURN @errores;
END;
GO

-- =========================================================================
-- fn_ValidarAmonestacion
-- Devuelve el texto con todas las condiciones que no cumple una tarjeta (una línea por
-- condición, cada una empieza con '- ') o una cadena vacía si es válida.
-- @idAmonestacionExcluir: en una modificación, la amonestación que se está cambiando (no se
-- la considera expulsión previa de sí misma); en un alta va NULL.
-- Lo usan SP_REGISTRAR_AMONESTACION (alta) y SP_MODIFICACION_Amonestacion (modificación).
-- =========================================================================
CREATE OR ALTER FUNCTION eventos.fn_ValidarAmonestacion
(
    @idPartido             INT,
    @tipoTarjeta           VARCHAR(30),
    @minuto                INT,
    @motivo                VARCHAR(200),
    @idJugador             INT,
    @idStaffTecnico        INT,
    @permitirFechaFutura   BIT,
    @idAmonestacionExcluir INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores         NVARCHAR(MAX) = N'',
            @salto           NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @existe          BIT = 0,
            @estado          VARCHAR(10),
            @idLocal         INT,
            @idVisitante     INT,
            @fechaHoraUTC    DATETIME2(0),
            @fechaLocal      DATE,
            @idSelSancionado INT,
            @susRoja         INT,
            @susDoble        INT,
            @susAcum         INT,
            @cantAcum        INT;

    SELECT @existe       = 1,
           @estado       = p.Estado,
           @idLocal      = p.IdSeleccionLocal,
           @idVisitante  = p.IdSeleccionVisitante,
           @fechaHoraUTC = p.FechaHoraUTC,
           -- Fecha local de la sede (huso de su ciudad), no la fecha UTC.
           @fechaLocal   = CAST((p.FechaHoraUTC AT TIME ZONE 'UTC') AT TIME ZONE c.HusoHorario AS DATE)
    FROM nucleo.Partido AS p
    INNER JOIN nucleo.Sede AS s ON s.IdSede = p.IdSede
    INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = s.IdCiudad
    WHERE p.IdPartido = @idPartido;

    SELECT @susRoja  = r.PartidosSuspension FROM eventos.ReglaSuspension AS r WHERE r.Criterio = 'Roja Directa';
    SELECT @susDoble = r.PartidosSuspension FROM eventos.ReglaSuspension AS r WHERE r.Criterio = 'Doble Amarilla';
    SELECT @susAcum  = r.PartidosSuspension, @cantAcum = r.CantidadAmarillas
    FROM eventos.ReglaSuspension AS r WHERE r.Criterio = 'Acumulacion Amarillas';

    -- ---- Validaciones ----------------------------------------------------
    IF @existe = 0
        SET @errores += N'- El partido indicado no existe.' + @salto;
    ELSE
    BEGIN
        IF @idLocal IS NULL OR @idVisitante IS NULL
            SET @errores += N'- El partido no tiene definidas ambas selecciones.' + @salto;
        IF @estado = 'Finalizado'
            SET @errores += N'- El partido ya está finalizado: no se pueden registrar más tarjetas.' + @salto;
        IF @permitirFechaFutura = 0 AND @fechaHoraUTC > SYSUTCDATETIME()
            SET @errores += N'- No se pueden registrar tarjetas de un partido que todavía no se jugó.' + @salto;
    END;

    IF @tipoTarjeta IS NULL OR @tipoTarjeta NOT IN ('Amarilla', 'Roja directa')
        SET @errores += N'- El tipo de tarjeta debe ser Amarilla o Roja directa (la roja por doble amarilla se genera automáticamente).' + @salto;

    IF (SELECT COUNT(*) FROM eventos.Tarjeta AS t
        WHERE t.Tipo IN ('Amarilla', 'Roja por doble amarilla', 'Roja directa')) < 3
        SET @errores += N'- El catálogo de tarjetas está incompleto (Amarilla, Roja por doble amarilla, Roja directa).' + @salto;

    IF @minuto IS NULL OR @minuto NOT BETWEEN 1 AND 135
        SET @errores += N'- El minuto debe estar entre 1 y 135.' + @salto;

    IF @motivo IS NULL OR LEN(LTRIM(RTRIM(@motivo))) = 0
        SET @errores += N'- El motivo es obligatorio.' + @salto;

    IF (@idJugador IS NULL AND @idStaffTecnico IS NULL)
       OR (@idJugador IS NOT NULL AND @idStaffTecnico IS NOT NULL)
        SET @errores += N'- Debe indicarse un jugador o un miembro del staff técnico (uno solo de los dos).' + @salto;
    ELSE IF @idJugador IS NOT NULL
    BEGIN
        SELECT @idSelSancionado = c.IdSeleccion FROM jugadores.Convocatoria AS c WHERE c.IdJugador = @idJugador;

        IF NOT EXISTS (SELECT 1 FROM jugadores.Jugador AS j WHERE j.IdJugador = @idJugador)
            SET @errores += N'- El jugador indicado no existe.' + @salto;
        ELSE IF @idSelSancionado IS NULL
            SET @errores += N'- El jugador indicado no está convocado.' + @salto;
        ELSE IF @existe = 1 AND @idSelSancionado NOT IN (ISNULL(@idLocal, -1), ISNULL(@idVisitante, -1))
            SET @errores += N'- El jugador no pertenece a ninguna de las selecciones del partido.' + @salto;
        ELSE IF @existe = 1
        BEGIN
            IF EXISTS (SELECT 1
                       FROM jugadores.Convocatoria AS c
                       INNER JOIN jugadores.Baja AS b ON b.IdConvocatoria = c.IdConvocatoria
                       WHERE c.IdJugador = @idJugador AND b.FechaBaja <= @fechaLocal)
                SET @errores += N'- El jugador está dado de baja de la convocatoria.' + @salto;

            IF eventos.fn_EstaSuspendido(@idJugador, @idPartido) = 1
                SET @errores += N'- El jugador está suspendido para este partido.' + @salto;

            IF @minuto IS NOT NULL
               AND EXISTS (SELECT 1
                           FROM eventos.Amonestacion AS a
                           INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                           WHERE a.IdPartido = @idPartido AND a.IdJugador = @idJugador
                             AND (@idAmonestacionExcluir IS NULL OR a.IdAmonestacion <> @idAmonestacionExcluir)
                             AND t.Tipo IN ('Roja por doble amarilla', 'Roja directa')
                             AND a.Minuto <= @minuto)
                SET @errores += N'- El jugador ya estaba expulsado en ese minuto.' + @salto;

            IF @susRoja IS NULL OR @susDoble IS NULL OR @susAcum IS NULL OR @cantAcum IS NULL
                SET @errores += N'- Faltan cargar reglas en eventos.ReglaSuspension (Roja Directa, Doble Amarilla y Acumulacion Amarillas).' + @salto;
        END;
    END
    ELSE
    BEGIN
        SELECT @idSelSancionado = s.IdSeleccion FROM nucleo.StaffTecnico AS s WHERE s.IdStaffTecnico = @idStaffTecnico;

        IF @idSelSancionado IS NULL
            SET @errores += N'- El miembro del staff técnico indicado no existe.' + @salto;
        ELSE IF @existe = 1 AND @idSelSancionado NOT IN (ISNULL(@idLocal, -1), ISNULL(@idVisitante, -1))
            SET @errores += N'- El miembro del staff técnico no pertenece a ninguna de las selecciones del partido.' + @salto;
        ELSE IF @existe = 1 AND @minuto IS NOT NULL
                AND EXISTS (SELECT 1
                            FROM eventos.Amonestacion AS a
                            INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                            WHERE a.IdPartido = @idPartido AND a.IdStaffTecnico = @idStaffTecnico
                              AND (@idAmonestacionExcluir IS NULL OR a.IdAmonestacion <> @idAmonestacionExcluir)
                              AND t.Tipo IN ('Roja por doble amarilla', 'Roja directa')
                              AND a.Minuto <= @minuto)
            SET @errores += N'- El miembro del staff técnico ya estaba expulsado en ese minuto.' + @salto;
    END;

    RETURN @errores;
END;
GO

-- =========================================================================
-- fn_CalcularSancion
-- Devuelve una fila con el tipo de tarjeta que corresponde registrar (TipoFinal) y los partidos
-- de suspensión (PartidosSuspension), según eventos.ReglaSuspension:
--   - Segunda amarilla del mismo partido (jugador o staff): 'Roja por doble amarilla'.
--   - Jugador: roja directa = 'Roja Directa'; doble amarilla = 'Doble Amarilla'; amarilla simple =
--     'Acumulacion Amarillas' cuando el total de amarillas (sin contar las de partidos que
--     terminaron en doble amarilla) llega a un múltiplo de CantidadAmarillas.
--   - Staff técnico: nunca suspende (PartidosSuspension = 0).
-- @idAmonestacionExcluir: la amonestación que se está modificando (NULL en un alta).
-- Se asume que la tarjeta ya pasó eventos.fn_ValidarAmonestacion.
-- =========================================================================
CREATE OR ALTER FUNCTION eventos.fn_CalcularSancion
(
    @idPartido             INT,
    @idJugador             INT,
    @idStaffTecnico        INT,
    @tipoTarjeta           VARCHAR(30),
    @idAmonestacionExcluir INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT CASE WHEN @tipoTarjeta = 'Amarilla'
                 AND EXISTS (SELECT 1
                             FROM eventos.Amonestacion AS a
                             INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                             WHERE a.IdPartido = @idPartido
                               AND ((@idJugador IS NOT NULL AND a.IdJugador = @idJugador)
                                 OR (@idStaffTecnico IS NOT NULL AND a.IdStaffTecnico = @idStaffTecnico))
                               AND (@idAmonestacionExcluir IS NULL OR a.IdAmonestacion <> @idAmonestacionExcluir)
                               AND t.Tipo = 'Amarilla')
                THEN CAST('Roja por doble amarilla' AS VARCHAR(30))
                ELSE @tipoTarjeta
           END AS TipoFinal,
           CASE WHEN @idJugador IS NULL
                THEN 0
                WHEN @tipoTarjeta = 'Roja directa'
                THEN ISNULL((SELECT r.PartidosSuspension FROM eventos.ReglaSuspension AS r
                             WHERE r.Criterio = 'Roja Directa'), 0)
                WHEN EXISTS (SELECT 1
                             FROM eventos.Amonestacion AS a
                             INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                             WHERE a.IdPartido = @idPartido
                               AND a.IdJugador = @idJugador
                               AND (@idAmonestacionExcluir IS NULL OR a.IdAmonestacion <> @idAmonestacionExcluir)
                               AND t.Tipo = 'Amarilla')
                THEN ISNULL((SELECT r.PartidosSuspension FROM eventos.ReglaSuspension AS r
                             WHERE r.Criterio = 'Doble Amarilla'), 0)
                WHEN ((SELECT COUNT(*)
                       FROM eventos.Amonestacion AS a
                       INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                       INNER JOIN nucleo.Partido AS po ON po.IdPartido = a.IdPartido
                       WHERE a.IdJugador = @idJugador
                         AND t.Tipo = 'Amarilla'
                         AND (@idAmonestacionExcluir IS NULL OR a.IdAmonestacion <> @idAmonestacionExcluir)
                         AND po.FechaHoraUTC < (SELECT pp.FechaHoraUTC FROM nucleo.Partido AS pp
                                                WHERE pp.IdPartido = @idPartido)
                         AND NOT EXISTS (SELECT 1
                                         FROM eventos.Amonestacion AS r
                                         INNER JOIN eventos.Tarjeta AS tr ON tr.IdTarjeta = r.IdTarjeta
                                         WHERE r.IdPartido = a.IdPartido
                                           AND r.IdJugador = a.IdJugador
                                           AND (@idAmonestacionExcluir IS NULL OR r.IdAmonestacion <> @idAmonestacionExcluir)
                                           AND tr.Tipo = 'Roja por doble amarilla')) + 1)
                      % NULLIF((SELECT r.CantidadAmarillas FROM eventos.ReglaSuspension AS r
                                WHERE r.Criterio = 'Acumulacion Amarillas'), 0) = 0
                THEN ISNULL((SELECT r.PartidosSuspension FROM eventos.ReglaSuspension AS r
                             WHERE r.Criterio = 'Acumulacion Amarillas'), 0)
                ELSE 0
           END AS PartidosSuspension
);
GO
