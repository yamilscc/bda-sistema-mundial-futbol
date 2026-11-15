/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-15
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar nucleo.SP_CONTROL_ARBITRAL (script 08_SP_ControlArbitral.sql): designaciones
          exitosas, cupo por rol, conflicto de nacionalidad (caso obligatorio de aceptación),
          advertencia de posible cruce y acumulación de errores en un único mensaje.
          Requiere ejecutados los scripts 01 a 09 (usa SP_ABM_Sede y SP_ABM_Partido).
          Datos de prueba con prefijo 'TEST' y NumeroPartido >= 9200; se borran al inicio y al final.

Escenario (fase Octavos, todos los países con zona horaria válida):
  TEST Pais 1..4 tienen selección 1..4. Partido 9201 = sel 1 vs sel 2; partido 9202 = sel 3 vs sel 4.
  TEST Pais 5 no tiene selección.
  Árbitros: ArbT1 (país 1), ArbT3 (país 3), ArbT5a/b/c/d (país 5).
*/

USE MundialFutbol;
GO

-- =========================================================================
-- LIMPIEZA PREVIA
-- =========================================================================
DELETE d FROM nucleo.DesignacionArbitral AS d INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido WHERE p.NumeroPartido >= 9200 AND p.NumeroPartido < 9300;
DELETE FROM nucleo.Partido WHERE NumeroPartido >= 9200 AND NumeroPartido < 9300;
DELETE FROM nucleo.Arbitro WHERE Documento LIKE 'TEST_ARB_%';
DELETE FROM nucleo.Categoria WHERE Descripcion LIKE 'TEST%';
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
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
       ('TEST Pais 4', 'T4', 'TS4', @idConf, 'Eastern Standard Time'),
       ('TEST Pais 5', 'T5', 'TS5', @idConf, 'Eastern Standard Time');

DECLARE @pais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS1');
DECLARE @pais3 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS3');
DECLARE @pais4 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS4');
DECLARE @pais5 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS5');

INSERT INTO nucleo.Ciudad (Nombre, IdPais) VALUES ('TEST Ciudad', @pais4);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST Ciudad');

INSERT INTO nucleo.Seleccion (IdPais)
SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 IN ('TS1', 'TS2', 'TS3', 'TS4');

DECLARE @sel1 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion s JOIN nucleo.Pais p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'TS1');
DECLARE @sel2 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion s JOIN nucleo.Pais p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'TS2');
DECLARE @sel3 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion s JOIN nucleo.Pais p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'TS3');
DECLARE @sel4 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion s JOIN nucleo.Pais p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'TS4');

INSERT INTO nucleo.Categoria (Descripcion) VALUES ('TEST Categoria');
DECLARE @idCategoria INT = (SELECT IdCategoria FROM nucleo.Categoria WHERE Descripcion = 'TEST Categoria');

INSERT INTO nucleo.Arbitro (Nombre, Apellido, Documento, IdPais, IdCategoria)
VALUES ('TEST', 'ArbT1',  'TEST_ARB_T1',  @pais1, @idCategoria),
       ('TEST', 'ArbT3',  'TEST_ARB_T3',  @pais3, @idCategoria),
       ('TEST', 'ArbT5a', 'TEST_ARB_T5A', @pais5, @idCategoria),
       ('TEST', 'ArbT5b', 'TEST_ARB_T5B', @pais5, @idCategoria),
       ('TEST', 'ArbT5c', 'TEST_ARB_T5C', @pais5, @idCategoria),
       ('TEST', 'ArbT5d', 'TEST_ARB_T5D', @pais5, @idCategoria);

DECLARE @arbT1  INT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE Documento = 'TEST_ARB_T1');
DECLARE @arbT3  INT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE Documento = 'TEST_ARB_T3');
DECLARE @arbT5a INT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE Documento = 'TEST_ARB_T5A');
DECLARE @arbT5b INT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE Documento = 'TEST_ARB_T5B');
DECLARE @arbT5c INT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE Documento = 'TEST_ARB_T5C');
DECLARE @arbT5d INT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE Documento = 'TEST_ARB_T5D');

DECLARE @faseOctavos INT = (SELECT IdFase FROM nucleo.Fase WHERE Descripcion = 'Octavos');
DECLARE @sede INT, @p9201 INT, @p9202 INT, @adv VARCHAR(200);

EXEC nucleo.SP_ABM_Sede @operacion = 'ALTA', @idSede = @sede OUTPUT, @nombreEstadio = 'TEST Estadio Arbitral',
     @idCiudad = @idCiudad, @capacidad = 50000, @zonaHoraria = 'Eastern Standard Time';
EXEC nucleo.SP_ABM_Partido 'ALTA', @p9201 OUTPUT, 9201, @faseOctavos, @sede, '2026-06-12 20:00', @sel1, @sel2;
EXEC nucleo.SP_ABM_Partido 'ALTA', @p9202 OUTPUT, 9202, @faseOctavos, @sede, '2026-06-13 20:00', @sel3, @sel4;

