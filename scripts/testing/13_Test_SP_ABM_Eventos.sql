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
Objetivo: Probar los 6 stored procedures ABM del módulo de eventos (script 13_SP_ABM_Eventos.sql):
          - eventos.SP_ABM_ReglaSuspension
          - eventos.SP_ABM_TipoGol
          - eventos.SP_ABM_Periodo
          - eventos.SP_ABM_Tarjeta
          - eventos.SP_ABM_Gol
          - eventos.SP_ABM_Amonestacion
          Requiere ejecutados los scripts 01 a 13 (usa nucleo.SP_ALTA_Sede y
          nucleo.SP_ALTA_Partido).
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- PREPARACIÓN DE ESCENARIO DE PRUEBA
-- =========================================================================
DELETE FROM eventos.Amonestacion;
DELETE FROM eventos.Gol;
DELETE FROM eventos.ReglaSuspension;
DELETE FROM eventos.Tarjeta;
DELETE FROM eventos.Periodo;
DELETE FROM eventos.TipoGol;

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST EV6 Confederacion', 'TE6');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TE6');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST EV6 Pais 1', 'VA', 'VEA', 'Argentina Standard Time', @idConf),
       ('TEST EV6 Pais 2', 'VB', 'VEB', 'Argentina Standard Time', @idConf);

DECLARE @idPais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'VEA');
DECLARE @idPais2 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'VEB');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
VALUES ('VEA', 101, 0, @idPais1, @idGrupo),
       ('VEB', 102, 0, @idPais2, @idGrupo);

DECLARE @idSel1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'VEA');
DECLARE @idSel2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'VEB');

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST EV6 Ciudad', 'Argentina Standard Time', @idPais1);
DECLARE @idCiudad SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST EV6 Ciudad');

DECLARE @idSede TINYINT;
EXEC nucleo.SP_ALTA_Sede
     @nombreEstadio = 'TEST EV6 Estadio',
     @idCiudad      = @idCiudad,
     @capacidad     = 60000,
     @idSede        = @idSede OUTPUT;

INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion, IdClub)
VALUES ('Jugador', 'Uno', 'TEST_EV6_1', 'M', 'Delantero', NULL),
       ('Jugador', 'Dos', 'TEST_EV6_2', 'M', 'Mediocampista', NULL),
       ('Jugador', 'Tres', 'TEST_EV6_3', 'M', 'Defensor', NULL);

DECLARE @idJ1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV6_1');
DECLARE @idJ2 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV6_2');
DECLARE @idJ3 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_EV6_3');

INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
VALUES (@idSel1, @idJ1, 9), (@idSel1, @idJ2, 10), (@idSel2, @idJ3, 4);

DECLARE @idFase TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');
DECLARE @p251 SMALLINT, @p252 SMALLINT;

-- En fases eliminatorias SP_ALTA_Partido exige las selecciones en NULL.
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 251, @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = '2026-06-12 20:00', @idPartido = @p251 OUTPUT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 252, @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = '2026-06-16 20:00', @idPartido = @p252 OUTPUT;

-- Se asignan las selecciones al cruce eliminatorio para poder probar los eventos:
UPDATE nucleo.Partido
SET IdSeleccionLocal = @idSel1, IdSeleccionVisitante = @idSel2
WHERE IdPartido IN (@p251, @p252);

-- =========================================================================
-- TEST 1: eventos.SP_ABM_ReglaSuspension
-- =========================================================================
PRINT '--- TEST 1: SP_ABM_ReglaSuspension ---';

DECLARE @idReglaAcum INT, @idReglaDoble INT, @idReglaRoja INT;

-- 1.A ALTA exitosa de las 3 reglas.
BEGIN TRY
    EXEC eventos.SP_ABM_ReglaSuspension 'ALTA', @idReglaAcum OUTPUT, 'Acumulacion Amarillas', 2, 1;
    EXEC eventos.SP_ABM_ReglaSuspension 'ALTA', @idReglaDoble OUTPUT, 'Doble Amarilla', NULL, 1;
    EXEC eventos.SP_ABM_ReglaSuspension 'ALTA', @idReglaRoja OUTPUT, 'Roja Directa', NULL, 3;
    PRINT '1.A: OK - 3 reglas de suspensión dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '1.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.B MODIFICACION exitosa (Roja Directa pasa de 3 a 2 partidos).
