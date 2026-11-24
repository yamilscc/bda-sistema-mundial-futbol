/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar los stored procedures ABM del módulo publicidad, uno por operación y tabla (script 20_SP_ABM_Publicidad.sql):
          - publicidad.SP_ALTA/MODIFICACION/BAJA_Moneda
          - publicidad.SP_ALTA/MODIFICACION/BAJA_Anunciante
          - publicidad.SP_ALTA/MODIFICACION/BAJA_Campania
          - publicidad.SP_ALTA/MODIFICACION/BAJA_Pieza (la pieza cuelga de una campaña)
          - publicidad.SP_ALTA/BAJA_OrientacionPais
          - publicidad.SP_ALTA/MODIFICACION/BAJA_Tarifa
          - publicidad.SP_ALTA/MODIFICACION/BAJA_EspacioPublicitario (inmutable si el partido está Finalizado)
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
DELETE FROM publicidad.Campania;
DELETE FROM publicidad.Anunciante;
DELETE FROM publicidad.Tarifa;
DELETE FROM publicidad.CotizacionMoneda;
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
-- TEST 1: publicidad.SP_ALTA/MODIFICACION/BAJA_Moneda
-- =========================================================================
PRINT '--- TEST 1: SP_ALTA/MODIFICACION/BAJA_Moneda ---';

DECLARE @idMonUSD INT, @idMonEUR INT, @idMonARS INT;

-- 1.A ALTA exitosa de 3 monedas.
BEGIN TRY
    EXEC publicidad.SP_ALTA_Moneda @idMonUSD OUTPUT, 'USD', 'Dolar Estadounidense';
    EXEC publicidad.SP_ALTA_Moneda @idMonEUR OUTPUT, 'EUR', 'Euro';
    EXEC publicidad.SP_ALTA_Moneda @idMonARS OUTPUT, 'ARS', 'Peso Argentino';
    PRINT '1.A: OK - 3 monedas dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '1.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.B MODIFICACION exitosa.
BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_Moneda @idMonEUR, 'EUR', 'Euro Europeo';
    PRINT '1.B: OK - moneda EUR modificada.';
END TRY
BEGIN CATCH
    PRINT '1.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.C ALTA fallida con múltiples errores (código inválido y nombre duplicado) y modificación de una moneda inexistente.
BEGIN TRY
    EXEC publicidad.SP_ALTA_Moneda NULL, '12A', 'Dolar Estadounidense';
    PRINT '1.C.1: FALLÓ - permitió código inválido y nombre duplicado.';
END TRY
BEGIN CATCH
    PRINT '1.C.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_Moneda -1, 'JPY', 'Yen';
    PRINT '1.C.2: FALLÓ - permitió modificar una moneda inexistente.';
END TRY
BEGIN CATCH
    PRINT '1.C.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 1.D BAJA exitosa.
BEGIN TRY
    EXEC publicidad.SP_BAJA_Moneda @idMonEUR;
    PRINT '1.D: OK - baja de moneda EUR sin espacios, tarifas ni cotizaciones asociadas.';
END TRY
BEGIN CATCH
    PRINT '1.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.E Moneda con cotizaciones (CotizacionMoneda referencia a Moneda por el código ISO):
-- la baja y el cambio de código se bloquean con el mensaje del SP; cambiar solo el nombre se permite.
INSERT INTO publicidad.CotizacionMoneda (MonedaBase, Moneda, Fecha, Tasa) VALUES ('USD', 'ARS', '2026-06-01', 1200.00);

BEGIN TRY
    EXEC publicidad.SP_BAJA_Moneda @idMonARS;
    PRINT '1.E.1: FALLÓ - permitió borrar una moneda con cotizaciones.';
END TRY
BEGIN CATCH
    PRINT '1.E.1: ' + CASE WHEN ERROR_NUMBER() = 52000 THEN 'OK (Bloqueado) - ' ELSE 'FALLÓ (no lo validó el SP) - ' END
          + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_Moneda @idMonARS, 'ARG', 'Peso Argentino';
    PRINT '1.E.2: FALLÓ - permitió cambiar el código de una moneda con cotizaciones.';
