/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Canseco Carrizo, Yamil Simón
Integrantes:
Casella, Mateo Ezequiel
Chungara Tenorio, Denis Abner
Torczuk, Elías Alexei
Canseco Carrizo, Yamil Simón
Objetivo:
	- Probar nucleo.fn_DefinicionPartido, nucleo.fn_SeleccionesClasificadas,
	  nucleo.fn_FaseEliminatoriaInicial, nucleo.fn_ValidarFaseGruposCompleta y
	  nucleo.vw_PartidoResultado (script 25).
	- Requiere ejecutados los scripts 01 a 25 sobre una base recién creada con 00_Reset_Total.sql
	  (el escenario consume 48 valores de IDENTITY de nucleo.Seleccion, que es TINYINT).
	- Todo se inserta directo (sin SP). Datos con prefijo 'TEST FP' / 'TEST_FP', borrados al inicio
	  y deshechos al final (ROLLBACK), por lo que no queda nada en la base. Los cambios que el test
	  hace sobre nucleo.ReglaClasificacion también se deshacen.
	- Convención de salida: "OK" -> el caso se comportó como se esperaba; "FALLÓ" -> no;
	  "OMITIDO" -> el caso necesita una base sin otras selecciones.

Escenario: 12 grupos (letras M a X) de 4 selecciones TEST (48), una sede y un jugador convocado por
selección de los grupos M, N y O (12 jugadores, TEST_FP_01 a TEST_FP_12).
  Selecciones: a1..a4 = grupo M (TXA..TXD), b1..b4 = grupo N (TXE..TXH), c1..c4 = grupo O (TXI..TXL).
  Los grupos P a X no tienen partidos (todo en cero).
  Partidos de fase de grupos (Finalizado; entre paréntesis el resultado local-visitante):
    101 a1-a2 (2-0)  102 a1-a3 (1-1)  103 a1-a4 (0-1)  104 a2-a3 (3-0)  105 a2-a4 (1-0)  106 a3-a4 (2-0)
    111 b1-b2 (4-1)  112 b1-b3 (1-2)  113 b1-b4 (1-0)  114 b2-b3 (2-0)  115 b2-b4 (0-0)  116 b3-b4 (0-0)
    121 c1-c2 (1-0)
    122 c3-c4 (1-1 y tanda 3-2 para c3: en grupos la tanda se ignora)
    123 c1-c3 PROGRAMADO con 3 goles de c3 cargados (se ignora)
  Partidos de octavos de final (Finalizado):
    131 c1-c2 (2-0, se ignora en la tabla de grupos)
    141 a1-a2 (2-1)  142 a3-a4 (0-1)  143 a1-a3 (gol en contra de a3: 1-0)
    144 a2-a4 (1-1, tanda 4-3)  145 a1-a4 (1-1, tanda 3-3)  146 a2-a3 (0-0, sin tanda)
*/

USE MundialFutbol;
GO

-- Si una corrida anterior quedó con la transacción abierta, se deshace antes de empezar.
WHILE @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;

-- =========================================================================
-- LIMPIEZA PREVIA
-- =========================================================================
DELETE FROM eventos.Gol WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 101 AND 146);
DELETE FROM nucleo.Partido       WHERE NumeroPartido BETWEEN 101 AND 146;
DELETE FROM jugadores.Convocatoria WHERE IdJugador IN (SELECT IdJugador FROM jugadores.Jugador WHERE Documento LIKE 'TEST_FP%');
DELETE FROM jugadores.Jugador    WHERE Documento LIKE 'TEST_FP%';
DELETE FROM nucleo.Seleccion     WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST FP%');
DELETE FROM nucleo.Grupo         WHERE Nombre BETWEEN 'M' AND 'X' AND IdGrupo NOT IN (SELECT IdGrupo FROM nucleo.Seleccion);
DELETE FROM nucleo.Sede          WHERE NombreEstadio LIKE 'TEST FP%';
DELETE FROM nucleo.Ciudad        WHERE Nombre LIKE 'TEST FP%';
DELETE FROM nucleo.Pais          WHERE Nombre LIKE 'TEST FP%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST FP%';
GO

BEGIN TRANSACTION;

-- =========================================================================
-- DATOS DE PRUEBA
-- =========================================================================
-- Catálogos de eventos (se insertan solo si faltan).
INSERT INTO eventos.TipoGol (Descripcion)
SELECT v.d FROM (VALUES ('Jugada'), ('Penal'), ('En contra')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.TipoGol AS t WHERE t.Descripcion = v.d);

INSERT INTO eventos.Periodo (Descripcion)
SELECT v.d FROM (VALUES ('Primer Tiempo'), ('Definicion por Penales')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Periodo AS t WHERE t.Descripcion = v.d);

DECLARE @tgJugada INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'Jugada');
DECLARE @tgPenal  INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'Penal');
DECLARE @tgContra INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'En contra');
DECLARE @pePT     INT = (SELECT IdPeriodo FROM eventos.Periodo WHERE Descripcion = 'Primer Tiempo');
DECLARE @peTanda  INT = (SELECT IdPeriodo FROM eventos.Periodo WHERE Descripcion = 'Definicion por Penales');