BEGIN TRY
    EXEC eventos.SP_ABM_ReglaSuspension 'MODIFICACION', @idReglaRoja, 'Roja Directa', NULL, 2;
    PRINT '1.B: OK - regla Roja Directa modificada a 2 partidos.';
END TRY
BEGIN CATCH
    PRINT '1.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.C ALTA fallida con múltiples errores (criterio duplicado, cantidadAmarillas en Roja Directa y partidos <= 0).
BEGIN TRY
    EXEC eventos.SP_ABM_ReglaSuspension 'ALTA', NULL, 'Roja Directa', 2, 0;
    PRINT '1.C: FALLÓ - permitió alta inválida.';
END TRY
BEGIN CATCH
    PRINT '1.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 1.D BAJA exitosa y posterior re-alta para el resto del test.
BEGIN TRY
    EXEC eventos.SP_ABM_ReglaSuspension 'BAJA', @idReglaRoja;
    EXEC eventos.SP_ABM_ReglaSuspension 'ALTA', @idReglaRoja OUTPUT, 'Roja Directa', NULL, 2;
    PRINT '1.D: OK - baja y re-alta de regla Roja Directa.';
END TRY
BEGIN CATCH
    PRINT '1.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: eventos.SP_ABM_TipoGol
-- =========================================================================
PRINT '--- TEST 2: SP_ABM_TipoGol ---';

DECLARE @idTGJugada INT, @idTGPenal INT, @idTGContra INT, @idTGTemp INT;

-- 2.A ALTA exitosa.
BEGIN TRY
    EXEC eventos.SP_ABM_TipoGol 'ALTA', @idTGJugada OUTPUT, 'Jugada';
    EXEC eventos.SP_ABM_TipoGol 'ALTA', @idTGPenal  OUTPUT, 'Penal';
    EXEC eventos.SP_ABM_TipoGol 'ALTA', @idTGContra OUTPUT, 'En contra';
    EXEC eventos.SP_ABM_TipoGol 'ALTA', @idTGTemp   OUTPUT, 'Cabezazo';
    PRINT '2.A: OK - tipos de gol creados.';
END TRY
BEGIN CATCH
    PRINT '2.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.B MODIFICACION y BAJA exitosas sobre tipo sin goles asociados.
BEGIN TRY
    EXEC eventos.SP_ABM_TipoGol 'MODIFICACION', @idTGTemp, 'Tiro Libre';
    EXEC eventos.SP_ABM_TipoGol 'BAJA', @idTGTemp;
    PRINT '2.B: OK - modificación y baja de TipoGol sin goles asociados.';
END TRY
BEGIN CATCH
    PRINT '2.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.C ALTA fallida (descripción no permitida y duplicada).
BEGIN TRY
    EXEC eventos.SP_ABM_TipoGol 'ALTA', NULL, 'Chilena';
    PRINT '2.C: FALLÓ - permitió descripción inválida.';
END TRY
BEGIN CATCH
    PRINT '2.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 3: eventos.SP_ABM_Periodo
-- =========================================================================
PRINT '--- TEST 3: SP_ABM_Periodo ---';

DECLARE @idPePT INT, @idPeST INT, @idPeTanda INT, @idPeTemp INT;

-- 3.A ALTA, MODIFICACION y BAJA exitosas.
BEGIN TRY
    EXEC eventos.SP_ABM_Periodo 'ALTA', @idPePT    OUTPUT, 'Primer Tiempo';
    EXEC eventos.SP_ABM_Periodo 'ALTA', @idPeST    OUTPUT, 'Segundo Tiempo';
    EXEC eventos.SP_ABM_Periodo 'ALTA', @idPeTanda OUTPUT, 'Definicion por Penales';
    EXEC eventos.SP_ABM_Periodo 'ALTA', @idPeTemp  OUTPUT, 'Alargue PT';
    EXEC eventos.SP_ABM_Periodo 'MODIFICACION', @idPeTemp, 'Alargue ST';
    EXEC eventos.SP_ABM_Periodo 'BAJA', @idPeTemp;
    PRINT '3.A: OK - alta, modificación y baja de Período.';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.B MODIFICACION fallida (ID inexistente y descripción inválida).
