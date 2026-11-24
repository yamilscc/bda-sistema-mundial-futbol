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
	- Probar nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS (script 27).
	- Requiere ejecutados los scripts 01 a 27 sobre una base recién creada con 00_Reset_Total.sql.
	  Todo se inserta directo (sin SP). Datos con prefijo 'TEST CL' / 'TEST_CL', borrados al inicio;
	  el test corre dentro de una transacción que se deshace al final (ROLLBACK) y cada caso que
	  modifica datos vuelve a su estado con un savepoint.
	- Convención de salida: "OK" -> el caso se comportó como se esperaba; "OK (Bloqueado)" -> el SP
	  rechazó la operación con el mensaje esperado; "FALLÓ" -> no; "OMITIDO" -> el test necesita
	  una base sin otras selecciones ni otros partidos de fase de grupos.
	- Los result sets del SP se ven en pantalla; los casos verifican con los parámetros OUTPUT.

Escenario: 4 grupos (M, N, O, P) de 4 selecciones TEST (16), un jugador convocado por selección y
24 partidos de fase de grupos (NumeroPartido 171 a 194), todos contra todos dentro de cada grupo.
  En cada partido gana 1-0 la selección de menor IdSeleccion (el jugador local marca el único gol).
  Resultado en cada grupo (t1 < t2 < t3 < t4 por IdSeleccion):
    t1 9 pts (DG +3), t2 6 pts (DG +1), t3 3 pts (DG -1), t4 0 pts (DG -3).
  Con la regla (2, 0) clasifican los dos primeros de cada grupo: 8 selecciones, empieza en cuartos.
  Los partidos 171 a 176 son los del grupo M.
*/

USE MundialFutbol;
GO

-- Si una corrida anterior quedó con la transacción abierta, se deshace antes de empezar.
WHILE @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;

-- =========================================================================
-- LIMPIEZA PREVIA
-- =========================================================================
DELETE FROM eventos.Gol WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 171 AND 194);
DELETE FROM nucleo.Partido       WHERE NumeroPartido BETWEEN 171 AND 194;
DELETE FROM jugadores.Convocatoria WHERE IdJugador IN (SELECT IdJugador FROM jugadores.Jugador WHERE Documento LIKE 'TEST_CL%');
DELETE FROM jugadores.Jugador    WHERE Documento LIKE 'TEST_CL%';
DELETE FROM nucleo.Seleccion     WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST CL%');
DELETE FROM nucleo.Grupo         WHERE Nombre BETWEEN 'M' AND 'P' AND IdGrupo NOT IN (SELECT IdGrupo FROM nucleo.Seleccion);
DELETE FROM nucleo.Sede          WHERE NombreEstadio LIKE 'TEST CL%';
DELETE FROM nucleo.Ciudad        WHERE Nombre LIKE 'TEST CL%';
DELETE FROM nucleo.Pais          WHERE Nombre LIKE 'TEST CL%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST CL%';
GO

BEGIN TRANSACTION;

-- =========================================================================
-- DATOS DE PRUEBA
-- =========================================================================
INSERT INTO eventos.TipoGol (Descripcion)
SELECT v.d FROM (VALUES ('Jugada')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.TipoGol AS t WHERE t.Descripcion = v.d);

INSERT INTO eventos.Periodo (Descripcion)
SELECT v.d FROM (VALUES ('Primer Tiempo')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Periodo AS t WHERE t.Descripcion = v.d);

DECLARE @tgJugada INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'Jugada');
DECLARE @pePT     INT = (SELECT IdPeriodo FROM eventos.Periodo WHERE Descripcion = 'Primer Tiempo');

-- Regla inicial del test: 2 por grupo, sin mejores terceros.
DELETE FROM nucleo.ReglaClasificacion;
INSERT INTO nucleo.ReglaClasificacion (IdRegla, ClasificadosPorGrupo, MejoresTerceros) VALUES (1, 2, 0);

