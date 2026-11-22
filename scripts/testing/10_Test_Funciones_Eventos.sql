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
Objetivo: Probar eventos.fn_ResultadoPartido y eventos.fn_EstaSuspendido.
          Requiere ejecutados los scripts 01 a 10 (usa SP_ABM_Sede y SP_ABM_Partido).
          Datos de prueba con prefijo 'TEST EV' / 'TEST_EV', borrados al inicio y al final.

Escenario: 4 países TEST (selecciones 1 a 4) y una sede.
  Jugadores: J1 y J2 son de la selección 1; J3 es de la selección 2.
  Partidos (todos 20:00, 'Octavos', separados por 4 días por la regla de descanso):
    9201 Sel1 (local) vs Sel2  12/06  -> prueba de resultado, con goles y tanda
    9202 Sel1 (local) vs Sel2  16/06  -> prueba de resultado, sin goles
    9203 Sel1 (local) vs Sel2  20/06  -> partido de la tarjeta (roja directa a J1, 2 partidos)
    9204 Sel1 (local) vs Sel2  24/06
    9205 Sel1 (local) vs Sel2  28/06
    9206 Sel1 (local) vs Sel2  02/07
    9207 Sel3 (local) vs Sel4  21/06  -> partido de otras selecciones
*/

USE MundialFutbol;
GO

-- =========================================================================
-- LIMPIEZA PREVIA
-- =========================================================================
DELETE FROM eventos.Gol          WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 240 AND 249);
DELETE FROM eventos.Amonestacion WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 240 AND 249);
DELETE FROM nucleo.Partido       WHERE NumeroPartido BETWEEN 240 AND 249;
DELETE FROM jugadores.Convocatoria WHERE IdJugador IN (SELECT IdJugador FROM jugadores.Jugador WHERE Documento LIKE 'TEST_EV%');
DELETE FROM jugadores.Jugador    WHERE Documento LIKE 'TEST_EV%';
DELETE FROM nucleo.Seleccion     WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST EV%');
DELETE FROM nucleo.Sede          WHERE NombreEstadio LIKE 'TEST EV%';
DELETE FROM nucleo.Ciudad        WHERE Nombre LIKE 'TEST EV%';
DELETE FROM nucleo.Pais          WHERE Nombre LIKE 'TEST EV%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST EV%';
GO

-- =========================================================================
-- DATOS DE PRUEBA
-- =========================================================================
-- Catálogos de eventos (se insertan solo si faltan; no se borran al final).
INSERT INTO eventos.TipoGol (Descripcion)
SELECT v.d FROM (VALUES ('Jugada'), ('Penal'), ('En contra')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.TipoGol AS t WHERE t.Descripcion = v.d);

INSERT INTO eventos.Periodo (Descripcion)
SELECT v.d FROM (VALUES ('Primer Tiempo'), ('Segundo Tiempo'), ('Definicion por Penales')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Periodo AS t WHERE t.Descripcion = v.d);

INSERT INTO eventos.Tarjeta (Tipo)
SELECT v.d FROM (VALUES ('Amarilla'), ('Roja directa')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Tarjeta AS t WHERE t.Tipo = v.d);

DECLARE @tgJugada INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'Jugada');
DECLARE @tgPenal  INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'Penal');
DECLARE @tgContra INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'En contra');
DECLARE @pePT     INT = (SELECT IdPeriodo FROM eventos.Periodo WHERE Descripcion = 'Primer Tiempo');
DECLARE @peST     INT = (SELECT IdPeriodo FROM eventos.Periodo WHERE Descripcion = 'Segundo Tiempo');
DECLARE @peTanda  INT = (SELECT IdPeriodo FROM eventos.Periodo WHERE Descripcion = 'Definicion por Penales');
DECLARE @tarAmar  INT = (SELECT IdTarjeta FROM eventos.Tarjeta WHERE Tipo = 'Amarilla');
DECLARE @tarRoja  INT = (SELECT IdTarjeta FROM eventos.Tarjeta WHERE Tipo = 'Roja directa');

-- Países, selecciones y sede.
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST EV Confederacion', 'TEV');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TEV');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, HusoHorarioComercial)
VALUES ('TEST EV Pais 1', 'XA', 'XEA', @idConf, 'Argentina Standard Time'),
       ('TEST EV Pais 2', 'XB', 'XEB', @idConf, 'Argentina Standard Time'),
       ('TEST EV Pais 3', 'XC', 'XEC', @idConf, 'Argentina Standard Time'),
       ('TEST EV Pais 4', 'XD', 'XED', @idConf, 'Argentina Standard Time');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