BEGIN TRY
    EXEC eventos.SP_ABM_Periodo 'MODIFICACION', -1, 'Entretiempo';
    PRINT '3.B: FALLÓ - permitió modificar período inexistente.';
END TRY
BEGIN CATCH
    PRINT '3.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 4: eventos.SP_ABM_Tarjeta
-- =========================================================================
PRINT '--- TEST 4: SP_ABM_Tarjeta ---';

DECLARE @idTarAmar INT, @idTarDoble INT, @idTarRoja INT;

-- 4.A ALTA, MODIFICACION, BAJA y re-alta de las 3 tarjetas del catálogo.
BEGIN TRY
    EXEC eventos.SP_ABM_Tarjeta 'ALTA', @idTarAmar  OUTPUT, 'Amarilla';
    EXEC eventos.SP_ABM_Tarjeta 'ALTA', @idTarDoble OUTPUT, 'Roja por doble amarilla';
    EXEC eventos.SP_ABM_Tarjeta 'ALTA', @idTarRoja  OUTPUT, 'Roja directa';
    EXEC eventos.SP_ABM_Tarjeta 'BAJA', @idTarRoja;
    EXEC eventos.SP_ABM_Tarjeta 'ALTA', @idTarRoja  OUTPUT, 'Roja directa';
    PRINT '4.A: OK - alta y baja de Tarjeta.';
END TRY
BEGIN CATCH
    PRINT '4.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 4.B ALTA fallida (tipo duplicado).
BEGIN TRY
    EXEC eventos.SP_ABM_Tarjeta 'ALTA', NULL, 'Amarilla';
    PRINT '4.B: FALLÓ - permitió tarjeta duplicada.';
END TRY
BEGIN CATCH
    PRINT '4.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 5: eventos.SP_ABM_Gol
-- =========================================================================
PRINT '--- TEST 5: SP_ABM_Gol ---';

DECLARE @idGol1 INT, @idGol2 INT;

-- 5.A ALTA exitosa (delega en SP_REGISTRAR_GOL).
BEGIN TRY
    EXEC eventos.SP_ABM_Gol @operacion = 'ALTA', @idGol = @idGol1 OUTPUT,
         @idPartido = @p251, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 15, @idJugadorAsistencia = NULL;
    EXEC eventos.SP_ABM_Gol @operacion = 'ALTA', @idGol = @idGol2 OUTPUT,
         @idPartido = @p251, @idJugadorAutor = @idJ3, @tipoGol = 'Jugada',
         @periodo = 'Segundo Tiempo', @minuto = 55, @idJugadorAsistencia = NULL;
    PRINT '5.A: OK - 2 goles registrados vía SP_ABM_Gol.';
END TRY
BEGIN CATCH
    PRINT '5.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 5.B BAJA de TipoGol bloqueada por tener goles asociados.
BEGIN TRY
    EXEC eventos.SP_ABM_TipoGol 'BAJA', @idTGJugada;
    PRINT '5.B: FALLÓ - permitió borrar un TipoGol en uso.';
END TRY
BEGIN CATCH
    PRINT '5.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 5.C MODIFICACION exitosa (cambia minuto a 20 y agrega asistencia de J2).
BEGIN TRY
    EXEC eventos.SP_ABM_Gol @operacion = 'MODIFICACION', @idGol = @idGol1,
         @idPartido = @p251, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 20, @idJugadorAsistencia = @idJ2;
    PRINT '5.C: OK - gol modificado con asistencia y nuevo minuto.';
END TRY
BEGIN CATCH
    PRINT '5.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 5.D MODIFICACION fallida (auto-asistencia y minuto inválido).
BEGIN TRY
    EXEC eventos.SP_ABM_Gol @operacion = 'MODIFICACION', @idGol = @idGol1,
         @idPartido = @p251, @idJugadorAutor = @idJ1, @tipoGol = 'Jugada',
         @periodo = 'Primer Tiempo', @minuto = 200, @idJugadorAsistencia = @idJ1;
    PRINT '5.D: FALLÓ - permitió modificación inválida de gol.';
END TRY
BEGIN CATCH
    PRINT '5.D: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 5.E BAJA exitosa del segundo gol.
BEGIN TRY
    EXEC eventos.SP_ABM_Gol @operacion = 'BAJA', @idGol = @idGol2;
    PRINT '5.E: OK - gol eliminado correctamente.';