-- Regla de clasificación inicial del test: 2 por grupo, sin mejores terceros.
DELETE FROM nucleo.ReglaClasificacion;
INSERT INTO nucleo.ReglaClasificacion (IdRegla, ClasificadosPorGrupo, MejoresTerceros) VALUES (1, 2, 0);

-- 48 países (XA..XZ, YA..YV), 12 grupos (M..X) y 48 selecciones (4 por grupo, en orden de IdSeleccion).
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST FP Confederacion', 'TFP');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TFP');

WITH Nums AS (
	SELECT TOP (48) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_objects
)
INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, HusoHorarioComercial)
SELECT 'TEST FP Pais ' + RIGHT('0' + CAST(n AS VARCHAR(2)), 2),
       CASE WHEN n <= 26 THEN 'X' ELSE 'Y' END + CHAR(65 + ((n - 1) % 26)),
       'T' + CASE WHEN n <= 26 THEN 'X' ELSE 'Y' END + CHAR(65 + ((n - 1) % 26)),
       @idConf,
       'Argentina Standard Time'
FROM Nums;

INSERT INTO nucleo.Grupo (Nombre)
SELECT CHAR(76 + v.n)
FROM (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12)) AS v(n)
WHERE NOT EXISTS (SELECT 1 FROM nucleo.Grupo AS g WHERE g.Nombre = CHAR(76 + v.n));

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
SELECT p.CodigoISO3, 100 + x.n, p.IdPais, g.IdGrupo
FROM nucleo.Pais AS p
CROSS APPLY (SELECT CAST(RIGHT(p.Nombre, 2) AS INT) AS n) AS x
INNER JOIN nucleo.Grupo AS g ON g.Nombre = CHAR(76 + ((x.n - 1) / 4) + 1)
WHERE p.Nombre LIKE 'TEST FP Pais%'
ORDER BY x.n;

DECLARE @a1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TXA');
DECLARE @a2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TXB');
DECLARE @a3 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TXC');
DECLARE @a4 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TXD');
DECLARE @b1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TXE');
DECLARE @b2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TXF');
DECLARE @b3 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TXG');
DECLARE @b4 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TXH');
DECLARE @c1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TXI');
DECLARE @c2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TXJ');
DECLARE @c3 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TXK');
DECLARE @c4 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TXL');

DECLARE @gM TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'M');
DECLARE @gN TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'N');
DECLARE @gO TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'O');

-- Sede.
DECLARE @idPais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TXA');
INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais) VALUES ('TEST FP Ciudad', 'Argentina Standard Time', @idPais1);
INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad)
VALUES ('TEST FP Estadio', 60000, (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST FP Ciudad'));
DECLARE @idSede TINYINT = (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio = 'TEST FP Estadio');

-- Jugadores: el jugador n está convocado en la selección n (a1..a4, b1..b4, c1..c4).
INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion, IdClub)
SELECT 'Jugador', 'FP' + CAST(v.n AS VARCHAR(2)), 'TEST_FP_' + RIGHT('0' + CAST(v.n AS VARCHAR(2)), 2), 'M', 'Delantero', NULL
FROM (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12)) AS v(n);

INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
SELECT s.IdSeleccion, j.IdJugador, 9
FROM jugadores.Jugador AS j
CROSS APPLY (SELECT CAST(RIGHT(j.Documento, 2) AS INT) AS n) AS x
INNER JOIN nucleo.Seleccion AS s ON s.CodigoFIFA = 'TX' + CHAR(64 + x.n)
WHERE j.Documento LIKE 'TEST_FP_%';

-- Partidos (una fecha distinta por número de partido, en la única sede).
DECLARE @fGrupos  TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Fase de grupos');
DECLARE @fOctavos TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');

INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
SELECT v.Num, DATEADD(DAY, v.Num, CAST('2026-01-01 18:00' AS DATETIME2(0))), v.Estado, v.IdFase, @idSede, v.Loc, v.Vis
FROM (VALUES
	(101, 'Finalizado', @fGrupos, @a1, @a2), (102, 'Finalizado', @fGrupos, @a1, @a3),
	(103, 'Finalizado', @fGrupos, @a1, @a4), (104, 'Finalizado', @fGrupos, @a2, @a3),
	(105, 'Finalizado', @fGrupos, @a2, @a4), (106, 'Finalizado', @fGrupos, @a3, @a4),
	(111, 'Finalizado', @fGrupos, @b1, @b2), (112, 'Finalizado', @fGrupos, @b1, @b3),
	(113, 'Finalizado', @fGrupos, @b1, @b4), (114, 'Finalizado', @fGrupos, @b2, @b3),
	(115, 'Finalizado', @fGrupos, @b2, @b4), (116, 'Finalizado', @fGrupos, @b3, @b4),
	(121, 'Finalizado', @fGrupos, @c1, @c2), (122, 'Finalizado', @fGrupos, @c3, @c4),
	(123, 'Programado', @fGrupos, @c1, @c3),
	(131, 'Finalizado', @fOctavos, @c1, @c2),
	(141, 'Finalizado', @fOctavos, @a1, @a2), (142, 'Finalizado', @fOctavos, @a3, @a4),
	(143, 'Finalizado', @fOctavos, @a1, @a3), (144, 'Finalizado', @fOctavos, @a2, @a4),
	(145, 'Finalizado', @fOctavos, @a1, @a4), (146, 'Finalizado', @fOctavos, @a2, @a3)
) AS v(Num, Estado, IdFase, Loc, Vis);

