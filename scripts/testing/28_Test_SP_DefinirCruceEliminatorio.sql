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
	- Probar nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO (script 28).
	- Requiere ejecutados los scripts 01 a 28 sobre una base recién creada con 00_Reset_Total.sql.
	  Todo se inserta directo (sin SP). Datos con prefijo 'TEST CR' / 'TEST_CR', borrados al inicio;
	  el test corre dentro de una transacción que se deshace al final (ROLLBACK) y cada caso que
	  modifica datos vuelve a su estado con un savepoint.
	- Convención de salida: "OK" -> el caso se comportó como se esperaba; "OK (Bloqueado)" -> el SP
	  rechazó la operación con el mensaje esperado; "FALLÓ" -> no; "OMITIDO" -> el test necesita
	  una base sin otras selecciones ni otros partidos de fase de grupos.

Escenario: mismo fixture que el test 27: 4 grupos (M, N, O, P) de 4 selecciones TEST (16), un jugador
convocado por selección y 24 partidos de fase de grupos finalizados (NumeroPartido 111 a 134); en cada
partido gana 1-0 la selección de menor IdSeleccion. Con la regla (2, 0) clasifican el 1.º y el 2.º de
cada grupo (8 selecciones) y la eliminación directa empieza en cuartos de final.
  Selecciones (DXA = s01 ... DXP = s16; el número de selección es el del país 'TEST CR Pais NN'):
    clasifican s01, s02 (grupo M), s05, s06 (N), s09, s10 (O) y s13, s14 (P); el resto no clasifica.
  Partidos eliminatorios (todos 'Programado', sin selecciones):
    135 octavos (28/01)              136 a 139 cuartos (01/02, 04/02, 07/02, 10/02)
    140 y 141 semifinales (01/03, 04/03)     142 tercer puesto (01/04)     143 final (05/04)
    144 semifinal el 05/02 (anterior a dos cuartos)     145 cuartos el 25/01 20:00 (a 26 h de un partido de s14)
  Cruces que se arman en el test: cuartos 136 s01-s05, 137 s09-s13, 138 s02-s06, 139 s10-s14;
  ganan s01, s09, s06 (visitante) y s14 (por penales). Semifinales: 140 s01-s09 (gana s01) y
  141 s06-s14 (gana s14). Tercer puesto: s09-s06. Final: s01-s14.
*/

USE MundialFutbol;
GO

-- Si una corrida anterior quedó con la transacción abierta, se deshace antes de empezar.
WHILE @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;

-- =========================================================================
-- LIMPIEZA PREVIA
-- =========================================================================
DELETE FROM eventos.Gol WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 111 AND 145);
DELETE FROM nucleo.Partido       WHERE NumeroPartido BETWEEN 111 AND 145;
DELETE FROM jugadores.Convocatoria WHERE IdJugador IN (SELECT IdJugador FROM jugadores.Jugador WHERE Documento LIKE 'TEST_CR%');
DELETE FROM jugadores.Jugador    WHERE Documento LIKE 'TEST_CR%';
DELETE FROM nucleo.Seleccion     WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST CR%');
DELETE FROM nucleo.Grupo         WHERE Nombre BETWEEN 'M' AND 'P' AND IdGrupo NOT IN (SELECT IdGrupo FROM nucleo.Seleccion);
DELETE FROM nucleo.Sede          WHERE NombreEstadio LIKE 'TEST CR%';
DELETE FROM nucleo.Ciudad        WHERE Nombre LIKE 'TEST CR%';
DELETE FROM nucleo.Pais          WHERE Nombre LIKE 'TEST CR%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST CR%';
GO

BEGIN TRANSACTION;

-- =========================================================================
-- DATOS DE PRUEBA
-- =========================================================================
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

-- Regla inicial del test: 2 por grupo, sin mejores terceros (8 clasificados: la eliminación empieza en cuartos).
DELETE FROM nucleo.ReglaClasificacion;
INSERT INTO nucleo.ReglaClasificacion (IdRegla, ClasificadosPorGrupo, MejoresTerceros) VALUES (1, 2, 0);

