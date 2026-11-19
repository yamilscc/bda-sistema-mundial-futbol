/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-19
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Pruebas de casos límite y restricciones DDL sobre las tablas del módulo de publicidad
          (script 04_Tablas_Publicidad.sql y FK de 06_FK_Cruzadas.sql): Moneda, Anunciante,
          Pieza, OrientacionPais y EspacioPublicitario.
          Requiere ejecutados los scripts 01 a 09 (usa SP_ABM_Sede y SP_ABM_Partido).
          Las inserciones se hacen directo sobre las tablas a propósito: se prueban las
          restricciones, no los stored procedures.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- PREPARACIÓN DE DATOS MÍNIMOS PARA PRUEBAS DE INTEGRIDAD
-- Todo corre dentro de una transacción que se deshace al final (ROLLBACK), por lo que
-- los DELETE de abajo no afectan los datos reales y no queda basura de prueba.
-- =========================================================================
BEGIN TRANSACTION;

DELETE FROM publicidad.EspacioPublicitario;
DELETE FROM publicidad.OrientacionPais;
DELETE FROM publicidad.Pieza;
DELETE FROM publicidad.Anunciante;
DELETE FROM publicidad.Moneda;

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST PU4 Confederacion', 'TP4');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TP4');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, ZonaHoraria)
VALUES ('TEST PU4 Pais 1', 'V1', 'VP1', @idConf, 'Argentina Standard Time'),
       ('TEST PU4 Pais 2', 'V2', 'VP2', @idConf, 'Argentina Standard Time');
DECLARE @idPais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'VP1');
DECLARE @idPais2 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'VP2');

INSERT INTO nucleo.Ciudad (Nombre, IdPais) VALUES ('TEST PU4 Ciudad', @idPais1);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST PU4 Ciudad');

DECLARE @idSede INT, @idPartido INT;
EXEC nucleo.SP_ABM_Sede @operacion = 'ALTA', @idSede = @idSede OUTPUT, @nombreEstadio = 'TEST PU4 Estadio',
     @idCiudad = @idCiudad, @capacidad = 50000, @zonaHoraria = 'Argentina Standard Time';

DECLARE @idFase INT = (SELECT IdFase FROM nucleo.Fase WHERE Descripcion = 'Octavos');
EXEC nucleo.SP_ABM_Partido 'ALTA', @idPartido OUTPUT, 9401, @idFase, @idSede, '2026-06-12 20:00', NULL, NULL;

INSERT INTO nucleo.Idioma (Nombre) VALUES ('TEST PU4 Idioma');
DECLARE @idIdioma INT = (SELECT IdIdioma FROM nucleo.Idioma WHERE Nombre = 'TEST PU4 Idioma');

-- =========================================================================
-- TEST 1: Moneda - Código ISO 4217 (3 letras mayúsculas) y unicidad
-- =========================================================================

-- 1.A Caso exitoso: dos monedas con código válido.
-- Resultado esperado: Inserción exitosa de 2 filas.
INSERT INTO publicidad.Moneda (Codigo, Nombre)
VALUES ('USD', 'Dolar Estadounidense'),
       ('EUR', 'Euro');
DECLARE @idUSD INT = (SELECT IdMoneda FROM publicidad.Moneda WHERE Codigo = 'USD');
DECLARE @idEUR INT = (SELECT IdMoneda FROM publicidad.Moneda WHERE Codigo = 'EUR');

-- 1.B Caso límite fallido: código en minúsculas (el CHECK compara con collation binaria).
-- Resultado esperado: Error por restricción CHECK CK_Moneda_Codigo.
BEGIN TRY
    INSERT INTO publicidad.Moneda (Codigo, Nombre) VALUES ('ars', 'Peso Argentino');
    PRINT 'TEST 1.B FALLÓ: Permitió un código de moneda en minúsculas.';
END TRY
BEGIN CATCH
    PRINT 'TEST 1.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 1.C Caso límite fallido: código con un dígito.
-- Resultado esperado: Error por restricción CHECK CK_Moneda_Codigo.
BEGIN TRY
    INSERT INTO publicidad.Moneda (Codigo, Nombre) VALUES ('AR5', 'Peso Argentino');
    PRINT 'TEST 1.C FALLÓ: Permitió un código de moneda con un dígito.';