END TRY
BEGIN CATCH
    PRINT '1.E.2: ' + CASE WHEN ERROR_NUMBER() = 52000 THEN 'OK (Bloqueado) - ' ELSE 'FALLÓ (no lo validó el SP) - ' END
          + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_Moneda @idMonARS, 'ARS', 'Peso de la República Argentina';
    PRINT '1.E.3: OK - con cotizaciones se puede cambiar el nombre (no el código).';
END TRY
BEGIN CATCH
    PRINT '1.E.3: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: publicidad.SP_ALTA/MODIFICACION/BAJA_Anunciante
-- =========================================================================
PRINT '--- TEST 2: SP_ALTA/MODIFICACION/BAJA_Anunciante ---';

DECLARE @idAnunc1 INT, @idAnunc2 INT;

-- 2.A ALTA exitosa de 2 anunciantes.
BEGIN TRY
    EXEC publicidad.SP_ALTA_Anunciante @idAnunc1 OUTPUT, 'TEST PU20 Marca Global', @idPais1;
    EXEC publicidad.SP_ALTA_Anunciante @idAnunc2 OUTPUT, 'TEST PU20 Marca Temp',   @idPais2;
    PRINT '2.A: OK - 2 anunciantes dados de alta.';
END TRY
BEGIN CATCH
    PRINT '2.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.B MODIFICACION exitosa.
BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_Anunciante @idAnunc1, 'TEST PU20 Marca Global Mod', @idPais2;
    PRINT '2.B: OK - anunciante modificado.';
END TRY
BEGIN CATCH
    PRINT '2.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.C ALTA fallida (nombre duplicado y país inexistente).
BEGIN TRY
    EXEC publicidad.SP_ALTA_Anunciante NULL, 'TEST PU20 Marca Global Mod', -1;
    PRINT '2.C: FALLÓ - permitió anunciante duplicado y país inexistente.';
END TRY
BEGIN CATCH
    PRINT '2.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 2.D BAJA exitosa.
BEGIN TRY
    EXEC publicidad.SP_BAJA_Anunciante @idAnunc2;
    PRINT '2.D: OK - baja de anunciante sin campañas.';
END TRY
BEGIN CATCH
    PRINT '2.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: publicidad.SP_ALTA/MODIFICACION/BAJA_Campania
-- =========================================================================
PRINT '--- TEST 3: SP_ALTA/MODIFICACION/BAJA_Campania ---';

DECLARE @idCamp1 INT, @idCamp2 INT, @idCamp3 INT;

-- 3.A ALTA exitosa de 3 campañas del anunciante 1 (una con todos los datos y otra de un solo día).
BEGIN TRY
    EXEC publicidad.SP_ALTA_Campania @idCamp1 OUTPUT, @idAnunc1, 'TEST PU20 Campaña Mundial', 'Marca Global', 'Agencia Uno', '2026-06-01', '2026-07-19';
    EXEC publicidad.SP_ALTA_Campania @idCamp2 OUTPUT, @idAnunc1, 'TEST PU20 Campaña Final';
    EXEC publicidad.SP_ALTA_Campania @idCamp3 OUTPUT, @idAnunc1, 'TEST PU20 Campaña Un Día', NULL, NULL, '2026-06-11', '2026-06-11';
    PRINT '3.A: OK - 3 campañas dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.B MODIFICACION exitosa: cambia agencia y fechas; marca y agencia en blanco se guardan como NULL.
BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_Campania @idCamp2, @idAnunc1, 'TEST PU20 Campaña Final', '  ', '', '2026-07-01', '2026-07-19';
    IF EXISTS (SELECT 1 FROM publicidad.Campania
               WHERE IdCampania = @idCamp2 AND Marca IS NULL AND Agencia IS NULL AND FechaDesde = '2026-07-01')
        PRINT '3.B: OK - campaña modificada (marca y agencia vacías quedan en NULL).';
    ELSE
        PRINT '3.B: FALLÓ - la campaña no quedó con los datos esperados.';
END TRY
BEGIN CATCH
    PRINT '3.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.C ALTA fallida con múltiples errores: título repetido para el anunciante y fecha de fin anterior a la de inicio.
BEGIN TRY
    EXEC publicidad.SP_ALTA_Campania NULL, @idAnunc1, 'TEST PU20 Campaña Mundial', NULL, NULL, '2026-07-19', '2026-06-01';
    PRINT '3.C.1: FALLÓ - permitió título repetido y fechas invertidas.';