-- Goles en juego (tipo 'Jugada', primer tiempo): (partido, jugador autor, cantidad).
INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
SELECT p.IdPartido, j.IdJugador, NULL, @tgJugada, @pePT, 10 + k.n * 5
FROM (VALUES
	(101, 1, 2),
	(102, 1, 1), (102, 3, 1),
	(103, 4, 1),
	(104, 2, 3),
	(105, 2, 1),
	(106, 3, 2),
	(111, 5, 4), (111, 6, 1),
	(112, 5, 1), (112, 7, 2),
	(113, 5, 1),
	(114, 6, 2),
	(121, 9, 1),
	(122, 11, 1), (122, 12, 1),
	(123, 11, 3),
	(131, 9, 2),
	(141, 1, 2), (141, 2, 1),
	(142, 4, 1),
	(144, 2, 1), (144, 4, 1),
	(145, 1, 1), (145, 4, 1)
) AS g(Num, Jug, Cant)
INNER JOIN nucleo.Partido AS p ON p.NumeroPartido = g.Num
INNER JOIN jugadores.Jugador AS j ON j.Documento = 'TEST_FP_' + RIGHT('0' + CAST(g.Jug AS VARCHAR(2)), 2)
INNER JOIN (VALUES (1), (2), (3), (4)) AS k(n) ON k.n <= g.Cant;

-- Gol en contra: el jugador 3 (a3) marca en su propia valla en el partido 143 y suma a a1 (local).
INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
SELECT p.IdPartido, j.IdJugador, NULL, @tgContra, @pePT, 30
FROM nucleo.Partido AS p
INNER JOIN jugadores.Jugador AS j ON j.Documento = 'TEST_FP_03'
WHERE p.NumeroPartido = 143;

-- Tandas de penales (tipo 'Penal', período 'Definicion por Penales'): (partido, jugador, cantidad).
INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
SELECT p.IdPartido, j.IdJugador, NULL, @tgPenal, @peTanda, 120
FROM (VALUES
	(122, 11, 3), (122, 12, 2),
	(144, 2, 4),  (144, 4, 3),
	(145, 1, 3),  (145, 4, 3)
) AS g(Num, Jug, Cant)
INNER JOIN nucleo.Partido AS p ON p.NumeroPartido = g.Num
INNER JOIN jugadores.Jugador AS j ON j.Documento = 'TEST_FP_' + RIGHT('0' + CAST(g.Jug AS VARCHAR(2)), 2)
INNER JOIN (VALUES (1), (2), (3), (4)) AS k(n) ON k.n <= g.Cant;

DECLARE @id SMALLINT;

-- =========================================================================
-- TEST 1: nucleo.fn_DefinicionPartido
-- =========================================================================
-- 1.A Octavos 2-1.
-- Esperado: ganador a1, perdedor a2, DefinidoPorPenales = 0.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 141);
IF EXISTS (SELECT 1 FROM nucleo.fn_DefinicionPartido(@id) WHERE IdGanador = @a1 AND IdPerdedor = @a2 AND DefinidoPorPenales = 0)
	PRINT 'TEST 1.A OK: gana el local por goles.';
ELSE
	PRINT 'TEST 1.A FALLÓ: no devolvió ganador a1 / perdedor a2.';

-- 1.B Octavos 0-1 (gana el visitante).
-- Esperado: ganador a4, perdedor a3, DefinidoPorPenales = 0.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 142);
IF EXISTS (SELECT 1 FROM nucleo.fn_DefinicionPartido(@id) WHERE IdGanador = @a4 AND IdPerdedor = @a3 AND DefinidoPorPenales = 0)
	PRINT 'TEST 1.B OK: gana el visitante por goles.';
ELSE
	PRINT 'TEST 1.B FALLÓ: no devolvió ganador a4 / perdedor a3.';

-- 1.C Octavos con un único gol en contra de a3.
-- Esperado: el gol en contra suma al rival: ganador a1 (1-0), perdedor a3.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 143);
IF EXISTS (SELECT 1 FROM nucleo.fn_DefinicionPartido(@id) WHERE IdGanador = @a1 AND IdPerdedor = @a3 AND DefinidoPorPenales = 0)
	PRINT 'TEST 1.C OK: el gol en contra suma al rival.';
ELSE
	PRINT 'TEST 1.C FALLÓ: no devolvió ganador a1 / perdedor a3.';

-- 1.D Fase de grupos 1-1.
-- Esperado: empate: IdGanador e IdPerdedor NULL, DefinidoPorPenales = 0.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 102);
IF EXISTS (SELECT 1 FROM nucleo.fn_DefinicionPartido(@id) WHERE IdGanador IS NULL AND IdPerdedor IS NULL AND DefinidoPorPenales = 0)
	PRINT 'TEST 1.D OK: el empate en grupos no tiene ganador.';
