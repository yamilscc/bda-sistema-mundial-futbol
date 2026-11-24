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
	- Probar nucleo.SP_FINALIZAR_PARTIDO (script 26) y el cálculo del ganador sin estar finalizado
	  de nucleo.fn_DefinicionPartido (script 25).
	- Requiere ejecutados los scripts 01 a 26. Sede, partidos y goles se cargan con INSERT directo.
	- Datos de prueba con prefijo 'TEST FIN' / 'TEST_FIN', borrados al inicio y al final. Los partidos
	  usan los NumeroPartido 151 a 170.
	- Convención de salida: "OK" -> el caso se comportó como se esperaba; "OK (Bloqueado)" -> el SP
	  rechazó la operación inválida con el mensaje esperado; "FALLÓ" -> el caso no se comportó como
	  se esperaba.

Escenario: 5 selecciones TEST en el grupo Z (s1..s5), 6 jugadores (j1..j6) y 2 sedes.
  j1..j5 están convocados en s1..s5; j6 no está convocado. s5 es una selección ajena a los partidos.
  Sede 1: capacidad 50000. Sede 2: sin capacidad cargada.
  Todos los partidos se crean 'Programado'; cada caso usa su propio partido (entre paréntesis, el
  resultado que arman los goles cargados):
    151 grupos s1-s2 (2-1)            152 grupos s1-s3 (0-0)           153 grupos s1-s4 (1-0)
    154 octavos s1-s2 (2-1)           155 octavos s3-s4 (1-1, tanda 4-3)
    156 grupos s2-s3 en sede 2 (1-0)  170 octavos s2-s4 (0-0, tanda 4-3)
    157 grupos sin selecciones        158 grupos s1-s2, fecha futura   159 grupos s2-s4 (1-0)
    161 grupos s1-s2, gol de j5 (selección ajena)
    162 grupos s1-s3, gol de j6 (sin convocar)
    163 grupos s1-s4 (1-1, tanda 3-2)
    164 octavos s1-s2 (0-0, sin tanda)
    165 octavos s3-s4 (1-1, tanda 3-3)
    166 octavos s1-s3 (2-1, con tanda)
    167 grupos s2-s3, fecha futura, 1-1 con tanda
    169 grupos s1-s4 (1-0)
*/

USE MundialFutbol;
GO

-- Si una corrida anterior quedó con la transacción abierta, se deshace antes de empezar.
WHILE @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;

-- =========================================================================
-- LIMPIEZA PREVIA
-- =========================================================================
DELETE FROM eventos.Gol          WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 151 AND 170);
DELETE FROM nucleo.Partido       WHERE NumeroPartido BETWEEN 151 AND 170;
DELETE FROM jugadores.Convocatoria WHERE IdJugador IN (SELECT IdJugador FROM jugadores.Jugador WHERE Documento LIKE 'TEST_FIN%');
DELETE FROM jugadores.Jugador    WHERE Documento LIKE 'TEST_FIN%';
DELETE FROM nucleo.Seleccion     WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST FIN%');
DELETE FROM nucleo.Grupo         WHERE Nombre = 'Z' AND IdGrupo NOT IN (SELECT IdGrupo FROM nucleo.Seleccion);
DELETE FROM nucleo.Sede          WHERE NombreEstadio LIKE 'TEST FIN%';
DELETE FROM nucleo.Ciudad        WHERE Nombre LIKE 'TEST FIN%';
DELETE FROM nucleo.Pais          WHERE Nombre LIKE 'TEST FIN%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST FIN%';
GO

-- =========================================================================
-- DATOS DE PRUEBA
-- =========================================================================
-- Catálogos de eventos (se insertan solo si faltan; no se borran al final).
INSERT INTO eventos.TipoGol (Descripcion)
SELECT v.d FROM (VALUES ('Jugada'), ('Penal')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.TipoGol AS t WHERE t.Descripcion = v.d);