END TRY
BEGIN CATCH
    PRINT '3.C.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 3.C.2 ALTA fallida: anunciante inexistente y título vacío (solo espacios).
BEGIN TRY
    EXEC publicidad.SP_ALTA_Campania NULL, -1, '   ';
    PRINT '3.C.2: FALLÓ - permitió anunciante inexistente y título vacío.';
END TRY
BEGIN CATCH
    PRINT '3.C.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 3.C.3 MODIFICACION fallida: campaña inexistente.
BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_Campania -1, @idAnunc1, 'TEST PU20 Campaña Fantasma';
    PRINT '3.C.3: FALLÓ - permitió modificar una campaña inexistente.';
END TRY
BEGIN CATCH
    PRINT '3.C.3: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 3.D BAJA bloqueada de Anunciante por tener campañas asociadas.
BEGIN TRY
    EXEC publicidad.SP_BAJA_Anunciante @idAnunc1;
    PRINT '3.D: FALLÓ - permitió borrar anunciante con campañas asociadas.';
END TRY
BEGIN CATCH
    PRINT '3.D: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 3.E BAJA exitosa de una campaña sin piezas.
BEGIN TRY
    EXEC publicidad.SP_BAJA_Campania @idCamp3;
    PRINT '3.E: OK - baja de campaña sin piezas.';
END TRY
BEGIN CATCH
    PRINT '3.E: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: publicidad.SP_ALTA/MODIFICACION/BAJA_Pieza
-- =========================================================================
PRINT '--- TEST 4: SP_ALTA/MODIFICACION/BAJA_Pieza ---';

DECLARE @idPieza1 INT, @idPieza2 INT, @idPieza3 INT;

-- 4.A ALTA exitosa de 2 piezas publicitarias en la campaña 1.
BEGIN TRY
    EXEC publicidad.SP_ALTA_Pieza @idPieza1 OUTPUT, @idCamp1, @idIdioma, 'Spot Oficial A', 'Banner LED perimetral A';
    EXEC publicidad.SP_ALTA_Pieza @idPieza2 OUTPUT, @idCamp1, @idIdioma, 'Spot Oficial B', 'Banner LED perimetral B';
    PRINT '4.A: OK - 2 piezas publicitarias dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '4.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 4.B Caso límite exitoso: mismo título e idioma en otra campaña del mismo anunciante (la unicidad es por campaña).
BEGIN TRY
    EXEC publicidad.SP_ALTA_Pieza @idPieza3 OUTPUT, @idCamp2, @idIdioma, 'Spot Oficial A', 'Versión para la final';
    PRINT '4.B: OK - pieza con el mismo título en otra campaña.';
END TRY
BEGIN CATCH
    PRINT '4.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 4.C BAJA bloqueada de Campania por tener piezas asociadas.
BEGIN TRY
    EXEC publicidad.SP_BAJA_Campania @idCamp1;
    PRINT '4.C: FALLÓ - permitió borrar una campaña con piezas asociadas.';
END TRY
BEGIN CATCH
    PRINT '4.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 4.D MODIFICACION exitosa.
BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_Pieza @idPieza1, @idCamp1, @idIdioma, 'Spot Oficial A', 'Banner LED actualizado';
    PRINT '4.D: OK - pieza modificada.';
END TRY
BEGIN CATCH
    PRINT '4.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 4.E ALTA fallida (clave única Campania+Titulo+Idioma duplicada) y con campaña e idioma inexistentes.
BEGIN TRY
    EXEC publicidad.SP_ALTA_Pieza NULL, @idCamp1, @idIdioma, 'Spot Oficial A', 'Duplicada';
    PRINT '4.E.1: FALLÓ - permitió pieza duplicada en la campaña.';
END TRY
BEGIN CATCH
    PRINT '4.E.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC publicidad.SP_ALTA_Pieza NULL, -1, 0, 'Pieza huérfana';
    PRINT '4.E.2: FALLÓ - permitió pieza con campaña e idioma inexistentes.';
END TRY
BEGIN CATCH
    PRINT '4.E.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 4.F MODIFICACION fallida: mover la pieza 3 a la campaña 1, donde ya existe 'Spot Oficial A' en el mismo idioma.
BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_Pieza @idPieza3, @idCamp1, @idIdioma, 'Spot Oficial A', 'Versión para la final';
    PRINT '4.F: FALLÓ - permitió duplicar la pieza al cambiarla de campaña.';
END TRY
BEGIN CATCH
    PRINT '4.F: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 4.G BAJA exitosa y re-alta de @idPieza2.
BEGIN TRY
    EXEC publicidad.SP_BAJA_Pieza @idPieza2;
    EXEC publicidad.SP_ALTA_Pieza @idPieza2 OUTPUT, @idCamp1, @idIdioma, 'Spot Oficial B', 'Banner LED perimetral B';
    PRINT '4.G: OK - baja y re-alta de pieza publicitaria.';
END TRY
BEGIN CATCH
    PRINT '4.G: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 5: publicidad.SP_ALTA/BAJA_OrientacionPais
-- =========================================================================
PRINT '--- TEST 5: SP_ALTA/BAJA_OrientacionPais ---';

-- 5.A ALTA exitosa de orientación a 2 países.
BEGIN TRY
    EXEC publicidad.SP_ALTA_OrientacionPais @idPieza1, @idPais1;
    EXEC publicidad.SP_ALTA_OrientacionPais @idPieza1, @idPais2;
    PRINT '5.A: OK - 2 orientaciones de país registradas.';
END TRY
BEGIN CATCH
    PRINT '5.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 5.B ALTA fallida (duplicada) y verificación de que no existe SP de modificación.
BEGIN TRY
    EXEC publicidad.SP_ALTA_OrientacionPais @idPieza1, @idPais1;
    PRINT '5.B.1: FALLÓ - permitió orientación duplicada.';
END TRY
BEGIN CATCH
    PRINT '5.B.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

IF OBJECT_ID('publicidad.SP_MODIFICACION_OrientacionPais', 'P') IS NULL
    PRINT '5.B.2: OK - OrientacionPais es una tabla asociativa: no existe SP de modificación (solo alta y baja).';
ELSE
    PRINT '5.B.2: FALLÓ - existe un SP de modificación para la tabla asociativa.';

-- 5.C BAJA exitosa de una orientación.
BEGIN TRY
    EXEC publicidad.SP_BAJA_OrientacionPais @idPieza1, @idPais2;
    PRINT '5.C: OK - baja de orientación de país.';
END TRY
BEGIN CATCH
    PRINT '5.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 6: publicidad.SP_ALTA/MODIFICACION/BAJA_Tarifa
-- =========================================================================
PRINT '--- TEST 6: SP_ALTA/MODIFICACION/BAJA_Tarifa ---';

DECLARE @idTarifa1 INT, @idTarifa2 INT,
        @idFaseFinal TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Final');

-- 6.A ALTA exitosa: tarifa de cuartos con vigencia explícita y tarifa de la final sin vigencia (toma la fecha de hoy).
BEGIN TRY
    EXEC publicidad.SP_ALTA_Tarifa @idTarifa1 OUTPUT, @idFase, @idMonUSD, 30000.00, '2026-06-01';
    EXEC publicidad.SP_ALTA_Tarifa @idTarifa2 OUTPUT, @idFaseFinal, @idMonUSD, 0.00;
    IF EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE IdTarifa = @idTarifa2 AND VigenciaDesde = CAST(GETDATE() AS DATE))
        PRINT '6.A: OK - 2 tarifas dadas de alta (la de la final con vigencia de hoy y monto 0).';
    ELSE
        PRINT '6.A: FALLÓ - la tarifa sin vigencia no tomó la fecha de hoy.';
END TRY
BEGIN CATCH
    PRINT '6.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 6.B MODIFICACION exitosa del monto.
BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_Tarifa @idTarifa1, @idFase, @idMonUSD, 32000.00, '2026-06-01';
    PRINT '6.B: OK - monto de la tarifa de cuartos modificado.';
END TRY
BEGIN CATCH
    PRINT '6.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 6.C ALTA fallida con múltiples errores: fase y moneda inexistentes y monto negativo.
BEGIN TRY
    EXEC publicidad.SP_ALTA_Tarifa NULL, 0, -1, -0.01, '2026-06-01';
    PRINT '6.C.1: FALLÓ - permitió fase y moneda inexistentes y monto negativo.';
