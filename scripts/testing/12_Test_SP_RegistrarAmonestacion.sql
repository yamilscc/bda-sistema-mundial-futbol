/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-22
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar eventos.SP_REGISTRAR_AMONESTACION (script 12_SP_RegistrarAmonestacion.sql).
          Requiere ejecutados los scripts 01 a 12 (usa nucleo.SP_ALTA_Sede y
          nucleo.SP_ALTA_Partido del script 09).
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK): los datos de
          prueba y las reglas de suspensión que carga el test no quedan en la base. Si el script
          se corta por un error, ejecutar ROLLBACK TRANSACTION; a mano.

Escenario: 3 países TEST (selecciones 1, 2 y 3), una sede y 4 partidos de Octavos (20:00 local).
  Jugadores: J1 y J2 de Sel1; J3 de Sel2; J4 de Sel3; J5 sin convocatoria.
  Staff: S1 de Sel1 y S2 de Sel3 (ambos Director Técnico).
  Partidos: 251 Sel1 vs Sel2 (12/06), 252 (16/06), 253 (20/06) y 254 (se programa en 2030).
  Octavos es fase eliminatoria: SP_ALTA_Partido no admite selecciones en esas fases, por lo que
  los partidos se crean sin cruce y las selecciones se asignan con un UPDATE de preparación.
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

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

-- Los códigos ISO solo admiten letras (CK_Pais_CodigoISO2/3_Valido); se usan códigos de uso libre (X**).
INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST EV5 Pais 1', 'XA', 'XEA', 'Argentina Standard Time', @idConf),
       ('TEST EV5 Pais 2', 'XB', 'XEB', 'Argentina Standard Time', @idConf),
       ('TEST EV5 Pais 3', 'XC', 'XEC', 'Argentina Standard Time', @idConf);

DECLARE @idPais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XEA');
DECLARE @idPais2 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XEB');
DECLARE @idPais3 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XEC');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
VALUES ('XEA', 201, 0, @idPais1, @idGrupo),
       ('XEB', 202, 0, @idPais2, @idGrupo),
       ('XEC', 203, 0, @idPais3, @idGrupo);

DECLARE @idSel1 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XEA');
DECLARE @idSel2 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XEB');
DECLARE @idSel3 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XEC');

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais) VALUES ('TEST EV5 Ciudad', 'Argentina Standard Time', @idPais1);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST EV5 Ciudad');

DECLARE @idSede TINYINT;
EXEC nucleo.SP_ALTA_Sede @nombreEstadio = 'TEST EV5 Estadio', @idCiudad = @idCiudad,
     @capacidad = 60000, @idSede = @idSede OUTPUT;

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

INSERT INTO nucleo.StaffTecnico (NombreApellido, Rol, IdSeleccion)
VALUES ('TEST EV5 Staff Uno', 'Director Técnico', @idSel1),
       ('TEST EV5 Staff Dos', 'Director Técnico', @idSel3);
DECLARE @idS1 INT = (SELECT IdStaffTecnico FROM nucleo.StaffTecnico WHERE NombreApellido = 'TEST EV5 Staff Uno');
DECLARE @idS2 INT = (SELECT IdStaffTecnico FROM nucleo.StaffTecnico WHERE NombreApellido = 'TEST EV5 Staff Dos');

DECLARE @idFase TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');
DECLARE @p251 SMALLINT, @p252 SMALLINT, @p253 SMALLINT, @p254 SMALLINT;

-- Las fechas son horas LOCALES de la sede (Argentina Standard Time, UTC-3 sin horario de verano);
-- el SP las convierte a UTC. El partido 254 se programa en 2030 para probar la validación de fecha.
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 251, @idFase = @idFase, @idSede = @idSede,
     @fechaHoraLocal = '2026-06-12 20:00', @idPartido = @p251 OUTPUT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 252, @idFase = @idFase, @idSede = @idSede,
     @fechaHoraLocal = '2026-06-16 20:00', @idPartido = @p252 OUTPUT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 253, @idFase = @idFase, @idSede = @idSede,
     @fechaHoraLocal = '2026-06-20 20:00', @idPartido = @p253 OUTPUT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 254, @idFase = @idFase, @idSede = @idSede,
     @fechaHoraLocal = '2030-06-12 20:00', @idPartido = @p254 OUTPUT;

