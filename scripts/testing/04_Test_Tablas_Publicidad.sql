/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Pruebas de casos límite y restricciones DDL sobre las tablas del módulo de publicidad
          (script 04_Tablas_Publicidad.sql y FK de 06_FK_Cruzadas.sql): Moneda, Anunciante,
          Campania, Pieza, OrientacionPais, Tarifa y EspacioPublicitario.
          Requiere ejecutados los scripts 01 a 06.
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
DELETE FROM publicidad.Campania;
DELETE FROM publicidad.Anunciante;
DELETE FROM publicidad.Tarifa;
DELETE FROM publicidad.CotizacionMoneda;
DELETE FROM publicidad.Moneda;

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST PU4 Confederacion', 'TP4');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TP4');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, HusoHorarioComercial)
VALUES ('TEST PU4 Pais 1', 'VA', 'VPA', @idConf, 'Argentina Standard Time'),
       ('TEST PU4 Pais 2', 'VB', 'VPB', @idConf, 'Argentina Standard Time');
DECLARE @idPais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'VPA');
DECLARE @idPais2 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'VPB');

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST PU4 Ciudad', 'Argentina Standard Time', @idPais1);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST PU4 Ciudad');

DECLARE @idSede INT, @idPartido INT;
INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad)
VALUES ('TEST PU4 Estadio', 50000, @idCiudad);
SET @idSede = SCOPE_IDENTITY();

DECLARE @idFase INT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (236, '2026-06-12 20:00', 'Programado', @idFase, @idSede, NULL, NULL);
SET @idPartido = SCOPE_IDENTITY();

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
-- TEST 3: Campania - Unicidad por anunciante y título, título no vacío, rango de fechas y FK
-- =========================================================================

-- 3.A Caso exitoso: dos campañas del anunciante 1 (una con todos los datos opcionales) y una del anunciante 2.
-- Resultado esperado: Inserción exitosa de 3 filas.
INSERT INTO publicidad.Campania (IdAnunciante, Titulo, Marca, Agencia, FechaDesde, FechaHasta)
VALUES (@idAnun1, 'Campaña 1', 'Marca 1', 'Agencia 1', '2026-06-01', '2026-07-19'),
       (@idAnun1, 'Campaña 2', NULL, NULL, NULL, NULL),
       (@idAnun2, 'Campaña 1', NULL, NULL, NULL, NULL);
DECLARE @idCamp1 INT = (SELECT IdCampania FROM publicidad.Campania WHERE IdAnunciante = @idAnun1 AND Titulo = 'Campaña 1');
DECLARE @idCamp2 INT = (SELECT IdCampania FROM publicidad.Campania WHERE IdAnunciante = @idAnun1 AND Titulo = 'Campaña 2');
DECLARE @idCamp3 INT = (SELECT IdCampania FROM publicidad.Campania WHERE IdAnunciante = @idAnun2 AND Titulo = 'Campaña 1');

-- 3.B Caso límite exitoso: campaña de un solo día (FechaHasta = FechaDesde).
-- Resultado esperado: Inserción exitosa de 1 fila.
INSERT INTO publicidad.Campania (IdAnunciante, Titulo, FechaDesde, FechaHasta)
VALUES (@idAnun2, 'Campaña de un día', '2026-06-11', '2026-06-11');

-- 3.C Caso límite fallido: mismo anunciante y título.
-- Resultado esperado: Error por restricción UNIQUE UQ_Campania_IdAnunciante_Titulo.
BEGIN TRY
    INSERT INTO publicidad.Campania (IdAnunciante, Titulo) VALUES (@idAnun1, 'Campaña 1');
    PRINT 'TEST 3.C FALLÓ: Permitió dos campañas con el mismo título para el mismo anunciante.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.D Caso límite fallido: título con solo espacios.
-- Resultado esperado: Error por restricción CHECK CK_Campania_Titulo_NoVacio.
BEGIN TRY
    INSERT INTO publicidad.Campania (IdAnunciante, Titulo) VALUES (@idAnun1, '   ');
    PRINT 'TEST 3.D FALLÓ: Permitió una campaña con título vacío.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.E Caso límite fallido: FechaHasta un día antes de FechaDesde.
-- Resultado esperado: Error por restricción CHECK CK_Campania_Fechas.
BEGIN TRY
    INSERT INTO publicidad.Campania (IdAnunciante, Titulo, FechaDesde, FechaHasta)
    VALUES (@idAnun1, 'Campaña invertida', '2026-06-11', '2026-06-10');
    PRINT 'TEST 3.E FALLÓ: Permitió una campaña que termina antes de empezar.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.F Caso límite fallido: anunciante inexistente.