-- 16 países, 4 grupos (M..P) y 16 selecciones (4 por grupo, en orden de IdSeleccion).
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST CR Confederacion', 'TCR');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TCR');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, HusoHorarioComercial)
SELECT 'TEST CR Pais ' + RIGHT('0' + CAST(v.n AS VARCHAR(2)), 2), 'X' + CHAR(64 + v.n), 'DX' + CHAR(64 + v.n),
       @idConf, 'Argentina Standard Time'
FROM (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12), (13), (14), (15), (16)) AS v(n);

INSERT INTO nucleo.Grupo (Nombre)
SELECT CHAR(76 + v.n)
FROM (VALUES (1), (2), (3), (4)) AS v(n)
WHERE NOT EXISTS (SELECT 1 FROM nucleo.Grupo AS g WHERE g.Nombre = CHAR(76 + v.n));

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
SELECT p.CodigoISO3, 100 + x.n, p.IdPais, g.IdGrupo
FROM nucleo.Pais AS p
CROSS APPLY (SELECT CAST(RIGHT(p.Nombre, 2) AS INT) AS n) AS x
INNER JOIN nucleo.Grupo AS g ON g.Nombre = CHAR(76 + ((x.n - 1) / 4) + 1)
WHERE p.Nombre LIKE 'TEST CR Pais%'
ORDER BY x.n;

DECLARE @s01 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'DXA');
DECLARE @s02 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'DXB');
DECLARE @s03 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'DXC');
DECLARE @s04 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'DXD');
DECLARE @s05 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'DXE');
DECLARE @s06 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'DXF');
DECLARE @s09 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'DXI');
DECLARE @s10 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'DXJ');
DECLARE @s13 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'DXM');
DECLARE @s14 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'DXN');

-- Sede y jugadores (el jugador n está convocado en la selección n).
DECLARE @idPais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE Nombre = 'TEST CR Pais 01');
INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais) VALUES ('TEST CR Ciudad', 'Argentina Standard Time', @idPais1);
INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad)
VALUES ('TEST CR Estadio', 60000, (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST CR Ciudad'));
DECLARE @idSede TINYINT = (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio = 'TEST CR Estadio');

INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion, IdClub)
SELECT 'Jugador', 'CR' + CAST(v.n AS VARCHAR(2)), 'TEST_CR_' + RIGHT('0' + CAST(v.n AS VARCHAR(2)), 2), 'M', 'Delantero', NULL
FROM (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12), (13), (14), (15), (16)) AS v(n);

INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
SELECT s.IdSeleccion, j.IdJugador, 9
FROM jugadores.Jugador AS j
CROSS APPLY (SELECT CAST(RIGHT(j.Documento, 2) AS INT) AS n) AS x
INNER JOIN nucleo.Pais AS p ON p.Nombre = 'TEST CR Pais ' + RIGHT('0' + CAST(x.n AS VARCHAR(2)), 2)
INNER JOIN nucleo.Seleccion AS s ON s.IdPais = p.IdPais
WHERE j.Documento LIKE 'TEST_CR_%';

-- Partidos de fase de grupos: todos contra todos dentro de cada grupo, gana 1-0 el de menor IdSeleccion.
DECLARE @fGrupos TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Fase de grupos');

INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
SELECT 110 + r.n,
       DATEADD(DAY, r.n, CAST('2026-01-01 18:00' AS DATETIME2(0))),
       'Finalizado', @fGrupos, @idSede, r.IdLocal, r.IdVisitante
FROM (SELECT ROW_NUMBER() OVER (ORDER BY a.IdSeleccion, b.IdSeleccion) AS n,
             a.IdSeleccion AS IdLocal, b.IdSeleccion AS IdVisitante
      FROM nucleo.Seleccion AS a
      INNER JOIN nucleo.Pais AS pa ON pa.IdPais = a.IdPais AND pa.Nombre LIKE 'TEST CR Pais%'
      INNER JOIN nucleo.Seleccion AS b ON b.IdGrupo = a.IdGrupo AND b.IdSeleccion > a.IdSeleccion) AS r;

INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
SELECT p.IdPartido, c.IdJugador, NULL, @tgJugada, @pePT, 20
FROM nucleo.Partido AS p
INNER JOIN jugadores.Convocatoria AS c ON c.IdSeleccion = p.IdSeleccionLocal
WHERE p.NumeroPartido BETWEEN 111 AND 134;

-- Partidos eliminatorios 'Programado', sin selecciones.
DECLARE @fOctavos  TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');
DECLARE @fCuartos  TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Cuartos de final');
DECLARE @fSemi     TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Semifinal');
DECLARE @fTercer   TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Tercer puesto');
DECLARE @fFinal    TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Final');

INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (135, '2026-01-28 18:00', 'Programado', @fOctavos, @idSede, NULL, NULL),
       (136, '2026-02-01 18:00', 'Programado', @fCuartos, @idSede, NULL, NULL),
       (137, '2026-02-04 18:00', 'Programado', @fCuartos, @idSede, NULL, NULL),
       (138, '2026-02-07 18:00', 'Programado', @fCuartos, @idSede, NULL, NULL),
       (139, '2026-02-10 18:00', 'Programado', @fCuartos, @idSede, NULL, NULL),
       (140, '2026-03-01 18:00', 'Programado', @fSemi,    @idSede, NULL, NULL),
       (141, '2026-03-04 18:00', 'Programado', @fSemi,    @idSede, NULL, NULL),
       (142, '2026-04-01 18:00', 'Programado', @fTercer,  @idSede, NULL, NULL),
       (143, '2026-04-05 18:00', 'Programado', @fFinal,   @idSede, NULL, NULL),
       (144, '2026-02-05 18:00', 'Programado', @fSemi,    @idSede, NULL, NULL),
       (145, '2026-01-25 20:00', 'Programado', @fCuartos, @idSede, NULL, NULL);

-- Con otras selecciones o con otros partidos de grupos en la base, los clasificados y las listas cambian.
DECLARE @hayOtras BIT = CASE WHEN EXISTS (SELECT 1 FROM nucleo.Seleccion AS s
                                          INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais
                                          WHERE p.Nombre NOT LIKE 'TEST CR%')
                               OR EXISTS (SELECT 1 FROM nucleo.Partido AS pa
                                          INNER JOIN nucleo.Fase AS f ON f.IdFase = pa.IdFase AND f.Nombre = 'Fase de grupos'
                                          WHERE pa.NumeroPartido NOT BETWEEN 111 AND 134)
                             THEN 1 ELSE 0 END;

DECLARE @id INT;

IF @hayOtras = 1
	PRINT 'TEST 28 OMITIDO: la base tiene selecciones u otros partidos de fase de grupos que no son de este test.';