INSERT INTO eventos.Periodo (Descripcion)
SELECT v.d FROM (VALUES ('Primer Tiempo'), ('Definicion por Penales')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Periodo AS t WHERE t.Descripcion = v.d);

DECLARE @tgJugada INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'Jugada');
DECLARE @tgPenal  INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'Penal');
DECLARE @pePT     INT = (SELECT IdPeriodo FROM eventos.Periodo WHERE Descripcion = 'Primer Tiempo');
DECLARE @peTanda  INT = (SELECT IdPeriodo FROM eventos.Periodo WHERE Descripcion = 'Definicion por Penales');

-- Países, selecciones y sedes.
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST FIN Confederacion', 'TFN');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TFN');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, HusoHorarioComercial)
VALUES ('TEST FIN Pais 1', 'QM', 'QMA', @idConf, 'Argentina Standard Time'),
       ('TEST FIN Pais 2', 'QN', 'QNA', @idConf, 'Argentina Standard Time'),
       ('TEST FIN Pais 3', 'QO', 'QOA', @idConf, 'Argentina Standard Time'),
       ('TEST FIN Pais 4', 'QP', 'QPA', @idConf, 'Argentina Standard Time'),
       ('TEST FIN Pais 5', 'QQ', 'QQA', @idConf, 'Argentina Standard Time');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
	INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
SELECT p.CodigoISO3, 100 + ROW_NUMBER() OVER (ORDER BY p.CodigoISO3), p.IdPais, @idGrupo
FROM nucleo.Pais AS p WHERE p.Nombre LIKE 'TEST FIN Pais%'
ORDER BY p.CodigoISO3;

DECLARE @s1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'QMA');
DECLARE @s2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'QNA');
DECLARE @s3 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'QOA');
DECLARE @s4 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'QPA');

DECLARE @idPais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QMA');
INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais) VALUES ('TEST FIN Ciudad', 'Argentina Standard Time', @idPais1);
DECLARE @idCiudad SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST FIN Ciudad');
INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad)
VALUES ('TEST FIN Estadio 1', 50000, @idCiudad),
       ('TEST FIN Estadio 2', NULL,  @idCiudad);
DECLARE @idSede1 TINYINT = (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio = 'TEST FIN Estadio 1');
DECLARE @idSede2 TINYINT = (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio = 'TEST FIN Estadio 2');

-- Jugadores: j1..j5 convocados en s1..s5; j6 sin convocar.
INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion, IdClub)
SELECT 'Jugador', 'FIN' + CAST(v.n AS VARCHAR(2)), 'TEST_FIN_' + CAST(v.n AS VARCHAR(2)), 'M', 'Delantero', NULL
FROM (VALUES (1), (2), (3), (4), (5), (6)) AS v(n);

INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
SELECT s.IdSeleccion, j.IdJugador, 9
FROM jugadores.Jugador AS j
INNER JOIN nucleo.Seleccion AS s ON s.CodigoFIFA = CASE j.Documento
                                                      WHEN 'TEST_FIN_1' THEN 'QMA'
                                                      WHEN 'TEST_FIN_2' THEN 'QNA'
                                                      WHEN 'TEST_FIN_3' THEN 'QOA'
                                                      WHEN 'TEST_FIN_4' THEN 'QPA'
                                                      WHEN 'TEST_FIN_5' THEN 'QQA'
                                                   END;

-- Partidos (todos 'Programado'; una fecha distinta por número: pasada o, si Futuro = 1, en 2030).
DECLARE @fGrupos  TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Fase de grupos');
DECLARE @fOctavos TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');

INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
SELECT v.Num,
       DATEADD(DAY, v.Num, CASE WHEN v.Futuro = 1 THEN CAST('2030-01-01 18:00' AS DATETIME2(0))
                                ELSE CAST('2026-01-01 18:00' AS DATETIME2(0)) END),
       'Programado', v.IdFase, v.IdSede, v.Loc, v.Vis
