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
Objetivo: Probar eventos.SP_REGISTRAR_GOL (script 11_SP_RegistrarGol.sql).
          Requiere ejecutados los scripts 01 a 11 (usa nucleo.SP_ALTA_Sede y
          nucleo.SP_ALTA_Partido del script 09).
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK): los datos de
          prueba no quedan en la base. Si el script se corta por un error, ejecutar
          ROLLBACK TRANSACTION; a mano.

Escenario: 3 países TEST (selecciones 1, 2 y 3), una sede y 4 partidos de Octavos (20:00 local).
  Octavos es fase eliminatoria: SP_ALTA_Partido no admite selecciones en esas fases, por lo que
  los partidos se crean sin cruce y las selecciones se asignan con un UPDATE de preparación.
  Jugadores: J1 y J2 de Sel1; J3 de Sel2; J4 de Sel3; J5 sin convocatoria.
  Partidos: 241 Sel1 vs Sel2 (12/06), 242 (16/06), 243 (20/06) y 244 (se programa en 2030).
  Tarjetas previas: J2 roja directa (min 30 de 241, 2 partidos) y J1 doble amarilla
  (min 60 de 241, 1 partido).

Cada caso informa 'OK' o 'FALLÓ'. Los casos negativos informan 'OK (Bloqueado)' con el mensaje
del SP; al final se muestra un control con la cantidad esperada.
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- DATOS DE PRUEBA
-- =========================================================================
INSERT INTO eventos.TipoGol (Descripcion)
SELECT v.d FROM (VALUES ('Jugada'), ('Penal'), ('En contra')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.TipoGol AS t WHERE t.Descripcion = v.d);

INSERT INTO eventos.Periodo (Descripcion)
SELECT v.d FROM (VALUES ('Primer Tiempo'), ('Segundo Tiempo'), ('Definicion por Penales')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Periodo AS t WHERE t.Descripcion = v.d);

INSERT INTO eventos.Tarjeta (Tipo)
SELECT v.d FROM (VALUES ('Amarilla'), ('Roja por doble amarilla'), ('Roja directa')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Tarjeta AS t WHERE t.Tipo = v.d);

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST EV4 Confederacion', 'TE4');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TE4');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST EV4 Pais 1', 'ZA', 'ZEA', 'Argentina Standard Time', @idConf),
       ('TEST EV4 Pais 2', 'ZB', 'ZEB', 'Argentina Standard Time', @idConf),
       ('TEST EV4 Pais 3', 'ZC', 'ZEC', 'Argentina Standard Time', @idConf);

DECLARE @idPais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'ZEA');
DECLARE @idPais2 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'ZEB');
DECLARE @idPais3 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'ZEC');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
VALUES ('ZEA', 101, 0, @idPais1, @idGrupo),
       ('ZEB', 102, 0, @idPais2, @idGrupo),
       ('ZEC', 103, 0, @idPais3, @idGrupo);

DECLARE @idSel1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'ZEA');
DECLARE @idSel2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'ZEB');
DECLARE @idSel3 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'ZEC');

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST EV4 Ciudad', 'Argentina Standard Time', @idPais1);
DECLARE @idCiudad SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST EV4 Ciudad');

DECLARE @idSede TINYINT;
EXEC nucleo.SP_ALTA_Sede
     @nombreEstadio = 'TEST EV4 Estadio',
     @idCiudad = @idCiudad,
     @capacidad = 60000,
     @idSede = @idSede OUTPUT;

INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion, IdClub)
VALUES ('Jugador', 'Uno',    'TEST_EV4_1', 'M', 'Delantero', NULL),
       ('Jugador', 'Dos',    'TEST_EV4_2', 'M', 'Defensor',  NULL),
       ('Jugador', 'Tres',   'TEST_EV4_3', 'M', 'Delantero', NULL),
       ('Jugador', 'Cuatro', 'TEST_EV4_4', 'M', 'Delantero', NULL),
       ('Jugador', 'Cinco',  'TEST_EV4_5', 'M', 'Delantero', NULL);

