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
Objetivo: Probar jugadores.SP_REGISTRAR_FORMACION y jugadores.SP_AGREGAR_JUGADOR_FORMACION
          (script 16_SP_RegistrarFormacion.sql), incluyendo el rechazo de jugadores
          suspendidos (eventos.fn_EstaSuspendido), dados de baja, de otra selección,
          tope de 11 titulares y obligatoriedad de 1 arquero.
          Requiere ejecutados los scripts 01 a 16 (usa nucleo.SP_ALTA_Sede y
          nucleo.SP_ALTA_Partido).
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- PREPARACIÓN DE ESCENARIO DE PRUEBA
-- =========================================================================
INSERT INTO eventos.Tarjeta (Tipo)
SELECT v.d FROM (VALUES ('Amarilla'), ('Roja por doble amarilla'), ('Roja directa')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Tarjeta AS t WHERE t.Tipo = v.d);

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST RF Confederacion', 'TRF');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TRF');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST RF Pais 1', 'RA', 'TRA', 'Argentina Standard Time', @idConf),
       ('TEST RF Pais 2', 'RB', 'TRB', 'Argentina Standard Time', @idConf);

DECLARE @idPais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TRA');
DECLARE @idPais2 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TRB');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
VALUES ('TRA', 101, 0, @idPais1, @idGrupo),
       ('TRB', 102, 0, @idPais2, @idGrupo);

DECLARE @idSel1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TRA');
DECLARE @idSel2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TRB');

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST RF Ciudad', 'Argentina Standard Time', @idPais1);
DECLARE @idCiudad SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST RF Ciudad');

DECLARE @idSede TINYINT;
DECLARE @pPrevio SMALLINT, @pActual SMALLINT;
EXEC nucleo.SP_ALTA_Sede
     @nombreEstadio = 'TEST RF Estadio',
     @idCiudad      = @idCiudad,
     @capacidad     = 60000,
     @idSede        = @idSede OUTPUT;

DECLARE @idFase TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');

-- En fases eliminatorias SP_ALTA_Partido exige las selecciones en NULL.
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 253, @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = '2026-06-12 20:00', @idPartido = @pPrevio OUTPUT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 254, @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = '2026-06-16 20:00', @idPartido = @pActual OUTPUT;

-- Se asignan las selecciones al cruce eliminatorio para poder probar la formación:
UPDATE nucleo.Partido
SET IdSeleccionLocal = @idSel1, IdSeleccionVisitante = @idSel2
WHERE IdPartido IN (@pPrevio, @pActual);

-- Se crean 15 jugadores para Sel1 (1 al 12 válidos, 13 suspendido, 14 dado de baja, 15 de Sel2).
INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion)
VALUES ('Jug', 'Tit1_Arq',   'TEST_RF_01', 'M', 'Arquero'),
       ('Jug', 'Tit2_Def',   'TEST_RF_02', 'M', 'Defensor'),
       ('Jug', 'Tit3_Def',   'TEST_RF_03', 'M', 'Defensor'),
       ('Jug', 'Tit4_Def',   'TEST_RF_04', 'M', 'Defensor'),
       ('Jug', 'Tit5_Def',   'TEST_RF_05', 'M', 'Defensor'),
       ('Jug', 'Tit6_Med',   'TEST_RF_06', 'M', 'Mediocampista'),
       ('Jug', 'Tit7_Med',   'TEST_RF_07', 'M', 'Mediocampista'),
       ('Jug', 'Tit8_Med',   'TEST_RF_08', 'M', 'Mediocampista'),
       ('Jug', 'Tit9_Del',   'TEST_RF_09', 'M', 'Delantero'),
       ('Jug', 'Tit10_Del',  'TEST_RF_10', 'M', 'Delantero'),
       ('Jug', 'Tit11_Del',  'TEST_RF_11', 'M', 'Delantero'),
       ('Jug', 'Sup12_Arq',  'TEST_RF_12', 'M', 'Arquero'),
       ('Jug', 'Suspendido', 'TEST_RF_13', 'M', 'Defensor'),
       ('Jug', 'DadoDeBaja', 'TEST_RF_14', 'M', 'Mediocampista'),
       ('Jug', 'RivalSel2',  'TEST_RF_15', 'M', 'Delantero');

INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal, FechaAlta)
SELECT CASE WHEN Documento = 'TEST_RF_15' THEN @idSel2 ELSE @idSel1 END,
       IdJugador,
       CAST(RIGHT(Documento, 2) AS INT),
       '2026-06-01'
FROM jugadores.Jugador
WHERE Documento LIKE 'TEST_RF_%';

DECLARE @idJugSusp INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RF_13');
DECLARE @idJugBaja INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RF_14');
DECLARE @idJugRiv  INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RF_15');
DECLARE @idJug12   INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_RF_12');

-- TEST_RF_13 recibe suspensión de 1 partido en el encuentro previo (@pPrevio).
INSERT INTO eventos.Amonestacion (IdPartido, IdTarjeta, IdJugador, IdStaffTecnico, Minuto, Motivo, PartidosSuspension)
VALUES (@pPrevio, (SELECT IdTarjeta FROM eventos.Tarjeta WHERE Tipo = 'Amarilla'), @idJugSusp, NULL, 50, 'Acumulación', 1);