FROM (VALUES
	(151, @fGrupos,  @idSede1, @s1, @s2, 0), (152, @fGrupos,  @idSede1, @s1, @s3, 0),
	(153, @fGrupos,  @idSede1, @s1, @s4, 0), (154, @fOctavos, @idSede1, @s1, @s2, 0),
	(155, @fOctavos, @idSede1, @s3, @s4, 0), (156, @fGrupos,  @idSede2, @s2, @s3, 0),
	(157, @fGrupos,  @idSede1, NULL, NULL, 0), (158, @fGrupos,  @idSede1, @s1, @s2, 1),
	(159, @fGrupos,  @idSede1, @s2, @s4, 0), (161, @fGrupos,  @idSede1, @s1, @s2, 0),
	(162, @fGrupos,  @idSede1, @s1, @s3, 0), (163, @fGrupos,  @idSede1, @s1, @s4, 0),
	(164, @fOctavos, @idSede1, @s1, @s2, 0), (165, @fOctavos, @idSede1, @s3, @s4, 0),
	(166, @fOctavos, @idSede1, @s1, @s3, 0), (167, @fGrupos,  @idSede1, @s2, @s3, 1),
	(169, @fGrupos,  @idSede1, @s1, @s4, 0), (170, @fOctavos, @idSede1, @s2, @s4, 0)
) AS v(Num, IdFase, IdSede, Loc, Vis, Futuro);

-- Goles en juego (tipo 'Jugada', primer tiempo): (partido, jugador autor, cantidad).
INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
SELECT p.IdPartido, j.IdJugador, NULL, @tgJugada, @pePT, 10 + k.n * 5
FROM (VALUES
	(151, 1, 2), (151, 2, 1),
	(153, 1, 1),
	(154, 1, 2), (154, 2, 1),
	(155, 3, 1), (155, 4, 1),
	(156, 2, 1),
	(159, 2, 1),
	(161, 1, 1), (161, 5, 1),
	(162, 1, 1), (162, 6, 1),
	(163, 1, 1), (163, 3, 1),
	(165, 3, 1), (165, 4, 1),
	(166, 1, 2), (166, 3, 1),
	(167, 2, 1), (167, 3, 1),
	(169, 1, 1)
) AS g(Num, Jug, Cant)
INNER JOIN nucleo.Partido AS p ON p.NumeroPartido = g.Num
INNER JOIN jugadores.Jugador AS j ON j.Documento = 'TEST_FIN_' + CAST(g.Jug AS VARCHAR(2))
INNER JOIN (VALUES (1), (2), (3), (4)) AS k(n) ON k.n <= g.Cant;

-- Tandas de penales (tipo 'Penal', período 'Definicion por Penales'): (partido, jugador, cantidad).
INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
SELECT p.IdPartido, j.IdJugador, NULL, @tgPenal, @peTanda, 120
FROM (VALUES
	(155, 3, 4), (155, 4, 3),
	(163, 1, 3), (163, 3, 2),
	(165, 3, 3), (165, 4, 3),
	(166, 1, 1),
	(167, 2, 2), (167, 3, 1),
	(170, 2, 4), (170, 4, 3)
) AS g(Num, Jug, Cant)
INNER JOIN nucleo.Partido AS p ON p.NumeroPartido = g.Num
INNER JOIN jugadores.Jugador AS j ON j.Documento = 'TEST_FIN_' + CAST(g.Jug AS VARCHAR(2))
INNER JOIN (VALUES (1), (2), (3), (4)) AS k(n) ON k.n <= g.Cant;

DECLARE @id INT;

-- =========================================================================
-- TEST 1: finalizaciones válidas
-- =========================================================================
-- 1.A Fase de grupos, 2-1, concurrencia 45000.
-- Esperado: OK. El partido queda Finalizado con Concurrencia = 45000 y la vista devuelve 2-1, ganador s1.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 151);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 45000;
	IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND Estado = 'Finalizado' AND Concurrencia = 45000)
	   AND EXISTS (SELECT 1 FROM nucleo.vw_PartidoResultado WHERE IdPartido = @id AND GolesLocal = 2 AND GolesVisitante = 1 AND IdGanador = @s1)
		PRINT 'TEST 1.A OK: partido de grupos finalizado con 2-1 y concurrencia 45000.';
	ELSE
		PRINT 'TEST 1.A FALLÓ: el partido no quedó Finalizado con el resultado esperado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.A FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.B Fase de grupos, 0-0 (sin goles cargados).
