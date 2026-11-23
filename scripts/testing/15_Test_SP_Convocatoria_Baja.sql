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
Objetivo: Probar jugadores.SP_CONVOCAR_JUGADOR y jugadores.SP_REGISTRAR_BAJA_CONVOCATORIA
          (script 15_SP_Convocatoria_Baja.sql).
          Requiere ejecutados los scripts 01 a 15.
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- DATOS DE PRUEBA
-- Regla del test: mínimo 2, máximo 3 convocados activos por selección.
-- =========================================================================
DELETE FROM jugadores.ReglaConvocados;
INSERT INTO jugadores.ReglaConvocados (Minimo, Maximo) VALUES (2, 3);

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST CB Confederacion', 'TCB');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TCB');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST CB Pais 1', 'CA', 'TCA', 'Argentina Standard Time', @idConf),
       ('TEST CB Pais 2', 'CB', 'TCB', 'Argentina Standard Time', @idConf);

DECLARE @idPais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TCA');
DECLARE @idPais2 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TCB');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
VALUES ('TCA', 101, 0, @idPais1, @idGrupo),
       ('TCB', 102, 0, @idPais2, @idGrupo);

DECLARE @idSel1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TCA');
DECLARE @idSel2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TCB');

INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion)
VALUES ('Jugador', 'Uno',   'TEST_CB_1', 'M', 'Arquero'),
       ('Jugador', 'Dos',   'TEST_CB_2', 'M', 'Defensor'),
       ('Jugador', 'Tres',  'TEST_CB_3', 'M', 'Mediocampista'),
       ('Jugador', 'Cuatro','TEST_CB_4', 'M', 'Delantero'),
       ('Jugador', 'Cinco', 'TEST_CB_5', 'M', 'Delantero');

DECLARE @idJ1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_CB_1');
DECLARE @idJ2 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_CB_2');
DECLARE @idJ3 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_CB_3');
DECLARE @idJ4 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_CB_4');
DECLARE @idJ5 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_CB_5');

DECLARE @idConv1 INT, @idConv2 INT, @idConv3 INT, @idConv4 INT, @idBaja1 INT, @idConvReemp INT;

-- =========================================================================
-- TEST 1: jugadores.SP_CONVOCAR_JUGADOR
-- =========================================================================
PRINT '--- TEST 1: SP_CONVOCAR_JUGADOR ---';

-- C1 Convocatoria exitosa de 3 jugadores (alcanza el tope máximo de 3).
BEGIN TRY
    EXEC jugadores.SP_CONVOCAR_JUGADOR @idSeleccion = @idSel1, @idJugador = @idJ1, @dorsal = 1,  @fechaAlta = '2026-06-01', @idConvocatoria = @idConv1 OUTPUT;
    EXEC jugadores.SP_CONVOCAR_JUGADOR @idSeleccion = @idSel1, @idJugador = @idJ2, @dorsal = 4,  @fechaAlta = '2026-06-01', @idConvocatoria = @idConv2 OUTPUT;
    EXEC jugadores.SP_CONVOCAR_JUGADOR @idSeleccion = @idSel1, @idJugador = @idJ3, @dorsal = 8,  @fechaAlta = '2026-06-01', @idConvocatoria = @idConv3 OUTPUT;
    PRINT 'C1: OK - 3 jugadores convocados.';
END TRY
BEGIN CATCH
    PRINT 'C1: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- C2 Supera el máximo de convocados activos (intento de convocar a J4 cuando ya hay 3 activos).
BEGIN TRY
    EXEC jugadores.SP_CONVOCAR_JUGADOR @idSeleccion = @idSel1, @idJugador = @idJ4, @dorsal = 9, @fechaAlta = '2026-06-01';
    PRINT 'C2: FALLÓ - permitió superar el máximo de convocados.';
END TRY
BEGIN CATCH
    PRINT 'C2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- C3 Múltiples errores a la vez: jugador ya convocado (J1) y dorsal fuera de rango (105) en Sel2.
