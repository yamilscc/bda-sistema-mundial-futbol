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
Objetivo: Probar los SP del script 22: nucleo.SP_IMPORTAR_FIXTURE_CSV, nucleo.SP_IMPORTAR_PBI_JSON,
          publicidad.SP_IMPORTAR_COTIZACIONES_JSON y publicidad.SP_IMPORTAR_PAUTA_JSON: lote mixto con errores
          parciales en eventos.LogImportacion, re-ejecución idempotente (Upsert), modificación de datos
          existentes, conversión de moneda y validaciones de entrada. La pauta busca la pieza por anunciante,
          título e idioma a través de las campañas del anunciante, y no puede modificar espacios de un partido
          Finalizado. Requiere ejecutados los scripts 01 a 22.
          Los JSON de este test son datos de prueba con el formato de las APIs (no son respuestas reales).
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
          Resultado: no debe aparecer "FALLÓ" en Mensajes.
*/
USE MundialFutbol;
GO
SET NOCOUNT ON;
BEGIN TRANSACTION;

-- =========================================================================
-- ESCENARIO MÍNIMO (AUTOCONTENIDO)
-- =========================================================================
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST IMP Conf', 'TIC');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TIC');
INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, HusoHorarioComercial)
VALUES ('TEST IMP Pais P', 'QP', 'TQP', @idConf, 'Argentina Standard Time'),
       ('TEST IMP Pais A', 'QA', 'TQA', @idConf, 'Argentina Standard Time'),
       ('TEST IMP Pais B', 'QB', 'TQB', @idConf, 'Argentina Standard Time'),
       ('TEST IMP Pais C', 'QC', 'TQC', @idConf, 'Argentina Standard Time'),
       ('TEST IMP Pais X', 'QX', 'TQX', @idConf, 'Argentina Standard Time'),
       ('TEST IMP Pais Y', 'QY', 'TQY', @idConf, 'Argentina Standard Time'),
       ('TEST IMP Pais Z', 'QZ', 'TQZ', @idConf, 'Argentina Standard Time');
IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z') INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');
INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
SELECT p.CodigoISO3, 150 + ROW_NUMBER() OVER (ORDER BY p.CodigoISO3), p.IdPais, @idGrupo
FROM nucleo.Pais AS p WHERE p.CodigoISO3 IN ('TQA', 'TQB', 'TQC');

DECLARE @ok INT, @err INT, @n INT;

-- =========================================================================
-- TEST 1: SP_IMPORTAR_FIXTURE_CSV con lote mixto (3 filas válidas + 4 inválidas)
-- Esperado: Procesadas = 3, ConError = 4, 4 logs, 2 sedes, 2 ciudades, 3 partidos.
-- =========================================================================
INSERT INTO eventos.vw_CargaStagingFixture
    (NumeroPartido, Fase, NombreEstadio, Ciudad, PaisISO3, HusoHorario, Capacidad, Latitud, Longitud, FechaHoraLocal, SeleccionLocal, SeleccionVisitante)
VALUES
    ('245', 'Fase de grupos', 'TEST IMP Estadio 1', 'TEST IMP Ciudad 1', 'TQP', 'Argentina Standard Time', '50000', '-34.603700', '-58.381600', '2026-06-11T20:00:00', 'TQA', 'TQB'),
    ('246', 'Fase de grupos', 'TEST IMP Estadio 1', 'TEST IMP Ciudad 1', 'TQP', 'Argentina Standard Time', '50000', '-34.603700', '-58.381600', '2026-06-15T20:00:00', 'TQA', 'TQC'),
    ('247', 'Fase de grupos', 'TEST IMP Estadio 2', 'TEST IMP Ciudad 2', 'TQP', 'Argentina Standard Time', '40000', '-31.420100', '-64.188800', '2026-06-19T18:00:00', 'TQB', 'TQC'),
    ('abc', 'Fase de grupos', 'TEST IMP Estadio 1', 'TEST IMP Ciudad 1', 'TQP', 'Argentina Standard Time', '50000', '-34.603700', '-58.381600', '2026-06-25T20:00:00', 'TQA', 'TQB'),  -- número inválido
    ('248', 'Fase de grupos', 'TEST IMP Estadio 1', 'TEST IMP Ciudad 1', 'TQP', 'Huso Inexistente',        '50000', '-34.603700', '-58.381600', '2026-06-25T20:00:00', 'TQA', 'TQB'),  -- huso inválido
    ('249', 'Fase de grupos', 'TEST IMP Estadio 1', 'TEST IMP Ciudad 1', 'TQP', 'Argentina Standard Time', '50000', '-34.603700', '-58.381600', '2026-06-25T20:00:00', 'ZZZ', 'TQB'),  -- selección inexistente
    ('250', 'Fase inexistente', 'TEST IMP Estadio 1', 'TEST IMP Ciudad 1', 'TQP', 'Argentina Standard Time', '50000', '-34.603700', '-58.381600', '2026-06-25T20:00:00', 'TQA', 'TQB'); -- fase inexistente
