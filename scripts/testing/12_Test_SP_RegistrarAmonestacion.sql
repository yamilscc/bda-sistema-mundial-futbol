/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-15
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar eventos.SP_REGISTRAR_AMONESTACION (script 12_SP_RegistrarAmonestacion.sql).
          Requiere ejecutados los scripts 01 a 12 (usa SP_ABM_Sede, SP_ABM_Partido y
          SP_REGISTRAR_RESULTADO_PARTIDO).
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK): los datos de
          prueba y las reglas de suspensión que carga el test no quedan en la base. Si el script
          se corta por un error, ejecutar ROLLBACK TRANSACTION; a mano.

Escenario: 3 países TEST (selecciones 1, 2 y 3), una sede y 4 partidos de Octavos (20:00 local).
  Jugadores: J1 y J2 de Sel1; J3 de Sel2; J4 de Sel3; J5 sin convocatoria.
  Staff: S1 de Sel1 y S2 de Sel3.
  Partidos: 9501 Sel1 vs Sel2 (12/06), 9502 (16/06), 9503 (20/06) y 9504 (se pasa al año 2030).
  Reglas de suspensión del test: 2 amarillas = 1 partido; doble amarilla = 1; roja directa = 2.

Cada caso informa 'OK' o 'FALLÓ'. Los casos negativos informan 'OK (Bloqueado)' con el mensaje
del SP; al final se muestran controles con la cantidad esperada.
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- DATOS DE PRUEBA
-- =========================================================================
INSERT INTO eventos.Tarjeta (Tipo)
SELECT v.d FROM (VALUES ('Amarilla'), ('Roja por doble amarilla'), ('Roja directa')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Tarjeta AS t WHERE t.Tipo = v.d);

-- Reglas del test (se deshacen con el ROLLBACK final).
DELETE FROM eventos.ReglaSuspension;
INSERT INTO eventos.ReglaSuspension (Criterio, CantidadAmarillas, PartidosSuspension)
VALUES ('Acumulacion Amarillas', 2, 1), ('Doble Amarilla', NULL, 1), ('Roja Directa', NULL, 2);

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST EV5 Confederacion', 'TE5');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TE5');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, ZonaHoraria)
VALUES ('TEST EV5 Pais 1', 'W1', 'WE1', @idConf, 'Argentina Standard Time'),
       ('TEST EV5 Pais 2', 'W2', 'WE2', @idConf, 'Argentina Standard Time'),
       ('TEST EV5 Pais 3', 'W3', 'WE3', @idConf, 'Argentina Standard Time');

INSERT INTO nucleo.Seleccion (IdPais)
SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 IN ('WE1', 'WE2', 'WE3');

DECLARE @idSel1 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion AS s INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'WE1');
DECLARE @idSel2 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion AS s INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'WE2');
DECLARE @idSel3 INT = (SELECT s.IdSeleccion FROM nucleo.Seleccion AS s INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais WHERE p.CodigoISO3 = 'WE3');

DECLARE @idPais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'WE1');
INSERT INTO nucleo.Ciudad (Nombre, IdPais) VALUES ('TEST EV5 Ciudad', @idPais1);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST EV5 Ciudad');

DECLARE @idSede INT;
EXEC nucleo.SP_ABM_Sede @operacion = 'ALTA', @idSede = @idSede OUTPUT, @nombreEstadio = 'TEST EV5 Estadio',
     @idCiudad = @idCiudad, @capacidad = 60000, @zonaHoraria = 'Argentina Standard Time';

INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion, IdClub)
VALUES ('Jugador', 'Uno',    'TEST_EV5_1', 'M', 'Delantero', NULL),
       ('Jugador', 'Dos',    'TEST_EV5_2', 'M', 'Defensor',  NULL),
       ('Jugador', 'Tres',   'TEST_EV5_3', 'M', 'Delantero', NULL),
       ('Jugador', 'Cuatro', 'TEST_EV5_4', 'M', 'Delantero', NULL),
       ('Jugador', 'Cinco',  'TEST_EV5_5', 'M', 'Delantero', NULL);

DECLARE @idJ1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV5_1');
DECLARE @idJ2 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV5_2');
DECLARE @idJ3 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV5_3');
DECLARE @idJ4 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV5_4');
DECLARE @idJ5 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV5_5');

INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
VALUES (@idSel1, @idJ1, 9), (@idSel1, @idJ2, 4), (@idSel2, @idJ3, 9), (@idSel3, @idJ4, 9);