ELSE
	PRINT 'TEST 1.D FALLÓ: el empate de grupos devolvió ganador o no devolvió fila.';

-- 1.E Octavos 1-1 con tanda 4-3 para a2.
-- Esperado: ganador a2, perdedor a4, DefinidoPorPenales = 1.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 144);
IF EXISTS (SELECT 1 FROM nucleo.fn_DefinicionPartido(@id) WHERE IdGanador = @a2 AND IdPerdedor = @a4 AND DefinidoPorPenales = 1)
	PRINT 'TEST 1.E OK: gana a2 por penales.';
ELSE
	PRINT 'TEST 1.E FALLÓ: no devolvió ganador a2 por penales.';

-- 1.F Octavos 1-1 con tanda igualada 3-3 (dato inválido).
-- Esperado: IdGanador e IdPerdedor NULL, DefinidoPorPenales = 0.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 145);
IF EXISTS (SELECT 1 FROM nucleo.fn_DefinicionPartido(@id) WHERE IdGanador IS NULL AND IdPerdedor IS NULL AND DefinidoPorPenales = 0)
	PRINT 'TEST 1.F OK: la tanda igualada no define ganador.';
ELSE
	PRINT 'TEST 1.F FALLÓ: la tanda igualada devolvió ganador o no devolvió fila.';

-- 1.G Octavos 0-0 sin tanda (dato inválido).
-- Esperado: IdGanador e IdPerdedor NULL, DefinidoPorPenales = 0.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 146);
IF EXISTS (SELECT 1 FROM nucleo.fn_DefinicionPartido(@id) WHERE IdGanador IS NULL AND IdPerdedor IS NULL AND DefinidoPorPenales = 0)
	PRINT 'TEST 1.G OK: el empate sin tanda en eliminatoria no define ganador.';
ELSE
	PRINT 'TEST 1.G FALLÓ: devolvió ganador o no devolvió fila.';

-- 1.H Fase de grupos 1-1 con tanda 3-2 cargada.
-- Esperado: la tanda se ignora en grupos: IdGanador NULL, DefinidoPorPenales = 0.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 122);
IF EXISTS (SELECT 1 FROM nucleo.fn_DefinicionPartido(@id) WHERE IdGanador IS NULL AND IdPerdedor IS NULL AND DefinidoPorPenales = 0)
	PRINT 'TEST 1.H OK: la tanda se ignora en fase de grupos.';
ELSE
	PRINT 'TEST 1.H FALLÓ: la tanda de un partido de grupos definió ganador.';

-- 1.I Partido Programado con 3 goles de c3 (visitante) cargados.
-- Esperado: la función no mira el Estado (la usa SP_FINALIZAR_PARTIDO antes de cerrar el partido):
--           ganador c3, perdedor c1, DefinidoPorPenales = 0. La vista lo oculta (ver TEST 5.C).
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 123);
IF EXISTS (SELECT 1 FROM nucleo.fn_DefinicionPartido(@id) WHERE IdGanador = @c3 AND IdPerdedor = @c1 AND DefinidoPorPenales = 0)
	PRINT 'TEST 1.I OK: la definición se calcula también para un partido Programado.';
ELSE
	PRINT 'TEST 1.I FALLÓ: no calculó el ganador de un partido Programado.';

-- 1.J Partido inexistente.
-- Esperado: 0 filas.
IF NOT EXISTS (SELECT 1 FROM nucleo.fn_DefinicionPartido(0))
	PRINT 'TEST 1.J OK: un partido inexistente no devuelve filas.';
ELSE
	PRINT 'TEST 1.J FALLÓ: devolvió fila para un partido inexistente.';

-- =========================================================================
-- TEST 2: nucleo.fn_SeleccionesClasificadas - tabla de posiciones (cupo 2, 0)
-- =========================================================================
DECLARE @esp TABLE (IdSeleccion TINYINT, PJ INT, PG INT, PE INT, PP INT, GF INT, GC INT, DG INT, Pts INT, Posicion INT);

-- 2.A Grupo M: victorias, empates y derrotas; a1 y a3 empatan en puntos y se desempatan por DG.
-- Esperado: a2 (6 pts, 1.º), a1 (4 pts, DG +1, 2.º), a3 (4 pts, DG -1, 3.º), a4 (3 pts, 4.º).
INSERT INTO @esp VALUES
	(@a2, 3, 2, 0, 1, 4, 2,  2, 6, 1),
	(@a1, 3, 1, 1, 1, 3, 2,  1, 4, 2),
	(@a3, 3, 1, 1, 1, 3, 4, -1, 4, 3),
	(@a4, 3, 1, 0, 2, 1, 3, -2, 3, 4);
