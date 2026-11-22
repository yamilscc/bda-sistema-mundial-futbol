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
Objetivo: Probar las restricciones DDL (CHECK, UNIQUE, PK y FK) de las tablas del módulo
          de jugadores creadas en 02_Tablas_Jugadores_y_Alineaciones.sql:
          ReglaConvocados, ReglaCambios, Club, Jugador, Convocatoria, Baja,
          Formacion, FormacionJugador y Sustitucion.
          Requiere ejecutados los scripts 01 y 02.
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- PREPARACIÓN DE ESCENARIO MÍNIMO
-- =========================================================================
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST JUG Confederacion', 'TJC');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TJC');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, HusoHorarioComercial)
VALUES ('TEST JUG Pais 1', 'JA', 'TJA', @idConf, 'Argentina Standard Time'),
       ('TEST JUG Pais 2', 'JB', 'TJB', @idConf, 'Argentina Standard Time');

DECLARE @idPais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TJA');
DECLARE @idPais2 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TJB');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
VALUES ('TJA', 101, @idPais1, @idGrupo),
       ('TJB', 102, @idPais2, @idGrupo);
DECLARE @idSel1 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais1);
DECLARE @idSel2 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais2);

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST JUG Ciudad', 'Argentina Standard Time', @idPais1);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST JUG Ciudad');

DECLARE @idSede INT, @idPartido INT;
INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad)
VALUES ('TEST JUG Estadio', 50000, @idCiudad);
SET @idSede = SCOPE_IDENTITY();

DECLARE @idFase INT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (234, '2026-06-12 20:00', 'Programado', @idFase, @idSede, @idSel1, @idSel2);
SET @idPartido = SCOPE_IDENTITY();

-- =========================================================================
-- TEST 1: ReglaConvocados y ReglaCambios
-- =========================================================================
INSERT INTO jugadores.ReglaConvocados (Minimo, Maximo) VALUES (23, 26);
INSERT INTO jugadores.ReglaCambios (MaxCambiosRegular, MaxVentanasRegular, MaxCambiosSuplementario, MaxVentanasSuplementario)
VALUES (5, 3, 1, 1);
PRINT 'TEST 1.A OK: ReglaConvocados y ReglaCambios insertadas.';

BEGIN TRY
    INSERT INTO jugadores.ReglaConvocados (Minimo, Maximo) VALUES (26, 23);
    PRINT 'TEST 1.B FALLÓ: permitió Maximo menor que Minimo.';
END TRY
BEGIN CATCH
    PRINT 'TEST 1.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    INSERT INTO jugadores.ReglaCambios (MaxCambiosRegular, MaxVentanasRegular, MaxCambiosSuplementario, MaxVentanasSuplementario)
    VALUES (-1, 3, 1, 1);
    PRINT 'TEST 1.C FALLÓ: permitió cambios negativos.';
END TRY
BEGIN CATCH
    PRINT 'TEST 1.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: Club y Jugador (unicidad, fecha de nacimiento, sexo y posición)
-- =========================================================================
INSERT INTO jugadores.Club (Nombre) VALUES ('TEST Club 1');
DECLARE @idClub INT = (SELECT IdClub FROM jugadores.Club WHERE Nombre = 'TEST Club 1');

INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, FechaNacimiento, Sexo, Posicion, IdClub)
VALUES ('Emiliano', 'Martinez', 'TEST_JUG_D1', '1992-09-02', 'M', 'Arquero',   @idClub),
       ('Julian',   'Alvarez',  'TEST_JUG_D2', '2000-01-31', 'M', 'Delantero', @idClub),
       ('Lautaro',  'Martinez', 'TEST_JUG_D3', '1997-08-22', 'M', 'Delantero', NULL);

DECLARE @idJug1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_JUG_D1');
DECLARE @idJug2 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_JUG_D2');
DECLARE @idJug3 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_JUG_D3');

