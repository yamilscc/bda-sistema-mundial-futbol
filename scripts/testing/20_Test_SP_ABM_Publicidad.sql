/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner
Fecha: 2026-11-19
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar los 5 stored procedures ABM del módulo publicidad (script 20_SP_ABM_Publicidad.sql):
          - publicidad.SP_ABM_Moneda
          - publicidad.SP_ABM_Anunciante
          - publicidad.SP_ABM_Pieza
          - publicidad.SP_ABM_OrientacionPais
          - publicidad.SP_ABM_EspacioPublicitario
          Requiere ejecutados los scripts 01 a 20 (usa nucleo.SP_ALTA_Sede y
          nucleo.SP_ALTA_Partido).
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- PREPARACIÓN DE ESCENARIO DE PRUEBA
-- =========================================================================
DELETE FROM publicidad.EspacioPublicitario;
DELETE FROM publicidad.OrientacionPais;
DELETE FROM publicidad.Pieza;
DELETE FROM publicidad.Anunciante;
DELETE FROM publicidad.Moneda;

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST PU20 Confederacion', 'TP20');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TP20');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, PBIPerCapitaUSD, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST PU20 Pais 1', 'UA', 'PUA', 15000.00, 'Argentina Standard Time', @idConf),
       ('TEST PU20 Pais 2', 'UB', 'PUB', 48000.00, 'UTC', @idConf);

DECLARE @idPais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'PUA');
DECLARE @idPais2 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'PUB');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
VALUES ('PUA', 101, 0, @idPais1, @idGrupo),
       ('PUB', 102, 0, @idPais2, @idGrupo);

DECLARE @idSel1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'PUA');
DECLARE @idSel2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'PUB');

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST PU20 Ciudad', 'Argentina Standard Time', @idPais1);
DECLARE @idCiudad SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST PU20 Ciudad');

DECLARE @idSede TINYINT;
EXEC nucleo.SP_ALTA_Sede
     @nombreEstadio = 'TEST PU20 Estadio',
     @idCiudad      = @idCiudad,
     @capacidad     = 55000,
     @idSede        = @idSede OUTPUT;

DECLARE @idFase TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Cuartos de final');
DECLARE @p251 SMALLINT;

-- En fases eliminatorias SP_ALTA_Partido exige las selecciones en NULL.
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 251, @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = '2026-07-04 20:00', @idPartido = @p251 OUTPUT;

-- Se asignan las selecciones al cruce eliminatorio:
UPDATE nucleo.Partido
SET IdSeleccionLocal = @idSel1, IdSeleccionVisitante = @idSel2
WHERE IdPartido = @p251;

INSERT INTO nucleo.Idioma (Nombre) VALUES ('TEST PU20 Idioma');
DECLARE @idIdioma TINYINT = (SELECT IdIdioma FROM nucleo.Idioma WHERE Nombre = 'TEST PU20 Idioma');

-- =========================================================================
-- TEST 1: publicidad.SP_ABM_Moneda
-- =========================================================================
PRINT '--- TEST 1: SP_ABM_Moneda ---';

DECLARE @idMonUSD INT, @idMonEUR INT;

-- 1.A ALTA exitosa de 2 monedas.
BEGIN TRY
    EXEC publicidad.SP_ABM_Moneda 'ALTA', @idMonUSD OUTPUT, 'USD', 'Dolar Estadounidense';
    EXEC publicidad.SP_ABM_Moneda 'ALTA', @idMonEUR OUTPUT, 'EUR', 'Euro';
    PRINT '1.A: OK - 2 monedas dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '1.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.B MODIFICACION exitosa.
BEGIN TRY
    EXEC publicidad.SP_ABM_Moneda 'MODIFICACION', @idMonEUR, 'EUR', 'Euro Europeo';
    PRINT '1.B: OK - moneda EUR modificada.';
END TRY
BEGIN CATCH
    PRINT '1.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.C ALTA fallida con múltiples errores (código inválido y nombre duplicado) y operación inválida.
BEGIN TRY
    EXEC publicidad.SP_ABM_Moneda 'ALTA', NULL, '12A', 'Dolar Estadounidense';
    PRINT '1.C.1: FALLÓ - permitió código inválido y nombre duplicado.';
END TRY
BEGIN CATCH
    PRINT '1.C.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC publicidad.SP_ABM_Moneda 'ELIMINAR';
    PRINT '1.C.2: FALLÓ - permitió operación inválida.';
END TRY
BEGIN CATCH
    PRINT '1.C.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 1.D BAJA exitosa.
BEGIN TRY
    EXEC publicidad.SP_ABM_Moneda 'BAJA', @idMonEUR;
    PRINT '1.D: OK - baja de moneda EUR sin espacios asociados.';