BEGIN TRY
    EXEC jugadores.SP_CONVOCAR_JUGADOR @idSeleccion = @idSel2, @idJugador = @idJ1, @dorsal = 105, @fechaAlta = '2026-06-01';
    PRINT 'C3: FALLÓ - permitió jugador ya convocado y dorsal inválido.';
END TRY
BEGIN CATCH
    PRINT 'C3: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 2: jugadores.SP_REGISTRAR_BAJA_CONVOCATORIA
-- =========================================================================
PRINT '--- TEST 2: SP_REGISTRAR_BAJA_CONVOCATORIA ---';

-- B1 Baja con reemplazo en la misma transacción: sale J3 por lesión y entra J4 con dorsal 19.
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_BAJA_CONVOCATORIA
         @idConvocatoria          = @idConv3,
         @motivo                  = 'Rotura fibrilar en entrenamiento',
         @fechaBaja               = '2026-06-05',
         @idJugadorReemplazante   = @idJ4,
         @dorsalReemplazante      = 19,
         @idBaja                  = @idBaja1 OUTPUT,
         @idConvocatoriaReemplazo = @idConvReemp OUTPUT;
    PRINT 'B1: OK - baja de J3 registrada y alta de reemplazante J4 completada.';
END TRY
BEGIN CATCH
    PRINT 'B1: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- B2 Intento de dar de baja nuevamente a J3 (@idConv3) y con motivo vacío.
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_BAJA_CONVOCATORIA @idConvocatoria = @idConv3, @motivo = '   ', @fechaBaja = '2026-06-06';
    PRINT 'B2: FALLÓ - permitió doble baja y motivo vacío.';
END TRY
BEGIN CATCH
    PRINT 'B2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- B3 Fecha de baja anterior a la fecha de alta ('2026-05-20' < '2026-06-01') y reemplazante sin dorsal.
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_BAJA_CONVOCATORIA
         @idConvocatoria        = @idConv2,
         @motivo                = 'Lesión previa',
         @fechaBaja             = '2026-05-20',
         @idJugadorReemplazante = @idJ5,
         @dorsalReemplazante    = NULL;
    PRINT 'B3: FALLÓ - permitió fecha de baja anterior al alta y reemplazo incompleto.';
END TRY
BEGIN CATCH
    PRINT 'B3: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- B4 Baja simple sin reemplazo (sale J2) y posterior convocatoria exitosa de J5 con SP_CONVOCAR_JUGADOR.
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_BAJA_CONVOCATORIA @idConvocatoria = @idConv2, @motivo = 'Cuadro febril', @fechaBaja = '2026-06-07';
    EXEC jugadores.SP_CONVOCAR_JUGADOR @idSeleccion = @idSel1, @idJugador = @idJ5, @dorsal = 11, @fechaAlta = '2026-06-07', @idConvocatoria = @idConv4 OUTPUT;
    PRINT 'B4: OK - baja sin reemplazo dejó cupo libre y permitió convocar a J5.';
END TRY
BEGIN CATCH
    PRINT 'B4: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
-- Convocados activos (sin baja) en Sel1: esperado 3 (J1, J4 y J5). Total histórico en tabla: 5 (con 2 bajas: J2 y J3).
SELECT 'Convocados activos en Sel1 (esperado: 3)' AS Control, COUNT(*) AS Cantidad
FROM jugadores.Convocatoria AS c
WHERE c.IdSeleccion = @idSel1
  AND NOT EXISTS (SELECT 1 FROM jugadores.Baja AS b WHERE b.IdConvocatoria = c.IdConvocatoria);

SELECT 'Bajas registradas en Sel1 (esperado: 2)' AS Control, COUNT(*) AS Cantidad
FROM jugadores.Baja AS b
INNER JOIN jugadores.Convocatoria AS c ON c.IdConvocatoria = b.IdConvocatoria
WHERE c.IdSeleccion = @idSel1;

ROLLBACK TRANSACTION;
GO