-- 16 países, 4 grupos (M..P) y 16 selecciones (4 por grupo, en orden de IdSeleccion).
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST CL Confederacion', 'TCL');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TCL');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, HusoHorarioComercial)
SELECT 'TEST CL Pais ' + RIGHT('0' + CAST(v.n AS VARCHAR(2)), 2), v.iso2, 'C' + v.iso2, @idConf, 'Argentina Standard Time'
FROM (VALUES (1, 'QR'), (2, 'QS'), (3, 'QT'), (4, 'QU'), (5, 'QV'), (6, 'QW'), (7, 'QX'), (8, 'QY'),
             (9, 'QZ'), (10, 'XL'), (11, 'XM'), (12, 'XN'), (13, 'XO'), (14, 'XP'), (15, 'XQ'), (16, 'XR')) AS v(n, iso2);

INSERT INTO nucleo.Grupo (Nombre)
SELECT CHAR(76 + v.n)
FROM (VALUES (1), (2), (3), (4)) AS v(n)
WHERE NOT EXISTS (SELECT 1 FROM nucleo.Grupo AS g WHERE g.Nombre = CHAR(76 + v.n));

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
SELECT p.CodigoISO3, 100 + x.n, p.IdPais, g.IdGrupo
FROM nucleo.Pais AS p
CROSS APPLY (SELECT CAST(RIGHT(p.Nombre, 2) AS INT) AS n) AS x
INNER JOIN nucleo.Grupo AS g ON g.Nombre = CHAR(76 + ((x.n - 1) / 4) + 1)
WHERE p.Nombre LIKE 'TEST CL Pais%'
ORDER BY x.n;

-- Sede y jugadores (el jugador n está convocado en la selección n).
DECLARE @idPais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE Nombre = 'TEST CL Pais 01');
INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais) VALUES ('TEST CL Ciudad', 'Argentina Standard Time', @idPais1);
INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad)
VALUES ('TEST CL Estadio', 60000, (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST CL Ciudad'));
DECLARE @idSede TINYINT = (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio = 'TEST CL Estadio');

INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion, IdClub)
SELECT 'Jugador', 'CL' + CAST(v.n AS VARCHAR(2)), 'TEST_CL_' + RIGHT('0' + CAST(v.n AS VARCHAR(2)), 2), 'M', 'Delantero', NULL
FROM (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12), (13), (14), (15), (16)) AS v(n);

INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
SELECT s.IdSeleccion, j.IdJugador, 9
FROM jugadores.Jugador AS j
CROSS APPLY (SELECT CAST(RIGHT(j.Documento, 2) AS INT) AS n) AS x
INNER JOIN nucleo.Pais AS p ON p.Nombre = 'TEST CL Pais ' + RIGHT('0' + CAST(x.n AS VARCHAR(2)), 2)
INNER JOIN nucleo.Seleccion AS s ON s.IdPais = p.IdPais
WHERE j.Documento LIKE 'TEST_CL_%';

-- Partidos: todos contra todos dentro de cada grupo (a vs b con IdSeleccion de a menor que el de b).
DECLARE @fGrupos TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Fase de grupos');

INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
SELECT 170 + r.n,
       DATEADD(DAY, r.n, CAST('2026-01-01 18:00' AS DATETIME2(0))),
       'Finalizado', @fGrupos, @idSede, r.IdLocal, r.IdVisitante
FROM (SELECT ROW_NUMBER() OVER (ORDER BY a.IdSeleccion, b.IdSeleccion) AS n,
             a.IdSeleccion AS IdLocal, b.IdSeleccion AS IdVisitante
      FROM nucleo.Seleccion AS a
      INNER JOIN nucleo.Pais AS pa ON pa.IdPais = a.IdPais AND pa.Nombre LIKE 'TEST CL Pais%'
      INNER JOIN nucleo.Seleccion AS b ON b.IdGrupo = a.IdGrupo AND b.IdSeleccion > a.IdSeleccion) AS r;