-- Cruce de los partidos de Octavos: se asigna directo como preparación del escenario
-- (en el sistema real lo hace SP_DEFINIR_CRUCE_ELIMINATORIO).
UPDATE nucleo.Partido
SET IdSeleccionLocal     = @idSel1,
    IdSeleccionVisitante = @idSel2
WHERE IdPartido IN (@p251, @p252, @p253, @p254);

DECLARE @idAmon INT;

-- =========================================================================
-- TEST: eventos.SP_REGISTRAR_AMONESTACION
-- =========================================================================
PRINT '--- SP_REGISTRAR_AMONESTACION ---';

-- A1 Primera amarilla a J1 (partido 251).
-- Resultado esperado: OK, PartidosSuspension = 0.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 15,
         @motivo = 'Falta tactica', @idJugador = @idJ1, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A1: OK - amarilla registrada (suspensión esperada: 0).';
END TRY
BEGIN CATCH
    PRINT 'A1: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A2 Segunda amarilla a J1 en el mismo partido.
-- Resultado esperado: OK, se registra como 'Roja por doble amarilla', PartidosSuspension = 1.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 60,
         @motivo = 'Protestas', @idJugador = @idJ1, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A2: OK - segunda amarilla convertida en roja por doble amarilla (suspensión esperada: 1).';
END TRY
BEGIN CATCH
    PRINT 'A2: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A3 Tarjeta a J1 después de su expulsión (minuto 70, expulsado en el 60).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 70,
         @motivo = 'Reclamo', @idJugador = @idJ1;
    PRINT 'A3: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A3: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A4 Roja directa a J2 (partido 251).
-- Resultado esperado: OK, PartidosSuspension = 2.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Roja directa', @minuto = 30,
         @motivo = 'Juego brusco grave', @idJugador = @idJ2, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A4: OK - roja directa registrada (suspensión esperada: 2).';
END TRY
BEGIN CATCH
    PRINT 'A4: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A5 Tipo de tarjeta no permitido como dato de entrada.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Roja por doble amarilla', @minuto = 40,
         @motivo = 'Prueba', @idJugador = @idJ3;
    PRINT 'A5: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A5: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A6 Jugador y staff a la vez.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 40,
         @motivo = 'Prueba', @idJugador = @idJ3, @idStaffTecnico = @idS1;
    PRINT 'A6: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A6: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A7 Ni jugador ni staff.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 40,
         @motivo = 'Prueba';
    PRINT 'A7: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A7: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A8 Motivo vacío.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 40,
         @motivo = '   ', @idJugador = @idJ3;
    PRINT 'A8: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A8: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A9 Jugador de una selección que no juega el partido (J4 es de Sel3).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 40,
         @motivo = 'Prueba', @idJugador = @idJ4;
    PRINT 'A9: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A9: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A10 Jugador sin convocatoria (J5).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 40,
         @motivo = 'Prueba', @idJugador = @idJ5;
    PRINT 'A10: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A10: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A11 Amarilla al staff S1 (partido 251).
-- Resultado esperado: OK, PartidosSuspension = 0.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 50,
         @motivo = 'Protestas desde el banco', @idStaffTecnico = @idS1, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A11: OK - amarilla al staff registrada (suspensión esperada: 0).';
END TRY
BEGIN CATCH
    PRINT 'A11: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A12 Roja directa al staff S1.
-- Resultado esperado: OK, PartidosSuspension = 0.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Roja directa', @minuto = 80,
         @motivo = 'Conducta antideportiva', @idStaffTecnico = @idS1, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A12: OK - roja directa al staff registrada (suspensión esperada: 0).';
END TRY
BEGIN CATCH
    PRINT 'A12: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A13 Tarjeta al staff S1 después de su expulsión.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 85,
         @motivo = 'Prueba', @idStaffTecnico = @idS1;
    PRINT 'A13: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A13: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A14 Staff de una selección que no juega el partido (S2 es de Sel3).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 50,
         @motivo = 'Prueba', @idStaffTecnico = @idS2;
    PRINT 'A14: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A14: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A15 Acumulación de amarillas de J3: primera amarilla (partido 251).