BEGIN TRY
    INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion)
    VALUES ('Otro', 'Jugador', 'TEST_JUG_D1', 'M', 'Defensor');
    PRINT 'TEST 2.A FALLÓ: permitió documento duplicado.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.A OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, FechaNacimiento, Sexo, Posicion)
    VALUES ('Futuro', 'Jugador', 'TEST_JUG_FUT', '2099-01-01', 'M', 'Defensor');
    PRINT 'TEST 2.B FALLÓ: permitió fecha de nacimiento futura.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion)
    VALUES ('Mal', 'Posicion', 'TEST_JUG_POS', 'M', 'Enganche');
    PRINT 'TEST 2.C FALLÓ: permitió posición inválida.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: Convocatoria y Baja
-- =========================================================================
INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
VALUES (@idSel1, @idJug1, 23),
       (@idSel1, @idJug2, 9);

DECLARE @idConv1 INT = (SELECT IdConvocatoria FROM jugadores.Convocatoria WHERE IdJugador = @idJug1);

BEGIN TRY
    INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
    VALUES (@idSel2, @idJug1, 1);
    PRINT 'TEST 3.A FALLÓ: permitió convocar un jugador en dos selecciones.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.A OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
    VALUES (@idSel1, @idJug3, 23);
    PRINT 'TEST 3.B FALLÓ: permitió repetir dorsal en la misma selección.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
    VALUES (@idSel1, @idJug3, 100);
    PRINT 'TEST 3.C FALLÓ: permitió dorsal fuera de rango.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

INSERT INTO jugadores.Baja (IdConvocatoria, Motivo) VALUES (@idConv1, 'Lesión muscular');
BEGIN TRY
    INSERT INTO jugadores.Baja (IdConvocatoria, Motivo) VALUES (@idConv1, 'Segunda baja repetida');
    PRINT 'TEST 3.D FALLÓ: permitió dar de baja dos veces la misma convocatoria.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: Formacion y FormacionJugador
-- =========================================================================
INSERT INTO jugadores.Formacion (IdPartido, Localia, EsquemaTactico)
VALUES (@idPartido, 'Local', '4-3-3');
DECLARE @idForm INT = (SELECT IdFormacion FROM jugadores.Formacion WHERE IdPartido = @idPartido AND Localia = 'Local');

BEGIN TRY
    INSERT INTO jugadores.Formacion (IdPartido, Localia, EsquemaTactico)
    VALUES (@idPartido, 'Visitante', '433');
    PRINT 'TEST 4.A FALLÓ: permitió esquema táctico con formato inválido.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.A OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

INSERT INTO jugadores.FormacionJugador (IdFormacion, IdJugador, EstadoTitularidad, PosicionEnCampo, Dorsal)
VALUES (@idForm, @idJug1, 'Titular',  'Arquero', 23),
       (@idForm, @idJug2, 'Suplente', NULL,       9);
PRINT 'TEST 4.B OK: Titular y Suplente insertados en FormacionJugador.';

BEGIN TRY
    INSERT INTO jugadores.FormacionJugador (IdFormacion, IdJugador, EstadoTitularidad, PosicionEnCampo, Dorsal)
    VALUES (@idForm, @idJug3, 'Suplente', 'Delantero', 10);
    PRINT 'TEST 4.C FALLÓ: permitió suplente con posición en campo.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 5: Sustitucion
-- =========================================================================
INSERT INTO jugadores.Sustitucion (IdPartido, IdJugadorSaliente, IdJugadorEntrante, Minuto, Periodo, Motivo)
VALUES (@idPartido, @idJug1, @idJug2, 18, 'Regular', 'Lesion');
PRINT 'TEST 5.A OK: Sustitución válida insertada.';

BEGIN TRY
    INSERT INTO jugadores.Sustitucion (IdPartido, IdJugadorSaliente, IdJugadorEntrante, Minuto, Periodo, Motivo)
    VALUES (@idPartido, @idJug3, @idJug3, 60, 'Regular', 'Tactico');
    PRINT 'TEST 5.B FALLÓ: permitió saliente igual a entrante.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

ROLLBACK TRANSACTION;
GO