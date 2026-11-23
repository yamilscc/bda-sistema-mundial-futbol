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
          -exitosas, cupo por rol, conflicto de nacionalidad (caso obligatorio de aceptación),
          advertencia de posible cruce y acumulación de errores en un único mensaje.
          Datos de prueba con prefijo 'TEST' y NumeroPartido entre 250 y 254; se borran al inicio y al final.

Escenario (fase Octavos de final, todos los países con huso horario válido):
  TEST Pais 1..4 tienen selección 1..4. Partido 251 = sel 1 vs sel 2; partido 252 = sel 3 vs sel 4.
  TEST Pais 5 no tiene selección.
  Árbitros: ArbT1 (país 1), ArbT3 (país 3), ArbT5a/b/c/d (país 5) y ArbT5e (país 5, no habilitado).
*/

USE MundialFutbol;
GO

-- =========================================================================
-- LIMPIEZA PREVIA
-- =========================================================================
DELETE d FROM nucleo.DesignacionArbitral AS d INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido WHERE p.NumeroPartido >= 250 AND p.NumeroPartido < 255;
DELETE FROM nucleo.Partido WHERE NumeroPartido >= 250 AND NumeroPartido < 255;
DELETE FROM nucleo.Arbitro WHERE NombreApellido LIKE 'TEST ArbT%';
DELETE FROM nucleo.Categoria WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Grupo WHERE Nombre = 'Z' AND IdGrupo NOT IN (SELECT IdGrupo FROM nucleo.Seleccion);
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
GO

-- =========================================================================
-- FIXTURE
-- =========================================================================
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST Confederacion', 'TST');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TST');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST Pais 1', 'TA', 'TSA', 'Argentina Standard Time', @idConf),
       ('TEST Pais 2', 'TB', 'TSB', 'Tokyo Standard Time', @idConf),
       ('TEST Pais 3', 'TC', 'TSC', 'W. Europe Standard Time', @idConf),
       ('TEST Pais 4', 'TD', 'TSD', 'Eastern Standard Time', @idConf),
       ('TEST Pais 5', 'TE', 'TSE', 'Eastern Standard Time', @idConf);

DECLARE @pais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TSA');
DECLARE @pais3 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TSC');
DECLARE @pais4 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TSD');
DECLARE @pais5 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TSE');

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST Ciudad', 'Eastern Standard Time', @pais4);
DECLARE @idCiudad SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST Ciudad');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
SELECT CodigoISO3, 100 + ROW_NUMBER() OVER (ORDER BY IdPais), IdPais, @idGrupo
FROM nucleo.Pais
WHERE CodigoISO3 IN ('TSA', 'TSB', 'TSC', 'TSD');

DECLARE @sel1 TINYINT = (SELECT s.IdSeleccion FROM nucleo.Seleccion s JOIN nucleo.Pais p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'TSA');
DECLARE @sel2 TINYINT = (SELECT s.IdSeleccion FROM nucleo.Seleccion s JOIN nucleo.Pais p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'TSB');
DECLARE @sel3 TINYINT = (SELECT s.IdSeleccion FROM nucleo.Seleccion s JOIN nucleo.Pais p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'TSC');
DECLARE @sel4 TINYINT = (SELECT s.IdSeleccion FROM nucleo.Seleccion s JOIN nucleo.Pais p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'TSD');

INSERT INTO nucleo.Categoria (Nombre) VALUES ('TEST Categoria');
DECLARE @idCategoria TINYINT = (SELECT IdCategoria FROM nucleo.Categoria WHERE Nombre = 'TEST Categoria');

INSERT INTO nucleo.Arbitro (NombreApellido, FechaNacimiento, IdPais, IdCategoria)
VALUES ('TEST ArbT1',  '1985-01-01', @pais1, @idCategoria),
       ('TEST ArbT3',  '1985-01-01', @pais3, @idCategoria),
       ('TEST ArbT5a', '1985-01-01', @pais5, @idCategoria),
       ('TEST ArbT5b', '1985-01-01', @pais5, @idCategoria),
       ('TEST ArbT5c', '1985-01-01', @pais5, @idCategoria),
       ('TEST ArbT5d', '1985-01-01', @pais5, @idCategoria);

-- Árbitro no habilitado (para el caso 2.G).
INSERT INTO nucleo.Arbitro (NombreApellido, EstaHabilitado, FechaNacimiento, IdPais, IdCategoria)
VALUES ('TEST ArbT5e', 'N', '1985-01-01', @pais5, @idCategoria);

DECLARE @arbT1  SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST ArbT1');
DECLARE @arbT3  SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST ArbT3');
DECLARE @arbT5a SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST ArbT5a');
DECLARE @arbT5b SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST ArbT5b');
DECLARE @arbT5c SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST ArbT5c');
DECLARE @arbT5d SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST ArbT5d');
DECLARE @arbT5e SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST ArbT5e');

DECLARE @faseOctavos TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');
DECLARE @sede TINYINT, @p251 SMALLINT, @p252 SMALLINT, @adv VARCHAR(200);

INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad)
VALUES ('TEST Estadio Arbitral', 50000, @idCiudad);
SET @sede = SCOPE_IDENTITY();

INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (251, '2026-06-12 20:00:00', 'Programado', @faseOctavos, @sede, @sel1, @sel2);
SET @p251 = SCOPE_IDENTITY();

INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (252, '2026-06-13 20:00:00', 'Programado', @faseOctavos, @sede, @sel3, @sel4);
SET @p252 = SCOPE_IDENTITY();

-- =========================================================================
-- TEST 1: designaciones exitosas
-- =========================================================================
-- 1.A Principal, Asistente 1 y Asistente 2. País 5 no juega ni tiene selección.
-- Resultado esperado: 3 filas en DesignacionArbitral para el partido 251 y @adv NULL.
EXEC nucleo.SP_CONTROL_ARBITRAL @p251, @arbT5a, 'Principal',   @adv OUTPUT;
EXEC nucleo.SP_CONTROL_ARBITRAL @p251, @arbT5b, 'Asistente 1', @adv OUTPUT;
EXEC nucleo.SP_CONTROL_ARBITRAL @p251, @arbT5c, 'Asistente 2', @adv OUTPUT;
SELECT '1.A' AS Test, d.Rol, a.NombreApellido, @adv AS Advertencia_Esperada_NULL
FROM nucleo.DesignacionArbitral AS d
INNER JOIN nucleo.Arbitro AS a ON a.IdArbitro = d.IdArbitro
WHERE d.IdPartido = @p251
ORDER BY d.Rol, a.NombreApellido;

-- 1.B Advertencia: ArbT3 es del país 3, cuya selección juega otro partido de Octavos (252).
-- Resultado esperado: la designación se inserta (VAR) y @adv trae el texto de advertencia.
EXEC nucleo.SP_CONTROL_ARBITRAL @p251, @arbT3, 'VAR', @adv OUTPUT;
SELECT '1.B' AS Test, @adv AS Advertencia_Esperada_NoNula,
       (SELECT COUNT(*) FROM nucleo.DesignacionArbitral WHERE IdPartido = @p251 AND Rol = 'VAR') AS VAR_Esperado_1;

-- =========================================================================
-- TEST 2: validaciones que deben fallar
-- =========================================================================
-- 2.A Conflicto de nacionalidad (caso obligatorio): ArbT1 es del país de la selección 1 (local de 251).
-- Resultado esperado: THROW 52000 con 1 renglón (el país del árbitro coincide); no se inserta nada.
BEGIN TRY
    EXEC nucleo.SP_CONTROL_ARBITRAL @p251, @arbT1, 'Cuarto', @adv OUTPUT;
    PRINT 'TEST 2.A FALLÓ: designó a un árbitro del país de una de las selecciones.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.A OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.B Cupo de Asistente 1 ya cubierto por ArbT5b: ArbT5d como Asistente 1.
-- Resultado esperado: THROW 52000 con 1 renglón (lugares cubiertos para ese rol).
BEGIN TRY
    EXEC nucleo.SP_CONTROL_ARBITRAL @p251, @arbT5d, 'Asistente 1', @adv OUTPUT;
    PRINT 'TEST 2.B FALLÓ: superó el cupo del rol Asistente 1.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.C Dos errores a la vez: ArbT1 (conflicto de nacionalidad) como Principal (cupo ya cubierto por ArbT5a).
-- Resultado esperado: THROW 52000 con UN mensaje de 2 renglones.
BEGIN TRY
    EXEC nucleo.SP_CONTROL_ARBITRAL @p251, @arbT1, 'Principal', @adv OUTPUT;
    PRINT 'TEST 2.C FALLÓ: aceptó la designación inválida.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.D Árbitro ya designado en el partido y cupo del rol cubierto: ArbT5a de nuevo como Principal.
-- Resultado esperado: THROW 52000 con UN mensaje de 2 renglones (ya designado + cupo cubierto).
BEGIN TRY
    EXEC nucleo.SP_CONTROL_ARBITRAL @p251, @arbT5a, 'Principal', @adv OUTPUT;
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

-- 2.G Árbitro no habilitado: ArbT5e (EstaHabilitado = 'N', país 5 sin conflicto) como Cuarto (rol libre).
-- Resultado esperado: THROW 52000 con 1 renglón ("El árbitro no está habilitado para ser designado").
BEGIN TRY
    EXEC nucleo.SP_CONTROL_ARBITRAL @p251, @arbT5e, 'Cuarto', @adv OUTPUT;
    PRINT 'TEST 2.G FALLÓ: designó a un árbitro no habilitado.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 52000 AND ERROR_MESSAGE() LIKE N'%no está habilitado%'
        PRINT 'TEST 2.G OK (Bloqueado): ' + ERROR_MESSAGE();
    ELSE
        PRINT 'TEST 2.G FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.F Ninguna designación inválida debe haber quedado guardada.
-- Resultado esperado: 4 filas en total para 251 (Principal, Asistente 1, Asistente 2, VAR).
SELECT '2.F' AS Test, COUNT(*) AS Designaciones_Esperadas_4
FROM nucleo.DesignacionArbitral WHERE IdPartido = @p251;
GO

-- =========================================================================
-- LIMPIEZA FINAL
-- =========================================================================
DELETE d FROM nucleo.DesignacionArbitral AS d INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido WHERE p.NumeroPartido >= 250 AND p.NumeroPartido < 255;
DELETE FROM nucleo.Partido WHERE NumeroPartido >= 250 AND NumeroPartido < 255;
DELETE FROM nucleo.Arbitro WHERE NombreApellido LIKE 'TEST ArbT%';
DELETE FROM nucleo.Categoria WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Grupo WHERE Nombre = 'Z' AND IdGrupo NOT IN (SELECT IdGrupo FROM nucleo.Seleccion);
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
GO