-- Resultado esperado: OK, PartidosSuspension = 0.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 25,
         @motivo = 'Falta', @idJugador = @idJ3, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A15: OK - primera amarilla de J3 (suspensión esperada: 0).';
END TRY
BEGIN CATCH
    PRINT 'A15: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A16 Acumulación: segunda amarilla de J3 en otro partido (252).
-- Resultado esperado: OK, PartidosSuspension = 1 (2 amarillas = 1 partido en las reglas del test).
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p252, @tipoTarjeta = 'Amarilla', @minuto = 25,
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

-- A17 Tarjeta a J3 en el partido 253, cumpliendo 1 partido por acumulación de amarillas.
-- Resultado esperado: error (suspendido).
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p253, @tipoTarjeta = 'Amarilla', @minuto = 10,
         @motivo = 'Falta', @idJugador = @idJ3;
    PRINT 'A17: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A17: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- Se finaliza el partido 253 con 1 a 0. SP_ALTA_Partido solo crea partidos 'Programado' y ya no
-- existe un SP de resultado, por lo que el estado se deja como preparación del escenario
-- (cumple CK_Partido_Resultado: Finalizado exige goles y ambas selecciones informados).
UPDATE nucleo.Partido
SET Estado         = 'Finalizado',
    GolesLocal     = 1,
    GolesVisitante = 0
WHERE IdPartido = @p253;

-- A18 Tarjeta en el partido finalizado.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p253, @tipoTarjeta = 'Amarilla', @minuto = 10,
         @motivo = 'Falta', @idJugador = @idJ1;
    PRINT 'A18: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A18: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A19 Tarjeta en un partido que todavía no se jugó (254, año 2030).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p254, @tipoTarjeta = 'Amarilla', @minuto = 10,
         @motivo = 'Falta', @idJugador = @idJ1;
    PRINT 'A19: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'A19: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- A20 Primera amarilla al staff S1 en el partido 252.
-- Resultado esperado: OK, se registra como Amarilla con PartidosSuspension = 0.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p252, @tipoTarjeta = 'Amarilla', @minuto = 30,
         @motivo = 'Protestas desde el banco', @idStaffTecnico = @idS1, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A20: OK - primera amarilla al staff registrada (suspensión esperada: 0).';
END TRY
BEGIN CATCH
    PRINT 'A20: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- A21 Segunda amarilla al mismo miembro del staff en el mismo partido.
-- Resultado esperado: OK, se registra como 'Roja por doble amarilla' con PartidosSuspension = 0
-- (el staff no se suspende).
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = @p252, @tipoTarjeta = 'Amarilla', @minuto = 70,
         @motivo = 'Reclamos reiterados', @idStaffTecnico = @idS1, @idAmonestacion = @idAmon OUTPUT;
    PRINT 'A21: OK - segunda amarilla al staff convertida en roja por doble amarilla (suspensión esperada: 0).';
END TRY
BEGIN CATCH
    PRINT 'A21: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
PRINT '--- CONTROLES ---';

-- Amonestaciones esperadas: 9 (A1, A2, A4, A11, A12, A15, A16, A20 y A21).
SELECT 'Amonestaciones registradas (esperado: 9)' AS Control, COUNT(*) AS Cantidad
FROM eventos.Amonestacion
WHERE IdPartido IN (@p251, @p252, @p253, @p254);

-- Suspensiones esperadas: J1 doble amarilla = 1, J2 roja directa = 2, J3 en 252 (2da amarilla) = 1,
-- el staff (A11, A12, A20 y A21) 0 y el resto 0.
SELECT p.NumeroPartido, t.Tipo AS Tarjeta, a.IdJugador, a.IdStaffTecnico, a.Minuto, a.PartidosSuspension
FROM eventos.Amonestacion AS a
INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
INNER JOIN nucleo.Partido AS p ON p.IdPartido = a.IdPartido
WHERE a.IdPartido IN (@p251, @p252, @p253, @p254)
ORDER BY p.NumeroPartido, a.Minuto;

-- =========================================================================
-- FIN: se deshacen todos los cambios de la prueba.
-- =========================================================================
ROLLBACK TRANSACTION;
GO