IF NOT EXISTS (SELECT * FROM @esp
               EXCEPT SELECT IdSeleccion, PJ, PG, PE, PP, GF, GC, DG, Pts, Posicion FROM nucleo.fn_SeleccionesClasificadas() WHERE IdGrupo = @gM)
   AND NOT EXISTS (SELECT IdSeleccion, PJ, PG, PE, PP, GF, GC, DG, Pts, Posicion FROM nucleo.fn_SeleccionesClasificadas() WHERE IdGrupo = @gM
                   EXCEPT SELECT * FROM @esp)
	PRINT 'TEST 2.A OK: tabla del grupo M y desempate por diferencia de gol.';
ELSE
	PRINT 'TEST 2.A FALLÓ: la tabla del grupo M no coincide con la esperada.';

-- 2.B Grupo N: b2 y b3 empatan en puntos (4) y en DG (-1); se desempatan por goles a favor.
-- Esperado: b1 (6 pts, 1.º), b2 (GF 3, 2.º), b3 (GF 2, 3.º), b4 (2 pts, 4.º).
DELETE FROM @esp;
INSERT INTO @esp VALUES
	(@b1, 3, 2, 0, 1, 6, 3,  3, 6, 1),
	(@b2, 3, 1, 1, 1, 3, 4, -1, 4, 2),
	(@b3, 3, 1, 1, 1, 2, 3, -1, 4, 3),
	(@b4, 3, 0, 2, 1, 0, 1, -1, 2, 4);
IF NOT EXISTS (SELECT * FROM @esp
               EXCEPT SELECT IdSeleccion, PJ, PG, PE, PP, GF, GC, DG, Pts, Posicion FROM nucleo.fn_SeleccionesClasificadas() WHERE IdGrupo = @gN)
   AND NOT EXISTS (SELECT IdSeleccion, PJ, PG, PE, PP, GF, GC, DG, Pts, Posicion FROM nucleo.fn_SeleccionesClasificadas() WHERE IdGrupo = @gN
                   EXCEPT SELECT * FROM @esp)
	PRINT 'TEST 2.B OK: tabla del grupo N y desempate por goles a favor.';
ELSE
	PRINT 'TEST 2.B FALLÓ: la tabla del grupo N no coincide con la esperada.';

-- 2.C Grupo O: solo cuentan los partidos de grupos finalizados (121 y 122). Se ignoran el 123
--     (Programado, con goles), el 131 (octavos) y la tanda del 122. c3 y c4 empatan en todo
--     (1 pt, DG 0, GF 1) y se desempatan por IdSeleccion (c3 es anterior).
-- Esperado: c1 (3 pts, 1.º), c3 (1 pt, 2.º), c4 (1 pt, 3.º), c2 (0 pts, 4.º).
DELETE FROM @esp;
INSERT INTO @esp VALUES
	(@c1, 1, 1, 0, 0, 1, 0,  1, 3, 1),
	(@c3, 1, 0, 1, 0, 1, 1,  0, 1, 2),
	(@c4, 1, 0, 1, 0, 1, 1,  0, 1, 3),
	(@c2, 1, 0, 0, 1, 0, 1, -1, 0, 4);
IF NOT EXISTS (SELECT * FROM @esp
               EXCEPT SELECT IdSeleccion, PJ, PG, PE, PP, GF, GC, DG, Pts, Posicion FROM nucleo.fn_SeleccionesClasificadas() WHERE IdGrupo = @gO)
   AND NOT EXISTS (SELECT IdSeleccion, PJ, PG, PE, PP, GF, GC, DG, Pts, Posicion FROM nucleo.fn_SeleccionesClasificadas() WHERE IdGrupo = @gO
                   EXCEPT SELECT * FROM @esp)
	PRINT 'TEST 2.C OK: tabla del grupo O, partidos no válidos ignorados y desempate por IdSeleccion.';
ELSE
	PRINT 'TEST 2.C FALLÓ: la tabla del grupo O no coincide con la esperada.';

-- 2.D Grupos P a X (sin partidos).
-- Esperado: las 36 selecciones aparecen con PJ = 0 y Pts = 0, ordenadas por IdSeleccion.
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionesClasificadas() WHERE Grupo BETWEEN 'P' AND 'X') = 36
   AND NOT EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE Grupo BETWEEN 'P' AND 'X' AND (PJ <> 0 OR Pts <> 0))
   AND NOT EXISTS (SELECT 1
                   FROM (SELECT Posicion, ROW_NUMBER() OVER (PARTITION BY IdGrupo ORDER BY IdSeleccion) AS rn
                         FROM nucleo.fn_SeleccionesClasificadas() WHERE Grupo BETWEEN 'P' AND 'X') AS x
                   WHERE x.Posicion <> x.rn)
	PRINT 'TEST 2.D OK: grupos sin partidos con todo en cero y orden por IdSeleccion.';
ELSE
	PRINT 'TEST 2.D FALLÓ: los grupos sin partidos no quedaron en cero o desordenados.';

-- =========================================================================
-- TEST 3: nucleo.fn_SeleccionesClasificadas - cupo de clasificados
-- =========================================================================
-- Con otras selecciones en la base (por ejemplo el seed) el ranking de mejores terceros incluiría a
-- esas selecciones: los casos que dependen de ese ranking se omiten.
DECLARE @hayOtras BIT = CASE WHEN EXISTS (SELECT 1 FROM nucleo.Seleccion AS s
                                          INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais
                                          WHERE p.Nombre NOT LIKE 'TEST FP%')
                             THEN 1 ELSE 0 END;

