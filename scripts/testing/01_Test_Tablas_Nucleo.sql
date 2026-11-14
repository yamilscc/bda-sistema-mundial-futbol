/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-14
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar las restricciones (UNIQUE, CHECK, FK, índice único filtrado) de las tablas
          del núcleo creadas en 01_Tablas_Nucleo.sql. Los datos de prueba usan el prefijo
          'TEST' y se borran al inicio y al final.
          Se inserta directo en las tablas a propósito: acá se prueba el DDL, no los SP.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- LIMPIEZA PREVIA (orden inverso a las dependencias)
-- =========================================================================
DELETE FROM nucleo.Sancion WHERE Descripcion LIKE 'TEST%';
DELETE d FROM nucleo.DesignacionArbitral AS d INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido WHERE p.NumeroPartido >= 9800;
DELETE FROM nucleo.Partido WHERE NumeroPartido >= 9800;
DELETE ai FROM nucleo.ArbitroIdioma AS ai INNER JOIN nucleo.Arbitro AS a ON a.IdArbitro = ai.IdArbitro WHERE a.Documento LIKE 'TEST%';
DELETE FROM nucleo.Arbitro WHERE Documento LIKE 'TEST%';
DELETE FROM nucleo.StaffTecnico WHERE Documento LIKE 'TEST%';
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Idioma WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Categoria WHERE Descripcion LIKE 'TEST%';
GO

-- =========================================================================
-- DATOS MÍNIMOS
-- =========================================================================
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST Confederacion', 'TST');

DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TST');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, ZonaHoraria)
VALUES ('TEST Pais 1', 'T1', 'TS1', @idConf, 'Argentina Standard Time'),
       ('TEST Pais 2', 'T2', 'TS2', @idConf, 'Tokyo Standard Time');

DECLARE @idPais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS1');
DECLARE @idPais2 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS2');

INSERT INTO nucleo.Ciudad (Nombre, IdPais) VALUES ('TEST Ciudad', @idPais1);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST Ciudad');

INSERT INTO nucleo.Seleccion (IdPais) VALUES (@idPais1), (@idPais2);
DECLARE @idSel1 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais1);
DECLARE @idSel2 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais2);

INSERT INTO nucleo.Sede (NombreEstadio, IdCiudad, Capacidad, ZonaHoraria, Latitud, Longitud)
VALUES ('TEST Estadio', @idCiudad, 50000, 'Argentina Standard Time', -34.6, -58.4);
DECLARE @idSede INT = (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio = 'TEST Estadio');

DECLARE @idFaseGrupos INT = (SELECT IdFase FROM nucleo.Fase WHERE Descripcion = 'Grupos');

-- =========================================================================
-- TEST 1: Pais - códigos ISO únicos
-- =========================================================================
-- 1.A Resultado esperado: error por UNIQUE UQ_Pais_CodigoISO3 (TS1 repetido).
BEGIN TRY
    INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, ZonaHoraria)
    VALUES ('TEST Pais Dup', 'T9', 'TS1', @idConf, 'Tokyo Standard Time');
    PRINT 'TEST 1.A FALLÓ: permitió un ISO3 duplicado.';
END TRY
BEGIN CATCH
    PRINT 'TEST 1.A OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: Sede - capacidad y coordenadas
-- =========================================================================
-- 2.A Resultado esperado: error por CHECK CK_Sede_Capacidad (capacidad 0).
BEGIN TRY
    INSERT INTO nucleo.Sede (NombreEstadio, IdCiudad, Capacidad, ZonaHoraria)
    VALUES ('TEST Estadio Cero', @idCiudad, 0, 'Argentina Standard Time');
    PRINT 'TEST 2.A FALLÓ: permitió capacidad 0.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.A OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.B Resultado esperado: error por CHECK CK_Sede_Coordenadas (latitud sin longitud).
BEGIN TRY
    INSERT INTO nucleo.Sede (NombreEstadio, IdCiudad, Capacidad, ZonaHoraria, Latitud, Longitud)
    VALUES ('TEST Estadio Coord', @idCiudad, 1000, 'Argentina Standard Time', -34.6, NULL);
    PRINT 'TEST 2.B FALLÓ: permitió latitud sin longitud.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: StaffTecnico - un solo director técnico por selección
-- =========================================================================
-- 3.A Resultado esperado: inserción exitosa de 1 DT y 1 ayudante.
INSERT INTO nucleo.StaffTecnico (IdSeleccion, Nombre, Apellido, Documento, Rol)
VALUES (@idSel1, 'TEST', 'Director', 'TEST_DT_1', 'Director Tecnico'),
       (@idSel1, 'TEST', 'Ayudante', 'TEST_AY_1', 'Ayudante');
PRINT 'TEST 3.A OK: insertó 1 DT y 1 ayudante.';

-- 3.B Resultado esperado: error por índice único UQ_StaffTecnico_DirectorTecnico.
BEGIN TRY
    INSERT INTO nucleo.StaffTecnico (IdSeleccion, Nombre, Apellido, Documento, Rol)
    VALUES (@idSel1, 'TEST', 'Director2', 'TEST_DT_2', 'Director Tecnico');
    PRINT 'TEST 3.B FALLÓ: permitió dos directores técnicos.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: Partido - equipos y coherencia del resultado