END TRY
BEGIN CATCH
    PRINT 'TEST 1.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 1.D Caso límite fallido: código de solo 2 letras (CHAR(3) lo completa con un espacio).
-- Resultado esperado: Error por restricción CHECK CK_Moneda_Codigo.
BEGIN TRY
    INSERT INTO publicidad.Moneda (Codigo, Nombre) VALUES ('AR', 'Peso Argentino');
    PRINT 'TEST 1.D FALLÓ: Permitió un código de moneda de 2 letras.';
END TRY
BEGIN CATCH
    PRINT 'TEST 1.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 1.E Caso límite fallido: código repetido.
-- Resultado esperado: Error por restricción UNIQUE UQ_Moneda_Codigo.
BEGIN TRY
    INSERT INTO publicidad.Moneda (Codigo, Nombre) VALUES ('USD', 'Otro nombre');
    PRINT 'TEST 1.E FALLÓ: Permitió dos monedas con el mismo código.';
END TRY
BEGIN CATCH
    PRINT 'TEST 1.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 1.F Caso límite fallido: nombre repetido.
-- Resultado esperado: Error por restricción UNIQUE UQ_Moneda_Nombre.
BEGIN TRY
    INSERT INTO publicidad.Moneda (Codigo, Nombre) VALUES ('GBP', 'Euro');
    PRINT 'TEST 1.F FALLÓ: Permitió dos monedas con el mismo nombre.';
END TRY
BEGIN CATCH
    PRINT 'TEST 1.F OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: Anunciante - Nombre único y país de origen existente
-- =========================================================================

-- 2.A Caso exitoso: dos anunciantes de países distintos.
-- Resultado esperado: Inserción exitosa de 2 filas.
INSERT INTO publicidad.Anunciante (Nombre, IdPais)
VALUES ('TEST PU4 Anunciante 1', @idPais1),
       ('TEST PU4 Anunciante 2', @idPais2);
DECLARE @idAnun1 INT = (SELECT IdAnunciante FROM publicidad.Anunciante WHERE Nombre = 'TEST PU4 Anunciante 1');
DECLARE @idAnun2 INT = (SELECT IdAnunciante FROM publicidad.Anunciante WHERE Nombre = 'TEST PU4 Anunciante 2');

-- 2.B Caso límite fallido: nombre de anunciante repetido.
-- Resultado esperado: Error por restricción UNIQUE UQ_Anunciante_Nombre.
BEGIN TRY
    INSERT INTO publicidad.Anunciante (Nombre, IdPais) VALUES ('TEST PU4 Anunciante 1', @idPais2);
    PRINT 'TEST 2.B FALLÓ: Permitió dos anunciantes con el mismo nombre.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.C Caso límite fallido: país de origen inexistente.
-- Resultado esperado: Error por clave foránea FK_Anunciante_Pais.
BEGIN TRY
    INSERT INTO publicidad.Anunciante (Nombre, IdPais) VALUES ('TEST PU4 Anunciante 3', -1);
    PRINT 'TEST 2.C FALLÓ: Permitió un anunciante con país inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: Pieza - Unicidad por anunciante, título e idioma; FK a anunciante e idioma
-- =========================================================================

-- 3.A Caso exitoso: dos piezas distintas del mismo anunciante.
-- Resultado esperado: Inserción exitosa de 2 filas.
INSERT INTO publicidad.Pieza (IdAnunciante, IdIdioma, Titulo, Descripcion)
VALUES (@idAnun1, @idIdioma, 'Pieza A', 'Descripción de la pieza A'),
       (@idAnun1, @idIdioma, 'Pieza B', NULL);
DECLARE @idPiezaA INT = (SELECT IdPieza FROM publicidad.Pieza WHERE IdAnunciante = @idAnun1 AND Titulo = 'Pieza A');
DECLARE @idPiezaB INT = (SELECT IdPieza FROM publicidad.Pieza WHERE IdAnunciante = @idAnun1 AND Titulo = 'Pieza B');

-- 3.B Caso límite exitoso: mismo título para otro anunciante (la unicidad es por anunciante).
-- Resultado esperado: Inserción exitosa de 1 fila.
INSERT INTO publicidad.Pieza (IdAnunciante, IdIdioma, Titulo)
VALUES (@idAnun2, @idIdioma, 'Pieza A');
DECLARE @idPiezaC INT = (SELECT IdPieza FROM publicidad.Pieza WHERE IdAnunciante = @idAnun2 AND Titulo = 'Pieza A');

