/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-14
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar nucleo.SP_ABM_Sede, nucleo.SP_ABM_Partido, nucleo.SP_REGISTRAR_RESULTADO_PARTIDO
          y nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS, con casos exitosos y casos donde
          las validaciones deben fallar (un único mensaje con todas las condiciones incumplidas).
          Requiere ejecutados los scripts 01 a 09. Datos de prueba con prefijo 'TEST' y
          NumeroPartido >= 9000; se borran al inicio y al final.
          Los catálogos (confederación, países, ciudad, grupos, selecciones) se cargan directo
          como fixture porque sus ABM no forman parte de este script.

Escenario: sede 'Eastern Standard Time' (UTC-4 en junio). Grupo TEST-1 con TEST Pais 1, 2 y 3;
grupo TEST-2 con TEST Pais 4.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- LIMPIEZA PREVIA
-- =========================================================================
DELETE FROM nucleo.Partido WHERE NumeroPartido >= 9000 AND NumeroPartido < 9100;
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Grupo WHERE Nombre LIKE 'TEST-%';
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
GO

-- =========================================================================
-- FIXTURE
-- =========================================================================
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST Confederacion', 'TST');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TST');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, ZonaHoraria)
VALUES ('TEST Pais 1', 'T1', 'TS1', @idConf, 'Argentina Standard Time'),
       ('TEST Pais 2', 'T2', 'TS2', @idConf, 'Tokyo Standard Time'),
       ('TEST Pais 3', 'T3', 'TS3', @idConf, 'W. Europe Standard Time'),
       ('TEST Pais 4', 'T4', 'TS4', @idConf, 'Eastern Standard Time');

INSERT INTO nucleo.Ciudad (Nombre, IdPais)
VALUES ('TEST Ciudad', (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS4'));
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST Ciudad');

INSERT INTO nucleo.Grupo (Nombre) VALUES ('TEST-1'), ('TEST-2');
DECLARE @idGrupo1 INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'TEST-1');
DECLARE @idGrupo2 INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'TEST-2');

INSERT INTO nucleo.Seleccion (IdPais, IdGrupo)
SELECT IdPais, CASE CodigoISO3 WHEN 'TS4' THEN @idGrupo2 ELSE @idGrupo1 END
FROM nucleo.Pais WHERE CodigoISO3 IN ('TS1', 'TS2', 'TS3', 'TS4');

DECLARE @sel1 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion s JOIN nucleo.Pais p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'TS1');
DECLARE @sel2 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion s JOIN nucleo.Pais p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'TS2');
DECLARE @sel3 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion s JOIN nucleo.Pais p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'TS3');
DECLARE @sel4 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion s JOIN nucleo.Pais p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'TS4');

DECLARE @faseGrupos  INT = (SELECT IdFase FROM nucleo.Fase WHERE Descripcion = 'Grupos');
DECLARE @faseOctavos INT = (SELECT IdFase FROM nucleo.Fase WHERE Descripcion = 'Octavos');

DECLARE @sede INT, @sedeBaja INT, @p9001 INT, @p9002 INT, @p9003 INT, @p9010 INT, @p9011 INT, @p9099 INT;

-- =========================================================================
-- TEST 1: nucleo.SP_ABM_Sede
-- =========================================================================
-- 1.A ALTA exitosa. Resultado esperado: se inserta la sede y @sede devuelve su Id (no NULL).
EXEC nucleo.SP_ABM_Sede @operacion = 'ALTA', @idSede = @sede OUTPUT, @nombreEstadio = 'TEST Estadio 1',
     @idCiudad = @idCiudad, @capacidad = 50000, @zonaHoraria = 'Eastern Standard Time',
     @latitud = 40.813500, @longitud = -74.074500;
SELECT '1.A' AS Test, IdSede, NombreEstadio, Capacidad, ZonaHoraria FROM nucleo.Sede WHERE IdSede = @sede;

-- 1.B ALTA con 5 errores a la vez: nombre duplicado, capacidad 0, zona inválida,
-- latitud sin longitud y latitud fuera de rango.
-- Resultado esperado: THROW 52000 con UN mensaje de 5 renglones; no se inserta nada.
BEGIN TRY
    EXEC nucleo.SP_ABM_Sede @operacion = 'ALTA', @nombreEstadio = 'TEST Estadio 1', @idCiudad = @idCiudad,
         @capacidad = 0, @zonaHoraria = 'Zona Inexistente', @latitud = 200;
    PRINT 'TEST 1.B FALLÓ: permitió el alta inválida.';