-- =========================================================================
-- 4.A Resultado esperado: inserción exitosa (partido programado sin resultado).
INSERT INTO nucleo.Partido (NumeroPartido, IdFase, IdSede, FechaHoraLocal, FechaHoraUTC, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (9801, @idFaseGrupos, @idSede, '2026-06-12 20:00', '2026-06-12 23:00', @idSel1, @idSel2);
PRINT 'TEST 4.A OK: insertó partido programado.';

-- 4.B Resultado esperado: error por CHECK CK_Partido_Equipos (misma selección en ambos lados).
BEGIN TRY
    INSERT INTO nucleo.Partido (NumeroPartido, IdFase, IdSede, FechaHoraLocal, FechaHoraUTC, IdSeleccionLocal, IdSeleccionVisitante)
    VALUES (9802, @idFaseGrupos, @idSede, '2026-06-13 20:00', '2026-06-13 23:00', @idSel1, @idSel1);
    PRINT 'TEST 4.B FALLÓ: permitió una selección contra sí misma.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.C Resultado esperado: error por CHECK CK_Partido_Resultado (goles con estado 'Programado').
BEGIN TRY
    UPDATE nucleo.Partido SET GolesLocal = 1, GolesVisitante = 0 WHERE NumeroPartido = 9801;
    PRINT 'TEST 4.C FALLÓ: permitió goles en un partido programado.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.D Resultado esperado: error por CHECK CK_Partido_Penales (penales con resultado no empatado).
BEGIN TRY
    UPDATE nucleo.Partido
    SET Estado = 'Finalizado', GolesLocal = 2, GolesVisitante = 1, PenalesLocal = 4, PenalesVisitante = 3
    WHERE NumeroPartido = 9801;
    PRINT 'TEST 4.D FALLÓ: permitió penales sin empate.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.E Resultado esperado: error por UNIQUE UQ_Partido_Sede_FechaUTC (misma sede y mismo instante).
BEGIN TRY
    INSERT INTO nucleo.Partido (NumeroPartido, IdFase, IdSede, FechaHoraLocal, FechaHoraUTC)
    VALUES (9803, @idFaseGrupos, @idSede, '2026-06-12 20:00', '2026-06-12 23:00');
    PRINT 'TEST 4.E FALLÓ: permitió dos partidos simultáneos en la sede.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 5: Arbitro, ArbitroIdioma, DesignacionArbitral y Sancion
-- =========================================================================
INSERT INTO nucleo.Categoria (Descripcion) VALUES ('TEST Categoria');
INSERT INTO nucleo.Idioma (Nombre) VALUES ('TEST Idioma');

DECLARE @idCategoria INT = (SELECT IdCategoria FROM nucleo.Categoria WHERE Descripcion = 'TEST Categoria');
DECLARE @idIdioma    INT = (SELECT IdIdioma FROM nucleo.Idioma WHERE Nombre = 'TEST Idioma');

INSERT INTO nucleo.Arbitro (Nombre, Apellido, Documento, IdPais, IdCategoria)
VALUES ('TEST', 'Arbitro', 'TEST_ARB_1', @idPais2, @idCategoria);
DECLARE @idArbitro INT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE Documento = 'TEST_ARB_1');
DECLARE @idPartido INT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 9801);

-- 5.A Resultado esperado: inserción exitosa del idioma del árbitro.
INSERT INTO nucleo.ArbitroIdioma (IdArbitro, IdIdioma) VALUES (@idArbitro, @idIdioma);
PRINT 'TEST 5.A OK: insertó árbitro-idioma.';

-- 5.B Resultado esperado: error por PRIMARY KEY PK_ArbitroIdioma (par repetido).
BEGIN TRY
    INSERT INTO nucleo.ArbitroIdioma (IdArbitro, IdIdioma) VALUES (@idArbitro, @idIdioma);
    PRINT 'TEST 5.B FALLÓ: permitió idioma repetido para el árbitro.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 5.C Resultado esperado: error por CHECK CK_DesignacionArbitral_Rol (rol inexistente).
BEGIN TRY
    INSERT INTO nucleo.DesignacionArbitral (IdPartido, IdArbitro, Rol) VALUES (@idPartido, @idArbitro, 'Linier');
    PRINT 'TEST 5.C FALLÓ: permitió un rol inválido.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 5.D Resultado esperado: inserción exitosa de la designación y de una sanción asociada.
INSERT INTO nucleo.DesignacionArbitral (IdPartido, IdArbitro, Rol) VALUES (@idPartido, @idArbitro, 'Principal');
DECLARE @idDesignacion INT = (SELECT IdDesignacion FROM nucleo.DesignacionArbitral WHERE IdPartido = @idPartido AND IdArbitro = @idArbitro);
INSERT INTO nucleo.Sancion (IdDesignacion, Tipo, Descripcion) VALUES (@idDesignacion, 'Informe', 'TEST informe post-partido');
PRINT 'TEST 5.D OK: insertó designación y sanción.';

-- 5.E Resultado esperado: error por CHECK CK_Sancion_Tipo (tipo inexistente).
BEGIN TRY
    INSERT INTO nucleo.Sancion (IdDesignacion, Tipo, Descripcion) VALUES (@idDesignacion, 'Castigo', 'TEST tipo inválido');
    PRINT 'TEST 5.E FALLÓ: permitió un tipo de sanción inválido.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;
GO

-- =========================================================================
-- LIMPIEZA FINAL
-- =========================================================================
DELETE FROM nucleo.Sancion WHERE Descripcion LIKE 'TEST%';
DELETE d FROM nucleo.DesignacionArbitral AS d INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido WHERE p.NumeroPartido >= 9800;
DELETE FROM nucleo.Partido WHERE NumeroPartido >= 9800;
DELETE ai FROM nucleo.ArbitroIdioma AS ai INNER JOIN nucleo.Arbitro AS a ON a.IdArbitro = ai.IdArbitro WHERE a.Documento LIKE 'TEST%';
DELETE FROM nucleo.Arbitro WHERE Documento LIKE 'TEST%';
DELETE FROM nucleo.StaffTecnico WHERE Documento LIKE 'TEST%';
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Idioma WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Categoria WHERE Descripcion LIKE 'TEST%';
GO