-- TEST_RF_14 es dado de baja antes del partido @pActual.
INSERT INTO jugadores.Baja (IdConvocatoria, FechaBaja, Motivo)
SELECT IdConvocatoria, '2026-06-10', 'Lesión ligamentaria'
FROM jugadores.Convocatoria WHERE IdJugador = @idJugBaja;

DECLARE @idFormLocal INT;

-- =========================================================================
-- TEST 1: jugadores.SP_REGISTRAR_FORMACION
-- =========================================================================
PRINT '--- TEST 1: SP_REGISTRAR_FORMACION ---';

-- F1 Alta exitosa de formación Local con esquema 4-3-3.
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_FORMACION @idPartido = @pActual, @localia = 'Local',
         @esquemaTactico = '4-3-3', @idFormacion = @idFormLocal OUTPUT;
    PRINT 'F1: OK - formación Local registrada.';
END TRY
BEGIN CATCH
    PRINT 'F1: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- F2 Rechazo por localía duplicada y esquema táctico que no suma 10 ('5-4-2' suma 11).
BEGIN TRY
    EXEC jugadores.SP_REGISTRAR_FORMACION @idPartido = @pActual, @localia = 'Local', @esquemaTactico = '5-4-2';
    PRINT 'F2: FALLÓ - permitió localía duplicada y esquema inválido.';
END TRY
BEGIN CATCH
    PRINT 'F2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 2: jugadores.SP_AGREGAR_JUGADOR_FORMACION
-- =========================================================================
PRINT '--- TEST 2: SP_AGREGAR_JUGADOR_FORMACION ---';

-- F3 Caso obligatorio: intento de incluir en la formación al jugador suspendido (@idJugSusp).
BEGIN TRY
    EXEC jugadores.SP_AGREGAR_JUGADOR_FORMACION @idFormacion = @idFormLocal, @idJugador = @idJugSusp,
         @estadoTitularidad = 'Titular', @posicionEnCampo = 'Defensor';
    PRINT 'F3: FALLÓ - permitió incluir un jugador suspendido.';
END TRY
BEGIN CATCH
    PRINT 'F3: OK (Bloqueado por suspensión) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- F4 Intento de incluir al jugador dado de baja (@idJugBaja).
BEGIN TRY
    EXEC jugadores.SP_AGREGAR_JUGADOR_FORMACION @idFormacion = @idFormLocal, @idJugador = @idJugBaja,
         @estadoTitularidad = 'Suplente';
    PRINT 'F4: FALLÓ - permitió incluir un jugador dado de baja.';
END TRY
BEGIN CATCH
    PRINT 'F4: OK (Bloqueado por baja) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- F5 Intento de incluir un jugador de la otra selección (@idJugRiv).
BEGIN TRY
    EXEC jugadores.SP_AGREGAR_JUGADOR_FORMACION @idFormacion = @idFormLocal, @idJugador = @idJugRiv,
         @estadoTitularidad = 'Suplente';
    PRINT 'F5: FALLÓ - permitió incluir un jugador de otra selección.';
END TRY
BEGIN CATCH
    PRINT 'F5: OK (Bloqueado por selección) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- F6 Carga exitosa de los 11 titulares (1 Arquero + 10 jugadores de campo) y 1 suplente.
BEGIN TRY
    DECLARE @doc CHAR(10), @idJ INT, @pos VARCHAR(20), @i INT = 1;
    WHILE @i <= 11
    BEGIN
        SET @doc = 'TEST_RF_' + RIGHT('0' + CAST(@i AS VARCHAR(2)), 2);
        SELECT @idJ = IdJugador, @pos = Posicion FROM jugadores.Jugador WHERE Documento = @doc;
        EXEC jugadores.SP_AGREGAR_JUGADOR_FORMACION @idFormacion = @idFormLocal, @idJugador = @idJ,
             @estadoTitularidad = 'Titular', @posicionEnCampo = @pos;
        SET @i += 1;
    END;

    -- Se agrega el jugador 12 como Suplente (con PosicionEnCampo NULL).
    EXEC jugadores.SP_AGREGAR_JUGADOR_FORMACION @idFormacion = @idFormLocal, @idJugador = @idJug12,
         @estadoTitularidad = 'Suplente', @posicionEnCampo = NULL;
    PRINT 'F6: OK - 11 titulares y 1 suplente agregados correctamente.';
END TRY
BEGIN CATCH
    PRINT 'F6: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- F7 Intento de agregar un 12do titular y además segundo arquero titular.
BEGIN TRY
    INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion)
    VALUES ('Jug', 'Extra', 'TEST_RF_16', 'M', 'Arquero');
    DECLARE @idJug16 INT = SCOPE_IDENTITY();
    INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal, FechaAlta)
    VALUES (@idSel1, @idJug16, 16, '2026-06-01');

    EXEC jugadores.SP_AGREGAR_JUGADOR_FORMACION @idFormacion = @idFormLocal, @idJugador = @idJug16,
         @estadoTitularidad = 'Titular', @posicionEnCampo = 'Arquero';
    PRINT 'F7: FALLÓ - permitió superar los 11 titulares y repetir arquero.';
END TRY
BEGIN CATCH
    PRINT 'F7: OK (Bloqueado 12do titular + 2do arquero) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
SELECT EstadoTitularidad, COUNT(*) AS Cantidad
FROM jugadores.FormacionJugador
WHERE IdFormacion = @idFormLocal
GROUP BY EstadoTitularidad;

ROLLBACK TRANSACTION;
GO