END TRY
BEGIN CATCH
    PRINT 'TEST 1.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 1.C MODIFICACION exitosa. Resultado esperado: capacidad 60000 y misma zona.
EXEC nucleo.SP_ABM_Sede @operacion = 'MODIFICACION', @idSede = @sede, @nombreEstadio = 'TEST Estadio 1',
     @idCiudad = @idCiudad, @capacidad = 60000, @zonaHoraria = 'Eastern Standard Time',
     @latitud = 40.813500, @longitud = -74.074500;
SELECT '1.C' AS Test, IdSede, Capacidad FROM nucleo.Sede WHERE IdSede = @sede;

-- 1.D BAJA exitosa de una sede sin partidos. Resultado esperado: 0 filas con ese nombre.
EXEC nucleo.SP_ABM_Sede @operacion = 'ALTA', @idSede = @sedeBaja OUTPUT, @nombreEstadio = 'TEST Estadio Baja',
     @idCiudad = @idCiudad, @capacidad = 1000, @zonaHoraria = 'Eastern Standard Time';
EXEC nucleo.SP_ABM_Sede @operacion = 'BAJA', @idSede = @sedeBaja;
SELECT '1.D' AS Test, COUNT(*) AS Filas_Esperadas_0 FROM nucleo.Sede WHERE NombreEstadio = 'TEST Estadio Baja';

-- 1.E Operación inválida. Resultado esperado: THROW 52001 'Operación inválida...'.
BEGIN TRY
    EXEC nucleo.SP_ABM_Sede @operacion = 'BORRAR', @idSede = @sede;
    PRINT 'TEST 1.E FALLÓ: aceptó una operación inválida.';
END TRY
BEGIN CATCH
    PRINT 'TEST 1.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: nucleo.SP_ABM_Partido
-- =========================================================================
-- 2.A ALTA exitosa de 3 partidos de grupo (TEST-1), con fechas separadas por 4 días.
-- Resultado esperado: 3 filas. 9001 -> FechaHoraUTC 2026-06-13 00:00 (20:00 EDT + 4 h).
EXEC nucleo.SP_ABM_Partido 'ALTA', @p9001 OUTPUT, 9001, @faseGrupos, @sede, '2026-06-12 20:00', @sel1, @sel2;
EXEC nucleo.SP_ABM_Partido 'ALTA', @p9002 OUTPUT, 9002, @faseGrupos, @sede, '2026-06-16 20:00', @sel1, @sel3;
EXEC nucleo.SP_ABM_Partido 'ALTA', @p9003 OUTPUT, 9003, @faseGrupos, @sede, '2026-06-20 20:00', @sel2, @sel3;
SELECT '2.A' AS Test, NumeroPartido, FechaHoraLocal, FechaHoraUTC, Estado
FROM nucleo.Partido WHERE NumeroPartido IN (9001, 9002, 9003) ORDER BY NumeroPartido;

-- 2.B ALTA con 4 errores a la vez: número repetido, selección contra sí misma,
-- sede ocupada a menos de 3 h (21:00 vs 20:00 del 9001) y descanso < 72 h de TEST Pais 1.
-- Resultado esperado: THROW 52000 con UN mensaje de 4 renglones.
BEGIN TRY
    EXEC nucleo.SP_ABM_Partido 'ALTA', NULL, 9001, @faseGrupos, @sede, '2026-06-12 21:00', @sel1, @sel1;
    PRINT 'TEST 2.B FALLÓ: permitió el alta inválida.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.C ALTA en fase de grupos con selecciones de grupos distintos (TEST Pais 1 vs TEST Pais 4).
-- Resultado esperado: THROW 52000 con 1 renglón (deben pertenecer al mismo grupo).
BEGIN TRY
    EXEC nucleo.SP_ABM_Partido 'ALTA', NULL, 9004, @faseGrupos, @sede, '2026-06-30 20:00', @sel1, @sel4;
    PRINT 'TEST 2.C FALLÓ: permitió cruzar grupos distintos.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.D ALTA con fase y sede inexistentes. Resultado esperado: THROW 52000 con 2 renglones.
BEGIN TRY
    EXEC nucleo.SP_ABM_Partido 'ALTA', NULL, 9005, -1, -1, '2026-06-30 20:00', NULL, NULL;
    PRINT 'TEST 2.D FALLÓ: permitió fase y sede inexistentes.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.E ALTA de un cruce repetido en grupos (TEST Pais 2 vs TEST Pais 1 ya existe como 9001).