END TRY
BEGIN CATCH
    PRINT '1.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: publicidad.SP_ABM_Anunciante
-- =========================================================================
PRINT '--- TEST 2: SP_ABM_Anunciante ---';

DECLARE @idAnunc1 INT, @idAnunc2 INT;

-- 2.A ALTA exitosa de 2 anunciantes.
BEGIN TRY
    EXEC publicidad.SP_ABM_Anunciante 'ALTA', @idAnunc1 OUTPUT, 'TEST PU20 Marca Global', @idPais1;
    EXEC publicidad.SP_ABM_Anunciante 'ALTA', @idAnunc2 OUTPUT, 'TEST PU20 Marca Temp',   @idPais2;
    PRINT '2.A: OK - 2 anunciantes dados de alta.';
END TRY
BEGIN CATCH
    PRINT '2.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.B MODIFICACION exitosa.
BEGIN TRY
    EXEC publicidad.SP_ABM_Anunciante 'MODIFICACION', @idAnunc1, 'TEST PU20 Marca Global Mod', @idPais2;
    PRINT '2.B: OK - anunciante modificado.';
END TRY
BEGIN CATCH
    PRINT '2.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.C ALTA fallida (nombre duplicado y país inexistente).
BEGIN TRY
    EXEC publicidad.SP_ABM_Anunciante 'ALTA', NULL, 'TEST PU20 Marca Global Mod', -1;
    PRINT '2.C: FALLÓ - permitió anunciante duplicado y país inexistente.';
END TRY
BEGIN CATCH
    PRINT '2.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 2.D BAJA exitosa.
BEGIN TRY
    EXEC publicidad.SP_ABM_Anunciante 'BAJA', @idAnunc2;
    PRINT '2.D: OK - baja de anunciante sin piezas.';
END TRY
BEGIN CATCH
    PRINT '2.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: publicidad.SP_ABM_Pieza
-- =========================================================================
PRINT '--- TEST 3: SP_ABM_Pieza ---';

DECLARE @idPieza1 INT, @idPieza2 INT;

-- 3.A ALTA exitosa de 2 piezas publicitarias.
BEGIN TRY
    EXEC publicidad.SP_ABM_Pieza 'ALTA', @idPieza1 OUTPUT, @idAnunc1, @idIdioma, 'Spot Oficial A', 'Banner LED perimetral A';
    EXEC publicidad.SP_ABM_Pieza 'ALTA', @idPieza2 OUTPUT, @idAnunc1, @idIdioma, 'Spot Oficial B', 'Banner LED perimetral B';
    PRINT '3.A: OK - 2 piezas publicitarias dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.B BAJA bloqueada de Anunciante por tener piezas asociadas.
BEGIN TRY
    EXEC publicidad.SP_ABM_Anunciante 'BAJA', @idAnunc1;
    PRINT '3.B: FALLÓ - permitió borrar anunciante con piezas asociadas.';
END TRY
BEGIN CATCH
    PRINT '3.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 3.C MODIFICACION exitosa.
BEGIN TRY
    EXEC publicidad.SP_ABM_Pieza 'MODIFICACION', @idPieza1, @idAnunc1, @idIdioma, 'Spot Oficial A', 'Banner LED actualizado';
    PRINT '3.C: OK - pieza modificada.';
END TRY
BEGIN CATCH
    PRINT '3.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.D ALTA fallida (clave única Anunciante+Titulo+Idioma duplicada e idioma inexistente).
BEGIN TRY
    EXEC publicidad.SP_ABM_Pieza 'ALTA', NULL, @idAnunc1, @idIdioma, 'Spot Oficial A', 'Duplicada';
    PRINT '3.D: FALLÓ - permitió pieza duplicada.';
END TRY
BEGIN CATCH
    PRINT '3.D: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 3.E BAJA exitosa y re-alta de @idPieza2.
BEGIN TRY
    EXEC publicidad.SP_ABM_Pieza 'BAJA', @idPieza2;
    EXEC publicidad.SP_ABM_Pieza 'ALTA', @idPieza2 OUTPUT, @idAnunc1, @idIdioma, 'Spot Oficial B', 'Banner LED perimetral B';
    PRINT '3.E: OK - baja y re-alta de pieza publicitaria.';
END TRY
BEGIN CATCH
    PRINT '3.E: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: publicidad.SP_ABM_OrientacionPais
-- =========================================================================
PRINT '--- TEST 4: SP_ABM_OrientacionPais ---';