END TRY
BEGIN CATCH
    PRINT '5.E: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 6: eventos.SP_ABM_Amonestacion
-- =========================================================================
PRINT '--- TEST 6: SP_ABM_Amonestacion ---';

DECLARE @idAmon1 INT, @idAmon2 INT, @idAmon3 INT;

-- 6.A ALTA exitosa de 1ra y 2da amarilla a J1 en 251, y amarilla a J3 en 251.
BEGIN TRY
    EXEC eventos.SP_ABM_Amonestacion @operacion = 'ALTA', @idAmonestacion = @idAmon1 OUTPUT,
         @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 25, @motivo = 'Falta táctica', @idJugador = @idJ1;
    EXEC eventos.SP_ABM_Amonestacion @operacion = 'ALTA', @idAmonestacion = @idAmon2 OUTPUT,
         @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 70, @motivo = 'Reiteración', @idJugador = @idJ1;
    EXEC eventos.SP_ABM_Amonestacion @operacion = 'ALTA', @idAmonestacion = @idAmon3 OUTPUT,
         @idPartido = @p251, @tipoTarjeta = 'Amarilla', @minuto = 40, @motivo = 'Demorar juego', @idJugador = @idJ3;
    PRINT '6.A: OK - 3 amonestaciones dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '6.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 6.B BAJA bloqueada: intento de borrar la 1ra amarilla (@idAmon1) existiendo roja por doble amarilla (@idAmon2).
BEGIN TRY
    EXEC eventos.SP_ABM_Amonestacion @operacion = 'BAJA', @idAmonestacion = @idAmon1;
    PRINT '6.B: FALLÓ - permitió eliminar la 1ra amarilla dejando huérfana la doble amarilla.';
END TRY
BEGIN CATCH
    PRINT '6.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 6.C MODIFICACION exitosa: la amarilla de J3 (@idAmon3) pasa a 'Roja directa' (PartidosSuspension debe pasar a 2).
BEGIN TRY
    EXEC eventos.SP_ABM_Amonestacion @operacion = 'MODIFICACION', @idAmonestacion = @idAmon3,
         @idPartido = @p251, @tipoTarjeta = 'Roja directa', @minuto = 42,
         @motivo = 'Plancha revisada en VAR', @idJugador = @idJ3;
    PRINT '6.C: OK - amonestación de J3 modificada a Roja directa.';
END TRY
BEGIN CATCH
    PRINT '6.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 6.D BAJA exitosa de la 2da amarilla (@idAmon2) y luego de la 1ra (@idAmon1).
BEGIN TRY
    EXEC eventos.SP_ABM_Amonestacion @operacion = 'BAJA', @idAmonestacion = @idAmon2;
    EXEC eventos.SP_ABM_Amonestacion @operacion = 'BAJA', @idAmonestacion = @idAmon1;
    PRINT '6.D: OK - baja en orden correcto de doble amarilla y primera amarilla.';
END TRY
BEGIN CATCH
    PRINT '6.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 6.E Bloqueo de BAJA de Gol y Amonestación cuando el partido pasa a 'Finalizado'.
UPDATE nucleo.Partido
SET Estado         = 'Finalizado',
    GolesLocal     = 1,
    GolesVisitante = 0
WHERE IdPartido = @p251;

BEGIN TRY
    EXEC eventos.SP_ABM_Gol @operacion = 'BAJA', @idGol = @idGol1;
    PRINT '6.E.1: FALLÓ - permitió borrar gol de un partido finalizado.';
END TRY
BEGIN CATCH
    PRINT '6.E.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC eventos.SP_ABM_Amonestacion @operacion = 'BAJA', @idAmonestacion = @idAmon3;
    PRINT '6.E.2: FALLÓ - permitió borrar amonestación de un partido finalizado.';
END TRY
BEGIN CATCH
    PRINT '6.E.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
SELECT 'Goles en 251 (esperado: 1)' AS Control, COUNT(*) AS Cantidad
FROM eventos.Gol WHERE IdPartido = @p251;

SELECT 'Amonestaciones en 251 (esperado: 1, Roja directa con 2 partidos)' AS Control,
       t.Tipo, a.Minuto, a.Motivo, a.PartidosSuspension
FROM eventos.Amonestacion AS a
INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
WHERE a.IdPartido = @p251;

ROLLBACK TRANSACTION;
GO