-- Resultado esperado: THROW 52000 que incluye 'Ese cruce ya está programado'.
BEGIN TRY
    EXEC nucleo.SP_ABM_Partido 'ALTA', NULL, 9006, @faseGrupos, @sede, '2026-07-10 20:00', @sel2, @sel1;
    PRINT 'TEST 2.E FALLÓ: permitió repetir el cruce.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.F MODIFICACION exitosa: se mueve el 9003 al 22/06. Resultado esperado: FechaHoraLocal 2026-06-22 20:00.
EXEC nucleo.SP_ABM_Partido 'MODIFICACION', @p9003, 9003, @faseGrupos, @sede, '2026-06-22 20:00', @sel2, @sel3;
SELECT '2.F' AS Test, NumeroPartido, FechaHoraLocal, FechaHoraUTC FROM nucleo.Partido WHERE IdPartido = @p9003;

-- 2.G ALTA exitosa de un octavos con cruce de grupos distintos (permitido en eliminación directa).
-- Resultado esperado: 1 fila, Estado 'Programado'.
EXEC nucleo.SP_ABM_Partido 'ALTA', @p9010 OUTPUT, 9010, @faseOctavos, @sede, '2026-07-05 20:00', @sel1, @sel4;
SELECT '2.G' AS Test, NumeroPartido, Estado FROM nucleo.Partido WHERE IdPartido = @p9010;

-- 2.H BAJA exitosa. Resultado esperado: 0 filas con NumeroPartido 9099.
EXEC nucleo.SP_ABM_Partido 'ALTA', @p9099 OUTPUT, 9099, @faseOctavos, @sede, '2026-07-12 20:00', NULL, NULL;
EXEC nucleo.SP_ABM_Partido 'BAJA', @p9099;
SELECT '2.H' AS Test, COUNT(*) AS Filas_Esperadas_0 FROM nucleo.Partido WHERE NumeroPartido = 9099;

-- =========================================================================
-- TEST 3: nucleo.SP_REGISTRAR_RESULTADO_PARTIDO
-- =========================================================================
-- 3.A Goles negativos + penales en fase de grupos + asistencia mayor a la capacidad (60000), sobre 9002.
-- Resultado esperado: THROW 52000 con 3 renglones; el partido sigue 'Programado'.
BEGIN TRY
    EXEC nucleo.SP_REGISTRAR_RESULTADO_PARTIDO @idPartido = @p9002, @golesLocal = -1, @golesVisitante = 1,
         @penalesLocal = 4, @penalesVisitante = 3, @asistencia = 70000;
    PRINT 'TEST 3.A FALLÓ: aceptó un resultado inválido.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.A OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;
SELECT '3.A' AS Test, Estado AS Estado_Esperado_Programado FROM nucleo.Partido WHERE IdPartido = @p9002;

-- 3.B Resultados exitosos de grupo: 9001 = 2-0, 9002 = 1-1, 9003 = 0-3.
-- Resultado esperado: cada llamada devuelve 1 fila con Estado 'Finalizado'.
EXEC nucleo.SP_REGISTRAR_RESULTADO_PARTIDO @p9001, 2, 0, NULL, NULL, 45000;
EXEC nucleo.SP_REGISTRAR_RESULTADO_PARTIDO @p9002, 1, 1, NULL, NULL, 52000;
EXEC nucleo.SP_REGISTRAR_RESULTADO_PARTIDO @p9003, 0, 3, NULL, NULL, 38000;

-- 3.C Empate en octavos sin penales. Resultado esperado: THROW 52000 con 1 renglón.
BEGIN TRY
    EXEC nucleo.SP_REGISTRAR_RESULTADO_PARTIDO @idPartido = @p9010, @golesLocal = 2, @golesVisitante = 2, @asistencia = 50000;
    PRINT 'TEST 3.C FALLÓ: aceptó un empate sin penales en eliminación directa.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.D Octavos con ganador y penales informados. Resultado esperado: THROW 52000 con 1 renglón.
BEGIN TRY
    EXEC nucleo.SP_REGISTRAR_RESULTADO_PARTIDO @idPartido = @p9010, @golesLocal = 1, @golesVisitante = 0,
         @penalesLocal = 4, @penalesVisitante = 3;
    PRINT 'TEST 3.D FALLÓ: aceptó penales sin empate.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.E Octavos empatado 2-2 y definido por penales 4-3. Resultado esperado: 1 fila Finalizado, penales 4-3.
EXEC nucleo.SP_REGISTRAR_RESULTADO_PARTIDO @idPartido = @p9010, @golesLocal = 2, @golesVisitante = 2,
     @penalesLocal = 4, @penalesVisitante = 3, @asistencia = 50000;