-- Resultado esperado: Error por clave foránea FK_Campania_Anunciante.
BEGIN TRY
    INSERT INTO publicidad.Campania (IdAnunciante, Titulo) VALUES (-1, 'Campaña huérfana');
    PRINT 'TEST 3.F FALLÓ: Permitió una campaña con anunciante inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.F OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: Pieza - Unicidad por campaña, título e idioma; FK a campaña e idioma
-- =========================================================================

-- 4.A Caso exitoso: dos piezas distintas de la misma campaña.
-- Resultado esperado: Inserción exitosa de 2 filas.
INSERT INTO publicidad.Pieza (IdCampania, IdIdioma, Titulo, Descripcion)
VALUES (@idCamp1, @idIdioma, 'Pieza A', 'Descripción de la pieza A'),
       (@idCamp1, @idIdioma, 'Pieza B', NULL);
DECLARE @idPiezaA INT = (SELECT IdPieza FROM publicidad.Pieza WHERE IdCampania = @idCamp1 AND Titulo = 'Pieza A');
DECLARE @idPiezaB INT = (SELECT IdPieza FROM publicidad.Pieza WHERE IdCampania = @idCamp1 AND Titulo = 'Pieza B');

-- 4.B Caso límite exitoso: mismo título e idioma en otra campaña del MISMO anunciante y en una
-- campaña de otro anunciante (la unicidad es por campaña).
-- Resultado esperado: Inserción exitosa de 2 filas.
INSERT INTO publicidad.Pieza (IdCampania, IdIdioma, Titulo)
VALUES (@idCamp2, @idIdioma, 'Pieza A'),
       (@idCamp3, @idIdioma, 'Pieza A');
DECLARE @idPiezaC INT = (SELECT IdPieza FROM publicidad.Pieza WHERE IdCampania = @idCamp3 AND Titulo = 'Pieza A');

-- 4.C Caso límite fallido: misma campaña, título e idioma.
-- Resultado esperado: Error por restricción UNIQUE UQ_Pieza_Campania_Titulo_Idioma.
BEGIN TRY
    INSERT INTO publicidad.Pieza (IdCampania, IdIdioma, Titulo)
    VALUES (@idCamp1, @idIdioma, 'Pieza A');
    PRINT 'TEST 4.C FALLÓ: Permitió una pieza repetida en la misma campaña.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.D Caso límite fallido: campaña inexistente.
-- Resultado esperado: Error por clave foránea FK_Pieza_Campania.
BEGIN TRY
    INSERT INTO publicidad.Pieza (IdCampania, IdIdioma, Titulo)
    VALUES (-1, @idIdioma, 'Pieza huérfana');
    PRINT 'TEST 4.D FALLÓ: Permitió una pieza con campaña inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.E Caso límite fallido: idioma inexistente.
-- Resultado esperado: Error por clave foránea FK_Pieza_Idioma.
BEGIN TRY
    INSERT INTO publicidad.Pieza (IdCampania, IdIdioma, Titulo)
    VALUES (@idCamp1, 0, 'Pieza sin idioma');
    PRINT 'TEST 4.E FALLÓ: Permitió una pieza con idioma inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 5: OrientacionPais - PK compuesta (IdPieza, IdPais) y FK
-- =========================================================================

-- 5.A Caso exitoso: una pieza orientada a dos países y otra pieza al mismo país.
-- Resultado esperado: Inserción exitosa de 3 filas.
INSERT INTO publicidad.OrientacionPais (IdPieza, IdPais)
VALUES (@idPiezaA, @idPais1),
       (@idPiezaA, @idPais2),
       (@idPiezaB, @idPais1);

-- 5.B Caso límite fallido: la misma pieza orientada dos veces al mismo país.
-- Resultado esperado: Error por clave primaria PK_OrientacionPais.
BEGIN TRY
    INSERT INTO publicidad.OrientacionPais (IdPieza, IdPais) VALUES (@idPiezaA, @idPais1);
    PRINT 'TEST 5.B FALLÓ: Permitió orientar dos veces la misma pieza al mismo país.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 5.C Caso límite fallido: pieza inexistente.
