/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-16
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar los 27 stored procedures ABM del módulo de jugadores (alta, modificación y baja de cada tabla) (script 18_SP_ABM_Jugadores.sql):
          ReglaConvocados, ReglaCambios, Club, Jugador, Convocatoria, Baja,
          Formacion, FormacionJugador y Sustitucion.
          Requiere ejecutados los scripts 01 a 18 (usa nucleo.SP_ALTA_Sede y
          nucleo.SP_ALTA_Partido).
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- PREPARACIÓN DE ESCENARIO DE PRUEBA
-- =========================================================================
DELETE FROM jugadores.Sustitucion;
DELETE FROM jugadores.FormacionJugador;
DELETE FROM jugadores.Formacion;
DELETE FROM jugadores.ReglaConvocados;
DELETE FROM jugadores.ReglaCambios;

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST ABMJ Confederacion', 'TAJ');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TAJ');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST ABMJ Pais 1', 'AA', 'TAA', 'Argentina Standard Time', @idConf),
       ('TEST ABMJ Pais 2', 'AB', 'TAB', 'Argentina Standard Time', @idConf);

DECLARE @idPais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TAA');
DECLARE @idPais2 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TAB');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
VALUES ('TAA', 101, 0, @idPais1, @idGrupo),
       ('TAB', 102, 0, @idPais2, @idGrupo);

DECLARE @idSel1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TAA');
DECLARE @idSel2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TAB');

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST ABMJ Ciudad', 'Argentina Standard Time', @idPais1);
DECLARE @idCiudad SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST ABMJ Ciudad');

DECLARE @idSede TINYINT;
DECLARE @idPartido SMALLINT;
EXEC nucleo.SP_ALTA_Sede
     @nombreEstadio = 'TEST ABMJ Estadio',
     @idCiudad      = @idCiudad,
     @capacidad     = 50000,
     @idSede        = @idSede OUTPUT;

DECLARE @idFase TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');

-- En fases eliminatorias SP_ALTA_Partido exige las selecciones en NULL.
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 251, @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = '2026-06-12 20:00', @idPartido = @idPartido OUTPUT;

-- Se asignan las selecciones al cruce eliminatorio para poder probar formaciones y sustituciones:
UPDATE nucleo.Partido
SET IdSeleccionLocal = @idSel1, IdSeleccionVisitante = @idSel2
WHERE IdPartido = @idPartido;

-- =========================================================================
-- TEST 1: SP_ALTA/MODIFICACION/BAJA_ReglaConvocados y SP_ALTA/MODIFICACION/BAJA_ReglaCambios
-- =========================================================================
PRINT '--- TEST 1: ReglaConvocados y ReglaCambios ---';

DECLARE @idRegConv INT, @idRegCam INT;

BEGIN TRY
    EXEC jugadores.SP_ALTA_ReglaConvocados @idRegConv OUTPUT, 2, 5;
    EXEC jugadores.SP_MODIFICACION_ReglaConvocados @idRegConv, 2, 4;
    EXEC jugadores.SP_ALTA_ReglaCambios @idRegCam OUTPUT, 5, 3, 1, 1;
    EXEC jugadores.SP_MODIFICACION_ReglaCambios @idRegCam, 3, 2, 1, 1;
    PRINT '1.A: OK - alta y modificación de ReglaConvocados y ReglaCambios.';
END TRY
BEGIN CATCH
    PRINT '1.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC jugadores.SP_ALTA_ReglaConvocados NULL, 26, 23;
    PRINT '1.B: FALLÓ - permitió máximo menor que mínimo.';
END TRY
BEGIN CATCH
    PRINT '1.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 2: SP_ALTA/MODIFICACION/BAJA_Club y SP_ALTA/MODIFICACION/BAJA_Jugador
-- =========================================================================
PRINT '--- TEST 2: Club y Jugador ---';

DECLARE @idClub1 INT, @idClub2 INT, @idJ1 INT, @idJ2 INT, @idJ3 INT;

BEGIN TRY
    EXEC jugadores.SP_ALTA_Club @idClub1 OUTPUT, 'TEST ABMJ Club 1';
    EXEC jugadores.SP_ALTA_Club @idClub2 OUTPUT, 'TEST ABMJ Club 2';
    EXEC jugadores.SP_MODIFICACION_Club @idClub2, 'TEST ABMJ Club 2 Editado';
    EXEC jugadores.SP_BAJA_Club @idClub2;

    EXEC jugadores.SP_ALTA_Jugador @idJ1 OUTPUT, 'Titular',  'Uno',  'TEST_ABMJ_1', '1998-05-10', 'M', 'Arquero',   @idClub1;
    EXEC jugadores.SP_ALTA_Jugador @idJ2 OUTPUT, 'Suplente', 'Dos',  'TEST_ABMJ_2', '2001-03-15', 'M', 'Delantero', @idClub1;
    EXEC jugadores.SP_ALTA_Jugador @idJ3 OUTPUT, 'Temp',     'Tres', 'TEST_ABMJ_3', '2000-01-01', 'M', 'Defensor',  NULL;
    EXEC jugadores.SP_MODIFICACION_Jugador @idJ3, 'TempMod', 'Tres', 'TEST_ABMJ_3', '2000-01-01', 'M', 'Defensor',  NULL;
    EXEC jugadores.SP_BAJA_Jugador @idJ3;
    PRINT '2.A: OK - ABM de Club y Jugador.';
