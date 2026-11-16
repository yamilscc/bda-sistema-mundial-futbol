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
Objetivo: Probar los 9 stored procedures ABM del módulo de jugadores (script 18_SP_ABM_Jugadores.sql):
          ReglaConvocados, ReglaCambios, Club, Jugador, Convocatoria, Baja,
          Formacion, FormacionJugador y Sustitucion.
          Requiere ejecutados los scripts 01 a 18.
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
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TAJ');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, ZonaHoraria)
VALUES ('TEST ABMJ Pais 1', 'A1', 'TA1', @idConf, 'Argentina Standard Time'),
       ('TEST ABMJ Pais 2', 'A2', 'TA2', @idConf, 'Argentina Standard Time');

DECLARE @idPais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TA1');
DECLARE @idPais2 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TA2');

INSERT INTO nucleo.Seleccion (IdPais) VALUES (@idPais1), (@idPais2);
DECLARE @idSel1 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais1);
DECLARE @idSel2 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais2);

INSERT INTO nucleo.Ciudad (Nombre, IdPais) VALUES ('TEST ABMJ Ciudad', @idPais1);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST ABMJ Ciudad');

DECLARE @idSede INT, @idPartido INT;
EXEC nucleo.SP_ABM_Sede @operacion = 'ALTA', @idSede = @idSede OUTPUT, @nombreEstadio = 'TEST ABMJ Estadio',
     @idCiudad = @idCiudad, @capacidad = 50000, @zonaHoraria = 'Argentina Standard Time';

DECLARE @idFase INT = (SELECT IdFase FROM nucleo.Fase WHERE Descripcion = 'Octavos');
EXEC nucleo.SP_ABM_Partido 'ALTA', @idPartido OUTPUT, 9740, @idFase, @idSede, '2026-06-12 20:00', @idSel1, @idSel2;

-- =========================================================================
-- TEST 1: SP_ABM_ReglaConvocados y SP_ABM_ReglaCambios
-- =========================================================================
PRINT '--- TEST 1: ReglaConvocados y ReglaCambios ---';

DECLARE @idRegConv INT, @idRegCam INT;

BEGIN TRY
    EXEC jugadores.SP_ABM_ReglaConvocados 'ALTA', @idRegConv OUTPUT, 2, 5;
    EXEC jugadores.SP_ABM_ReglaConvocados 'MODIFICACION', @idRegConv, 2, 4;
    EXEC jugadores.SP_ABM_ReglaCambios 'ALTA', @idRegCam OUTPUT, 5, 3, 1, 1;
    EXEC jugadores.SP_ABM_ReglaCambios 'MODIFICACION', @idRegCam, 3, 2, 1, 1;
    PRINT '1.A: OK - alta y modificación de ReglaConvocados y ReglaCambios.';
END TRY
BEGIN CATCH
    PRINT '1.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC jugadores.SP_ABM_ReglaConvocados 'ALTA', NULL, 26, 23;
    PRINT '1.B: FALLÓ - permitió máximo menor que mínimo.';
END TRY
BEGIN CATCH
    PRINT '1.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 2: SP_ABM_Club y SP_ABM_Jugador
-- =========================================================================
PRINT '--- TEST 2: Club y Jugador ---';

DECLARE @idClub1 INT, @idClub2 INT, @idJ1 INT, @idJ2 INT, @idJ3 INT;

BEGIN TRY
    EXEC jugadores.SP_ABM_Club 'ALTA', @idClub1 OUTPUT, 'TEST ABMJ Club 1';
    EXEC jugadores.SP_ABM_Club 'ALTA', @idClub2 OUTPUT, 'TEST ABMJ Club 2';
    EXEC jugadores.SP_ABM_Club 'MODIFICACION', @idClub2, 'TEST ABMJ Club 2 Editado';
    EXEC jugadores.SP_ABM_Club 'BAJA', @idClub2;

    EXEC jugadores.SP_ABM_Jugador 'ALTA', @idJ1 OUTPUT, 'Titular',  'Uno',  'TEST_ABMJ_1', '1998-05-10', 'M', 'Arquero',   @idClub1;
    EXEC jugadores.SP_ABM_Jugador 'ALTA', @idJ2 OUTPUT, 'Suplente', 'Dos',  'TEST_ABMJ_2', '2001-03-15', 'M', 'Delantero', @idClub1;
    EXEC jugadores.SP_ABM_Jugador 'ALTA', @idJ3 OUTPUT, 'Temp',     'Tres', 'TEST_ABMJ_3', '2000-01-01', 'M', 'Defensor',  NULL;
    EXEC jugadores.SP_ABM_Jugador 'MODIFICACION', @idJ3, 'TempMod', 'Tres', 'TEST_ABMJ_3', '2000-01-01', 'M', 'Defensor',  NULL;
    EXEC jugadores.SP_ABM_Jugador 'BAJA', @idJ3;
    PRINT '2.A: OK - ABM de Club y Jugador.';