-- 3.A Cupo (2, 0).
-- Esperado: clasifican 'Directo' los dos primeros de cada grupo (24 en total): a2 y a1 sí; a3 y a4 no.
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionesClasificadas() WHERE Grupo BETWEEN 'M' AND 'X' AND Clasifica = 1) = 24
   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE IdSeleccion = @a2 AND Clasifica = 1 AND ClasificaComo = 'Directo')
   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE IdSeleccion = @a1 AND Clasifica = 1 AND ClasificaComo = 'Directo')
   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE IdSeleccion = @a3 AND Clasifica = 0 AND ClasificaComo IS NULL)
   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE IdSeleccion = @a4 AND Clasifica = 0 AND ClasificaComo IS NULL)
	PRINT 'TEST 3.A OK: cupo (2, 0): 2 clasificados directos por grupo.';
ELSE
	PRINT 'TEST 3.A FALLÓ: el cupo (2, 0) no clasificó a los dos primeros de cada grupo.';

-- 3.B Cupo (2, 1): se suma el mejor tercero entre los grupos.
-- Esperado: a3 (4 pts, DG -1, GF 3) es el mejor tercero y le gana a b3 (4 pts, DG -1, GF 2) por goles
--           a favor; c4 y el resto no clasifican. Total: 24 directos + 1 = 25.
IF @hayOtras = 1
	PRINT 'TEST 3.B OMITIDO: la base tiene selecciones que no son de este test.';
ELSE
BEGIN
	UPDATE nucleo.ReglaClasificacion SET ClasificadosPorGrupo = 2, MejoresTerceros = 1 WHERE IdRegla = 1;
	IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionesClasificadas() WHERE Grupo BETWEEN 'M' AND 'X' AND Clasifica = 1) = 25
	   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE IdSeleccion = @a3 AND Clasifica = 1 AND ClasificaComo = 'Mejor tercero')
	   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE IdSeleccion = @b3 AND Clasifica = 0)
	   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE IdSeleccion = @c4 AND Clasifica = 0)
		PRINT 'TEST 3.B OK: cupo (2, 1): a3 es el mejor tercero.';
	ELSE
		PRINT 'TEST 3.B FALLÓ: el mejor tercero no es a3 o el total no es 25.';
END;

-- 3.C Cupo (1, 4): 1 directo por grupo y 4 más tomados del puesto siguiente (los mejores segundos).
-- Esperado: 12 directos + 4 = 16. Los mejores segundos son a1 (4 pts, DG +1), b2 (4 pts, DG -1)
--           y c3 (1 pt), más el segundo de un grupo sin partidos; salen con 'Mejor tercero'
--           (nombre genérico del cupo adicional, ver encabezado del script 25).
IF @hayOtras = 1
	PRINT 'TEST 3.C OMITIDO: la base tiene selecciones que no son de este test.';
ELSE
BEGIN
	UPDATE nucleo.ReglaClasificacion SET ClasificadosPorGrupo = 1, MejoresTerceros = 4 WHERE IdRegla = 1;
	IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionesClasificadas() WHERE Grupo BETWEEN 'M' AND 'X' AND Clasifica = 1) = 16
	   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE IdSeleccion = @a2 AND ClasificaComo = 'Directo')
	   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE IdSeleccion = @a1 AND ClasificaComo = 'Mejor tercero')
	   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE IdSeleccion = @b2 AND ClasificaComo = 'Mejor tercero')
	   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE IdSeleccion = @c3 AND ClasificaComo = 'Mejor tercero')
		PRINT 'TEST 3.C OK: cupo (1, 4): el cupo adicional se toma del puesto siguiente a los directos.';
	ELSE
		PRINT 'TEST 3.C FALLÓ: el cupo (1, 4) no clasificó a los mejores segundos.';
END;

-- 3.D Regla de clasificación inexistente.
-- Esperado: la función devuelve igual las 48 selecciones, todas con Clasifica = 0 y ClasificaComo NULL.
DELETE FROM nucleo.ReglaClasificacion;
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionesClasificadas() WHERE Grupo BETWEEN 'M' AND 'X') = 48
   AND NOT EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesClasificadas() WHERE Grupo BETWEEN 'M' AND 'X' AND (Clasifica = 1 OR ClasificaComo IS NOT NULL))
	PRINT 'TEST 3.D OK: sin regla se devuelven las posiciones y nadie clasifica.';
ELSE
	PRINT 'TEST 3.D FALLÓ: sin regla la función no devolvió las posiciones sin clasificados.';
INSERT INTO nucleo.ReglaClasificacion (IdRegla, ClasificadosPorGrupo, MejoresTerceros) VALUES (1, 2, 0);

-- =========================================================================
-- TEST 4: nucleo.fn_FaseEliminatoriaInicial
-- =========================================================================
-- La función cuenta los clasificados de TODAS las selecciones de la base: con selecciones que no son
-- de este test los totales cambian y los casos se omiten.
IF @hayOtras = 1
	PRINT 'TEST 4 OMITIDO: la base tiene selecciones que no son de este test.';