END TRY
BEGIN CATCH
    PRINT '2.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- Bloqueo de baja de Club con jugadores asociados
BEGIN TRY
    EXEC jugadores.SP_BAJA_Club @idClub1;
    PRINT '2.B: FALLÓ - permitió eliminar club con jugadores.';
END TRY
BEGIN CATCH
    PRINT '2.B: OK (Bloqueado club en uso) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 3: SP_ALTA/MODIFICACION/BAJA_Convocatoria y SP_ALTA/MODIFICACION/BAJA_Baja
-- =========================================================================
PRINT '--- TEST 3: Convocatoria y Baja ---';

DECLARE @idConv1 INT, @idConv2 INT, @idBaja INT;

BEGIN TRY
    EXEC jugadores.SP_ALTA_Convocatoria @idConv1 OUTPUT, @idSel1, @idJ1, 1, '2026-06-01';
    EXEC jugadores.SP_ALTA_Convocatoria @idConv2 OUTPUT, @idSel1, @idJ2, 9, '2026-06-01';
    EXEC jugadores.SP_MODIFICACION_Convocatoria @idConv2, @idSel1, @idJ2, 19, '2026-06-01';

    EXEC jugadores.SP_ALTA_Baja @idBaja OUTPUT, @idConv2, '2026-06-03', 'Molestia muscular';
    EXEC jugadores.SP_MODIFICACION_Baja @idBaja, @idConv2, '2026-06-04', 'Sobrecarga confirmada';
    EXEC jugadores.SP_BAJA_Baja @idBaja;
    PRINT '3.A: OK - ABM de Convocatoria y Baja.';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: SP_ALTA/MODIFICACION/BAJA_Formacion, SP_ALTA/MODIFICACION/BAJA_FormacionJugador y SP_ALTA/MODIFICACION/BAJA_Sustitucion
-- =========================================================================
PRINT '--- TEST 4: Formacion, FormacionJugador y Sustitucion ---';

DECLARE @idForm INT, @idSust INT;

BEGIN TRY
    EXEC jugadores.SP_ALTA_Formacion @idForm OUTPUT, @idPartido, 'Local', '4-4-2';
    EXEC jugadores.SP_MODIFICACION_Formacion @idForm, @idPartido, 'Local', '4-3-3';

    EXEC jugadores.SP_ALTA_FormacionJugador @idForm, @idJ1, 'Titular',  'Arquero', 1;
    EXEC jugadores.SP_ALTA_FormacionJugador @idForm, @idJ2, 'Suplente', NULL,      19;
    EXEC jugadores.SP_MODIFICACION_FormacionJugador @idForm, @idJ2, 'Suplente', NULL, 20;

    EXEC jugadores.SP_ALTA_Sustitucion @idSust OUTPUT, @idPartido, @idJ1, @idJ2, 50, 'Regular', 'Lesion', 1;
    EXEC jugadores.SP_MODIFICACION_Sustitucion @idSust, @idPartido, @idJ1, @idJ2, 55, 'Regular', 'Precaucion', 1;
    PRINT '4.A: OK - alta y modificación de Formacion, FormacionJugador y Sustitucion.';
END TRY
BEGIN CATCH
    PRINT '4.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- Bloqueo de baja de FormacionJugador mientras participa en una sustitución
BEGIN TRY
    EXEC jugadores.SP_BAJA_FormacionJugador @idForm, @idJ1;
    PRINT '4.B: FALLÓ - permitió quitar de la formación a un jugador con sustitución.';
END TRY
BEGIN CATCH
    PRINT '4.B: OK (Bloqueado por sustitución activa) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- Baja en orden correcto: primero Sustitucion, luego FormacionJugador, luego Formacion
BEGIN TRY
    EXEC jugadores.SP_BAJA_Sustitucion @idSust;
    EXEC jugadores.SP_BAJA_FormacionJugador @idForm, @idJ2;
    EXEC jugadores.SP_BAJA_FormacionJugador @idForm, @idJ1;
    EXEC jugadores.SP_BAJA_Formacion @idForm;
    PRINT '4.C: OK - baja en cascada manual de Sustitucion, FormacionJugador y Formacion.';
END TRY
BEGIN CATCH
    PRINT '4.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

ROLLBACK TRANSACTION;
GO