-- Resultado esperado: Error por clave foránea FK_OrientacionPais_Pieza.
BEGIN TRY
    INSERT INTO publicidad.OrientacionPais (IdPieza, IdPais) VALUES (-1, @idPais1);
    PRINT 'TEST 5.C FALLÓ: Permitió orientar una pieza inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 5.D Caso límite fallido: país inexistente.
-- Resultado esperado: Error por clave foránea FK_OrientacionPais_Pais.
BEGIN TRY
    INSERT INTO publicidad.OrientacionPais (IdPieza, IdPais) VALUES (@idPiezaB, -1);
    PRINT 'TEST 5.D FALLÓ: Permitió orientar una pieza a un país inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 5.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 6: Tarifa - Monto no negativo, vigencia por defecto, unicidad (fase, moneda, vigencia) y FK
-- =========================================================================

-- 6.A Caso límite exitoso: tarifa 0 en USD para octavos con vigencia explícita, y otra en USD para
-- semifinales sin vigencia (toma el default: la fecha de hoy).
-- Resultado esperado: Inserción exitosa de 2 filas; la segunda con VigenciaDesde = hoy.
DECLARE @idFaseSemi INT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Semifinal');
INSERT INTO publicidad.Tarifa (IdFase, IdMoneda, Monto, VigenciaDesde) VALUES (@idFase, @idUSD, 0.00, '2026-01-01');
INSERT INTO publicidad.Tarifa (IdFase, IdMoneda, Monto) VALUES (@idFaseSemi, @idUSD, 15000.00);
SELECT 'TEST 6.A (esperado: Vigencia_Hoy_1 = 1)' AS Caso,
       (SELECT COUNT(*) FROM publicidad.Tarifa
        WHERE IdFase = @idFaseSemi AND IdMoneda = @idUSD AND VigenciaDesde = CAST(GETDATE() AS DATE)) AS Vigencia_Hoy_1;

-- 6.B Caso límite exitoso: misma fase y moneda con otra fecha de vigencia (historial de tarifas).
-- Resultado esperado: Inserción exitosa de 1 fila.
INSERT INTO publicidad.Tarifa (IdFase, IdMoneda, Monto, VigenciaDesde) VALUES (@idFase, @idUSD, 30000.00, '2026-06-01');

-- 6.C Caso límite fallido: monto negativo.
-- Resultado esperado: Error por restricción CHECK CK_Tarifa_Monto.
BEGIN TRY
    INSERT INTO publicidad.Tarifa (IdFase, IdMoneda, Monto, VigenciaDesde) VALUES (@idFase, @idUSD, -0.01, '2026-02-01');
    PRINT 'TEST 6.C FALLÓ: Permitió una tarifa con monto negativo.';
END TRY
BEGIN CATCH
    PRINT 'TEST 6.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 6.D Caso límite fallido: misma fase, moneda y vigencia.
-- Resultado esperado: Error por restricción UNIQUE UQ_Tarifa_Fase_Moneda_Vigencia.
BEGIN TRY
    INSERT INTO publicidad.Tarifa (IdFase, IdMoneda, Monto, VigenciaDesde) VALUES (@idFase, @idUSD, 99.00, '2026-01-01');
    PRINT 'TEST 6.D FALLÓ: Permitió dos tarifas con la misma fase, moneda y vigencia.';
END TRY
BEGIN CATCH
    PRINT 'TEST 6.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 6.E Caso límite fallido: fase inexistente.
-- Resultado esperado: Error por clave foránea FK_Tarifa_Fase.
BEGIN TRY
    INSERT INTO publicidad.Tarifa (IdFase, IdMoneda, Monto, VigenciaDesde) VALUES (0, @idUSD, 100.00, '2026-01-01');
    PRINT 'TEST 6.E FALLÓ: Permitió una tarifa con fase inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 6.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 6.F Caso límite fallido: moneda inexistente.
-- Resultado esperado: Error por clave foránea FK_Tarifa_Moneda.
BEGIN TRY
    INSERT INTO publicidad.Tarifa (IdFase, IdMoneda, Monto, VigenciaDesde) VALUES (@idFase, -1, 100.00, '2026-01-01');
    PRINT 'TEST 6.F FALLÓ: Permitió una tarifa con moneda inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 6.F OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 7: EspacioPublicitario - Fronteras de NumeroEspacio (0, 1, 4, 5), tarifa, unicidad
--         y datos de asignación (FechaAsignacion por defecto, CriterioAsignacion opcional)
-- =========================================================================