ELSE
BEGIN
	-- 4.A 12 grupos, regla (2, 8) = 24 + 8 = 32.
	-- Esperado: 'Dieciseisavos de final' con TotalClasificados = 32.
	UPDATE nucleo.ReglaClasificacion SET ClasificadosPorGrupo = 2, MejoresTerceros = 8 WHERE IdRegla = 1;
	IF EXISTS (SELECT 1 FROM nucleo.fn_FaseEliminatoriaInicial() WHERE Nombre = 'Dieciseisavos de final' AND TotalClasificados = 32)
		PRINT 'TEST 4.A OK: 12 grupos con (2, 8) = 32 clasificados, empieza en dieciseisavos.';
	ELSE
		PRINT 'TEST 4.A FALLÓ: no devolvió dieciseisavos con 32 clasificados.';

	-- 4.B 12 grupos, regla (1, 4) = 12 + 4 = 16.
	-- Esperado: 'Octavos de final' con TotalClasificados = 16.
	UPDATE nucleo.ReglaClasificacion SET ClasificadosPorGrupo = 1, MejoresTerceros = 4 WHERE IdRegla = 1;
	IF EXISTS (SELECT 1 FROM nucleo.fn_FaseEliminatoriaInicial() WHERE Nombre = 'Octavos de final' AND TotalClasificados = 16)
		PRINT 'TEST 4.B OK: 12 grupos con (1, 4) = 16 clasificados, empieza en octavos.';
	ELSE
		PRINT 'TEST 4.B FALLÓ: no devolvió octavos con 16 clasificados.';

	-- 4.C 12 grupos, regla (2, 0) = 24 (regla de 8 grupos con el formato de 12).
	-- Esperado: 0 filas (el total no corresponde a ninguna fase).
	UPDATE nucleo.ReglaClasificacion SET ClasificadosPorGrupo = 2, MejoresTerceros = 0 WHERE IdRegla = 1;
	IF NOT EXISTS (SELECT 1 FROM nucleo.fn_FaseEliminatoriaInicial())
		PRINT 'TEST 4.C OK: 24 clasificados es un total inválido (0 filas).';
	ELSE
		PRINT 'TEST 4.C FALLÓ: devolvió una fase para un total de 24 clasificados.';

	-- Se quitan los grupos U a X (sin partidos ni jugadores): quedan 8 grupos de 4 selecciones.
	DELETE FROM nucleo.Seleccion WHERE IdGrupo IN (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre BETWEEN 'U' AND 'X');

	-- 4.D 8 grupos, regla (2, 0) = 16.
	-- Esperado: 'Octavos de final' con TotalClasificados = 16.
	IF EXISTS (SELECT 1 FROM nucleo.fn_FaseEliminatoriaInicial() WHERE Nombre = 'Octavos de final' AND TotalClasificados = 16)
		PRINT 'TEST 4.D OK: 8 grupos con (2, 0) = 16 clasificados, empieza en octavos.';
	ELSE
		PRINT 'TEST 4.D FALLÓ: no devolvió octavos con 16 clasificados.';

	-- 4.E 8 grupos, regla (1, 0) = 8.
	-- Esperado: 'Cuartos de final' con TotalClasificados = 8.
	UPDATE nucleo.ReglaClasificacion SET ClasificadosPorGrupo = 1, MejoresTerceros = 0 WHERE IdRegla = 1;
	IF EXISTS (SELECT 1 FROM nucleo.fn_FaseEliminatoriaInicial() WHERE Nombre = 'Cuartos de final' AND TotalClasificados = 8)
		PRINT 'TEST 4.E OK: 8 grupos con (1, 0) = 8 clasificados, empieza en cuartos.';
	ELSE
		PRINT 'TEST 4.E FALLÓ: no devolvió cuartos con 8 clasificados.';

	-- 4.F Regla de clasificación inexistente.
	-- Esperado: 0 filas (nadie clasifica).
	DELETE FROM nucleo.ReglaClasificacion;
	IF NOT EXISTS (SELECT 1 FROM nucleo.fn_FaseEliminatoriaInicial())
		PRINT 'TEST 4.F OK: sin regla no hay fase inicial (0 filas).';
	ELSE
		PRINT 'TEST 4.F FALLÓ: devolvió una fase sin regla de clasificación.';
END;

-- =========================================================================
-- TEST 5: nucleo.vw_PartidoResultado
-- =========================================================================
-- 5.A Octavos 1-1 con tanda 4-3 para a2.
-- Esperado: goles 1-1, penales 4-3, ganador a2, perdedor a4, DefinidoPorPenales = 1.
IF EXISTS (SELECT 1 FROM nucleo.vw_PartidoResultado
           WHERE NumeroPartido = 144 AND GolesLocal = 1 AND GolesVisitante = 1
             AND PenalesLocal = 4 AND PenalesVisitante = 3
             AND IdGanador = @a2 AND IdPerdedor = @a4 AND DefinidoPorPenales = 1)
	PRINT 'TEST 5.A OK: resultado, penales y ganador del partido 144.';