SELECT CodigoISO3, 100 + ROW_NUMBER() OVER (ORDER BY IdPais), IdPais, @idGrupo
FROM nucleo.Pais WHERE CodigoISO3 IN ('XEA', 'XEB', 'XEC', 'XED');

DECLARE @idSel1 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion AS s INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'XEA');
DECLARE @idSel2 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion AS s INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'XEB');
DECLARE @idSel3 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion AS s INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'XEC');
DECLARE @idSel4 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion AS s INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'XED');

DECLARE @idPais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XEA');
INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais) VALUES ('TEST EV Ciudad', 'Argentina Standard Time', @idPais1);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST EV Ciudad');

DECLARE @idSede INT;
INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad) VALUES ('TEST EV Estadio', 60000, @idCiudad);
SET @idSede = SCOPE_IDENTITY();

-- Jugadores convocados.
INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion, IdClub)
VALUES ('Jugador', 'Uno',  'TEST_EV_1', 'M', 'Delantero', NULL),
       ('Jugador', 'Dos',  'TEST_EV_2', 'M', 'Defensor',  NULL),
       ('Jugador', 'Tres', 'TEST_EV_3', 'M', 'Delantero', NULL);

DECLARE @idJ1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV_1');
DECLARE @idJ2 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV_2');
DECLARE @idJ3 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV_3');

INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
VALUES (@idSel1, @idJ1, 9), (@idSel1, @idJ2, 4), (@idSel2, @idJ3, 9);

-- Partidos.
DECLARE @idFase INT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');
DECLARE @p9201 INT, @p9202 INT, @p9203 INT, @p9204 INT, @p9205 INT, @p9206 INT, @p9207 INT;

INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (241, '2026-06-12 20:00', 'Programado', @idFase, @idSede, @idSel1, @idSel2); SET @p9201 = SCOPE_IDENTITY();
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (242, '2026-06-16 20:00', 'Programado', @idFase, @idSede, @idSel1, @idSel2); SET @p9202 = SCOPE_IDENTITY();
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (243, '2026-06-20 20:00', 'Programado', @idFase, @idSede, @idSel1, @idSel2); SET @p9203 = SCOPE_IDENTITY();
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (244, '2026-06-24 20:00', 'Programado', @idFase, @idSede, @idSel1, @idSel2); SET @p9204 = SCOPE_IDENTITY();
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (245, '2026-06-28 20:00', 'Programado', @idFase, @idSede, @idSel1, @idSel2); SET @p9205 = SCOPE_IDENTITY();
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (246, '2026-07-02 20:00', 'Programado', @idFase, @idSede, @idSel1, @idSel2); SET @p9206 = SCOPE_IDENTITY();
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (247, '2026-06-21 20:00', 'Programado', @idFase, @idSede, @idSel3, @idSel4); SET @p9207 = SCOPE_IDENTITY();

-- Goles del partido 9201: 2 a 2 en juego (uno en contra) y tanda 2 a 1 para Sel1.
INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
VALUES (@p9201, @idJ1, NULL, @tgJugada, @pePT,    10),   -- Sel1
       (@p9201, @idJ1, NULL, @tgJugada, @peST,    55),   -- Sel1
       (@p9201, @idJ3, NULL, @tgJugada, @pePT,    30),   -- Sel2
       (@p9201, @idJ2, NULL, @tgContra, @peST,    70),   -- en contra de J2 (Sel1): suma a Sel2
       (@p9201, @idJ1, NULL, @tgPenal,  @peTanda, 120),  -- tanda Sel1
       (@p9201, @idJ2, NULL, @tgPenal,  @peTanda, 120),  -- tanda Sel1
       (@p9201, @idJ3, NULL, @tgPenal,  @peTanda, 120);  -- tanda Sel2

-- Tarjetas: roja directa a J1 en 9203 (2 partidos) y amarilla sin suspensión a J2 en 9203.
INSERT INTO eventos.Amonestacion (IdPartido, IdTarjeta, IdJugador, IdStaffTecnico, Minuto, Motivo, PartidosSuspension)
VALUES (@p9203, @tarRoja, @idJ1, NULL, 40, 'TEST EV Agresion', 2),
       (@p9203, @tarAmar, @idJ2, NULL, 60, 'TEST EV Falta tactica', 0);