-- 3.C Caso límite fallido: mismo anunciante, título e idioma.
-- Resultado esperado: Error por restricción UNIQUE UQ_Pieza_Anunciante_Titulo_Idioma.
BEGIN TRY
    INSERT INTO publicidad.Pieza (IdAnunciante, IdIdioma, Titulo)
    VALUES (@idAnun1, @idIdioma, 'Pieza A');
    PRINT 'TEST 3.C FALLÓ: Permitió una pieza repetida del mismo anunciante.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.D Caso límite fallido: anunciante inexistente.
-- Resultado esperado: Error por clave foránea FK_Pieza_Anunciante.
BEGIN TRY
    INSERT INTO publicidad.Pieza (IdAnunciante, IdIdioma, Titulo)
    VALUES (-1, @idIdioma, 'Pieza huérfana');
    PRINT 'TEST 3.D FALLÓ: Permitió una pieza con anunciante inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.E Caso límite fallido: idioma inexistente.
-- Resultado esperado: Error por clave foránea FK_Pieza_Idioma.
BEGIN TRY
    INSERT INTO publicidad.Pieza (IdAnunciante, IdIdioma, Titulo)
    VALUES (@idAnun1, -1, 'Pieza sin idioma');
    PRINT 'TEST 3.E FALLÓ: Permitió una pieza con idioma inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: OrientacionPais - PK compuesta (IdPieza, IdPais) y FK
-- =========================================================================

-- 4.A Caso exitoso: una pieza orientada a dos países y otra pieza al mismo país.
-- Resultado esperado: Inserción exitosa de 3 filas.
INSERT INTO publicidad.OrientacionPais (IdPieza, IdPais)
VALUES (@idPiezaA, @idPais1),
       (@idPiezaA, @idPais2),
       (@idPiezaB, @idPais1);

-- 4.B Caso límite fallido: la misma pieza orientada dos veces al mismo país.
-- Resultado esperado: Error por clave primaria PK_OrientacionPais.
BEGIN TRY
    INSERT INTO publicidad.OrientacionPais (IdPieza, IdPais) VALUES (@idPiezaA, @idPais1);
    PRINT 'TEST 4.B FALLÓ: Permitió orientar dos veces la misma pieza al mismo país.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.C Caso límite fallido: pieza inexistente.
-- Resultado esperado: Error por clave foránea FK_OrientacionPais_Pieza.
BEGIN TRY
    INSERT INTO publicidad.OrientacionPais (IdPieza, IdPais) VALUES (-1, @idPais1);
    PRINT 'TEST 4.C FALLÓ: Permitió orientar una pieza inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.D Caso límite fallido: país inexistente.
-- Resultado esperado: Error por clave foránea FK_OrientacionPais_Pais.
BEGIN TRY
    INSERT INTO publicidad.OrientacionPais (IdPieza, IdPais) VALUES (@idPiezaB, -1);
    PRINT 'TEST 4.D FALLÓ: Permitió orientar una pieza a un país inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 5: EspacioPublicitario - Fronteras de NumeroEspacio (0, 1, 4, 5), tarifa y unicidad
-- =========================================================================

-- 5.A Caso límite exitoso: espacios en los bordes exactos permitidos (1 y 4), uno con tarifa 0.
-- Resultado esperado: Inserción exitosa de 2 filas.
INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
VALUES (@idPartido, 1, @idPiezaA, 25000.00, @idUSD),
       (@idPartido, 4, @idPiezaB, 0.00,     @idEUR);

-- 5.B Caso límite fallido: NumeroEspacio = 0 (fuera de borde inferior).
-- Resultado esperado: Error por restricción CHECK CK_EspacioPublicitario_NumeroEspacio.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 0, @idPiezaA, 100.00, @idUSD);
    PRINT 'TEST 5.B FALLÓ: Permitió el espacio publicitario 0.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 5.C Caso límite fallido: NumeroEspacio = 5 (fuera de borde superior).
-- Resultado esperado: Error por restricción CHECK CK_EspacioPublicitario_NumeroEspacio.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 5, @idPiezaA, 100.00, @idUSD);
    PRINT 'TEST 5.C FALLÓ: Permitió el espacio publicitario 5.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 5.D Caso límite fallido: tarifa negativa.