INSERT INTO nucleo.StaffTecnico (IdSeleccion, Nombre, Apellido, Documento, Rol)
VALUES (@idSel1, 'Staff', 'Uno', 'TEST_EV5_S1', 'Ayudante'),
       (@idSel3, 'Staff', 'Dos', 'TEST_EV5_S2', 'Ayudante');
DECLARE @idS1 INT = (SELECT IdStaffTecnico FROM nucleo.StaffTecnico WHERE Documento = 'TEST_EV5_S1');
DECLARE @idS2 INT = (SELECT IdStaffTecnico FROM nucleo.StaffTecnico WHERE Documento = 'TEST_EV5_S2');

DECLARE @idFase INT = (SELECT IdFase FROM nucleo.Fase WHERE Descripcion = 'Octavos');
DECLARE @p9501 INT, @p9502 INT, @p9503 INT, @p9504 INT;
EXEC nucleo.SP_ABM_Partido 'ALTA', @p9501 OUTPUT, 9501, @idFase, @idSede, '2026-06-12 20:00', @idSel1, @idSel2;
EXEC nucleo.SP_ABM_Partido 'ALTA', @p9502 OUTPUT, 9502, @idFase, @idSede, '2026-06-16 20:00', @idSel1, @idSel2;
EXEC nucleo.SP_ABM_Partido 'ALTA', @p9503 OUTPUT, 9503, @idFase, @idSede, '2026-06-20 20:00', @idSel1, @idSel2;
EXEC nucleo.SP_ABM_Partido 'ALTA', @p9504 OUTPUT, 9504, @idFase, @idSede, '2026-06-24 20:00', @idSel1, @idSel2;

-- El partido 9504 pasa al futuro para probar la validación de fecha.
UPDATE nucleo.Partido
SET FechaHoraLocal = '2030-06-12 20:00', FechaHoraUTC = '2030-06-12 23:00'
WHERE IdPartido = @p9504;

DECLARE @idAmon INT;

-- =========================================================================
-- TEST: eventos.SP_REGISTRAR_AMONESTACION
-- =========================================================================
PRINT '--- SP_REGISTRAR_AMONESTACION ---';

-- A1 Primera amarilla a J1 (partido 9501).
-- Resultado esperado: OK, PartidosSuspension = 0.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Amarilla', @minuto = 15,
         @motivo = 'Falta tactica', @idJugador = @idJ1, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A1: OK - amarilla registrada (suspensión esperada: 0).';
END TRY
BEGIN CATCH
    PRINT 'A1: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A2 Segunda amarilla a J1 en el mismo partido.
-- Resultado esperado: OK, se registra como 'Roja por doble amarilla', PartidosSuspension = 1.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Amarilla', @minuto = 60,
         @motivo = 'Protestas', @idJugador = @idJ1, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A2: OK - segunda amarilla convertida en roja por doble amarilla (suspensión esperada: 1).';
END TRY
BEGIN CATCH
    PRINT 'A2: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A3 Tarjeta a J1 después de su expulsión (minuto 70, expulsado en el 60).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Amarilla', @minuto = 70,
         @motivo = 'Reclamo', @idJugador = @idJ1;
    PRINT 'A3: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A3: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A4 Roja directa a J2 (partido 9501).
-- Resultado esperado: OK, PartidosSuspension = 2.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Roja directa', @minuto = 30,
         @motivo = 'Juego brusco grave', @idJugador = @idJ2, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A4: OK - roja directa registrada (suspensión esperada: 2).';
END TRY
BEGIN CATCH
    PRINT 'A4: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A5 Tipo de tarjeta no permitido como dato de entrada.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Roja por doble amarilla', @minuto = 40,
         @motivo = 'Prueba', @idJugador = @idJ3;
    PRINT 'A5: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A5: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A6 Jugador y staff a la vez.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Amarilla', @minuto = 40,
         @motivo = 'Prueba', @idJugador = @idJ3, @idStaffTecnico = @idS1;
    PRINT 'A6: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A6: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A7 Ni jugador ni staff.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Amarilla', @minuto = 40,
         @motivo = 'Prueba';
    PRINT 'A7: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A7: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A8 Motivo vacío.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Amarilla', @minuto = 40,
         @motivo = '   ', @idJugador = @idJ3;
    PRINT 'A8: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A8: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A9 Jugador de una selección que no juega el partido (J4 es de Sel3).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Amarilla', @minuto = 40,
         @motivo = 'Prueba', @idJugador = @idJ4;
    PRINT 'A9: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A9: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A10 Jugador sin convocatoria (J5).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Amarilla', @minuto = 40,
         @motivo = 'Prueba', @idJugador = @idJ5;
    PRINT 'A10: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A10: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A11 Amarilla al staff S1 (partido 9501).