-- Esperado: OK. Finaliza; la vista devuelve 0-0 y sin ganador (empate).
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 152);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 30000;
	IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND Estado = 'Finalizado')
	   AND EXISTS (SELECT 1 FROM nucleo.vw_PartidoResultado WHERE IdPartido = @id AND GolesLocal = 0 AND GolesVisitante = 0 AND IdGanador IS NULL)
		PRINT 'TEST 1.B OK: empate 0-0 en grupos finalizado sin ganador.';
	ELSE
		PRINT 'TEST 1.B FALLÓ: el partido 0-0 no quedó Finalizado como se esperaba.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.B FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.C Concurrencia no informada (los datasets pueden no traerla).
-- Esperado: OK. Finaliza y Concurrencia queda NULL.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 153);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id;
	IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND Estado = 'Finalizado' AND Concurrencia IS NULL)
		PRINT 'TEST 1.C OK: finalizado sin concurrencia (queda NULL).';
	ELSE
		PRINT 'TEST 1.C FALLÓ: el partido no quedó Finalizado con Concurrencia NULL.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.C FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.D Octavos de final, 2-1 en juego.
-- Esperado: OK. Finaliza; la vista devuelve ganador s1 con DefinidoPorPenales = 0.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 154);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 48000;
	IF EXISTS (SELECT 1 FROM nucleo.vw_PartidoResultado WHERE IdPartido = @id AND Estado = 'Finalizado' AND IdGanador = @s1 AND DefinidoPorPenales = 0)
		PRINT 'TEST 1.D OK: eliminatoria ganada en juego finalizada.';
	ELSE
		PRINT 'TEST 1.D FALLÓ: la eliminatoria no quedó Finalizada con ganador s1.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.D FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.E Octavos de final, 1-1 con tanda 4-3 para s3.
-- Esperado: OK. Finaliza; la vista devuelve penales 4-3, ganador s3 y DefinidoPorPenales = 1.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 155);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 49000;
	IF EXISTS (SELECT 1 FROM nucleo.vw_PartidoResultado
	           WHERE IdPartido = @id AND Estado = 'Finalizado' AND GolesLocal = 1 AND GolesVisitante = 1
	             AND PenalesLocal = 4 AND PenalesVisitante = 3 AND IdGanador = @s3 AND DefinidoPorPenales = 1)
		PRINT 'TEST 1.E OK: eliminatoria definida por penales finalizada.';
	ELSE
		PRINT 'TEST 1.E FALLÓ: la eliminatoria por penales no quedó Finalizada con ganador s3.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.E FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.F Sede sin capacidad cargada y concurrencia 90000.
-- Esperado: OK. No se controla el tope porque la sede no tiene capacidad: Concurrencia = 90000.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 156);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 90000;
	IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND Estado = 'Finalizado' AND Concurrencia = 90000)
		PRINT 'TEST 1.F OK: sede sin capacidad, no se controla el tope.';
	ELSE
		PRINT 'TEST 1.F FALLÓ: el partido no quedó Finalizado con Concurrencia 90000.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.F FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.G Octavos de final 0-0 en juego (sin goles en juego) y tanda 4-3 para s2.
-- Esperado: OK. Finaliza; gana s2 por penales.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 170);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 20000;
	IF EXISTS (SELECT 1 FROM nucleo.vw_PartidoResultado
	           WHERE IdPartido = @id AND Estado = 'Finalizado' AND GolesLocal = 0 AND GolesVisitante = 0
	             AND IdGanador = @s2 AND DefinidoPorPenales = 1)
		PRINT 'TEST 1.G OK: 0-0 en juego definido por penales finalizado.';
	ELSE
		PRINT 'TEST 1.G FALLÓ: el partido 0-0 con tanda no quedó Finalizado con ganador s2.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.G FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: validaciones (una falla por caso)
