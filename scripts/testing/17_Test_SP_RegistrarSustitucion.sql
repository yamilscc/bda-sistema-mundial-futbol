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
Objetivo: Probar jugadores.SP_REGISTRAR_SUSTITUCION (script 17_SP_RegistrarSustitucion.sql):
          cambio obligatorio por lesión antes del minuto 20, múltiples cambios en una misma
          ventana, topes de cambios y de ventanas en tiempo regular y suplementario, y bloqueo
          de jugadores expulsados o fuera de cancha.
          Requiere ejecutados los scripts 01 a 17.
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- PREPARACIÓN DE ESCENARIO DE PRUEBA
-- Regla del test: máx 3 cambios en 2 ventanas (Regular) y 1 cambio en 1 ventana (Suplementario).
-- =========================================================================
DELETE FROM jugadores.Sustitucion;
DELETE FROM jugadores.ReglaCambios;
INSERT INTO jugadores.ReglaCambios (MaxCambiosRegular, MaxVentanasRegular, MaxCambiosSuplementario, MaxVentanasSuplementario)
VALUES (3, 2, 1, 1);

INSERT INTO eventos.Tarjeta (Tipo)
SELECT v.d FROM (VALUES ('Amarilla'), ('Roja por doble amarilla'), ('Roja directa')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Tarjeta AS t WHERE t.Tipo = v.d);

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST RS Confederacion', 'TRS');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TRS');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, ZonaHoraria)
VALUES ('TEST RS Pais 1', 'S1', 'TS8', @idConf, 'Argentina Standard Time'),
       ('TEST RS Pais 2', 'S2', 'TS9', @idConf, 'Argentina Standard Time');

DECLARE @idPais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS8');
DECLARE @idPais2 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS9');

INSERT INTO nucleo.Grupo (Nombre) VALUES ('TEST-RS');
DECLARE @idGrupo INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'TEST-RS');

INSERT INTO nucleo.Seleccion (IdPais, IdGrupo) VALUES (@idPais1, @idGrupo), (@idPais2, @idGrupo);
DECLARE @idSel1 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais1);
DECLARE @idSel2 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais2);

INSERT INTO nucleo.Ciudad (Nombre, IdPais) VALUES ('TEST RS Ciudad', @idPais1);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST RS Ciudad');

DECLARE @idSede INT, @pOctavos INT, @pGrupos INT;
EXEC nucleo.SP_ABM_Sede @operacion = 'ALTA', @idSede = @idSede OUTPUT, @nombreEstadio = 'TEST RS Estadio',
     @idCiudad = @idCiudad, @capacidad = 60000, @zonaHoraria = 'Argentina Standard Time';

DECLARE @idFaseOctavos INT = (SELECT IdFase FROM nucleo.Fase WHERE Descripcion = 'Octavos');
DECLARE @idFaseGrupos  INT = (SELECT IdFase FROM nucleo.Fase WHERE Descripcion = 'Grupos');

EXEC nucleo.SP_ABM_Partido 'ALTA', @pOctavos OUTPUT, 9730, @idFaseOctavos, @idSede, '2026-06-12 20:00', @idSel1, @idSel2;
EXEC nucleo.SP_ABM_Partido 'ALTA', @pGrupos  OUTPUT, 9731, @idFaseGrupos,  @idSede, '2026-06-16 20:00', @idSel1, @idSel2;

-- 4 titulares (T1..T4), 5 suplentes (S1..S5) de Sel1 y 1 jugador de Sel2 (R1)
INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion)
VALUES ('Jug', 'T1_Lesionado', 'TEST_RS_T1', 'M', 'Delantero'),
       ('Jug', 'T2_Titular',   'TEST_RS_T2', 'M', 'Mediocampista'),
       ('Jug', 'T3_Titular',   'TEST_RS_T3', 'M', 'Defensor'),
       ('Jug', 'T4_Expulsado', 'TEST_RS_T4', 'M', 'Defensor'),
       ('Jug', 'S1_Suplente',  'TEST_RS_S1', 'M', 'Delantero'),
       ('Jug', 'S2_Suplente',  'TEST_RS_S2', 'M', 'Mediocampista'),
       ('Jug', 'S3_Suplente',  'TEST_RS_S3', 'M', 'Defensor'),
       ('Jug', 'S4_Suplente',  'TEST_RS_S4', 'M', 'Delantero'),
       ('Jug', 'S5_Suplente',  'TEST_RS_S5', 'M', 'Mediocampista'),
       ('Jug', 'R1_Rival',     'TEST_RS_R1', 'M', 'Delantero');