-- 7.A Caso límite exitoso: espacios en los bordes exactos permitidos (1 y 4), uno con tarifa 0.
-- El espacio 1 se carga con criterio y el 4 sin criterio (carga manual).
-- Resultado esperado: Inserción exitosa de 2 filas.
INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda, CriterioAsignacion)
VALUES (@idPartido, 1, @idPiezaA, 25000.00, @idUSD, 'TEST criterio');
INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
VALUES (@idPartido, 4, @idPiezaB, 0.00, @idEUR);

-- 7.B Caso exitoso: FechaAsignacion toma el default (momento de la carga) en ambos espacios
-- y CriterioAsignacion queda NULL en el cargado a mano.
-- Resultado esperado: Con_Fecha_2 = 2, Sin_Criterio_1 = 1.
SELECT 'TEST 7.B (esperado: Con_Fecha_2 = 2, Sin_Criterio_1 = 1)' AS Caso,
       SUM(CASE WHEN FechaAsignacion >= DATEADD(MINUTE, -5, SYSDATETIME()) THEN 1 ELSE 0 END) AS Con_Fecha_2,
       SUM(CASE WHEN CriterioAsignacion IS NULL THEN 1 ELSE 0 END)                            AS Sin_Criterio_1
FROM publicidad.EspacioPublicitario
WHERE IdPartido = @idPartido;

-- 7.C Caso límite fallido: NumeroEspacio = 0 (fuera de borde inferior).
-- Resultado esperado: Error por restricción CHECK CK_EspacioPublicitario_NumeroEspacio.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 0, @idPiezaC, 100.00, @idUSD);
    PRINT 'TEST 7.C FALLÓ: Permitió el espacio publicitario 0.';
END TRY
BEGIN CATCH
    PRINT 'TEST 7.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 7.D Caso límite fallido: NumeroEspacio = 5 (fuera de borde superior).
-- Resultado esperado: Error por restricción CHECK CK_EspacioPublicitario_NumeroEspacio.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 5, @idPiezaC, 100.00, @idUSD);
    PRINT 'TEST 7.D FALLÓ: Permitió el espacio publicitario 5.';
END TRY
BEGIN CATCH
    PRINT 'TEST 7.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 7.E Caso límite fallido: tarifa negativa.
-- Resultado esperado: Error por restricción CHECK CK_EspacioPublicitario_TarifaPublicitaria.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 2, @idPiezaC, -0.01, @idUSD);
    PRINT 'TEST 7.E FALLÓ: Permitió una tarifa negativa.';
END TRY
BEGIN CATCH
    PRINT 'TEST 7.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 7.F Caso límite fallido: número de espacio ya ocupado en el mismo partido.
-- Resultado esperado: Error por clave primaria PK_EspacioPublicitario.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 1, @idPiezaC, 100.00, @idUSD);
    PRINT 'TEST 7.F FALLÓ: Permitió ocupar dos veces el mismo espacio del partido.';
END TRY
BEGIN CATCH
    PRINT 'TEST 7.F OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 7.G Caso límite fallido: la misma pieza en dos espacios del mismo partido.
-- Resultado esperado: Error por restricción UNIQUE UQ_EspacioPublicitario_Partido_Pieza.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 2, @idPiezaA, 100.00, @idUSD);
    PRINT 'TEST 7.G FALLÓ: Permitió la misma pieza en dos espacios del mismo partido.';
END TRY
BEGIN CATCH
    PRINT 'TEST 7.G OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 7.H Caso límite fallido: pieza inexistente.
-- Resultado esperado: Error por clave foránea FK_EspacioPublicitario_Pieza.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 2, -1, 100.00, @idUSD);
    PRINT 'TEST 7.H FALLÓ: Permitió un espacio con pieza inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 7.H OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 7.I Caso límite fallido: moneda inexistente.
-- Resultado esperado: Error por clave foránea FK_EspacioPublicitario_Moneda.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (@idPartido, 2, @idPiezaC, 100.00, -1);
    PRINT 'TEST 7.I FALLÓ: Permitió un espacio con moneda inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 7.I OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 7.J Caso límite fallido: partido inexistente.
-- Resultado esperado: Error por clave foránea FK_EspacioPublicitario_Partido.
BEGIN TRY
    INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
    VALUES (-1, 1, @idPiezaA, 100.00, @idUSD);
    PRINT 'TEST 7.J FALLÓ: Permitió un espacio con partido inexistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 7.J OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 8: Integridad al borrar (no se pueden borrar padres con hijos)
-- =========================================================================