END TRY
BEGIN CATCH
    PRINT '6.C.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 6.C.2 ALTA fallida: misma fase, moneda y vigencia que la tarifa 1.
BEGIN TRY
    EXEC publicidad.SP_ALTA_Tarifa NULL, @idFase, @idMonUSD, 50000.00, '2026-06-01';
    PRINT '6.C.2: FALLÓ - permitió dos tarifas con la misma fase, moneda y vigencia.';
END TRY
BEGIN CATCH
    PRINT '6.C.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 6.C.3 MODIFICACION fallida: dejar la tarifa 2 igual a la 1 (fase, moneda y vigencia); 6.C.4: dejarla sin vigencia.
BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_Tarifa @idTarifa2, @idFase, @idMonUSD, 10.00, '2026-06-01';
    PRINT '6.C.3: FALLÓ - permitió que la modificación repita fase, moneda y vigencia.';
END TRY
BEGIN CATCH
    PRINT '6.C.3: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_Tarifa @idTarifa2, @idFaseFinal, @idMonUSD, 10.00, NULL;
    PRINT '6.C.4: FALLÓ - permitió modificar una tarifa dejándola sin vigencia.';
END TRY
BEGIN CATCH
    PRINT '6.C.4: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 6.D BAJA bloqueada de Moneda por tener tarifas asociadas.
BEGIN TRY
    EXEC publicidad.SP_BAJA_Moneda @idMonUSD;
    PRINT '6.D: FALLÓ - permitió borrar una moneda con tarifas.';
END TRY
BEGIN CATCH
    PRINT '6.D: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 6.E BAJA exitosa de la tarifa de la final y baja fallida de una tarifa inexistente.
BEGIN TRY
    EXEC publicidad.SP_BAJA_Tarifa @idTarifa2;
    PRINT '6.E.1: OK - baja de la tarifa de la final.';
END TRY
BEGIN CATCH
    PRINT '6.E.1: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC publicidad.SP_BAJA_Tarifa @idTarifa2;
    PRINT '6.E.2: FALLÓ - permitió borrar dos veces la misma tarifa.';
END TRY
BEGIN CATCH
    PRINT '6.E.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 7: publicidad.SP_ALTA/MODIFICACION/BAJA_EspacioPublicitario
-- =========================================================================
PRINT '--- TEST 7: SP_ALTA/MODIFICACION/BAJA_EspacioPublicitario ---';

-- 7.A ALTA exitosa de espacios 1, 2 y 3 en partido 251 (el 1 con criterio de asignación, el resto carga manual).
BEGIN TRY
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p251, 1, @idPieza1, 25000.00, @idMonUSD, 'TEST criterio manual';
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p251, 2, @idPieza2, 18000.00, @idMonUSD;
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p251, 3, @idPieza3, 12000.00, @idMonUSD, '   ';
    PRINT '7.A: OK - 3 espacios publicitarios asignados en 251.';
END TRY
BEGIN CATCH
    PRINT '7.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 7.B Datos de asignación: FechaAsignacion se completa sola y el criterio vacío queda en NULL.
IF (SELECT COUNT(*) FROM publicidad.EspacioPublicitario
    WHERE IdPartido = @p251 AND FechaAsignacion >= DATEADD(MINUTE, -5, SYSDATETIME())) = 3
   AND EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdPartido = @p251 AND NumeroEspacio = 1 AND CriterioAsignacion = 'TEST criterio manual')
   AND EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdPartido = @p251 AND NumeroEspacio = 3 AND CriterioAsignacion IS NULL)
    PRINT '7.B: OK - FechaAsignacion completada y CriterioAsignacion guardado (vacío como NULL).';
ELSE
    PRINT '7.B: FALLÓ - FechaAsignacion o CriterioAsignacion no quedaron como se esperaba.';

-- 7.C BAJA bloqueada de Pieza por estar exhibida en espacios publicitarios.
BEGIN TRY
    EXEC publicidad.SP_BAJA_Pieza @idPieza1;
    PRINT '7.C: FALLÓ - permitió borrar pieza asignada a un partido.';
END TRY
BEGIN CATCH
    PRINT '7.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 7.D MODIFICACION exitosa de tarifa en espacio 1 (partido Programado).
BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_EspacioPublicitario @p251, 1, @idPieza1, 32000.00, @idMonUSD;
    PRINT '7.D: OK - tarifa del espacio 1 modificada.';