DECLARE @idT1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RS_T1');
DECLARE @idT2 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RS_T2');
DECLARE @idT3 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RS_T3');
DECLARE @idT4 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RS_T4');
DECLARE @idS1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RS_S1');
DECLARE @idS2 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RS_S2');
DECLARE @idS3 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RS_S3');
DECLARE @idS4 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RS_S4');
DECLARE @idS5 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RS_S5');
DECLARE @idR1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RS_R1');

INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal, FechaAlta)
VALUES (@idSel1, @idT1, 9,  '2026-06-01'),
       (@idSel1, @idT2, 8,  '2026-06-01'),
       (@idSel1, @idT3, 4,  '2026-06-01'),
       (@idSel1, @idT4, 2,  '2026-06-01'),
       (@idSel1, @idS1, 19, '2026-06-01'),
       (@idSel1, @idS2, 18, '2026-06-01'),
       (@idSel1, @idS3, 14, '2026-06-01'),
       (@idSel1, @idS4, 20, '2026-06-01'),
       (@idSel1, @idS5, 21, '2026-06-01'),
       (@idSel2, @idR1, 9,  '2026-06-01');

DECLARE @idFormOct INT, @idFormGrp INT, @idSust INT;
EXEC jugadores.SP_REGISTRAR_FORMACION @idPartido = @pOctavos, @localia = 'Local', @esquemaTactico = '4-3-3', @idFormacion = @idFormOct OUTPUT;
EXEC jugadores.SP_REGISTRAR_FORMACION @idPartido = @pGrupos,  @localia = 'Local', @esquemaTactico = '4-3-3', @idFormacion = @idFormGrp OUTPUT;

INSERT INTO jugadores.FormacionJugador (IdFormacion, IdJugador, EstadoTitularidad, PosicionEnCampo, Dorsal)
VALUES (@idFormOct, @idT1, 'Titular',  'Delantero',     9),
       (@idFormOct, @idT2, 'Titular',  'Mediocampista', 8),
       (@idFormOct, @idT3, 'Titular',  'Defensor',      4),
       (@idFormOct, @idT4, 'Titular',  'Defensor',      2),
       (@idFormOct, @idS1, 'Suplente', NULL,            19),
       (@idFormOct, @idS2, 'Suplente', NULL,            18),
       (@idFormOct, @idS3, 'Suplente', NULL,            14),
       (@idFormOct, @idS4, 'Suplente', NULL,            20),
       (@idFormOct, @idS5, 'Suplente', NULL,            21),
       (@idFormGrp, @idT1, 'Titular',  'Delantero',     9),
       (@idFormGrp, @idS1, 'Suplente', NULL,            19);

-- T4 es expulsado en el minuto 30 de @pOctavos
INSERT INTO eventos.Amonestacion (IdPartido, IdTarjeta, IdJugador, IdStaffTecnico, Minuto, Motivo, PartidosSuspension)
VALUES (@pOctavos, (SELECT IdTarjeta FROM eventos.Tarjeta WHERE Tipo = 'Roja directa'), @idT4, NULL, 30, 'TEST RS Roja', 2);

-- =========================================================================
-- TEST: jugadores.SP_REGISTRAR_SUSTITUCION
-- =========================================================================
PRINT '--- SP_REGISTRAR_SUSTITUCION ---';

-- S1 Caso obligatorio de aceptación: cambio por lesión antes del minuto 20 (min 15, Ventana 1, Cambio 1).
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_SUSTITUCION @idPartido = @pOctavos, @idJugadorSaliente = @idT1,
         @idJugadorEntrante = @idS1, @minuto = 15, @periodo = 'Regular', @motivo = 'Lesion',
         @idSustitucion = @idSust OUTPUT;
    PRINT 'S1: OK - cambio por lesión antes del minuto 20 registrado (Ventana 1, Cambio 1).';
END TRY
BEGIN CATCH
    PRINT 'S1: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- S2 Rechazo: intento de sustituir a un jugador expulsado (T4 expulsado en min 30, intento en min 40).
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_SUSTITUCION @idPartido = @pOctavos, @idJugadorSaliente = @idT4,
         @idJugadorEntrante = @idS2, @minuto = 40, @periodo = 'Regular', @motivo = 'Tactico';
    PRINT 'S2: FALLÓ - permitió sustituir a un jugador expulsado.';