-- Resultado esperado: Error por restricción CHECK CK_EspacioPublicitario_TarifaPublicitaria.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 2, @idPiezaA, -0.01, @idUSD);
    PRINT 'TEST 5.D FALLÓ: Permitió una tarifa negativa.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 5.E Caso límite fallido: número de espacio ya ocupado en el mismo partido.
-- Resultado esperado: Error por clave primaria PK_EspacioPublicitario.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 1, @idPiezaC, 100.00, @idUSD);
    PRINT 'TEST 5.E FALLÓ: Permitió ocupar dos veces el mismo espacio del partido.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 5.F Caso límite fallido: la misma pieza en dos espacios del mismo partido.
-- Resultado esperado: Error por restricción UNIQUE UQ_EspacioPublicitario_Partido_Pieza.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 2, @idPiezaA, 100.00, @idUSD);
    PRINT 'TEST 5.F FALLÓ: Permitió la misma pieza en dos espacios del mismo partido.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.F OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 5.G Caso límite fallido: pieza inexistente.
-- Resultado esperado: Error por clave foránea FK_EspacioPublicitario_Pieza.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 2, -1, 100.00, @idUSD);
    PRINT 'TEST 5.G FALLÓ: Permitió un espacio con pieza inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.G OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 5.H Caso límite fallido: moneda inexistente.
-- Resultado esperado: Error por clave foránea FK_EspacioPublicitario_Moneda.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 2, @idPiezaC, 100.00, -1);
    PRINT 'TEST 5.H FALLÓ: Permitió un espacio con moneda inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.H OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 5.I Caso límite fallido: partido inexistente.
-- Resultado esperado: Error por clave foránea FK_EspacioPublicitario_Partido.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (-1, 1, @idPiezaA, 100.00, @idUSD);
    PRINT 'TEST 5.I FALLÓ: Permitió un espacio con partido inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.I OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 6: Integridad al borrar (no se pueden borrar padres con hijos)
-- =========================================================================

-- 6.A Caso límite fallido: borrar una moneda usada en un espacio publicitario.
-- Resultado esperado: Error por clave foránea FK_EspacioPublicitario_Moneda.
BEGIN TRY
    DELETE FROM publicidad.Moneda WHERE IdMoneda = @idUSD;
    PRINT 'TEST 6.A FALLÓ: Permitió borrar una moneda con espacios publicitarios.';
END TRY
BEGIN CATCH
    PRINT 'TEST 6.A OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 6.B Caso límite fallido: borrar un anunciante con piezas.
-- Resultado esperado: Error por clave foránea FK_Pieza_Anunciante.
BEGIN TRY
    DELETE FROM publicidad.Anunciante WHERE IdAnunciante = @idAnun1;
    PRINT 'TEST 6.B FALLÓ: Permitió borrar un anunciante con piezas.';
END TRY
BEGIN CATCH
    PRINT 'TEST 6.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 6.C Caso límite fallido: borrar una pieza orientada a países.
-- Resultado esperado: Error por clave foránea FK_OrientacionPais_Pieza.
BEGIN TRY
    DELETE FROM publicidad.Pieza WHERE IdPieza = @idPiezaA;
    PRINT 'TEST 6.C FALLÓ: Permitió borrar una pieza con orientación por país.';
END TRY
BEGIN CATCH
    PRINT 'TEST 6.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
SELECT 'Filas persistidas (esperado: Moneda=2, Anunciante=2, Pieza=3, OrientacionPais=3, EspacioPublicitario=2)' AS Control,
       (SELECT COUNT(*) FROM publicidad.Moneda)              AS Moneda,
       (SELECT COUNT(*) FROM publicidad.Anunciante)          AS Anunciante,
       (SELECT COUNT(*) FROM publicidad.Pieza)               AS Pieza,
       (SELECT COUNT(*) FROM publicidad.OrientacionPais)     AS OrientacionPais,
       (SELECT COUNT(*) FROM publicidad.EspacioPublicitario) AS EspacioPublicitario;

-- =========================================================================
-- FIN: se deshacen todos los cambios de la prueba.
-- =========================================================================
ROLLBACK TRANSACTION;
GO
