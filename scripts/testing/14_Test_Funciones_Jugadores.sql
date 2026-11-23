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
Objetivo: Probar las funciones de 14_Funciones_Jugadores.sql:
          - jugadores.fn_EsquemaValido
          - jugadores.fn_JugadorEnCancha y jugadores.fn_JugadoresEnCancha
          - jugadores.fn_ValidarConvocatoria, jugadores.fn_ValidarFormacionJugador
            y jugadores.fn_ValidarSustitucion
          - Fecha local del partido (huso de la ciudad de la sede) al validar bajas de convocatoria.
          Requiere ejecutados los scripts 01 a 14.
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

INSERT INTO jugadores.ReglaConvocados (Minimo, Maximo) VALUES (2, 3);
INSERT INTO jugadores.ReglaCambios (MaxCambiosRegular, MaxVentanasRegular, MaxCambiosSuplementario, MaxVentanasSuplementario)
VALUES (2, 2, 1, 1);

INSERT INTO eventos.Tarjeta (Tipo)
SELECT v.d FROM (VALUES ('Amarilla'), ('Roja por doble amarilla'), ('Roja directa')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Tarjeta AS t WHERE t.Tipo = v.d);

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST FJ Confederacion', 'TFJ');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TFJ');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, HusoHorarioComercial)
VALUES ('TEST FJ Pais 1', 'FA', 'TFA', @idConf, 'Argentina Standard Time'),
       ('TEST FJ Pais 2', 'FB', 'TFB', @idConf, 'Argentina Standard Time');

DECLARE @idPais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TFA');
DECLARE @idPais2 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TFB');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
VALUES ('TFA', 101, @idPais1, @idGrupo),
       ('TFB', 102, @idPais2, @idGrupo);
DECLARE @idSel1 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais1);
DECLARE @idSel2 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais2);

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais) VALUES ('TEST FJ Ciudad', 'Argentina Standard Time', @idPais1);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST FJ Ciudad');

DECLARE @idSede INT, @idPartido INT;
INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad) VALUES ('TEST FJ Estadio', 50000, @idCiudad);
SET @idSede = SCOPE_IDENTITY();

DECLARE @idFase INT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (231, '2026-06-12 20:00', 'Programado', @idFase, @idSede, @idSel1, @idSel2);
SET @idPartido = SCOPE_IDENTITY();

INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion)
VALUES ('Titular',  'SaleMin45', 'TEST_FJ_1', 'M', 'Delantero'),
       ('Titular',  'ExpMin60',  'TEST_FJ_2', 'M', 'Defensor'),
       ('Suplente', 'EntraMin45','TEST_FJ_3', 'M', 'Delantero'),
       ('Extra',    'Cuarto',    'TEST_FJ_4', 'M', 'Arquero');

DECLARE @idJ1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_FJ_1');
DECLARE @idJ2 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_FJ_2');
DECLARE @idJ3 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_FJ_3');
DECLARE @idJ4 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_FJ_4');

INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal, FechaAlta)
VALUES (@idSel1, @idJ1, 9,  '2026-06-01'),
       (@idSel1, @idJ2, 4,  '2026-06-01'),
       (@idSel1, @idJ3, 19, '2026-06-01');

INSERT INTO jugadores.Formacion (IdPartido, Localia, EsquemaTactico)
VALUES (@idPartido, 'Local', '4-3-3');
DECLARE @idForm INT = (SELECT IdFormacion FROM jugadores.Formacion WHERE IdPartido = @idPartido AND Localia = 'Local');

INSERT INTO jugadores.FormacionJugador (IdFormacion, IdJugador, EstadoTitularidad, PosicionEnCampo, Dorsal)
VALUES (@idForm, @idJ1, 'Titular',  'Delantero', 9),
       (@idForm, @idJ2, 'Titular',  'Defensor',  4),
       (@idForm, @idJ3, 'Suplente', NULL,        19);

-- J3 reemplaza a J1 en el minuto 45
INSERT INTO jugadores.Sustitucion (IdPartido, IdJugadorSaliente, IdJugadorEntrante, Minuto, Periodo, Motivo)
VALUES (@idPartido, @idJ1, @idJ3, 45, 'Regular', 'Tactico');

-- J2 es expulsado con roja directa en el minuto 60
INSERT INTO eventos.Amonestacion (IdPartido, IdTarjeta, IdJugador, IdStaffTecnico, Minuto, Motivo, PartidosSuspension)
VALUES (@idPartido, (SELECT IdTarjeta FROM eventos.Tarjeta WHERE Tipo = 'Roja directa'), @idJ2, NULL, 60, 'TEST FJ Roja', 2);

-- =========================================================================
-- TEST 1: jugadores.fn_EsquemaValido
-- =========================================================================
-- Resultado esperado: '4-3-3' = 1, '4-2-3-1' = 1, '5-5-5' = 0 (suma 15), '433' = 0.
SELECT '1' AS Test,
       jugadores.fn_EsquemaValido('4-3-3')   AS [Esquema_4_3_3_Esperado_1],
       jugadores.fn_EsquemaValido('4-2-3-1') AS [Esquema_4_2_3_1_Esperado_1],
       jugadores.fn_EsquemaValido('5-5-5')   AS [Esquema_5_5_5_Esperado_0],
       jugadores.fn_EsquemaValido('433')     AS [Esquema_433_Esperado_0];

-- =========================================================================
-- TEST 2: jugadores.fn_JugadorEnCancha y jugadores.fn_JugadoresEnCancha
-- =========================================================================
-- 2.A Minuto 30: J1=1 (titular), J2=1 (titular), J3=0 (suplente aún no ingresó).
SELECT '2.A (Min 30)' AS Test,
       jugadores.fn_JugadorEnCancha(@idPartido, @idJ1, 30) AS J1_Esperado_1,
       jugadores.fn_JugadorEnCancha(@idPartido, @idJ2, 30) AS J2_Esperado_1,
       jugadores.fn_JugadorEnCancha(@idPartido, @idJ3, 30) AS J3_Esperado_0;

