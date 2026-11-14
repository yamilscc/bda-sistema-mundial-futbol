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
Objetivo: Probar jugadores.fn_SeleccionesDelPartido y nucleo.fn_MercadosEnPrimeTime
          (incluyendo los bordes del prime time: 19:00 entra, 23:00 no entra).
          Requiere ejecutados los scripts 01 a 09 (usa SP_ABM_Sede y SP_ABM_Partido).
          Datos de prueba con prefijo 'TEST', borrados al inicio y al final.

Escenario: sede en zona 'Eastern Standard Time' (en junio UTC-4). Países de prueba:
  TEST Pais 1 = 'Argentina Standard Time' (UTC-3), TEST Pais 2 = 'Tokyo Standard Time' (UTC+9),
  TEST Pais 3 = 'W. Europe Standard Time' (UTC+2 en junio), TEST Pais 4 = 'Eastern Standard Time' (UTC-4).
  Juegan TEST Pais 1 (local) y TEST Pais 2 (visitante).
*/

USE MundialFutbol;
GO

-- =========================================================================
-- LIMPIEZA PREVIA
-- =========================================================================
DELETE FROM nucleo.Partido WHERE NumeroPartido >= 9100 AND NumeroPartido < 9200;
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
GO

-- =========================================================================
-- DATOS DE PRUEBA
-- =========================================================================
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST Confederacion', 'TST');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TST');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, ZonaHoraria)
VALUES ('TEST Pais 1', 'T1', 'TS1', @idConf, 'Argentina Standard Time'),
       ('TEST Pais 2', 'T2', 'TS2', @idConf, 'Tokyo Standard Time'),
       ('TEST Pais 3', 'T3', 'TS3', @idConf, 'W. Europe Standard Time'),
       ('TEST Pais 4', 'T4', 'TS4', @idConf, 'Eastern Standard Time');

DECLARE @idPais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS1');
DECLARE @idPais2 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS2');
DECLARE @idPais4 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS4');

INSERT INTO nucleo.Ciudad (Nombre, IdPais) VALUES ('TEST Ciudad', @idPais4);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST Ciudad');

INSERT INTO nucleo.Seleccion (IdPais) VALUES (@idPais1), (@idPais2);
DECLARE @idSel1 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais1);
DECLARE @idSel2 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais2);

DECLARE @idSede INT, @idP1 INT, @idP2 INT, @idP3 INT, @idP4 INT;
DECLARE @idFaseOctavos INT = (SELECT IdFase FROM nucleo.Fase WHERE Descripcion = 'Octavos');

EXEC nucleo.SP_ABM_Sede @operacion = 'ALTA', @idSede = @idSede OUTPUT, @nombreEstadio = 'TEST Estadio Prime',
     @idCiudad = @idCiudad, @capacidad = 60000, @zonaHoraria = 'Eastern Standard Time';

-- 9101: 20:00 sede = 00:00 UTC del 13/06  | 9102: 23:00 sede = 03:00 UTC del 17/06
-- 9103: 19:00 sede = 23:00 UTC del 20/06  | 9104: cruce sin definir
EXEC nucleo.SP_ABM_Partido 'ALTA', @idP1 OUTPUT, 9101, @idFaseOctavos, @idSede, '2026-06-12 20:00', @idSel1, @idSel2;
EXEC nucleo.SP_ABM_Partido 'ALTA', @idP2 OUTPUT, 9102, @idFaseOctavos, @idSede, '2026-06-16 23:00', @idSel1, @idSel2;
EXEC nucleo.SP_ABM_Partido 'ALTA', @idP3 OUTPUT, 9103, @idFaseOctavos, @idSede, '2026-06-20 19:00', @idSel1, @idSel2;
EXEC nucleo.SP_ABM_Partido 'ALTA', @idP4 OUTPUT, 9104, @idFaseOctavos, @idSede, '2026-06-25 20:00', NULL, NULL;

-- =========================================================================
-- TEST 1: jugadores.fn_SeleccionesDelPartido
-- =========================================================================
-- 1.A Partido 9101 (cruce definido).
-- Resultado esperado: 2 filas -> (TEST Pais 1, 'Local') y (TEST Pais 2, 'Visitante').
SELECT '1.A' AS Test, s.IdSeleccion, pa.Nombre AS Pais, fs.Localia
FROM jugadores.fn_SeleccionesDelPartido(@idP1) AS fs
INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = fs.IdSeleccion
INNER JOIN nucleo.Pais AS pa ON pa.IdPais = s.IdPais
ORDER BY fs.Localia DESC;

-- 1.B Partido 9104 (cruce a definir).
-- Resultado esperado: 0 filas.
SELECT '1.B' AS Test, COUNT(*) AS Filas_Esperadas_0
FROM jugadores.fn_SeleccionesDelPartido(@idP4);

-- 1.C Partido inexistente.
-- Resultado esperado: 0 filas.
SELECT '1.C' AS Test, COUNT(*) AS Filas_Esperadas_0
FROM jugadores.fn_SeleccionesDelPartido(-1);

-- =========================================================================
-- TEST 2: nucleo.fn_MercadosEnPrimeTime
-- (se filtran los países 'TEST%' para ignorar los del seed real)
-- =========================================================================
-- 2.A Partido 9101 (00:00 UTC): Argentina 21:00 (sí), Tokyo 09:00 (no), Europa 02:00 (no), Eastern 20:00 (sí).
-- Resultado esperado: 2 filas -> TEST Pais 1 (21:00, EsPaisParticipante = 1) y TEST Pais 4 (20:00, EsPaisParticipante = 0).
SELECT '2.A' AS Test, Pais, ZonaHoraria, FechaHoraLocalMercado, EsPaisParticipante
FROM nucleo.fn_MercadosEnPrimeTime(@idP1)
WHERE Pais LIKE 'TEST%'
ORDER BY Pais;

-- 2.B Partido 9102 (03:00 UTC): Argentina 00:00, Tokyo 12:00, Europa 05:00, Eastern 23:00 (el borde 23:00 NO entra).
-- Resultado esperado: 0 filas.
SELECT '2.B' AS Test, COUNT(*) AS Filas_Esperadas_0
FROM nucleo.fn_MercadosEnPrimeTime(@idP2)
WHERE Pais LIKE 'TEST%';

-- 2.C Partido 9103 (23:00 UTC): Argentina 20:00 (sí), Tokyo 08:00 (no), Europa 01:00 (no), Eastern 19:00 (el borde 19:00 SÍ entra).
-- Resultado esperado: 2 filas -> TEST Pais 1 (20:00) y TEST Pais 4 (19:00).
SELECT '2.C' AS Test, Pais, FechaHoraLocalMercado, EsPaisParticipante
FROM nucleo.fn_MercadosEnPrimeTime(@idP3)
WHERE Pais LIKE 'TEST%'
ORDER BY Pais;

-- 2.D Partido inexistente.
-- Resultado esperado: 0 filas.
SELECT '2.D' AS Test, COUNT(*) AS Filas_Esperadas_0
FROM nucleo.fn_MercadosEnPrimeTime(-1);
GO

-- =========================================================================
-- LIMPIEZA FINAL
-- =========================================================================
DELETE FROM nucleo.Partido WHERE NumeroPartido >= 9100 AND NumeroPartido < 9200;
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
GO