-- Resultado esperado: OK, PartidosSuspension = 0.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Amarilla', @minuto = 50,
         @motivo = 'Protestas desde el banco', @idStaffTecnico = @idS1, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A11: OK - amarilla al staff registrada (suspensión esperada: 0).';
END TRY
BEGIN CATCH
    PRINT 'A11: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A12 Roja directa al staff S1.
-- Resultado esperado: OK, PartidosSuspension = 0.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Roja directa', @minuto = 80,
         @motivo = 'Conducta antideportiva', @idStaffTecnico = @idS1, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A12: OK - roja directa al staff registrada (suspensión esperada: 0).';
END TRY
BEGIN CATCH
    PRINT 'A12: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A13 Tarjeta al staff S1 después de su expulsión.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Amarilla', @minuto = 85,
         @motivo = 'Prueba', @idStaffTecnico = @idS1;
    PRINT 'A13: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A13: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A14 Staff de una selección que no juega el partido (S2 es de Sel3).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Amarilla', @minuto = 50,
         @motivo = 'Prueba', @idStaffTecnico = @idS2;
    PRINT 'A14: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A14: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A15 Acumulación de amarillas de J3: primera amarilla (partido 9501).
-- Resultado esperado: OK, PartidosSuspension = 0.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9501, @tipoTarjeta = 'Amarilla', @minuto = 25,
         @motivo = 'Falta', @idJugador = @idJ3, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A15: OK - primera amarilla de J3 (suspensión esperada: 0).';
END TRY
BEGIN CATCH
    PRINT 'A15: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A16 Acumulación: segunda amarilla de J3 en otro partido (9502).
-- Resultado esperado: OK, PartidosSuspension = 1 (2 amarillas = 1 partido en las reglas del test).
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9502, @tipoTarjeta = 'Amarilla', @minuto = 25,
         @motivo = 'Falta', @idJugador = @idJ3, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A16: OK - segunda amarilla de J3 en otro partido (suspensión esperada: 1).';
END TRY
BEGIN CATCH
    PRINT 'A16: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- Suspendidos, partido finalizado y partido futuro
-- =========================================================================
PRINT '--- Suspendidos, finalizado y futuro ---';

-- A17 Tarjeta a J3 en el partido 9503, cumpliendo 1 partido por acumulación de amarillas.
-- Resultado esperado: error (suspendido).
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9503, @tipoTarjeta = 'Amarilla', @minuto = 10,
         @motivo = 'Falta', @idJugador = @idJ3;
    PRINT 'A17: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A17: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- Se finaliza el partido 9503 con 1 a 0.
EXEC nucleo.SP_REGISTRAR_RESULTADO_PARTIDO @idPartido = @p9503, @golesLocal = 1, @golesVisitante = 0;

-- A18 Tarjeta en el partido finalizado.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9503, @tipoTarjeta = 'Amarilla', @minuto = 10,
         @motivo = 'Falta', @idJugador = @idJ1;
    PRINT 'A18: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A18: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A19 Tarjeta en un partido que todavía no se jugó (9504, año 2030).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p9504, @tipoTarjeta = 'Amarilla', @minuto = 10,
         @motivo = 'Falta', @idJugador = @idJ1;
    PRINT 'A19: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A19: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
PRINT '--- CONTROLES ---';

-- Amonestaciones esperadas: 7 (A1, A2, A4, A11, A12, A15 y A16).
SELECT 'Amonestaciones registradas (esperado: 7)' AS Control, COUNT(*) AS Cantidad
FROM eventos.Amonestacion
WHERE IdPartido IN (@p9501, @p9502, @p9503, @p9504);

-- Suspensiones esperadas: J1 doble amarilla = 1, J2 roja directa = 2, J3 en 9502 (2da amarilla) = 1,
-- el resto 0.
SELECT p.NumeroPartido, t.Tipo AS Tarjeta, a.IdJugador, a.IdStaffTecnico, a.Minuto, a.PartidosSuspension
FROM eventos.Amonestacion AS a
INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
INNER JOIN nucleo.Partido AS p ON p.IdPartido = a.IdPartido
WHERE a.IdPartido IN (@p9501, @p9502, @p9503, @p9504)
ORDER BY p.NumeroPartido, a.Minuto;

-- =========================================================================
-- FIN: se deshacen todos los cambios de la prueba.
-- =========================================================================
ROLLBACK TRANSACTION;
GO