-- 2.B Minuto 50 (tras cambio del min 45): J1=0 (salió), J2=1 (sigue), J3=1 (entró).
SELECT '2.B (Min 50)' AS Test,
       jugadores.fn_JugadorEnCancha(@idPartido, @idJ1, 50) AS J1_Esperado_0,
       jugadores.fn_JugadorEnCancha(@idPartido, @idJ2, 50) AS J2_Esperado_1,
       jugadores.fn_JugadorEnCancha(@idPartido, @idJ3, 50) AS J3_Esperado_1;

-- 2.C Minuto 70 (tras expulsión de J2 en el min 60): J1=0, J2=0 (expulsado), J3=1.
SELECT '2.C (Min 70)' AS Test,
       jugadores.fn_JugadorEnCancha(@idPartido, @idJ1, 70) AS J1_Esperado_0,
       jugadores.fn_JugadorEnCancha(@idPartido, @idJ2, 70) AS J2_Esperado_0,
       jugadores.fn_JugadorEnCancha(@idPartido, @idJ3, 70) AS J3_Esperado_1;

-- 2.D fn_JugadoresEnCancha en el minuto 70: debe devolver solo a J3.
SELECT '2.D' AS Test, IdJugador, Apellido, Dorsal, CondicionInicial
FROM jugadores.fn_JugadoresEnCancha(@idPartido, 70);

-- =========================================================================
-- TEST 3: Funciones de validación (fn_ValidarConvocatoria, FormacionJugador, Sustitucion)
-- =========================================================================
-- 3.A fn_ValidarConvocatoria: J4 en Sel1 cuando ya hay 3 convocados activos (tope = 3) y dorsal 9 repetido.
-- Resultado esperado: texto no vacío con 2 errores (dorsal ocupado + máximo de convocados alcanzado).
SELECT '3.A' AS Test,
       REPLACE(jugadores.fn_ValidarConvocatoria(@idSel1, @idJ4, 9, '2026-06-01', NULL), CHAR(13) + CHAR(10), ' | ') AS Errores_Esperados;

-- 3.B fn_ValidarFormacionJugador: suplente con PosicionEnCampo informada y dorsal repetido.
SELECT '3.B' AS Test,
       REPLACE(jugadores.fn_ValidarFormacionJugador(@idForm, @idJ4, 'Suplente', 'Arquero', 9, 0), CHAR(13) + CHAR(10), ' | ') AS Errores_Esperados;

-- 3.C fn_ValidarSustitucion: intento de sacar a J2 en minuto 75 (ya expulsado en el 60).
SELECT '3.C' AS Test,
       REPLACE(jugadores.fn_ValidarSustitucion(@idPartido, @idJ2, @idJ3, 75, 'Regular', 'Tactico', 1, NULL), CHAR(13) + CHAR(10), ' | ') AS Errores_Esperados;

-- =========================================================================
-- TEST 4: fecha local del partido en fn_ValidarFormacionJugador (baja de convocatoria)
-- Partido 230: 2026-06-13 01:00 UTC = 2026-06-12 22:00 en la sede (Argentina, UTC-3).
-- La baja se compara contra la fecha LOCAL (12/06), no contra la fecha UTC (13/06).
-- =========================================================================
DECLARE @idPartidoNoche INT;
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (230, '2026-06-13 01:00', 'Programado', @idFase, @idSede, @idSel1, @idSel2);
SET @idPartidoNoche = SCOPE_IDENTITY();

INSERT INTO jugadores.Formacion (IdPartido, Localia, EsquemaTactico)
VALUES (@idPartidoNoche, 'Local', '4-3-3');
DECLARE @idFormNoche INT = (SELECT IdFormacion FROM jugadores.Formacion WHERE IdPartido = @idPartidoNoche AND Localia = 'Local');

-- J1 es dado de baja el 13/06 (día UTC del partido, pero un día después de la fecha local).
INSERT INTO jugadores.Baja (IdConvocatoria, FechaBaja, Motivo)
SELECT IdConvocatoria, '2026-06-13', 'TEST FJ Baja posterior a la fecha local'
FROM jugadores.Convocatoria WHERE IdJugador = @idJ1;

-- 4.A Baja el 13/06 y partido el 12/06 local.
-- Esperado: OK, el resultado NO incluye "dado de baja" (con la fecha UTC sí lo incluiría).
SELECT '4.A' AS Test,
       CASE WHEN jugadores.fn_ValidarFormacionJugador(@idFormNoche, @idJ1, 'Titular', 'Delantero', 9, 0) LIKE N'%dado de baja%'
            THEN 'FALLÓ' ELSE 'OK' END AS Resultado_Esperado_OK;

-- 4.B La baja pasa al 12/06 (misma fecha local del partido).
-- Esperado: OK, el resultado SÍ incluye "dado de baja de la convocatoria para la fecha del partido".
UPDATE b SET FechaBaja = '2026-06-12'
FROM jugadores.Baja AS b
INNER JOIN jugadores.Convocatoria AS c ON c.IdConvocatoria = b.IdConvocatoria
WHERE c.IdJugador = @idJ1;

SELECT '4.B' AS Test,
       CASE WHEN jugadores.fn_ValidarFormacionJugador(@idFormNoche, @idJ1, 'Titular', 'Delantero', 9, 0) LIKE N'%dado de baja%'
            THEN 'OK' ELSE 'FALLÓ' END AS Resultado_Esperado_OK;

ROLLBACK TRANSACTION;
GO