END TRY
BEGIN CATCH
    PRINT '2.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- Bloqueo de baja de Club con jugadores asociados
BEGIN TRY
    EXEC jugadores.SP_ABM_Club 'BAJA', @idClub1;
    PRINT '2.B: FALLÓ - permitió eliminar club con jugadores.';
END TRY
BEGIN CATCH
    PRINT '2.B: OK (Bloqueado club en uso) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 3: SP_ABM_Convocatoria y SP_ABM_Baja
-- =========================================================================
PRINT '--- TEST 3: Convocatoria y Baja ---';

DECLARE @idConv1 INT, @idConv2 INT, @idBaja INT;

BEGIN TRY
    EXEC jugadores.SP_ABM_Convocatoria 'ALTA', @idConv1 OUTPUT, @idSel1, @idJ1, 1, '2026-06-01';
    EXEC jugadores.SP_ABM_Convocatoria 'ALTA', @idConv2 OUTPUT, @idSel1, @idJ2, 9, '2026-06-01';
    EXEC jugadores.SP_ABM_Convocatoria 'MODIFICACION', @idConv2, @idSel1, @idJ2, 19, '2026-06-01';

    EXEC jugadores.SP_ABM_Baja 'ALTA', @idBaja OUTPUT, @idConv2, '2026-06-03', 'Molestia muscular';
    EXEC jugadores.SP_ABM_Baja 'MODIFICACION', @idBaja, @idConv2, '2026-06-04', 'Sobrecarga confirmada';
    EXEC jugadores.SP_ABM_Baja 'BAJA', @idBaja;
    PRINT '3.A: OK - ABM de Convocatoria y Baja.';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: SP_ABM_Formacion, SP_ABM_FormacionJugador y SP_ABM_Sustitucion
-- =========================================================================
PRINT '--- TEST 4: Formacion, FormacionJugador y Sustitucion ---';

DECLARE @idForm INT, @idSust INT;

BEGIN TRY
    EXEC jugadores.SP_ABM_Formacion 'ALTA', @idForm OUTPUT, @idPartido, 'Local', '4-4-2';
    EXEC jugadores.SP_ABM_Formacion 'MODIFICACION', @idForm, @idPartido, 'Local', '4-3-3';

    EXEC jugadores.SP_ABM_FormacionJugador 'ALTA', @idForm, @idJ1, 'Titular',  'Arquero', 1;
    EXEC jugadores.SP_ABM_FormacionJugador 'ALTA', @idForm, @idJ2, 'Suplente', NULL,      19;
    EXEC jugadores.SP_ABM_FormacionJugador 'MODIFICACION', @idForm, @idJ2, 'Suplente', NULL, 20;

    EXEC jugadores.SP_ABM_Sustitucion 'ALTA', @idSust OUTPUT, @idPartido, @idJ1, @idJ2, 50, 'Regular', 'Lesion', 1;
    EXEC jugadores.SP_ABM_Sustitucion 'MODIFICACION', @idSust, @idPartido, @idJ1, @idJ2, 55, 'Regular', 'Precaucion', 1;
    PRINT '4.A: OK - alta y modificación de Formacion, FormacionJugador y Sustitucion.';
END TRY
BEGIN CATCH
    PRINT '4.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- Bloqueo de baja de FormacionJugador mientras participa en una sustitución
BEGIN TRY
    EXEC jugadores.SP_ABM_FormacionJugador 'BAJA', @idForm, @idJ1;
    PRINT '4.B: FALLÓ - permitió quitar de la formación a un jugador con sustitución.';
END TRY
BEGIN CATCH
    PRINT '4.B: OK (Bloqueado por sustitución activa) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- Baja en orden correcto: primero Sustitucion, luego FormacionJugador, luego Formacion
BEGIN TRY
    EXEC jugadores.SP_ABM_Sustitucion 'BAJA', @idSust;
    EXEC jugadores.SP_ABM_FormacionJugador 'BAJA', @idForm, @idJ2;
    EXEC jugadores.SP_ABM_FormacionJugador 'BAJA', @idForm, @idJ1;
    EXEC jugadores.SP_ABM_Formacion 'BAJA', @idForm;
    PRINT '4.C: OK - baja en cascada manual de Sustitucion, FormacionJugador y Formacion.';
END TRY
BEGIN CATCH
    PRINT '4.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

ROLLBACK TRANSACTION;
GO