-- =========================================================================
-- TEST 1: designaciones exitosas
-- =========================================================================
-- 1.A Principal, 2 asistentes (cupo completo de asistentes). País 5 no juega ni tiene selección.
-- Resultado esperado: 3 filas en DesignacionArbitral para el partido 9201 y @adv NULL.
EXEC nucleo.SP_CONTROL_ARBITRAL @p9201, @arbT5a, 'Principal', @adv OUTPUT;
EXEC nucleo.SP_CONTROL_ARBITRAL @p9201, @arbT5b, 'Asistente', @adv OUTPUT;
EXEC nucleo.SP_CONTROL_ARBITRAL @p9201, @arbT5c, 'Asistente', @adv OUTPUT;
SELECT '1.A' AS Test, d.Rol, a.Apellido, @adv AS Advertencia_Esperada_NULL
FROM nucleo.DesignacionArbitral AS d
INNER JOIN nucleo.Arbitro AS a ON a.IdArbitro = d.IdArbitro
WHERE d.IdPartido = @p9201
ORDER BY d.Rol, a.Apellido;

-- 1.B Advertencia: ArbT3 es del país 3, cuya selección juega otro partido de Octavos (9202).
-- Resultado esperado: la designación se inserta (VAR) y @adv trae el texto de advertencia.
EXEC nucleo.SP_CONTROL_ARBITRAL @p9201, @arbT3, 'VAR', @adv OUTPUT;
SELECT '1.B' AS Test, @adv AS Advertencia_Esperada_NoNula,
       (SELECT COUNT(*) FROM nucleo.DesignacionArbitral WHERE IdPartido = @p9201 AND Rol = 'VAR') AS VAR_Esperado_1;

-- =========================================================================
-- TEST 2: validaciones que deben fallar
-- =========================================================================
-- 2.A Conflicto de nacionalidad (caso obligatorio): ArbT1 es del país de la selección 1 (local de 9201).
-- Resultado esperado: THROW 52000 con 1 renglón (el país del árbitro coincide); no se inserta nada.
BEGIN TRY
    EXEC nucleo.SP_CONTROL_ARBITRAL @p9201, @arbT1, 'Cuarto', @adv OUTPUT;
    PRINT 'TEST 2.A FALLÓ: designó a un árbitro del país de una de las selecciones.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.A OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.B Cupo de asistentes completo (ya hay 2): ArbT5d como Asistente.
-- Resultado esperado: THROW 52000 con 1 renglón (lugares cubiertos para ese rol).
BEGIN TRY
    EXEC nucleo.SP_CONTROL_ARBITRAL @p9201, @arbT5d, 'Asistente', @adv OUTPUT;
    PRINT 'TEST 2.B FALLÓ: superó el cupo de asistentes.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.C Dos errores a la vez: ArbT1 (conflicto de nacionalidad) como Principal (cupo ya cubierto por ArbT5a).
-- Resultado esperado: THROW 52000 con UN mensaje de 2 renglones.
BEGIN TRY
    EXEC nucleo.SP_CONTROL_ARBITRAL @p9201, @arbT1, 'Principal', @adv OUTPUT;
    PRINT 'TEST 2.C FALLÓ: aceptó la designación inválida.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.D Árbitro ya designado en el partido y cupo del rol cubierto: ArbT5a de nuevo como Principal.
-- Resultado esperado: THROW 52000 con UN mensaje de 2 renglones (ya designado + cupo cubierto).
BEGIN TRY
    EXEC nucleo.SP_CONTROL_ARBITRAL @p9201, @arbT5a, 'Principal', @adv OUTPUT;
    PRINT 'TEST 2.D FALLÓ: designó dos veces al mismo árbitro.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.E Rol inválido, partido inexistente y árbitro inexistente a la vez.
-- Resultado esperado: THROW 52000 con UN mensaje de 3 renglones.
BEGIN TRY
    EXEC nucleo.SP_CONTROL_ARBITRAL -1, -1, 'Linier', @adv OUTPUT;
    PRINT 'TEST 2.E FALLÓ: aceptó datos inexistentes.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.F Ninguna designación inválida debe haber quedado guardada.
-- Resultado esperado: 4 filas en total para 9201 (Principal, 2 Asistente, VAR).
SELECT '2.F' AS Test, COUNT(*) AS Designaciones_Esperadas_4
FROM nucleo.DesignacionArbitral WHERE IdPartido = @p9201;
GO

-- =========================================================================
-- LIMPIEZA FINAL
-- =========================================================================
DELETE d FROM nucleo.DesignacionArbitral AS d INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido WHERE p.NumeroPartido >= 9200 AND p.NumeroPartido < 9300;
DELETE FROM nucleo.Partido WHERE NumeroPartido >= 9200 AND NumeroPartido < 9300;
DELETE FROM nucleo.Arbitro WHERE Documento LIKE 'TEST_ARB_%';
DELETE FROM nucleo.Categoria WHERE Descripcion LIKE 'TEST%';
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
GO