-- Un gol del jugador de la selección local en cada partido (gana el local 1-0).
INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
SELECT p.IdPartido, c.IdJugador, NULL, @tgJugada, @pePT, 20
FROM nucleo.Partido AS p
INNER JOIN jugadores.Convocatoria AS c ON c.IdSeleccion = p.IdSeleccionLocal
WHERE p.NumeroPartido BETWEEN 171 AND 194;

-- Con otras selecciones o con otros partidos de grupos en la base, los totales y las listas cambian.
DECLARE @hayOtras BIT = CASE WHEN EXISTS (SELECT 1 FROM nucleo.Seleccion AS s
                                          INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais
                                          WHERE p.Nombre NOT LIKE 'TEST CL%')
                               OR EXISTS (SELECT 1 FROM nucleo.Partido AS pa
                                          INNER JOIN nucleo.Fase AS f ON f.IdFase = pa.IdFase AND f.Nombre = 'Fase de grupos'
                                          WHERE pa.NumeroPartido NOT BETWEEN 171 AND 194)
                             THEN 1 ELSE 0 END;

DECLARE @idFaseOut TINYINT, @totalOut INT, @avisoOut NVARCHAR(MAX);
DECLARE @idFaseCuartos TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Cuartos de final');

IF @hayOtras = 1
	PRINT 'TEST 27 OMITIDO: la base tiene selecciones u otros partidos de fase de grupos que no son de este test.';