END TRY
BEGIN CATCH
    PRINT '7.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 7.E ALTA fallida con múltiples errores (espacio 5 fuera de rango, pieza repetida y tarifa negativa) + espacio ocupado.
BEGIN TRY
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p251, 5, @idPieza1, -500.00, @idMonUSD;
    PRINT '7.E.1: FALLÓ - permitió espacio 5, pieza repetida y tarifa negativa.';
END TRY
BEGIN CATCH
    PRINT '7.E.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p251, 1, @idPieza2, 15000.00, @idMonUSD;
    PRINT '7.E.2: FALLÓ - permitió sobrescribir espacio 1 ocupado.';
END TRY
BEGIN CATCH
    PRINT '7.E.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 7.F BAJA exitosa del espacio 2 (partido Programado).
BEGIN TRY
    EXEC publicidad.SP_BAJA_EspacioPublicitario @p251, 2;
    PRINT '7.F: OK - espacio publicitario 2 eliminado.';
END TRY
BEGIN CATCH
    PRINT '7.F: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 7.G Partido Finalizado: los espacios son histórico de facturación y no se modifican ni se eliminan.
-- SP_ALTA_Partido solo crea partidos 'Programado', por lo que el estado se deja como preparación del
-- escenario (cumple CK_Partido_Resultado: el partido tiene ambas selecciones).
UPDATE nucleo.Partido SET Estado = 'Finalizado' WHERE IdPartido = @p251;

BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_EspacioPublicitario @p251, 1, @idPieza1, 1.00, @idMonUSD;
    PRINT '7.G.1: FALLÓ - permitió modificar un espacio de un partido finalizado.';
END TRY
BEGIN CATCH
    PRINT '7.G.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC publicidad.SP_BAJA_EspacioPublicitario @p251, 3;
    PRINT '7.G.2: FALLÓ - permitió eliminar un espacio de un partido finalizado.';
END TRY
BEGIN CATCH
    PRINT '7.G.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 7.G.3 Con el partido finalizado, una modificación con otros errores informa todos juntos.
BEGIN TRY
    EXEC publicidad.SP_MODIFICACION_EspacioPublicitario @p251, 1, -1, -1.00, -1;
    PRINT '7.G.3: FALLÓ - permitió la modificación con errores en un partido finalizado.';
END TRY
BEGIN CATCH
    PRINT '7.G.3: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
SELECT 'Orientaciones activas de Pieza 1 (esperado: 1)' AS Control, COUNT(*) AS Cantidad
FROM publicidad.OrientacionPais WHERE IdPieza = @idPieza1;

SELECT 'Campañas del anunciante 1 (esperado: 2) y piezas por campaña (esperado: 2 y 1)' AS Control,
       c.Titulo, COUNT(p.IdPieza) AS Piezas
FROM publicidad.Campania AS c
LEFT JOIN publicidad.Pieza AS p ON p.IdCampania = c.IdCampania
WHERE c.IdAnunciante = @idAnunc1
GROUP BY c.Titulo
ORDER BY c.Titulo DESC;

SELECT 'Tarifas activas (esperado: 1, Cuartos de final 32000.00 USD)' AS Control,
       f.Nombre AS Fase, t.Monto, m.Codigo AS Moneda, t.VigenciaDesde
FROM publicidad.Tarifa AS t
INNER JOIN nucleo.Fase        AS f ON f.IdFase   = t.IdFase
INNER JOIN publicidad.Moneda  AS m ON m.IdMoneda = t.IdMoneda;

SELECT 'Espacios en 251 finalizado (esperado: 2 -> 1 con 32000.00 USD y 3 con 12000.00 USD, sin cambios tras finalizar)' AS Control,
       ep.NumeroEspacio, p.Titulo, ep.TarifaPublicitaria, m.Codigo AS Moneda, ep.CriterioAsignacion
FROM publicidad.EspacioPublicitario AS ep
INNER JOIN publicidad.Pieza  AS p ON p.IdPieza  = ep.IdPieza
INNER JOIN publicidad.Moneda AS m ON m.IdMoneda = ep.IdMoneda
WHERE ep.IdPartido = @p251
ORDER BY ep.NumeroEspacio;

ROLLBACK TRANSACTION;
GO