-- 8.A Caso límite fallido: borrar una moneda usada en un espacio publicitario (EUR no tiene tarifas).
-- Resultado esperado: Error por clave foránea FK_EspacioPublicitario_Moneda.
BEGIN TRY
    DELETE FROM publicidad.Moneda WHERE IdMoneda = @idEUR;
    PRINT 'TEST 8.A FALLÓ: Permitió borrar una moneda con espacios publicitarios.';
END TRY
BEGIN CATCH
    PRINT 'TEST 8.A OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.B Caso límite fallido: borrar un anunciante con campañas.
-- Resultado esperado: Error por clave foránea FK_Campania_Anunciante.
BEGIN TRY
    DELETE FROM publicidad.Anunciante WHERE IdAnunciante = @idAnun1;
    PRINT 'TEST 8.B FALLÓ: Permitió borrar un anunciante con campañas.';
END TRY
BEGIN CATCH
    PRINT 'TEST 8.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.C Caso límite fallido: borrar una campaña con piezas.
-- Resultado esperado: Error por clave foránea FK_Pieza_Campania.
BEGIN TRY
    DELETE FROM publicidad.Campania WHERE IdCampania = @idCamp3;
    PRINT 'TEST 8.C FALLÓ: Permitió borrar una campaña con piezas.';
END TRY
BEGIN CATCH
    PRINT 'TEST 8.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.D Caso límite fallido: borrar una pieza orientada a países.
-- Resultado esperado: Error por clave foránea FK_OrientacionPais_Pieza.
BEGIN TRY
    DELETE FROM publicidad.Pieza WHERE IdPieza = @idPiezaA;
    PRINT 'TEST 8.D FALLÓ: Permitió borrar una pieza con orientación por país.';
END TRY
BEGIN CATCH
    PRINT 'TEST 8.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.E Caso límite fallido: borrar una fase que solo usa una tarifa (la Final no tiene partidos en esta prueba).
-- Resultado esperado: Error por clave foránea FK_Tarifa_Fase.
DECLARE @idFaseFinal INT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Final');
INSERT INTO publicidad.Tarifa (IdFase, IdMoneda, Monto, VigenciaDesde) VALUES (@idFaseFinal, @idUSD, 90000.00, '2026-01-01');
BEGIN TRY
    DELETE FROM nucleo.Fase WHERE IdFase = @idFaseFinal;
    PRINT 'TEST 8.E FALLÓ: Permitió borrar una fase con tarifas.';
END TRY
BEGIN CATCH
    PRINT 'TEST 8.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.F Caso límite fallido: borrar una moneda que solo usan tarifas (FK_Tarifa_Moneda).
-- Se usa una moneda nueva con una sola tarifa para que la única FK que pueda bloquear sea la de Tarifa.
-- Resultado esperado: Error por clave foránea FK_Tarifa_Moneda.
INSERT INTO publicidad.Moneda (Codigo, Nombre) VALUES ('JPY', 'Yen');
DECLARE @idJPY INT = (SELECT IdMoneda FROM publicidad.Moneda WHERE Codigo = 'JPY');
INSERT INTO publicidad.Tarifa (IdFase, IdMoneda, Monto, VigenciaDesde) VALUES (@idFase, @idJPY, 1000000.00, '2026-01-01');
BEGIN TRY
    DELETE FROM publicidad.Moneda WHERE IdMoneda = @idJPY;
    PRINT 'TEST 8.F FALLÓ: Permitió borrar una moneda con tarifas.';
END TRY
BEGIN CATCH
    PRINT 'TEST 8.F OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
SELECT 'Filas persistidas (esperado: Moneda=3, Anunciante=2, Campania=4, Pieza=4, OrientacionPais=3, Tarifa=5, EspacioPublicitario=2)' AS Control,
       (SELECT COUNT(*) FROM publicidad.Moneda)              AS Moneda,
       (SELECT COUNT(*) FROM publicidad.Anunciante)          AS Anunciante,
       (SELECT COUNT(*) FROM publicidad.Campania)            AS Campania,
       (SELECT COUNT(*) FROM publicidad.Pieza)               AS Pieza,
       (SELECT COUNT(*) FROM publicidad.OrientacionPais)     AS OrientacionPais,
       (SELECT COUNT(*) FROM publicidad.Tarifa)              AS Tarifa,
       (SELECT COUNT(*) FROM publicidad.EspacioPublicitario) AS EspacioPublicitario;

-- =========================================================================
-- FIN: se deshacen todos los cambios de la prueba.
-- =========================================================================
ROLLBACK TRANSACTION;
GO