ELSE
BEGIN
	-- =====================================================================
	-- TEST 1: cruces válidos y rechazos de la fase inicial (cuartos de final)
	-- =====================================================================
	-- 1.A Descanso: el partido 145 (cuartos, 25/01 20:00) con s13 y s14. s14 jugó el 24/01 18:00, a 26 horas.
	-- Esperado: Bloqueado: "Tienen otro partido a menos de 48 horas de este: DXN" (y solo esa condición).
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 145);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s13, @idSeleccionVisitante = @s14;
		PRINT 'TEST 1.A FALLÓ: permitió un cruce con una selección que juega a menos de 48 horas.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%Tienen otro partido a menos de 48 horas de este: DXN%'
		   AND ERROR_MESSAGE() NOT LIKE '%DXM%' AND ERROR_MESSAGE() NOT LIKE '%clasificaron%'
		   AND @@TRANCOUNT = 1
			PRINT 'TEST 1.A OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 1.A FALLÓ: mensaje inesperado o transacción cerrada -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 1.B Cruce válido en la fase inicial: cuartos 136, s01 (local) contra s05 (visitante).
	-- Esperado: OK. El partido queda con IdSeleccionLocal = s01 e IdSeleccionVisitante = s05 (y sigue Programado).
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 136);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s01, @idSeleccionVisitante = @s05;
		IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND IdSeleccionLocal = @s01 AND IdSeleccionVisitante = @s05 AND Estado = 'Programado')
			PRINT 'TEST 1.B OK: cuartos 136 asignado (s01 contra s05).';
		ELSE
			PRINT 'TEST 1.B FALLÓ: el cruce no quedó asignado.';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 1.B FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 1.C Repetir exactamente el mismo cruce.
	-- Esperado: OK, sin error y sin cambios.
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s01, @idSeleccionVisitante = @s05;
		IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND IdSeleccionLocal = @s01 AND IdSeleccionVisitante = @s05)
			PRINT 'TEST 1.C OK: repetir el mismo cruce no da error.';
		ELSE
			PRINT 'TEST 1.C FALLÓ: el cruce cambió al repetirlo.';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 1.C FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 1.D Invertir local y visitante en un partido sin registros asociados.
	-- Esperado: OK. s05 pasa a ser el local (se deshace con un savepoint).
	SAVE TRANSACTION Caso1D;
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s05, @idSeleccionVisitante = @s01;
		IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND IdSeleccionLocal = @s05 AND IdSeleccionVisitante = @s01)
			PRINT 'TEST 1.D OK: sin registros asociados se puede cambiar el cruce.';
		ELSE
			PRINT 'TEST 1.D FALLÓ: el cruce no cambió.';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 1.D FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	ROLLBACK TRANSACTION Caso1D;

	-- 1.E Cambiar el cruce de un partido con un gol cargado, y repetir el mismo cruce.
	-- Esperado: cambiar a s02-s06 -> Bloqueado: "tiene registros asociados"; repetir s01-s05 -> OK.
	SAVE TRANSACTION Caso1E;
	INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
	SELECT @id, j.IdJugador, NULL, @tgJugada, @pePT, 30 FROM jugadores.Jugador AS j WHERE j.Documento = 'TEST_CR_01';
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s02, @idSeleccionVisitante = @s06;
		PRINT 'TEST 1.E FALLÓ: permitió cambiar el cruce de un partido con registros.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%tiene registros asociados%no se pueden cambiar sus selecciones%'
			PRINT 'TEST 1.E OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 1.E FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s01, @idSeleccionVisitante = @s05;
		PRINT 'TEST 1.E OK: repetir el mismo cruce con registros asociados no da error.';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 1.E FALLÓ: no permitió repetir el mismo cruce -> ' + ERROR_MESSAGE();
	END CATCH;
	ROLLBACK TRANSACTION Caso1E;

	-- 1.F Selección que no clasificó y selección ya asignada a otro partido de cuartos (varias fallas juntas).
	-- Esperado: Bloqueado con UN mensaje que contiene "No clasificaron ... DXC" y "Ya están asignadas a otro partido
	--           de Cuartos de final: DXE".
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 137);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s03, @idSeleccionVisitante = @s05;
		PRINT 'TEST 1.F FALLÓ: permitió un cruce con una selección que no clasificó.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE 'SP_DEFINIR_CRUCE_ELIMINATORIO - No se pudo definir el cruce:%'
		   AND ERROR_MESSAGE() LIKE '%No clasificaron a la eliminación directa: DXC%'
		   AND ERROR_MESSAGE() LIKE '%Ya están asignadas a otro partido de Cuartos de final: DXE%'
			PRINT 'TEST 1.F OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 1.F FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 1.G Fase de grupos incompleta (el partido 115 vuelve a Programado).
	-- Esperado: Bloqueado: "La fase de grupos no está completa" y "sin finalizar: 115".
	SAVE TRANSACTION Caso1G;
	UPDATE nucleo.Partido SET Estado = 'Programado' WHERE NumeroPartido = 115;
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s09, @idSeleccionVisitante = @s13;
		PRINT 'TEST 1.G FALLÓ: permitió un cruce de la fase inicial con la fase de grupos incompleta.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%La fase de grupos no está completa%' AND ERROR_MESSAGE() LIKE '%sin finalizar: 115%'
			PRINT 'TEST 1.G OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 1.G FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	ROLLBACK TRANSACTION Caso1G;

	-- 1.H Fase anterior a la inicial: octavos (135) cuando la eliminación empieza en cuartos.
	-- Esperado: Bloqueado: "Octavos de final no se juega con la regla de clasificación actual ... empieza en Cuartos de final".
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 135);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s03, @idSeleccionVisitante = @s04;
		PRINT 'TEST 1.H FALLÓ: permitió un cruce de una fase que no se juega.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%Octavos de final no se juega con la regla de clasificación actual: la eliminación directa empieza en Cuartos de final%'
			PRINT 'TEST 1.H OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 1.H FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 1.I Octavos como fase inicial: con la regla (4, 0) clasifican las 16 selecciones y la eliminación empieza en octavos.
	-- Esperado: OK. El partido 135 queda asignado (s03 contra s04), que con la regla (2, 0) no habrían clasificado.
	SAVE TRANSACTION Caso1I;
	UPDATE nucleo.ReglaClasificacion SET ClasificadosPorGrupo = 4, MejoresTerceros = 0 WHERE IdRegla = 1;
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s03, @idSeleccionVisitante = @s04;
		IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND IdSeleccionLocal = @s03 AND IdSeleccionVisitante = @s04)
			PRINT 'TEST 1.I OK: octavos como fase inicial con la regla (4, 0).';
		ELSE
			PRINT 'TEST 1.I FALLÓ: el cruce de octavos no quedó asignado.';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 1.I FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	ROLLBACK TRANSACTION Caso1I;

	-- 1.J Partido de fase de grupos (el 111).
	-- Esperado: Bloqueado: "El partido no es de una fase eliminatoria".
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 111);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s01, @idSeleccionVisitante = @s02;
		PRINT 'TEST 1.J FALLÓ: permitió definir un cruce en un partido de fase de grupos.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%El partido no es de una fase eliminatoria%'
			PRINT 'TEST 1.J OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 1.J FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 1.K Partido inexistente.
	-- Esperado: Bloqueado: "El partido indicado no existe".
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = 32000, @idSeleccionLocal = @s01, @idSeleccionVisitante = @s02;
		PRINT 'TEST 1.K FALLÓ: permitió definir un cruce en un partido inexistente.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%El partido indicado no existe%'
			PRINT 'TEST 1.K OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 1.K FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 1.L Selecciones inválidas: la misma dos veces, inexistente y nula (cuartos 137, todavía sin cruce).
	-- Esperado: Bloqueado, cada caso con su mensaje: "no puede enfrentarse a sí misma",
	--           "La selección visitante indicada no existe" y "La selección visitante es obligatoria".
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 137);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s09, @idSeleccionVisitante = @s09;
		PRINT 'TEST 1.L FALLÓ: permitió una selección contra sí misma.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%Una selección no puede enfrentarse a sí misma%'
			PRINT 'TEST 1.L.1 OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 1.L.1 FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s09, @idSeleccionVisitante = 32000;
		PRINT 'TEST 1.L FALLÓ: permitió una selección inexistente.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%La selección visitante indicada no existe%'
			PRINT 'TEST 1.L.2 OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 1.L.2 FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s09, @idSeleccionVisitante = NULL;
		PRINT 'TEST 1.L FALLÓ: permitió una selección nula.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%La selección visitante es obligatoria%'
			PRINT 'TEST 1.L.3 OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 1.L.3 FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 1.M a 1.O Los otros tres cuartos de final.
	-- Esperado: OK. 137 s09-s13, 138 s02-s06 y 139 s10-s14 quedan asignados.
	BEGIN TRY
		SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 137);
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s09, @idSeleccionVisitante = @s13;
		SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 138);
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s02, @idSeleccionVisitante = @s06;
		SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 139);
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s10, @idSeleccionVisitante = @s14;
		IF (SELECT COUNT(*) FROM nucleo.Partido
		    WHERE NumeroPartido BETWEEN 136 AND 139 AND IdSeleccionLocal IS NOT NULL AND IdSeleccionVisitante IS NOT NULL) = 4
			PRINT 'TEST 1.M OK: los cuatro cuartos de final quedaron asignados.';
		ELSE
			PRINT 'TEST 1.M FALLÓ: algún cuarto de final no quedó asignado.';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 1.M FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- =====================================================================
	-- Se juegan los cuartos de final: ganan s01 (136), s09 (137), s06 (138, visitante) y s14 (139, por penales).
	-- =====================================================================
	INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
	SELECT p.IdPartido, j.IdJugador, NULL, @tgJugada, @pePT, 15
	FROM (VALUES (136, 'TEST_CR_01'), (137, 'TEST_CR_09'), (138, 'TEST_CR_06'), (139, 'TEST_CR_10'), (139, 'TEST_CR_14')) AS g(Num, Doc)
	INNER JOIN nucleo.Partido AS p ON p.NumeroPartido = g.Num
	INNER JOIN jugadores.Jugador AS j ON j.Documento = g.Doc;

	INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
	SELECT p.IdPartido, j.IdJugador, NULL, @tgPenal, @peTanda, 120
	FROM (VALUES (139, 'TEST_CR_14', 4), (139, 'TEST_CR_10', 3)) AS g(Num, Doc, Cant)
	INNER JOIN nucleo.Partido AS p ON p.NumeroPartido = g.Num
	INNER JOIN jugadores.Jugador AS j ON j.Documento = g.Doc
	INNER JOIN (VALUES (1), (2), (3), (4)) AS k(n) ON k.n <= g.Cant;

	UPDATE nucleo.Partido SET Estado = 'Finalizado' WHERE NumeroPartido BETWEEN 136 AND 139;

	-- =====================================================================
	-- TEST 2: semifinales (ganadores de cuartos)
	-- =====================================================================
	-- 2.A Cuartos ya finalizado (136).
	-- Esperado: Bloqueado: "Solo se pueden definir cruces de partidos en estado Programado".
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 136);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s01, @idSeleccionVisitante = @s05;
		PRINT 'TEST 2.A FALLÓ: permitió definir el cruce de un partido finalizado.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%Solo se pueden definir cruces de partidos en estado Programado%'
			PRINT 'TEST 2.A OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 2.A FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 2.B Semifinal con una selección que perdió en cuartos (s05 perdió el 136).
	-- Esperado: Bloqueado: "No ganaron un partido finalizado de Cuartos de final: DXE".
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 140);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s05, @idSeleccionVisitante = @s09;
		PRINT 'TEST 2.B FALLÓ: permitió una semifinal con un perdedor de cuartos.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%No ganaron un partido finalizado de Cuartos de final: DXE%'
			PRINT 'TEST 2.B OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 2.B FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 2.C Semifinal 140 con los ganadores s01 y s09.
	-- Esperado: OK.
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s01, @idSeleccionVisitante = @s09;
		IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND IdSeleccionLocal = @s01 AND IdSeleccionVisitante = @s09)
			PRINT 'TEST 2.C OK: semifinal 140 asignada (s01 contra s09).';
		ELSE
			PRINT 'TEST 2.C FALLÓ: la semifinal no quedó asignada.';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 2.C FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 2.D Selección ya asignada a otra semifinal (s01 está en la 140).
	-- Esperado: Bloqueado: "Ya están asignadas a otro partido de Semifinal: DXA".
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 141);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s01, @idSeleccionVisitante = @s14;
		PRINT 'TEST 2.D FALLÓ: permitió una selección en dos semifinales.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%Ya están asignadas a otro partido de Semifinal: DXA%'
			PRINT 'TEST 2.D OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 2.D FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 2.E El partido de la fase anterior se jugó después: la semifinal 144 es el 05/02, pero s06 ganó su
	--     cuarto el 07/02 (138) y s14 el 10/02 (139).
	-- Esperado: Bloqueado: "no es anterior a este partido" con las dos selecciones (DXF y DXN).
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 144);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s06, @idSeleccionVisitante = @s14;
		PRINT 'TEST 2.E FALLÓ: permitió una semifinal anterior a los cuartos que ganaron las selecciones.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%El partido de Cuartos de final que ganaron no es anterior a este partido:%'
		   AND ERROR_MESSAGE() LIKE '%DXF%' AND ERROR_MESSAGE() LIKE '%DXN%'
			PRINT 'TEST 2.E OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 2.E FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 2.F Semifinal 141 con los ganadores s06 (visitante en cuartos) y s14 (por penales).
	-- Esperado: OK.
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 141);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s06, @idSeleccionVisitante = @s14;
		IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND IdSeleccionLocal = @s06 AND IdSeleccionVisitante = @s14)
			PRINT 'TEST 2.F OK: semifinal 141 asignada (s06 contra s14; s14 ganó por penales).';
		ELSE
			PRINT 'TEST 2.F FALLÓ: la semifinal no quedó asignada.';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 2.F FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- =====================================================================
	-- Se juegan las semifinales: gana s01 (140) y gana s14 (141).
	-- =====================================================================
	INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
	SELECT p.IdPartido, j.IdJugador, NULL, @tgJugada, @pePT, 15
	FROM (VALUES (140, 'TEST_CR_01'), (141, 'TEST_CR_14')) AS g(Num, Doc)
	INNER JOIN nucleo.Partido AS p ON p.NumeroPartido = g.Num
	INNER JOIN jugadores.Jugador AS j ON j.Documento = g.Doc;

	UPDATE nucleo.Partido SET Estado = 'Finalizado' WHERE NumeroPartido IN (140, 141);

	-- =====================================================================
	-- TEST 3: tercer puesto y final
	-- =====================================================================
	-- 3.A Tercer puesto con los ganadores de las semifinales (s01 y s14).
	-- Esperado: Bloqueado: "No perdieron un partido finalizado de Semifinal" con las dos selecciones.
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 142);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s01, @idSeleccionVisitante = @s14;
		PRINT 'TEST 3.A FALLÓ: permitió el tercer puesto con los ganadores de las semifinales.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%No perdieron un partido finalizado de Semifinal:%'
		   AND ERROR_MESSAGE() LIKE '%DXA%' AND ERROR_MESSAGE() LIKE '%DXN%'
			PRINT 'TEST 3.A OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 3.A FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 3.B Tercer puesto con los perdedores de las semifinales (s09 perdió la 140 y s06 perdió la 141).
	-- Esperado: OK.
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s09, @idSeleccionVisitante = @s06;
		IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND IdSeleccionLocal = @s09 AND IdSeleccionVisitante = @s06)
			PRINT 'TEST 3.B OK: tercer puesto asignado (s09 contra s06).';
		ELSE
			PRINT 'TEST 3.B FALLÓ: el tercer puesto no quedó asignado.';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 3.B FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 3.C Final con los perdedores de las semifinales (el Tercer puesto no cuenta como fase anterior).
	-- Esperado: Bloqueado: "No ganaron un partido finalizado de Semifinal" con las dos selecciones.
	SET @id = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 143);
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s09, @idSeleccionVisitante = @s06;
		PRINT 'TEST 3.C FALLÓ: permitió la final con los perdedores de las semifinales.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%No ganaron un partido finalizado de Semifinal:%'
		   AND ERROR_MESSAGE() LIKE '%DXI%' AND ERROR_MESSAGE() LIKE '%DXF%'
			PRINT 'TEST 3.C OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 3.C FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- 3.D Final con los ganadores de las semifinales (s01 contra s14).
	-- Esperado: OK. La salida (result set) muestra el partido sin resultado todavía (Programado).
	BEGIN TRY
		EXEC nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO @idPartido = @id, @idSeleccionLocal = @s01, @idSeleccionVisitante = @s14;
		IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @id AND IdSeleccionLocal = @s01 AND IdSeleccionVisitante = @s14)
			PRINT 'TEST 3.D OK: final asignada (s01 contra s14).';
		ELSE
			PRINT 'TEST 3.D FALLÓ: la final no quedó asignada.';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 3.D FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
END;

-- =========================================================================
-- LIMPIEZA: se deshace todo lo insertado por el test (incluidos los cambios de la regla)
-- =========================================================================
ROLLBACK TRANSACTION;
GO

IF EXISTS (SELECT 1 FROM nucleo.Pais WHERE Nombre LIKE 'TEST CR%')
	PRINT 'ATENCIÓN: quedaron datos de prueba TEST CR en la base.';
ELSE
	PRINT 'Limpieza OK: no quedaron datos de prueba TEST CR.';
GO