-- 4.A ALTA exitosa de orientación a 2 países.
BEGIN TRY
    EXEC publicidad.SP_ABM_OrientacionPais 'ALTA', @idPieza1, @idPais1;
    EXEC publicidad.SP_ABM_OrientacionPais 'ALTA', @idPieza1, @idPais2;
    PRINT '4.A: OK - 2 orientaciones de país registradas.';
END TRY
BEGIN CATCH
    PRINT '4.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 4.B ALTA fallida (duplicada) y MODIFICACION no admitida.
BEGIN TRY
    EXEC publicidad.SP_ABM_OrientacionPais 'ALTA', @idPieza1, @idPais1;
    PRINT '4.B.1: FALLÓ - permitió orientación duplicada.';
END TRY
BEGIN CATCH
    PRINT '4.B.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC publicidad.SP_ABM_OrientacionPais 'MODIFICACION', @idPieza1, @idPais1;
    PRINT '4.B.2: FALLÓ - permitió MODIFICACION en OrientacionPais.';
END TRY
BEGIN CATCH
    PRINT '4.B.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 4.C BAJA exitosa de una orientación.
BEGIN TRY
    EXEC publicidad.SP_ABM_OrientacionPais 'BAJA', @idPieza1, @idPais2;
    PRINT '4.C: OK - baja de orientación de país.';
END TRY
BEGIN CATCH
    PRINT '4.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 5: publicidad.SP_ABM_EspacioPublicitario
-- =========================================================================
PRINT '--- TEST 5: SP_ABM_EspacioPublicitario ---';

-- 5.A ALTA exitosa de espacios 1 y 2 en partido 251.
BEGIN TRY
    EXEC publicidad.SP_ABM_EspacioPublicitario 'ALTA', @p251, 1, @idPieza1, 25000.00, @idMonUSD;
    EXEC publicidad.SP_ABM_EspacioPublicitario 'ALTA', @p251, 2, @idPieza2, 18000.00, @idMonUSD;
    PRINT '5.A: OK - 2 espacios publicitarios asignados en 251.';
END TRY
BEGIN CATCH
    PRINT '5.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 5.B BAJA bloqueada de Pieza por estar exhibida en espacios publicitarios.
BEGIN TRY
    EXEC publicidad.SP_ABM_Pieza 'BAJA', @idPieza1;
    PRINT '5.B: FALLÓ - permitió borrar pieza asignada a un partido.';
END TRY
BEGIN CATCH
    PRINT '5.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 5.C MODIFICACION exitosa de tarifa en espacio 1.
BEGIN TRY
    EXEC publicidad.SP_ABM_EspacioPublicitario 'MODIFICACION', @p251, 1, @idPieza1, 32000.00, @idMonUSD;
    PRINT '5.C: OK - tarifa del espacio 1 modificada.';
END TRY
BEGIN CATCH
    PRINT '5.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 5.D ALTA fallida con múltiples errores (espacio 5 fuera de rango, pieza repetida y tarifa negativa) + espacio ocupado.
BEGIN TRY
    EXEC publicidad.SP_ABM_EspacioPublicitario 'ALTA', @p251, 5, @idPieza1, -500.00, @idMonUSD;
    PRINT '5.D.1: FALLÓ - permitió espacio 5, pieza repetida y tarifa negativa.';
END TRY
BEGIN CATCH
    PRINT '5.D.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC publicidad.SP_ABM_EspacioPublicitario 'ALTA', @p251, 1, @idPieza2, 15000.00, @idMonUSD;
    PRINT '5.D.2: FALLÓ - permitió sobrescribir espacio 1 ocupado.';
END TRY
BEGIN CATCH
    PRINT '5.D.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 5.E BAJA exitosa del espacio 2.
BEGIN TRY
    EXEC publicidad.SP_ABM_EspacioPublicitario 'BAJA', @p251, 2;
    PRINT '5.E: OK - espacio publicitario 2 eliminado.';
END TRY
BEGIN CATCH
    PRINT '5.E: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
SELECT 'Orientaciones activas de Pieza 1 (esperado: 1)' AS Control, COUNT(*) AS Cantidad
FROM publicidad.OrientacionPais WHERE IdPieza = @idPieza1;

SELECT 'Espacios activos en 251 (esperado: 1, Tarifa 32000.00 USD)' AS Control,
       ep.NumeroEspacio, p.Titulo, ep.TarifaPublicitaria, m.Codigo AS Moneda
FROM publicidad.EspacioPublicitario AS ep
INNER JOIN publicidad.Pieza  AS p ON p.IdPieza  = ep.IdPieza
INNER JOIN publicidad.Moneda AS m ON m.IdMoneda = ep.IdMoneda
WHERE ep.IdPartido = @p251;

ROLLBACK TRANSACTION;
GO