DECLARE @idJ1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV4_1');
DECLARE @idJ2 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV4_2');
DECLARE @idJ3 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV4_3');
DECLARE @idJ4 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV4_4');
DECLARE @idJ5 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV4_5');

INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
VALUES (@idSel1, @idJ1, 9), (@idSel1, @idJ2, 4), (@idSel2, @idJ3, 9), (@idSel3, @idJ4, 9);

DECLARE @idFase TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');
DECLARE @p241 SMALLINT, @p242 SMALLINT, @p243 SMALLINT, @p244 SMALLINT;

-- Las fechas son horas LOCALES de la sede (Argentina Standard Time, UTC-3 sin horario de verano);
-- el SP las convierte a UTC. El partido 244 se programa en 2030 para probar la validación de fecha.
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 241, @idFase = @idFase, @idSede = @idSede,
     @fechaHoraLocal = '2026-06-12 20:00', @idPartido = @p241 OUTPUT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 242, @idFase = @idFase, @idSede = @idSede,
     @fechaHoraLocal = '2026-06-16 20:00', @idPartido = @p242 OUTPUT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 243, @idFase = @idFase, @idSede = @idSede,
     @fechaHoraLocal = '2026-06-20 20:00', @idPartido = @p243 OUTPUT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 244, @idFase = @idFase, @idSede = @idSede,
     @fechaHoraLocal = '2030-06-12 20:00', @idPartido = @p244 OUTPUT;

-- Cruce de los partidos de Octavos: se asigna directo como preparación del escenario
-- (en el sistema real lo hace SP_DEFINIR_CRUCE_ELIMINATORIO).
UPDATE nucleo.Partido
SET IdSeleccionLocal     = @idSel1,
    IdSeleccionVisitante = @idSel2
WHERE IdPartido IN (@p241, @p242, @p243, @p244);

-- Tarjetas cargadas directo (el SP de amonestaciones no forma parte de este test):
--   J2: roja directa en el minuto 30 de 241 (2 partidos de suspensión).
--   J1: roja por doble amarilla en el minuto 60 de 241 (1 partido de suspensión).
INSERT INTO eventos.Amonestacion (IdPartido, IdTarjeta, IdJugador, IdStaffTecnico, Minuto, Motivo, PartidosSuspension)
VALUES (@p241, (SELECT IdTarjeta FROM eventos.Tarjeta WHERE Tipo = 'Roja directa'),            @idJ2, NULL, 30, 'TEST EV4 Roja directa', 2),
       (@p241, (SELECT IdTarjeta FROM eventos.Tarjeta WHERE Tipo = 'Roja por doble amarilla'), @idJ1, NULL, 60, 'TEST EV4 Doble amarilla', 1);

DECLARE @idGol INT;

-- =========================================================================
-- TEST: eventos.SP_REGISTRAR_GOL
-- =========================================================================
PRINT '--- SP_REGISTRAR_GOL ---';

-- G1 Gol válido con asistencia (J1 autor, J2 asiste).
-- Resultado esperado: OK, se registra el gol.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p241, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 10, @idJugadorAsistencia = @idJ2, @idGol = @idGol OUTPUT;
    PRINT 'G1: OK - gol registrado.';
END TRY
BEGIN CATCH
    PRINT 'G1: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- G2 Gol en contra con asistencia.
-- Resultado esperado: error (este tipo de gol no admite asistencia).
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p241, @idJugadorAutor = @idJ1, @tipoGol = 'En contra',
         @periodo = 'Segundo Tiempo', @minuto = 50, @idJugadorAsistencia = @idJ2;
    PRINT 'G2: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'G2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- G3 Autor de una selección que no juega el partido (J4 es de Sel3).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p241, @idJugadorAutor = @idJ4, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 12;
    PRINT 'G3: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'G3: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- G4 Autor sin convocatoria (J5).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p241, @idJugadorAutor = @idJ5, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 12;
    PRINT 'G4: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'G4: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- G5 Asistente de la otra selección (J3 es de Sel2, el autor J1 es de Sel1).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p241, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 14, @idJugadorAsistencia = @idJ3;
    PRINT 'G5: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'G5: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- G6 Gol de tipo Jugada en la definición por penales.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p241, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
         @periodo = 'Definicion por Penales', @minuto = 120;
    PRINT 'G6: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'G6: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- G7 Penal convertido en la tanda (Octavos es eliminación directa).