ELSE
	PRINT 'TEST 5.A FALLÓ: la vista no devolvió el resultado esperado del partido 144.';

-- 5.B Octavos 2-1 sin tanda.
-- Esperado: goles 2-1, penales NULL, ganador a1, DefinidoPorPenales = 0.
IF EXISTS (SELECT 1 FROM nucleo.vw_PartidoResultado
           WHERE NumeroPartido = 141 AND GolesLocal = 2 AND GolesVisitante = 1
             AND PenalesLocal IS NULL AND PenalesVisitante IS NULL
             AND IdGanador = @a1 AND DefinidoPorPenales = 0)
	PRINT 'TEST 5.B OK: resultado sin tanda del partido 141.';
ELSE
	PRINT 'TEST 5.B FALLÓ: la vista no devolvió el resultado esperado del partido 141.';

-- 5.C Partido Programado con 3 goles cargados.
-- Esperado: goles y penales NULL (no se muestra un resultado de un partido sin jugar), sin ganador.
IF EXISTS (SELECT 1 FROM nucleo.vw_PartidoResultado
           WHERE NumeroPartido = 123 AND Estado = 'Programado'
             AND GolesLocal IS NULL AND GolesVisitante IS NULL
             AND PenalesLocal IS NULL AND PenalesVisitante IS NULL
             AND IdGanador IS NULL AND IdPerdedor IS NULL)
	PRINT 'TEST 5.C OK: el partido Programado no muestra resultado.';
ELSE
	PRINT 'TEST 5.C FALLÓ: el partido Programado muestra resultado o ganador.';

-- =========================================================================
-- TEST 6: nucleo.fn_ValidarFaseGruposCompleta
-- (a esta altura del test solo quedan los grupos M a T: el TEST 4 quitó las selecciones de U a X)
-- =========================================================================
IF @hayOtras = 1
	PRINT 'TEST 6 OMITIDO: la base tiene selecciones que no son de este test.';
ELSE
BEGIN
	DECLARE @msg6 NVARCHAR(MAX) = nucleo.fn_ValidarFaseGruposCompleta();

	-- 6.A Partido 123 sin finalizar.
	-- Esperado: el texto informa "Hay 1 partido(s) de fase de grupos sin finalizar: 123".
	IF @msg6 LIKE N'%Hay 1 partido(s) de fase de grupos sin finalizar: 123.%'
		PRINT 'TEST 6.A OK: informa el partido 123 sin finalizar.';
	ELSE
		PRINT 'TEST 6.A FALLÓ: no informó el partido 123 sin finalizar -> ' + ISNULL(@msg6, 'NULL');

	-- 6.B Selecciones con partidos de grupo sin cargar: las 4 del grupo O (c1 y c3 con 2 de 3; c2 y c4 con 1 de 3)
	--     y las 20 de los grupos P a T (0 de 3).
	-- Esperado: "Hay 24 selección(es) con partidos de fase de grupos sin cargar", con la lista recortada a 20 y "y 4 más".
	IF @msg6 LIKE N'%Hay 24 selección(es) con partidos de fase de grupos sin cargar%'
	   AND @msg6 LIKE N'%y 4 más%'
		PRINT 'TEST 6.B OK: informa las 24 selecciones con partidos sin cargar (lista de 20 y "y 4 más").';
	ELSE
		PRINT 'TEST 6.B FALLÓ: no informó las 24 selecciones -> ' + ISNULL(@msg6, 'NULL');

	-- 6.C Fase de grupos completa: se quitan el grupo O (partidos, goles y convocatorias) y los grupos P a T,
	--     y quedan solo los grupos M y N, con los 6 partidos de cada uno finalizados.
	-- Esperado: cadena vacía.
	SAVE TRANSACTION Caso6C;
	DELETE FROM eventos.Gol WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido IN (121, 122, 123, 131));
	DELETE FROM nucleo.Partido WHERE NumeroPartido IN (121, 122, 123, 131);
	DELETE FROM jugadores.Convocatoria WHERE IdSeleccion IN (@c1, @c2, @c3, @c4);
	DELETE FROM nucleo.Seleccion WHERE IdGrupo IN (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre BETWEEN 'O' AND 'X');
	IF nucleo.fn_ValidarFaseGruposCompleta() = N''
		PRINT 'TEST 6.C OK: con los grupos completos la función devuelve una cadena vacía.';
	ELSE
		PRINT 'TEST 6.C FALLÓ: devolvió condiciones con la fase de grupos completa -> ' + nucleo.fn_ValidarFaseGruposCompleta();
	ROLLBACK TRANSACTION Caso6C;
END;

-- =========================================================================
-- LIMPIEZA: se deshace todo lo insertado por el test (incluidos los cambios de la regla)
-- =========================================================================
ROLLBACK TRANSACTION;
GO

IF EXISTS (SELECT 1 FROM nucleo.Pais WHERE Nombre LIKE 'TEST FP%')
	PRINT 'ATENCIÓN: quedaron datos de prueba TEST FP en la base.';
ELSE
	PRINT 'Limpieza OK: no quedaron datos de prueba TEST FP.';
GO