-- =========================================================================
-- TEST 1: eventos.fn_ResultadoPartido
-- =========================================================================
-- 1.A Partido 9201 (con goles y tanda).
-- Resultado esperado: GolesLocal = 2, GolesVisitante = 2, PenalesLocal = 2, PenalesVisitante = 1
--                     (el gol en contra de J2 suma a Sel2; los goles de la tanda no suman a los goles).
SELECT '1.A' AS Test, GolesLocal, GolesVisitante, PenalesLocal, PenalesVisitante
FROM eventos.fn_ResultadoPartido(@p9201);

-- 1.B Partido 9202 (sin goles cargados).
-- Resultado esperado: GolesLocal = 0, GolesVisitante = 0, PenalesLocal = NULL, PenalesVisitante = NULL.
SELECT '1.B' AS Test, GolesLocal, GolesVisitante, PenalesLocal, PenalesVisitante
FROM eventos.fn_ResultadoPartido(@p9202);

-- 1.C Partido inexistente.
-- Resultado esperado: 0 filas.
SELECT '1.C' AS Test, COUNT(*) AS Filas_Esperadas_0
FROM eventos.fn_ResultadoPartido(-1);

-- =========================================================================
-- TEST 2: eventos.fn_EstaSuspendido
-- (J1 tiene roja directa en 9203 con 2 partidos de suspensión)
-- =========================================================================
-- 2.A J1 en el mismo partido de la tarjeta (9203).
-- Resultado esperado: 0 (la sanción rige desde el partido siguiente).
SELECT '2.A' AS Test, eventos.fn_EstaSuspendido(@idJ1, @p9203) AS Suspendido;

-- 2.B J1 en el primer partido siguiente (9204).
-- Resultado esperado: 1.
SELECT '2.B' AS Test, eventos.fn_EstaSuspendido(@idJ1, @p9204) AS Suspendido;

-- 2.C J1 en el segundo partido siguiente (9205).
-- Resultado esperado: 1.
SELECT '2.C' AS Test, eventos.fn_EstaSuspendido(@idJ1, @p9205) AS Suspendido;

-- 2.D J1 en el tercer partido siguiente (9206): ya cumplió la sanción.
-- Resultado esperado: 0.
SELECT '2.D' AS Test, eventos.fn_EstaSuspendido(@idJ1, @p9206) AS Suspendido;

-- 2.E J2 con amarilla sin suspensión (PartidosSuspension = 0), en 9204.
-- Resultado esperado: 0.
SELECT '2.E' AS Test, eventos.fn_EstaSuspendido(@idJ2, @p9204) AS Suspendido;

-- 2.F J1 en un partido de otras selecciones (9207, entre 9203 y 9204).
-- Resultado esperado: 0 (el partido no lo juega la selección de J1).
SELECT '2.F' AS Test, eventos.fn_EstaSuspendido(@idJ1, @p9207) AS Suspendido;

-- 2.G Jugador inexistente.
-- Resultado esperado: 0.
SELECT '2.G' AS Test, eventos.fn_EstaSuspendido(-1, @p9204) AS Suspendido;

-- 2.H Partido inexistente.
-- Resultado esperado: 0.
SELECT '2.H' AS Test, eventos.fn_EstaSuspendido(@idJ1, -1) AS Suspendido;
GO

-- =========================================================================
-- LIMPIEZA FINAL
-- =========================================================================
DELETE FROM eventos.Gol          WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 240 AND 249);
DELETE FROM eventos.Amonestacion WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 240 AND 249);
DELETE FROM nucleo.Partido       WHERE NumeroPartido BETWEEN 240 AND 249;
DELETE FROM jugadores.Convocatoria WHERE IdJugador IN (SELECT IdJugador FROM jugadores.Jugador WHERE Documento LIKE 'TEST_EV%');
DELETE FROM jugadores.Jugador    WHERE Documento LIKE 'TEST_EV%';
DELETE FROM nucleo.Seleccion     WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST EV%');
DELETE FROM nucleo.Sede          WHERE NombreEstadio LIKE 'TEST EV%';
DELETE FROM nucleo.Ciudad        WHERE Nombre LIKE 'TEST EV%';
DELETE FROM nucleo.Pais          WHERE Nombre LIKE 'TEST EV%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST EV%';
GO