-- =========================================================================
-- 2.A Partido inexistente.
-- Esperado: Bloqueado: "El partido indicado no existe".
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = 32000, @concurrencia = 1000;
	PRINT 'TEST 2.A FALLÓ: permitió finalizar un partido inexistente.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%El partido indicado no existe%'
		PRINT 'TEST 2.A OK (Bloqueado): ' + ERROR_MESSAGE();
	ELSE
		PRINT 'TEST 2.A FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.B Partido ya finalizado (el 151 del caso 1.A).
-- Esperado: Bloqueado: "no está en estado Programado"; la concurrencia 45000 no se modifica.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 151);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 100;
	PRINT 'TEST 2.B FALLÓ: permitió finalizar un partido ya finalizado.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%no está en estado Programado%'
	   AND EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND Concurrencia = 45000)
		PRINT 'TEST 2.B OK (Bloqueado): ' + ERROR_MESSAGE();
	ELSE
		PRINT 'TEST 2.B FALLÓ: mensaje inesperado o se modificó la concurrencia -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.C Partido sin selecciones definidas.
-- Esperado: Bloqueado: "no tiene definidas ambas selecciones".
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 157);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 1000;
	PRINT 'TEST 2.C FALLÓ: permitió finalizar un partido sin selecciones.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%no tiene definidas ambas selecciones%'
		PRINT 'TEST 2.C OK (Bloqueado): ' + ERROR_MESSAGE();
	ELSE
		PRINT 'TEST 2.C FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.D Partido con fecha futura.
-- Esperado: Bloqueado: "todavía no se jugó".
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 158);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 1000;
	PRINT 'TEST 2.D FALLÓ: permitió finalizar un partido futuro.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%todavía no se jugó%'
		PRINT 'TEST 2.D OK (Bloqueado): ' + ERROR_MESSAGE();
	ELSE
		PRINT 'TEST 2.D FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.E Concurrencia negativa.
-- Esperado: Bloqueado: "La concurrencia no puede ser negativa".
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 159);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = -1;
	PRINT 'TEST 2.E FALLÓ: permitió una concurrencia negativa.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%La concurrencia no puede ser negativa%'
		PRINT 'TEST 2.E OK (Bloqueado): ' + ERROR_MESSAGE();
	ELSE
		PRINT 'TEST 2.E FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.F Concurrencia mayor que la capacidad de la sede (50000).
-- Esperado: Bloqueado: "supera la capacidad de la sede (50000)".
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 50001;
	PRINT 'TEST 2.F FALLÓ: permitió una concurrencia mayor que la capacidad.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%supera la capacidad de la sede (50000)%'
		PRINT 'TEST 2.F OK (Bloqueado): ' + ERROR_MESSAGE();
	ELSE
		PRINT 'TEST 2.F FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.G Gol de un jugador convocado en una selección ajena al partido (j5, selección s5).
-- Esperado: Bloqueado: "1 gol(es) cuyo autor no está convocado en ninguna de las dos selecciones".
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 161);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 1000;
	PRINT 'TEST 2.G FALLÓ: permitió finalizar con un gol de un jugador de otra selección.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%Hay 1 gol(es) cuyo autor no está convocado en ninguna de las dos selecciones%'
		PRINT 'TEST 2.G OK (Bloqueado): ' + ERROR_MESSAGE();
	ELSE
		PRINT 'TEST 2.G FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.H Gol de un jugador sin convocar (j6).
-- Esperado: Bloqueado: el mismo mensaje de 2.G.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 162);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 1000;
	PRINT 'TEST 2.H FALLÓ: permitió finalizar con un gol de un jugador sin convocar.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%Hay 1 gol(es) cuyo autor no está convocado en ninguna de las dos selecciones%'
		PRINT 'TEST 2.H OK (Bloqueado): ' + ERROR_MESSAGE();
	ELSE
		PRINT 'TEST 2.H FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.I Tanda de penales en un partido de fase de grupos.