ELSE
BEGIN
	-- =====================================================================
	-- 1.A Fase de grupos completa, regla (2, 0).
	-- Esperado: OK. Devuelve los 3 result sets (16 posiciones, 8 clasificados y la fase cuartos de final);
	--           @idFaseInicial = cuartos de final, @totalClasificados = 8 y sin aviso de desempate.
	-- =====================================================================
	BEGIN TRY
		EXEC nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS
		     @idFaseInicial = @idFaseOut OUTPUT, @totalClasificados = @totalOut OUTPUT, @avisoDesempate = @avisoOut OUTPUT;
		IF @idFaseOut = @idFaseCuartos AND @totalOut = 8 AND @avisoOut IS NULL
			PRINT 'TEST 1.A OK: 8 clasificados, empieza en cuartos de final y sin aviso de desempate.';
		ELSE
			PRINT 'TEST 1.A FALLÓ: salida inesperada (fase ' + ISNULL(CAST(@idFaseOut AS VARCHAR(5)), 'NULL')
			    + ', total ' + ISNULL(CAST(@totalOut AS VARCHAR(5)), 'NULL') + ').';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 1.A FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;

	-- =====================================================================
	-- 2.A Un partido de grupos sin finalizar (el 175).
	-- Esperado: Bloqueado: "Hay 1 partido(s) de fase de grupos sin finalizar: 175".
	-- =====================================================================
	SAVE TRANSACTION CasoB;
	UPDATE nucleo.Partido SET Estado = 'Programado' WHERE NumeroPartido = 175;
	BEGIN TRY
		EXEC nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS;
		PRINT 'TEST 2.A FALLÓ: permitió calcular con un partido sin finalizar.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%Hay 1 partido(s) de fase de grupos sin finalizar: 175%'
			PRINT 'TEST 2.A OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 2.A FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	ROLLBACK TRANSACTION CasoB;

	-- =====================================================================
	-- 2.B Un partido de grupos que nunca se cargó (se borra el 171, entre las dos primeras del grupo M).
	-- Esperado: Bloqueado: las dos selecciones del partido figuran con "(2 de 3)".
	-- =====================================================================
	SAVE TRANSACTION CasoC;
	DELETE FROM eventos.Gol WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 171);
	DELETE FROM nucleo.Partido WHERE NumeroPartido = 171;
	BEGIN TRY
		EXEC nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS;
		PRINT 'TEST 2.B FALLÓ: permitió calcular con un partido de grupos sin cargar.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%Hay 2 selección(es) con partidos de fase de grupos sin cargar%'
		   AND ERROR_MESSAGE() LIKE '%CQR (2 de 3)%' AND ERROR_MESSAGE() LIKE '%CQS (2 de 3)%'
			PRINT 'TEST 2.B OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 2.B FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	ROLLBACK TRANSACTION CasoC;

	-- =====================================================================
	-- 2.C Sin partidos de fase de grupos.
	-- Esperado: Bloqueado: "No hay partidos de fase de grupos cargados" (y ninguna otra línea).
	-- =====================================================================
	SAVE TRANSACTION CasoD;
	DELETE FROM eventos.Gol WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 171 AND 194);
	DELETE FROM nucleo.Partido WHERE NumeroPartido BETWEEN 171 AND 194;
	BEGIN TRY
		EXEC nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS;
		PRINT 'TEST 2.C FALLÓ: permitió calcular sin partidos de grupos.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%No hay partidos de fase de grupos cargados%'
		   AND ERROR_MESSAGE() NOT LIKE '%sin finalizar%' AND ERROR_MESSAGE() NOT LIKE '%sin cargar%'
			PRINT 'TEST 2.C OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 2.C FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	ROLLBACK TRANSACTION CasoD;

	-- =====================================================================
	-- 2.D Sin regla de clasificación.
	-- Esperado: Bloqueado: "No hay regla de clasificación cargada".
	-- =====================================================================
	SAVE TRANSACTION CasoE;
	DELETE FROM nucleo.ReglaClasificacion;
	BEGIN TRY
		EXEC nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS;
		PRINT 'TEST 2.D FALLÓ: permitió calcular sin regla de clasificación.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%No hay regla de clasificación cargada%'
			PRINT 'TEST 2.D OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 2.D FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	ROLLBACK TRANSACTION CasoE;

	-- =====================================================================
	-- 2.E Regla (2, 1): 4 grupos x 2 + 1 = 9 clasificados, que no corresponde a ninguna fase.
	-- Esperado: Bloqueado: "El total de clasificados (9) no corresponde a ninguna fase".
	-- =====================================================================
	SAVE TRANSACTION CasoF;
	UPDATE nucleo.ReglaClasificacion SET ClasificadosPorGrupo = 2, MejoresTerceros = 1 WHERE IdRegla = 1;
	BEGIN TRY
		EXEC nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS;
		PRINT 'TEST 2.E FALLÓ: permitió calcular con un total de 9 clasificados.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%El total de clasificados (9) no corresponde a ninguna fase%'
			PRINT 'TEST 2.E OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 2.E FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	ROLLBACK TRANSACTION CasoF;

	-- =====================================================================
	-- 3.A Varias fallas juntas: partido sin finalizar y regla con total inválido.
	-- Esperado: Bloqueado con UN solo mensaje que contiene las dos condiciones.
	-- =====================================================================
	SAVE TRANSACTION CasoG;
	UPDATE nucleo.Partido SET Estado = 'Programado' WHERE NumeroPartido = 175;
	UPDATE nucleo.ReglaClasificacion SET ClasificadosPorGrupo = 2, MejoresTerceros = 1 WHERE IdRegla = 1;
	BEGIN TRY
		EXEC nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS;
		PRINT 'TEST 3.A FALLÓ: permitió calcular con varias fallas.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE 'SP_CALCULO_DE_SELECCIONES_CLASIFICADAS - No se pudo calcular los clasificados:%'
		   AND ERROR_MESSAGE() LIKE '%sin finalizar: 175%'
		   AND ERROR_MESSAGE() LIKE '%El total de clasificados (9)%'
			PRINT 'TEST 3.A OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 3.A FALLÓ: el mensaje no agrupa las dos fallas -> ' + ERROR_MESSAGE();
	END CATCH;
	ROLLBACK TRANSACTION CasoG;

	-- =====================================================================
	-- 3.B Más de 20 partidos sin finalizar (los 24).
	-- Esperado: Bloqueado: "Hay 24 partido(s) ... sin finalizar: 171, 172, ... 190 y 4 más".
	-- =====================================================================
	SAVE TRANSACTION CasoH;
	UPDATE nucleo.Partido SET Estado = 'Programado' WHERE NumeroPartido BETWEEN 171 AND 194;
	BEGIN TRY
		EXEC nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS;
		PRINT 'TEST 3.B FALLÓ: permitió calcular con los 24 partidos sin finalizar.';
	END TRY
	BEGIN CATCH
		IF ERROR_MESSAGE() LIKE '%Hay 24 partido(s) de fase de grupos sin finalizar: 171, 172%190 y 4 más%'
		   AND ERROR_MESSAGE() NOT LIKE '%191%'
			PRINT 'TEST 3.B OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
		ELSE
			PRINT 'TEST 3.B FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	ROLLBACK TRANSACTION CasoH;

	-- =====================================================================
	-- 4.A Aviso de desempate: en el grupo M todos los partidos terminan 0-0 (se borran sus goles), por lo
	--     que las 4 selecciones empatan en puntos, diferencia de gol y goles a favor y el corte entre el
	--     2.º y el 3.º lo decide el IdSeleccion.
	-- Esperado: OK (no es un error). Sigue habiendo 8 clasificados y @avisoDesempate nombra al grupo M
	--           (CQS y CQT, el 2.º y el 3.º por IdSeleccion).
	-- =====================================================================
	SAVE TRANSACTION CasoI;
	DELETE FROM eventos.Gol WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 171 AND 176);
	SET @idFaseOut = NULL; SET @totalOut = NULL; SET @avisoOut = NULL;
	BEGIN TRY
		EXEC nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS
		     @idFaseInicial = @idFaseOut OUTPUT, @totalClasificados = @totalOut OUTPUT, @avisoDesempate = @avisoOut OUTPUT;
		IF @totalOut = 8 AND @avisoOut LIKE '%grupo M (CQS y CQT)%' AND @avisoOut NOT LIKE '%grupo N%'
			PRINT 'TEST 4.A OK: se avisa el desempate por IdSeleccion del grupo M -> ' + @avisoOut;
		ELSE
			PRINT 'TEST 4.A FALLÓ: aviso inesperado -> ' + ISNULL(@avisoOut, 'NULL');
	END TRY
	BEGIN CATCH
		PRINT 'TEST 4.A FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
	ROLLBACK TRANSACTION CasoI;

	-- =====================================================================
	-- 4.B Salida limpia cuando se vuelve al escenario original.
	-- Esperado: OK, de nuevo 8 clasificados y @avisoDesempate NULL (se revirtió el caso 4.A).
	-- =====================================================================
	SET @idFaseOut = NULL; SET @totalOut = NULL; SET @avisoOut = NULL;
	BEGIN TRY
		EXEC nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS
		     @idFaseInicial = @idFaseOut OUTPUT, @totalClasificados = @totalOut OUTPUT, @avisoDesempate = @avisoOut OUTPUT;
		IF @totalOut = 8 AND @avisoOut IS NULL
			PRINT 'TEST 4.B OK: sin aviso cuando el corte lo deciden los puntos.';
		ELSE
			PRINT 'TEST 4.B FALLÓ: quedó un aviso de un caso anterior.';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 4.B FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
END;

-- =========================================================================
-- LIMPIEZA: se deshace todo lo insertado por el test (incluidos los cambios de la regla)
-- =========================================================================
ROLLBACK TRANSACTION;
GO

IF EXISTS (SELECT 1 FROM nucleo.Pais WHERE Nombre LIKE 'TEST CL%')
	PRINT 'ATENCIÓN: quedaron datos de prueba TEST CL en la base.';
ELSE
	PRINT 'Limpieza OK: no quedaron datos de prueba TEST CL.';
GO