-- Resultado esperado: OK, se registra el gol.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p241, @idJugadorAutor = @idJ3, @tipoGol = 'Penal',
         @periodo = 'Definicion por Penales', @minuto = 120, @idGol = @idGol OUTPUT;
    PRINT 'G7: OK - penal de la tanda registrado.';
END TRY
BEGIN CATCH
    PRINT 'G7: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- G8 Minuto fuera de rango.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p241, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 0;
    PRINT 'G8: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'G8: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- G9 Partido inexistente.
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = -1, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 10;
    PRINT 'G9: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'G9: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- Expulsados y suspendidos
-- =========================================================================
PRINT '--- Expulsados y suspendidos ---';

-- G10 Gol de J2 en el minuto 40 (expulsado en el 30).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p241, @idJugadorAutor = @idJ2, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 40;
    PRINT 'G10: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'G10: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- G11 Gol de J2 en el minuto 20 (antes de ser expulsado).
-- Resultado esperado: OK, se registra el gol.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p241, @idJugadorAutor = @idJ2, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 20, @idGol = @idGol OUTPUT;
    PRINT 'G11: OK - gol anterior a la expulsión registrado.';
END TRY
BEGIN CATCH
    PRINT 'G11: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- G12 Gol de J1 en el minuto 61 (expulsado por doble amarilla en el 60).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p241, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
         @periodo = 'Segundo Tiempo', @minuto = 61;
    PRINT 'G12: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'G12: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- G13 Gol de J1 en el partido siguiente (242), cumpliendo 1 partido de suspensión.
-- Resultado esperado: error (suspendido).
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p242, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 10;
    PRINT 'G13: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'G13: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- Partido finalizado y partido futuro
-- =========================================================================
PRINT '--- Partido finalizado y futuro ---';

-- Se finaliza el partido 243 con 1 a 0. SP_ALTA_Partido solo crea partidos 'Programado' y ya no
-- existe un SP de resultado, por lo que el estado se deja como preparación del escenario
-- (cumple CK_Partido_Resultado: Finalizado exige ambas selecciones informadas).
UPDATE nucleo.Partido
SET Estado = 'Finalizado'
WHERE IdPartido = @p243;

-- G14 Gol en un partido finalizado.
-- Resultado esperado: error (partido finalizado).
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p243, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 10;
    PRINT 'G14: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'G14: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- G15 Gol en un partido que todavía no se jugó (244, año 2030).
-- Resultado esperado: error.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = @p244, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 10;
    PRINT 'G15: FALLÓ - se esperaba un error y no se produjo.';
END TRY
BEGIN CATCH
    PRINT 'G15: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
PRINT '--- CONTROLES ---';

-- Goles esperados: 3 (G1, G7 y G11).
SELECT 'Goles registrados (esperado: 3)' AS Control, COUNT(*) AS Cantidad
FROM eventos.Gol
WHERE IdPartido IN (@p241, @p242, @p243, @p244);

SELECT p.NumeroPartido, g.IdJugadorAutor, g.IdJugadorAsistencia, tg.Descripcion AS TipoGol,
       pe.Descripcion AS Periodo, g.Minuto
FROM eventos.Gol AS g
INNER JOIN eventos.TipoGol AS tg ON tg.IdTipoGol = g.IdTipoGol
INNER JOIN eventos.Periodo AS pe ON pe.IdPeriodo = g.IdPeriodo
INNER JOIN nucleo.Partido AS p ON p.IdPartido = g.IdPartido
WHERE g.IdPartido IN (@p241, @p242, @p243, @p244)
ORDER BY p.NumeroPartido, g.Minuto;

-- =========================================================================
-- FIN: se deshacen todos los cambios de la prueba.
-- =========================================================================
ROLLBACK TRANSACTION;
GO