UPDATE eventos.StagingFixture SET NombreArchivo = 'test_fixture.csv' WHERE NombreArchivo = 'PENDIENTE';

EXEC nucleo.SP_IMPORTAR_FIXTURE_CSV @nombreArchivo = 'test_fixture.csv', @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
SELECT '1' AS Test, @ok AS OK_Esperado_3, @err AS Error_Esperado_4,
       (SELECT COUNT(*) FROM eventos.LogImportacion WHERE NombreArchivo = 'test_fixture.csv') AS Logs_Esperado_4,
       (SELECT COUNT(*) FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST IMP%') AS Sedes_Esperado_2,
       (SELECT COUNT(*) FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST IMP%') AS Ciudades_Esperado_2,
       (SELECT COUNT(*) FROM nucleo.Partido WHERE NumeroPartido BETWEEN 245 AND 250) AS Partidos_Esperado_3;
IF @ok <> 3 OR @err <> 4 OR (SELECT COUNT(*) FROM nucleo.Partido WHERE NumeroPartido BETWEEN 245 AND 250) <> 3
    PRINT 'TEST 1 FALLÓ: el lote mixto no dio 3 válidas y 4 con error.';
ELSE PRINT 'TEST 1 OK';

-- =========================================================================
-- TEST 2: Re-ejecución idempotente (no duplica sedes, ciudades ni partidos)
-- Esperado: Procesadas = 3, ConError = 4 (las inválidas se vuelven a informar), mismos totales.
-- =========================================================================
EXEC nucleo.SP_IMPORTAR_FIXTURE_CSV @nombreArchivo = 'test_fixture.csv', @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
SELECT '2' AS Test, @ok AS OK_Esperado_3, @err AS Error_Esperado_4,
       (SELECT COUNT(*) FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST IMP%') AS Sedes_Esperado_2,
       (SELECT COUNT(*) FROM nucleo.Partido WHERE NumeroPartido BETWEEN 245 AND 250) AS Partidos_Esperado_3;
IF @ok <> 3 OR @err <> 4 OR (SELECT COUNT(*) FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST IMP%') <> 2
    PRINT 'TEST 2 FALLÓ: la re-ejecución no fue idempotente.';
ELSE PRINT 'TEST 2 OK';

-- =========================================================================
-- TEST 3: Upsert que modifica (cambia la hora del partido 246: 20:00 -> 21:00 hora local)
-- Esperado: FechaHoraUTC del 246 = 2026-06-16 00:00 (Argentina = UTC-3), sin duplicar.
-- =========================================================================
UPDATE eventos.StagingFixture SET FechaHoraLocal = '2026-06-15T21:00:00'
WHERE NombreArchivo = 'test_fixture.csv' AND NumeroPartido = '246';
EXEC nucleo.SP_IMPORTAR_FIXTURE_CSV @nombreArchivo = 'test_fixture.csv', @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
SELECT '3' AS Test, @ok AS OK_Esperado_3, FechaHoraUTC AS FechaHoraUTC_Esperada_20260616_0000
FROM nucleo.Partido WHERE NumeroPartido = 246;
IF NOT EXISTS (SELECT 1 FROM nucleo.Partido WHERE NumeroPartido = 246 AND FechaHoraUTC = '2026-06-16 00:00:00')
    PRINT 'TEST 3 FALLÓ: el Upsert no actualizó el horario del partido.';
ELSE PRINT 'TEST 3 OK';

-- =========================================================================
-- TEST 4: Validación de cabecera (archivo sin filas en staging)  -> THROW 52000
-- =========================================================================
BEGIN TRY
    EXEC nucleo.SP_IMPORTAR_FIXTURE_CSV @nombreArchivo = 'archivo_inexistente.csv';
    PRINT 'TEST 4 FALLÓ: aceptó un archivo sin filas en staging.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4 OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 5: SP_IMPORTAR_PBI_JSON con errores parciales
-- X tiene dos años (toma el último con valor: 2023), Y solo valores nulos, W no existe, Z válido.
-- Esperado: Procesadas = 2 (X, Z), ConError = 2 (Y, W), PBI de X = 2000.75.
-- =========================================================================
DECLARE @pbi NVARCHAR(MAX) = N'[{"page":1,"pages":1,"per_page":50,"total":5},[
 {"country":{"id":"QX","value":"X"},"countryiso3code":"TQX","date":"2022","value":1000.5},
 {"country":{"id":"QX","value":"X"},"countryiso3code":"TQX","date":"2023","value":2000.75},
 {"country":{"id":"QY","value":"Y"},"countryiso3code":"TQY","date":"2023","value":null},
 {"country":{"id":"QW","value":"W"},"countryiso3code":"QWW","date":"2023","value":3000},
 {"country":{"id":"QZ","value":"Z"},"countryiso3code":"TQZ","date":"2023","value":500}]]';
EXEC nucleo.SP_IMPORTAR_PBI_JSON @nombreArchivo = 'test_pbi.json', @contenidoJSON = @pbi, @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
SELECT '5' AS Test, @ok AS OK_Esperado_2, @err AS Error_Esperado_2,
       (SELECT PBIPerCapitaUSD FROM nucleo.Pais WHERE CodigoISO2 = 'QX') AS PBI_X_Esperado_2000_75,
       (SELECT COUNT(*) FROM eventos.LogImportacion WHERE NombreArchivo = 'test_pbi.json') AS Logs_Esperado_2;
IF @ok <> 2 OR @err <> 2 OR (SELECT PBIPerCapitaUSD FROM nucleo.Pais WHERE CodigoISO2 = 'QX') <> 2000.75
    PRINT 'TEST 5 FALLÓ: importación de PBI incorrecta.';
ELSE PRINT 'TEST 5 OK';

-- TEST 6: re-ejecución idempotente (mismos resultados, PBI sin cambios)
EXEC nucleo.SP_IMPORTAR_PBI_JSON @nombreArchivo = 'test_pbi.json', @contenidoJSON = @pbi, @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
IF @ok <> 2 OR @err <> 2 OR (SELECT PBIPerCapitaUSD FROM nucleo.Pais WHERE CodigoISO2 = 'QZ') <> 500
    PRINT 'TEST 6 FALLÓ: la re-ejecución del PBI no fue idempotente.';
ELSE PRINT 'TEST 6 OK';

-- TEST 7: validaciones de entrada (JSON inválido y respuesta de error de la API) -> THROW 52000
BEGIN TRY
    EXEC nucleo.SP_IMPORTAR_PBI_JSON @nombreArchivo = 'x.json', @contenidoJSON = N'no es json';
    PRINT 'TEST 7 FALLÓ: aceptó un JSON inválido.';
END TRY
BEGIN CATCH PRINT 'TEST 7a OK (Bloqueado): ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY
    EXEC nucleo.SP_IMPORTAR_PBI_JSON @nombreArchivo = 'x.json', @contenidoJSON = N'[{"message":[{"id":"120"}]}]';
    PRINT 'TEST 7 FALLÓ: aceptó una respuesta de error de la API.';
END TRY
BEGIN CATCH PRINT 'TEST 7b OK (Bloqueado): ' + ERROR_MESSAGE(); END CATCH;

-- =========================================================================
-- TEST 8: SP_IMPORTAR_COTIZACIONES_JSON (base USD; ZZZ no está en el catálogo de monedas)
-- Esperado: Procesadas = 3 (USD, EUR, JPY), ConError = 1 (ZZZ), 3 filas en CotizacionMoneda.
-- =========================================================================
INSERT INTO publicidad.Moneda (Codigo, Nombre)
SELECT v.Codigo, v.Nombre FROM (VALUES ('USD', 'Dólar estadounidense'), ('EUR', 'Euro'), ('JPY', 'Yen japonés'), ('ARS', 'Peso argentino')) AS v (Codigo, Nombre)
WHERE NOT EXISTS (SELECT 1 FROM publicidad.Moneda AS m WHERE m.Codigo = v.Codigo);
DELETE FROM publicidad.CotizacionMoneda;
DECLARE @cot NVARCHAR(MAX) = N'{"amount":1.0,"base":"USD","date":"2026-11-20","rates":{"EUR":0.5,"JPY":100,"ZZZ":7}}';
EXEC publicidad.SP_IMPORTAR_COTIZACIONES_JSON @nombreArchivo = 'test_cot.json', @contenidoJSON = @cot, @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
SELECT '8' AS Test, @ok AS OK_Esperado_3, @err AS Error_Esperado_1, (SELECT COUNT(*) FROM publicidad.CotizacionMoneda) AS Filas_Esperado_3;
IF @ok <> 3 OR @err <> 1 OR (SELECT COUNT(*) FROM publicidad.CotizacionMoneda) <> 3
    PRINT 'TEST 8 FALLÓ: importación de cotizaciones incorrecta.';
ELSE PRINT 'TEST 8 OK';

-- TEST 9: re-ejecución con una cotización nueva del mismo día -> actualiza, no duplica
SET @cot = N'{"amount":1.0,"base":"USD","date":"2026-11-20","rates":{"EUR":0.8,"JPY":100}}';
EXEC publicidad.SP_IMPORTAR_COTIZACIONES_JSON @nombreArchivo = 'test_cot.json', @contenidoJSON = @cot, @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
IF (SELECT COUNT(*) FROM publicidad.CotizacionMoneda) <> 3
   OR (SELECT Tasa FROM publicidad.CotizacionMoneda WHERE Moneda = 'EUR') <> 0.8
    PRINT 'TEST 9 FALLÓ: el Upsert de cotizaciones duplicó o no actualizó.';
ELSE PRINT 'TEST 9 OK';
SET @cot = N'{"amount":1.0,"base":"USD","date":"2026-11-20","rates":{"EUR":0.5,"JPY":100}}';
EXEC publicidad.SP_IMPORTAR_COTIZACIONES_JSON @nombreArchivo = 'test_cot.json', @contenidoJSON = @cot, @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;

-- =========================================================================
-- TEST 10: SP_IMPORTAR_PAUTA_JSON (conversión a USD con EUR = 0,5 y JPY = 100 por dólar)
-- Sobre el partido 245: 100 EUR -> 200,00 | 10000 JPY -> 100,00 | 50 USD -> 50,00.
-- Inválidas: moneda inexistente (ZZZ), ARS sin cotización y partido 250 inexistente.
-- Esperado: Procesadas = 3, ConError = 3, 3 espacios cargados.
-- =========================================================================
INSERT INTO nucleo.Idioma (Nombre) VALUES ('TEST IMP Idioma');
DECLARE @idIdioma INT = (SELECT IdIdioma FROM nucleo.Idioma WHERE Nombre = 'TEST IMP Idioma');
INSERT INTO publicidad.Anunciante (Nombre, IdPais) VALUES ('TEST IMP Anunciante', (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TQP'));
DECLARE @idAnu INT = (SELECT IdAnunciante FROM publicidad.Anunciante WHERE Nombre = 'TEST IMP Anunciante');
-- Dos campañas del mismo anunciante. La campaña 2 repite la pieza 'TEST IMP P1' (mismo título e idioma), que
-- se da de alta después: como el archivo no informa la campaña, la pauta debe tomar la de menor IdPieza.
INSERT INTO publicidad.Campania (IdAnunciante, Titulo) VALUES (@idAnu, 'TEST IMP Campaña 1'), (@idAnu, 'TEST IMP Campaña 2');
DECLARE @idCam1 INT = (SELECT IdCampania FROM publicidad.Campania WHERE IdAnunciante = @idAnu AND Titulo = 'TEST IMP Campaña 1');
DECLARE @idCam2 INT = (SELECT IdCampania FROM publicidad.Campania WHERE IdAnunciante = @idAnu AND Titulo = 'TEST IMP Campaña 2');
INSERT INTO publicidad.Pieza (IdCampania, IdIdioma, Titulo) VALUES (@idCam1, @idIdioma, 'TEST IMP P1'), (@idCam1, @idIdioma, 'TEST IMP P2'), (@idCam1, @idIdioma, 'TEST IMP P3');
INSERT INTO publicidad.Pieza (IdCampania, IdIdioma, Titulo) VALUES (@idCam2, @idIdioma, 'TEST IMP P1');
DECLARE @idP1Cam1 INT = (SELECT IdPieza FROM publicidad.Pieza WHERE IdCampania = @idCam1 AND Titulo = 'TEST IMP P1');

DECLARE @pauta NVARCHAR(MAX) = N'[
 {"numeroPartido":245,"numeroEspacio":1,"anunciante":"TEST IMP Anunciante","titulo":"TEST IMP P1","idioma":"TEST IMP Idioma","monto":100,"moneda":"EUR"},
 {"numeroPartido":245,"numeroEspacio":2,"anunciante":"TEST IMP Anunciante","titulo":"TEST IMP P2","idioma":"TEST IMP Idioma","monto":10000,"moneda":"JPY"},
 {"numeroPartido":245,"numeroEspacio":3,"anunciante":"TEST IMP Anunciante","titulo":"TEST IMP P3","idioma":"TEST IMP Idioma","monto":50,"moneda":"USD"},
 {"numeroPartido":245,"numeroEspacio":4,"anunciante":"TEST IMP Anunciante","titulo":"TEST IMP P1","idioma":"TEST IMP Idioma","monto":10,"moneda":"ZZZ"},
 {"numeroPartido":246,"numeroEspacio":1,"anunciante":"TEST IMP Anunciante","titulo":"TEST IMP P1","idioma":"TEST IMP Idioma","monto":9000,"moneda":"ARS"},
 {"numeroPartido":250,"numeroEspacio":1,"anunciante":"TEST IMP Anunciante","titulo":"TEST IMP P1","idioma":"TEST IMP Idioma","monto":10,"moneda":"USD"}]';
DECLARE @idP245 INT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 245);
EXEC publicidad.SP_IMPORTAR_PAUTA_JSON @nombreArchivo = 'test_pauta.json', @contenidoJSON = @pauta, @monedaDestino = 'USD',
                                       @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
SELECT '10' AS Test, @ok AS OK_Esperado_3, @err AS Error_Esperado_3,
       (SELECT COUNT(*) FROM eventos.LogImportacion WHERE NombreArchivo = 'test_pauta.json') AS Logs_Esperado_3;
SELECT '10 - Espacios' AS Detalle, NumeroEspacio, TarifaPublicitaria, m.Codigo AS Moneda
FROM publicidad.EspacioPublicitario AS e INNER JOIN publicidad.Moneda AS m ON m.IdMoneda = e.IdMoneda WHERE e.IdPartido = @idP245 ORDER BY NumeroEspacio;
IF @ok <> 3 OR @err <> 3
   OR (SELECT TarifaPublicitaria FROM publicidad.EspacioPublicitario WHERE IdPartido = @idP245 AND NumeroEspacio = 1) <> 200
   OR (SELECT TarifaPublicitaria FROM publicidad.EspacioPublicitario WHERE IdPartido = @idP245 AND NumeroEspacio = 2) <> 100
   OR (SELECT TarifaPublicitaria FROM publicidad.EspacioPublicitario WHERE IdPartido = @idP245 AND NumeroEspacio = 3) <> 50
   OR (SELECT IdPieza FROM publicidad.EspacioPublicitario WHERE IdPartido = @idP245 AND NumeroEspacio = 1) <> @idP1Cam1
    PRINT 'TEST 10 FALLÓ: la conversión de moneda, el lote mixto o la pieza elegida (menor IdPieza) son incorrectos.';
ELSE PRINT 'TEST 10 OK';

-- TEST 11: re-ejecución idempotente (mismos 3 espacios, sin error de "espacio ocupado")
EXEC publicidad.SP_IMPORTAR_PAUTA_JSON @nombreArchivo = 'test_pauta.json', @contenidoJSON = @pauta, @monedaDestino = 'USD',
                                       @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
IF @ok <> 3 OR @err <> 3 OR (SELECT COUNT(*) FROM publicidad.EspacioPublicitario WHERE IdPartido = @idP245) <> 3
    PRINT 'TEST 11 FALLÓ: la re-ejecución de la pauta no fue idempotente.';
ELSE PRINT 'TEST 11 OK';

-- TEST 12: Upsert que modifica (el monto del espacio 1 pasa a 200 EUR -> 400,00 USD)
SET @pauta = N'[{"numeroPartido":245,"numeroEspacio":1,"anunciante":"TEST IMP Anunciante","titulo":"TEST IMP P1","idioma":"TEST IMP Idioma","monto":200,"moneda":"EUR"}]';
EXEC publicidad.SP_IMPORTAR_PAUTA_JSON @nombreArchivo = 'test_pauta.json', @contenidoJSON = @pauta, @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
IF @ok <> 1 OR @err <> 0
   OR (SELECT TarifaPublicitaria FROM publicidad.EspacioPublicitario WHERE IdPartido = @idP245 AND NumeroEspacio = 1) <> 400
    PRINT 'TEST 12 FALLÓ: el Upsert no modificó la tarifa.';
ELSE PRINT 'TEST 12 OK';

-- TEST 13: moneda destino inexistente -> THROW 52000
BEGIN TRY
    EXEC publicidad.SP_IMPORTAR_PAUTA_JSON @nombreArchivo = 'x.json', @contenidoJSON = @pauta, @monedaDestino = 'QQQ';
    PRINT 'TEST 13 FALLÓ: aceptó una moneda destino inexistente.';
END TRY
BEGIN CATCH PRINT 'TEST 13 OK (Bloqueado): ' + ERROR_MESSAGE(); END CATCH;

-- =========================================================================
-- TEST 14: pauta sobre un partido Finalizado (los espacios son histórico de facturación)
-- Se carga el espacio 1 del partido 246 (50 USD), se finaliza el partido y se re-importa:
--   14.A misma fila: no cambia nada, así que se procesa sin error (no hace falta modificar).
--   14.B monto distinto: se rechaza (queda en LogImportacion) y la tarifa no cambia.
-- SP_ALTA_Partido solo crea partidos 'Programado': el estado se deja como preparación del escenario.
-- =========================================================================
DECLARE @idP246 INT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 246);
SET @pauta = N'[{"numeroPartido":246,"numeroEspacio":1,"anunciante":"TEST IMP Anunciante","titulo":"TEST IMP P2","idioma":"TEST IMP Idioma","monto":50,"moneda":"USD"}]';
EXEC publicidad.SP_IMPORTAR_PAUTA_JSON @nombreArchivo = 'test_pauta_fin.json', @contenidoJSON = @pauta, @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
UPDATE nucleo.Partido SET Estado = 'Finalizado' WHERE IdPartido = @idP246;

EXEC publicidad.SP_IMPORTAR_PAUTA_JSON @nombreArchivo = 'test_pauta_fin.json', @contenidoJSON = @pauta, @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
IF @ok <> 1 OR @err <> 0
    PRINT 'TEST 14.A FALLÓ: la re-importación idéntica sobre un partido finalizado dio error.';
ELSE PRINT 'TEST 14.A OK';

SET @pauta = N'[{"numeroPartido":246,"numeroEspacio":1,"anunciante":"TEST IMP Anunciante","titulo":"TEST IMP P2","idioma":"TEST IMP Idioma","monto":75,"moneda":"USD"}]';
EXEC publicidad.SP_IMPORTAR_PAUTA_JSON @nombreArchivo = 'test_pauta_fin.json', @contenidoJSON = @pauta, @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
SELECT '14.B' AS Test, @ok AS OK_Esperado_0, @err AS Error_Esperado_1,
       (SELECT TarifaPublicitaria FROM publicidad.EspacioPublicitario WHERE IdPartido = @idP246 AND NumeroEspacio = 1) AS Tarifa_Esperada_50;
IF @ok <> 0 OR @err <> 1
   OR (SELECT TarifaPublicitaria FROM publicidad.EspacioPublicitario WHERE IdPartido = @idP246 AND NumeroEspacio = 1) <> 50
   OR NOT EXISTS (SELECT 1 FROM eventos.LogImportacion
                  WHERE NombreArchivo = 'test_pauta_fin.json' AND MensajeError LIKE '%finalizado%')
    PRINT 'TEST 14.B FALLÓ: la pauta modificó un espacio de un partido finalizado o no lo registró en el log.';
ELSE PRINT 'TEST 14.B OK (Bloqueado): el espacio del partido finalizado no se modificó y quedó en LogImportacion.';

-- =========================================================================
-- FIN: se deshacen todos los cambios de la prueba.
-- =========================================================================
ROLLBACK TRANSACTION;
GO