-- Esperado: Bloqueado: "En fase de grupos no hay definición por penales".
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 163);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 1000;
	PRINT 'TEST 2.I FALLÓ: permitió una tanda de penales en fase de grupos.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%En fase de grupos no hay definición por penales%'
		PRINT 'TEST 2.I OK (Bloqueado): ' + ERROR_MESSAGE();
	ELSE
		PRINT 'TEST 2.I FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.J Eliminatoria 0-0 sin goles cargados y sin tanda.
-- Esperado: Bloqueado: "terminó empatado y no tiene definición por penales".
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 164);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 1000;
	PRINT 'TEST 2.J FALLÓ: permitió una eliminatoria empatada sin tanda.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%terminó empatado y no tiene definición por penales%'
		PRINT 'TEST 2.J OK (Bloqueado): ' + ERROR_MESSAGE();
	ELSE
		PRINT 'TEST 2.J FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.K Eliminatoria 1-1 con tanda igualada 3-3 (falta cargar algún penal).
-- Esperado: Bloqueado: "La definición por penales está igualada".
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 165);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 1000;
	PRINT 'TEST 2.K FALLÓ: permitió una tanda igualada.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%La definición por penales está igualada%'
		PRINT 'TEST 2.K OK (Bloqueado): ' + ERROR_MESSAGE();
	ELSE
		PRINT 'TEST 2.K FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.L Eliminatoria 2-1 con penales cargados.
-- Esperado: Bloqueado: "goles de la definición por penales pero el partido no terminó empatado".
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 166);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 1000;
	PRINT 'TEST 2.L FALLÓ: permitió penales en un partido que no terminó empatado.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%definición por penales pero el partido no terminó empatado%'
		PRINT 'TEST 2.L OK (Bloqueado): ' + ERROR_MESSAGE();
	ELSE
		PRINT 'TEST 2.L FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.M Los partidos rechazados siguen 'Programado'.
-- Esperado: OK, los 10 partidos de los casos 2.C a 2.L (157, 158, 159, 161 a 167) no cambiaron de estado.
IF (SELECT COUNT(*) FROM nucleo.Partido
    WHERE NumeroPartido IN (157, 158, 159, 161, 162, 163, 164, 165, 166, 167) AND Estado = 'Programado') = 10
	PRINT 'TEST 2.M OK: los partidos rechazados siguen Programado.';
ELSE
	PRINT 'TEST 2.M FALLÓ: algún partido rechazado cambió de estado.';

-- =========================================================================
-- TEST 3: varias fallas juntas
-- =========================================================================
-- 3.A Partido de grupos con fecha futura, 1-1 con tanda cargada y concurrencia negativa.
-- Esperado: Bloqueado con UN solo mensaje que contiene las tres condiciones incumplidas:
--           "todavía no se jugó", "La concurrencia no puede ser negativa" y
--           "En fase de grupos no hay definición por penales".
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 167);
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = -5;
	PRINT 'TEST 3.A FALLÓ: permitió finalizar un partido con varias fallas.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE 'SP_FINALIZAR_PARTIDO - No se pudo finalizar el partido:%'
	   AND ERROR_MESSAGE() LIKE '%todavía no se jugó%'
	   AND ERROR_MESSAGE() LIKE '%La concurrencia no puede ser negativa%'
	   AND ERROR_MESSAGE() LIKE '%En fase de grupos no hay definición por penales%'
		PRINT 'TEST 3.A OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
	ELSE
		PRINT 'TEST 3.A FALLÓ: el mensaje no agrupa las tres fallas -> ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: interacción con otros objetos y con la transacción del llamador