-- 3.F Partido a futuro y sin selecciones definidas.
-- Resultado esperado: THROW 52000 con 2 renglones (sin selecciones definidas + todavía no se jugó).
EXEC nucleo.SP_ABM_Partido 'ALTA', @p9011 OUTPUT, 9011, @faseOctavos, @sede, '2027-06-01 20:00', NULL, NULL;
BEGIN TRY
    EXEC nucleo.SP_REGISTRAR_RESULTADO_PARTIDO @idPartido = @p9011, @golesLocal = 1, @golesVisitante = 0;
    PRINT 'TEST 3.F FALLÓ: aceptó resultado de un partido futuro.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.F OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.G Partido inexistente. Resultado esperado: THROW 52000 'El partido indicado no existe.'
BEGIN TRY
    EXEC nucleo.SP_REGISTRAR_RESULTADO_PARTIDO @idPartido = -1, @golesLocal = 1, @golesVisitante = 0;
    PRINT 'TEST 3.G FALLÓ: aceptó un partido inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.G OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: validaciones de ABM que dependen de resultados ya cargados
-- =========================================================================
-- 4.A MODIFICACION de un partido finalizado. Resultado esperado: THROW 52000 (ya está finalizado).
BEGIN TRY
    EXEC nucleo.SP_ABM_Partido 'MODIFICACION', @p9001, 9001, @faseGrupos, @sede, '2026-06-13 20:00', @sel1, @sel2;
    PRINT 'TEST 4.A FALLÓ: modificó un partido finalizado.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.A OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.B MODIFICACION de sede con capacidad (40000) menor a la asistencia registrada (52000).
-- Resultado esperado: THROW 52000 con 1 renglón.
BEGIN TRY
    EXEC nucleo.SP_ABM_Sede @operacion = 'MODIFICACION', @idSede = @sede, @nombreEstadio = 'TEST Estadio 1',
         @idCiudad = @idCiudad, @capacidad = 40000, @zonaHoraria = 'Eastern Standard Time',
         @latitud = 40.813500, @longitud = -74.074500;
    PRINT 'TEST 4.B FALLÓ: bajó la capacidad por debajo de la asistencia.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.C BAJA de una sede con partidos. Resultado esperado: THROW 52000 con 1 renglón.
BEGIN TRY
    EXEC nucleo.SP_ABM_Sede @operacion = 'BAJA', @idSede = @sede;
    PRINT 'TEST 4.C FALLÓ: eliminó una sede con partidos.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 5: nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS
-- (se filtran los grupos 'TEST-%' para ignorar los del seed real)
-- =========================================================================
CREATE TABLE #Resultado (
    NombreGrupo VARCHAR(10), Posicion INT, IdSeleccion INT, Pais VARCHAR(80),
    PartidosJugados INT, Ganados INT, Empatados INT, Perdidos INT,
    GolesFavor INT, GolesContra INT, Diferencia INT, Puntos INT,
    GrupoCompleto BIT, Clasifica BIT, ClasificaComo VARCHAR(20)
);

-- 5.A Dos clasificados por grupo, sin mejores terceros.
-- Resultado esperado para TEST-1: 1º TEST Pais 3 (4 pts, DG +3), 2º TEST Pais 1 (4 pts, DG +2),
-- 3º TEST Pais 2 (0 pts). GrupoCompleto = 1. Clasifican 'Directo' los dos primeros.
-- Resultado esperado para TEST-2: TEST Pais 4 con 0 partidos y 'Directo' (es la única del grupo).
INSERT INTO #Resultado EXEC nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS @clasificadosPorGrupo = 2, @mejoresTerceros = 0;
SELECT '5.A' AS Test, * FROM #Resultado WHERE NombreGrupo LIKE 'TEST-%' ORDER BY NombreGrupo, Posicion;

-- 5.B Parámetros inválidos. Resultado esperado: THROW 52000 con 2 renglones
-- (clasificados por grupo < 1 y mejores terceros negativos).
BEGIN TRY
    EXEC nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS @clasificadosPorGrupo = 0, @mejoresTerceros = -1;
    PRINT 'TEST 5.B FALLÓ: aceptó parámetros inválidos.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

DROP TABLE #Resultado;
GO

-- =========================================================================
-- LIMPIEZA FINAL
-- =========================================================================
DELETE FROM nucleo.Partido WHERE NumeroPartido >= 9000 AND NumeroPartido < 9100;
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Grupo WHERE Nombre LIKE 'TEST-%';
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
GO