END TRY
BEGIN CATCH
    PRINT 'S2: OK (Bloqueado por expulsión) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- S3 Rechazo: intento de sacar a un suplente que todavía no entró (S2 por S3 en min 40).
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_SUSTITUCION @idPartido = @pOctavos, @idJugadorSaliente = @idS2,
         @idJugadorEntrante = @idS3, @minuto = 40, @periodo = 'Regular', @motivo = 'Tactico';
    PRINT 'S3: FALLÓ - permitió sacar a un suplente que no estaba en cancha.';
END TRY
BEGIN CATCH
    PRINT 'S3: OK (Bloqueado suplente fuera de cancha) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- S4 Cambio en Ventana 2 (min 60): sale T2 y entra S2 (Cambio 2, Ventana 2: agota las 2 ventanas regulares).
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_SUSTITUCION @idPartido = @pOctavos, @idJugadorSaliente = @idT2,
         @idJugadorEntrante = @idS2, @minuto = 60, @periodo = 'Regular', @motivo = 'Tactico',
         @idSustitucion = @idSust OUTPUT;
    PRINT 'S4: OK - segundo cambio en minuto 60 (Ventana 2, Cambio 2).';
END TRY
BEGIN CATCH
    PRINT 'S4: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- S5 Rechazo por superar el máximo de ventanas regulares (intento en min 75 = Ventana 3 > máx 2).
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_SUSTITUCION @idPartido = @pOctavos, @idJugadorSaliente = @idT3,
         @idJugadorEntrante = @idS3, @minuto = 75, @periodo = 'Regular', @motivo = 'Tactico';
    PRINT 'S5: FALLÓ - permitió abrir una 3ra ventana cuando el máximo era 2.';
END TRY
BEGIN CATCH
    PRINT 'S5: OK (Bloqueado por tope de ventanas) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- S6 Segundo cambio dentro de la MISMA Ventana 2 (min 60): sale S1 (que había entrado en min 15) y entra S3 (Cambio 3, Ventana 2).
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_SUSTITUCION @idPartido = @pOctavos, @idJugadorSaliente = @idS1,
         @idJugadorEntrante = @idS3, @minuto = 60, @periodo = 'Regular', @motivo = 'Precaucion',
         @idSustitucion = @idSust OUTPUT;
    PRINT 'S6: OK - cambio compartido en la ventana del min 60 (sale S1 que había ingresado en min 15).';
END TRY
BEGIN CATCH
    PRINT 'S6: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- S7 Rechazo por superar el máximo de cambios en tiempo regular (intento de 4to cambio en el mismo min 60).
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_SUSTITUCION @idPartido = @pOctavos, @idJugadorSaliente = @idT3,
         @idJugadorEntrante = @idS4, @minuto = 60, @periodo = 'Regular', @motivo = 'Tactico';
    PRINT 'S7: FALLÓ - permitió superar el máximo de 3 cambios regulares.';
END TRY
BEGIN CATCH
    PRINT 'S7: OK (Bloqueado por tope de cambios regulares) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- S8 Cambio exitoso en tiempo Suplementario de Octavos (min 100: sale T3 y entra S4).
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_SUSTITUCION @idPartido = @pOctavos, @idJugadorSaliente = @idT3,
         @idJugadorEntrante = @idS4, @minuto = 100, @periodo = 'Suplementario', @motivo = 'Tactico',
         @idSustitucion = @idSust OUTPUT;
    PRINT 'S8: OK - cambio en tiempo suplementario registrado.';
END TRY
BEGIN CATCH
    PRINT 'S8: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- S9 Rechazo de cambio Suplementario en un partido de Fase de Grupos (@pGrupos).
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_SUSTITUCION @idPartido = @pGrupos, @idJugadorSaliente = @idT1,
         @idJugadorEntrante = @idS1, @minuto = 95, @periodo = 'Suplementario', @motivo = 'Tactico';
    PRINT 'S9: FALLÓ - permitió tiempo suplementario en fase de grupos.';
END TRY
BEGIN CATCH
    PRINT 'S9: OK (Bloqueado suplementario en grupos) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
-- Sustituciones esperadas en @pOctavos: 4 (S1, S4, S6 en Regular y S8 en Suplementario).
SELECT 'Sustituciones registradas en 9730 (esperado: 4)' AS Control, COUNT(*) AS Cantidad
FROM jugadores.Sustitucion WHERE IdPartido = @pOctavos;

ROLLBACK TRANSACTION;
GO