-- =========================================================================
-- 4.A Registrar un gol después del cierre (partido 151, ya Finalizado).
-- Esperado: Bloqueado por SP_REGISTRAR_GOL: "El partido ya está finalizado".
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 151);
DECLARE @idJ1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_FIN_1');
BEGIN TRY
	EXEC eventos.SP_REGISTRAR_GOL @idPartido = @id, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
	     @periodo = 'Segundo Tiempo', @minuto = 80, @permitirFechaFutura = 1;
	PRINT 'TEST 4.A FALLÓ: permitió registrar un gol en un partido finalizado.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%El partido ya está finalizado%'
		PRINT 'TEST 4.A OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
	ELSE
		PRINT 'TEST 4.A FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 4.B Llamada inválida dentro de una transacción abierta por el llamador (partido 164, sin tanda).
-- Esperado: Bloqueado, y la transacción del llamador sigue abierta (@@TRANCOUNT = 1) y utilizable.
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 164);
BEGIN TRANSACTION;
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 1000;
	PRINT 'TEST 4.B FALLÓ: permitió finalizar una eliminatoria empatada sin tanda.';
END TRY
BEGIN CATCH
	IF @@TRANCOUNT = 1 AND XACT_STATE() = 1 AND ERROR_MESSAGE() LIKE '%terminó empatado y no tiene definición por penales%'
		PRINT 'TEST 4.B OK (Bloqueado): la transacción del llamador sigue abierta.';
	ELSE
		PRINT 'TEST 4.B FALLÓ: @@TRANCOUNT = ' + CAST(@@TRANCOUNT AS VARCHAR(5)) + ' -> ' + ERROR_MESSAGE();
END CATCH;
WHILE @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;

-- 4.C Finalización válida dentro de una transacción del llamador que luego se deshace (partido 169).
-- Esperado: dentro de la transacción el partido figura Finalizado; tras el ROLLBACK del llamador
--           vuelve a Programado con Concurrencia NULL (el SP no confirmó la transacción ajena).
SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 169);
BEGIN TRANSACTION;
BEGIN TRY
	EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @id, @concurrencia = 1000;
	IF NOT EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND Estado = 'Finalizado' AND Concurrencia = 1000)
		PRINT 'TEST 4.C FALLÓ: el partido no quedó Finalizado dentro de la transacción.';
END TRY
BEGIN CATCH
	PRINT 'TEST 4.C FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;
WHILE @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND Estado = 'Programado' AND Concurrencia IS NULL)
	PRINT 'TEST 4.C OK: tras el ROLLBACK del llamador el partido vuelve a Programado.';
ELSE
	PRINT 'TEST 4.C FALLÓ: el SP confirmó la transacción del llamador.';

-- =========================================================================
-- LIMPIEZA FINAL: borra todos los datos de prueba
-- =========================================================================
DELETE FROM eventos.Gol          WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 151 AND 170);
DELETE FROM nucleo.Partido       WHERE NumeroPartido BETWEEN 151 AND 170;
DELETE FROM jugadores.Convocatoria WHERE IdJugador IN (SELECT IdJugador FROM jugadores.Jugador WHERE Documento LIKE 'TEST_FIN%');
DELETE FROM jugadores.Jugador    WHERE Documento LIKE 'TEST_FIN%';
DELETE FROM nucleo.Seleccion     WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST FIN%');
DELETE FROM nucleo.Grupo         WHERE Nombre = 'Z' AND IdGrupo NOT IN (SELECT IdGrupo FROM nucleo.Seleccion);
DELETE FROM nucleo.Sede          WHERE NombreEstadio LIKE 'TEST FIN%';
DELETE FROM nucleo.Ciudad        WHERE Nombre LIKE 'TEST FIN%';
DELETE FROM nucleo.Pais          WHERE Nombre LIKE 'TEST FIN%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST FIN%';

IF EXISTS (SELECT 1 FROM nucleo.Pais WHERE Nombre LIKE 'TEST FIN%')
	PRINT 'ATENCIÓN: quedaron datos de prueba TEST FIN en la base.';
ELSE
	PRINT 'Limpieza OK: no quedaron datos de prueba TEST FIN.';
GO
