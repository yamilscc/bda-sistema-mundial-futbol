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
Objetivo: Probar publicidad.SP_IMPORTAR_CAMPANIAS_CSV (script 29_SP_Importacion_Campanias.sql) con un lote chico
          cargado directo en publicidad.StagingCampania (el BULK INSERT lo cubre el lanzador 08):
            1. Validaciones generales agrupadas (archivo sin filas e idioma Español inexistente).
            2. Primera corrida: 2 anunciantes, 3 campañas, 3 piezas y 3 orientaciones; 4 filas procesadas y 5
               inválidas registradas en eventos.LogImportacion; acentos conservados.
            3. Segunda corrida: sin cambios ni duplicados.
            4. Modificación de Marca y Agencia al cambiar el dato (conservando las fechas de la campaña).
            5. País de origen inexistente: todas las filas quedan en el log y no se crea nada.
            6. @crearPiezas = 0: crea anunciante y campaña, sin pieza.
            7. Anunciante existente con otro país: se actualiza el país y se suma la orientación.
          Requiere ejecutados los scripts 01 a 29.
          Funciona con la base recién creada o con el seed cargado. Todo corre dentro de una transacción que se
          deshace al final (ROLLBACK); los datos de prueba llevan el prefijo 'TEST CA29'.
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- PREPARACIÓN DEL ESCENARIO
-- Dos países de prueba (QYA = origen de las corridas, QZA = segundo país) y el idioma Español (si no existe).
-- Lote 'test_campanias.csv' (IdFila en orden de carga):
--   Fila  Anunciante                    Marca       Título                Agencia      Resultado esperado
--   1     TEST CA29 Anunciante Ñandú    Marca Uno   Campaña Única         Agencia Ñ    válida
--   2     TEST CA29 Anunciante Ñandú    (vacía)     Segunda Campaña       Agencia B    válida
--   3     TEST CA29 Anunciante Beta     Marca Beta  Campaña Beta          (vacía)      válida
--   4     (vacío)                       -           Sin anunciante        -            inválida: anunciante obligatorio
--   5     TEST CA29 Anunciante Gamma    -           (vacío)               -            inválida: título obligatorio
--   6     TEST CA29 Anunciante Epsilon  -           101 caracteres        -            inválida: título demasiado largo
--   7     101 caracteres                -           Anunciante largo      -            inválida: anunciante demasiado largo
--   8     TEST CA29 Anunciante Delta    101 chars   Marca larga           -            inválida: marca demasiado larga
--   9     TEST CA29 Anunciante Beta     Marca Beta  Campaña Beta          (vacía)      válida (repite la fila 3: no cambia nada)
-- =========================================================================
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST CA29 Confederacion', 'TC29');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TC29');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, PBIPerCapitaUSD, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST CA29 Pais A', 'QY', 'QYA', 1000.00, 'UTC', @idConf),
       ('TEST CA29 Pais B', 'QZ', 'QZA', 2000.00, 'UTC', @idConf);

DECLARE @paisA INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QYA'),
        @paisB INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QZA');

DECLARE @ok INT, @err INT, @cantidad INT, @mensaje NVARCHAR(2048), @lineas INT;

-- =========================================================================
-- TEST 1: validaciones generales (un único error agrupado, THROW 52000)
-- =========================================================================
PRINT '--- TEST 1: validaciones generales ---';

-- 1.A Archivo sin filas en staging e idioma Español inexistente, con @crearPiezas = 1.
-- Resultado esperado: un único error con 2 renglones ("No hay filas en publicidad.StagingCampania" y
-- "No existe el idioma Español"). Si el seed ya cargó el idioma, el caso se omite (no se puede borrar).
IF EXISTS (SELECT 1 FROM nucleo.Idioma WHERE Nombre = 'Español')
    PRINT '1.A: OMITIDO - el idioma Español ya existe (seed cargado); se prueba con el renglón de archivo vacío en 1.B.';
ELSE
BEGIN TRY
    EXEC publicidad.SP_IMPORTAR_CAMPANIAS_CSV @nombreArchivo = 'no_existe.csv', @codigoISO3Pais = 'QYA', @crearPiezas = 1;
    PRINT '1.A: FALLÓ - permitió importar un archivo sin filas y sin idioma Español.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 2
       AND @mensaje LIKE '%No hay filas en publicidad.StagingCampania%' AND @mensaje LIKE '%No existe el idioma Español%'
        PRINT '1.A: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '1.A: FALLÓ - renglones: ' + CAST(@lineas AS VARCHAR(10)) + ' - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 1.B Nombre de archivo NULL. Resultado esperado: error 52000 con 1 renglón ("El nombre del archivo es obligatorio").
BEGIN TRY
    EXEC publicidad.SP_IMPORTAR_CAMPANIAS_CSV @nombreArchivo = NULL, @crearPiezas = 0;
    PRINT '1.B: FALLÓ - permitió un nombre de archivo NULL.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 1 AND @mensaje LIKE '%El nombre del archivo es obligatorio%'
        PRINT '1.B: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '1.B: FALLÓ - renglones: ' + CAST(@lineas AS VARCHAR(10)) + ' - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 1.C Archivo inexistente con @crearPiezas = 0. Resultado esperado: error 52000 con 1 renglón (archivo sin filas).
BEGIN TRY
    EXEC publicidad.SP_IMPORTAR_CAMPANIAS_CSV @nombreArchivo = 'no_existe.csv', @crearPiezas = 0;
    PRINT '1.C: FALLÓ - permitió importar un archivo sin filas.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 1 AND @mensaje LIKE '%No hay filas en publicidad.StagingCampania%'
        PRINT '1.C: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '1.C: FALLÓ - renglones: ' + CAST(@lineas AS VARCHAR(10)) + ' - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- Desde acá se necesita el idioma Español.
IF NOT EXISTS (SELECT 1 FROM nucleo.Idioma WHERE Nombre = 'Español')
    INSERT INTO nucleo.Idioma (Nombre) VALUES ('Español');
DECLARE @idEspanol INT = (SELECT IdIdioma FROM nucleo.Idioma WHERE Nombre = 'Español');

INSERT INTO publicidad.StagingCampania (NombreArchivo, Anunciante, Marca, Titulo, Agencia, Productora, Periodo, Categorias)
VALUES ('test_campanias.csv', 'TEST CA29 Anunciante Ñandú',   'Marca Uno',  'Campaña Única',   'Agencia Ñ', 'Productora 1', '2026', 'Film'),
       ('test_campanias.csv', 'TEST CA29 Anunciante Ñandú',   '',           'Segunda Campaña', 'Agencia B', '',             '',     'Digital|Film'),
       ('test_campanias.csv', 'TEST CA29 Anunciante Beta',    'Marca Beta', 'Campaña Beta',    '',          '',             '',     ''),
       ('test_campanias.csv', '',                             '',           'Sin anunciante',  '',          '',             '',     ''),
       ('test_campanias.csv', 'TEST CA29 Anunciante Gamma',   '',           '',                '',          '',             '',     ''),
       ('test_campanias.csv', 'TEST CA29 Anunciante Epsilon', '',           REPLICATE('T', 101), '',        '',             '',     ''),
       ('test_campanias.csv', REPLICATE('A', 101),            '',           'Anunciante largo', '',         '',             '',     ''),
       ('test_campanias.csv', 'TEST CA29 Anunciante Delta',   REPLICATE('M', 101), 'Marca larga', '',       '',             '',     ''),
       ('test_campanias.csv', 'TEST CA29 Anunciante Beta',    'Marca Beta', 'Campaña Beta',    '',          '',             '',     '');

-- =========================================================================
-- TEST 2: primera corrida (país de origen QYA, con piezas)
-- =========================================================================
PRINT '--- TEST 2: primera corrida ---';

-- 2.A Resultado esperado: 4 filas procesadas (1, 2, 3 y 9) y 5 con error (4 a 8).
BEGIN TRY
    EXEC publicidad.SP_IMPORTAR_CAMPANIAS_CSV @nombreArchivo = 'test_campanias.csv', @filasProcesadas = @ok OUTPUT,
         @filasConError = @err OUTPUT, @codigoISO3Pais = 'QYA', @crearPiezas = 1;
    IF @ok = 4 AND @err = 5
        PRINT '2.A: OK - 4 filas procesadas y 5 con error.';
    ELSE
        PRINT '2.A: FALLÓ - procesadas ' + CAST(@ok AS VARCHAR(10)) + ', con error ' + CAST(@err AS VARCHAR(10)) + ' (esperado 4 y 5).';
END TRY
BEGIN CATCH
    PRINT '2.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.B Resultado esperado: 2 anunciantes (Ñandú y Beta, con país QYA), 3 campañas, 3 piezas y 3 orientaciones al
-- país QYA; ninguno de los anunciantes de las filas inválidas se creó.
SELECT @cantidad = COUNT(*) FROM publicidad.Anunciante WHERE Nombre LIKE 'TEST CA29%' AND IdPais = @paisA;
IF @cantidad = 2 AND (SELECT COUNT(*) FROM publicidad.Anunciante WHERE Nombre LIKE 'TEST CA29%') = 2
    PRINT '2.B.1: OK - 2 anunciantes de prueba con país QYA.';
ELSE
    PRINT '2.B.1: FALLÓ - anunciantes con país QYA: ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 2 en total).';

SELECT @cantidad = COUNT(*)
FROM publicidad.Campania AS c INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante
WHERE a.Nombre LIKE 'TEST CA29%';
IF @cantidad = 3 PRINT '2.B.2: OK - 3 campañas.';
ELSE PRINT '2.B.2: FALLÓ - campañas: ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 3).';

SELECT @cantidad = COUNT(*)
FROM publicidad.Pieza AS p
INNER JOIN publicidad.Campania  AS c ON c.IdCampania = p.IdCampania
INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante
WHERE a.Nombre LIKE 'TEST CA29%' AND p.IdIdioma = @idEspanol AND p.Titulo = c.Titulo;
IF @cantidad = 3 PRINT '2.B.3: OK - 3 piezas en español con el título de su campaña.';
ELSE PRINT '2.B.3: FALLÓ - piezas: ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 3).';

SELECT @cantidad = COUNT(*)
FROM publicidad.OrientacionPais AS o
INNER JOIN publicidad.Pieza AS p ON p.IdPieza = o.IdPieza
INNER JOIN publicidad.Campania  AS c ON c.IdCampania = p.IdCampania
INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante
WHERE a.Nombre LIKE 'TEST CA29%' AND o.IdPais = @paisA;
IF @cantidad = 3 PRINT '2.B.4: OK - 3 orientaciones al país QYA.';
ELSE PRINT '2.B.4: FALLÓ - orientaciones: ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 3).';

-- 2.C Acentos conservados (comparación binaria). Resultado esperado: el anunciante 'TEST CA29 Anunciante Ñandú',
-- la campaña 'Campaña Única' con marca 'Marca Uno' y agencia 'Agencia Ñ', y la campaña 'Segunda Campaña' sin marca.
IF EXISTS (SELECT 1
           FROM publicidad.Campania AS c INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante
           WHERE a.Nombre COLLATE Latin1_General_BIN2 = 'TEST CA29 Anunciante Ñandú' COLLATE Latin1_General_BIN2
             AND c.Titulo COLLATE Latin1_General_BIN2 = 'Campaña Única' COLLATE Latin1_General_BIN2
             AND c.Marca = 'Marca Uno' AND c.Agencia COLLATE Latin1_General_BIN2 = 'Agencia Ñ' COLLATE Latin1_General_BIN2)
   AND EXISTS (SELECT 1 FROM publicidad.Campania WHERE Titulo = 'Segunda Campaña' AND Marca IS NULL AND Agencia = 'Agencia B')
    PRINT '2.C: OK - acentos y eñes conservados; la marca vacía quedó en NULL.';
ELSE
    PRINT '2.C: FALLÓ - los datos con acentos no coinciden con lo esperado.';

-- 2.D Filas inválidas en eventos.LogImportacion. Resultado esperado: 5 registros del archivo, cada uno con el
-- IdFila de staging de su fila inválida, su motivo y los datos crudos:
--   'Sin anunciante'   -> "El nombre del anunciante es obligatorio"
--   fila sin título    -> "El título de la campaña es obligatorio" (anunciante Gamma)
--   título de 101 car. -> "El título de la campaña supera los 100 caracteres" (anunciante Epsilon)
--   'Anunciante largo' -> "El nombre del anunciante supera los 100 caracteres"
--   'Marca larga'      -> "La marca supera los 100 caracteres" (anunciante Delta)
SELECT @cantidad = COUNT(*)
FROM eventos.LogImportacion AS l
INNER JOIN publicidad.StagingCampania AS s ON s.IdFila = l.IdFilaStaging
WHERE l.NombreArchivo = 'test_campanias.csv'
  AND ((s.Titulo = 'Sin anunciante'    AND l.MensajeError LIKE '%El nombre del anunciante es obligatorio%'          AND l.DatosCrudos LIKE '%Sin anunciante%')
    OR (s.Anunciante LIKE '%Gamma'     AND l.MensajeError LIKE '%El título de la campaña es obligatorio%'           AND l.DatosCrudos LIKE '%Gamma%')
    OR (s.Anunciante LIKE '%Epsilon'   AND l.MensajeError LIKE '%El título de la campaña supera los 100 caracteres%' AND l.DatosCrudos LIKE '%Epsilon%')
    OR (s.Titulo = 'Anunciante largo'  AND l.MensajeError LIKE '%El nombre del anunciante supera los 100 caracteres%' AND l.DatosCrudos LIKE '%Anunciante largo%')
    OR (s.Anunciante LIKE '%Delta'     AND l.MensajeError LIKE '%La marca supera los 100 caracteres%'               AND l.DatosCrudos LIKE '%Delta%'));
IF @cantidad = 5 AND (SELECT COUNT(*) FROM eventos.LogImportacion WHERE NombreArchivo = 'test_campanias.csv') = 5
    PRINT '2.D: OK - las 5 filas inválidas quedaron en el log con su motivo; las válidas se importaron igual.';
ELSE
    PRINT '2.D: FALLÓ - registros del log con el motivo esperado: ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 5 de 5).';

-- =========================================================================
-- TEST 3: segunda corrida del mismo archivo (idempotencia)
-- =========================================================================
PRINT '--- TEST 3: segunda corrida ---';

-- 3.A Resultado esperado: otra vez 4 procesadas y 5 con error (las inválidas siguen inválidas y se vuelven a
-- registrar: 10 registros en el log), y los totales no cambian: 2 anunciantes, 3 campañas, 3 piezas, 3 orientaciones.
BEGIN TRY
    EXEC publicidad.SP_IMPORTAR_CAMPANIAS_CSV @nombreArchivo = 'test_campanias.csv', @filasProcesadas = @ok OUTPUT,
         @filasConError = @err OUTPUT, @codigoISO3Pais = 'QYA', @crearPiezas = 1;
    SELECT @cantidad = (SELECT COUNT(*) FROM publicidad.Anunciante WHERE Nombre LIKE 'TEST CA29%') * 1000
         + (SELECT COUNT(*) FROM publicidad.Campania AS c INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante WHERE a.Nombre LIKE 'TEST CA29%') * 100
         + (SELECT COUNT(*) FROM publicidad.Pieza AS p INNER JOIN publicidad.Campania AS c ON c.IdCampania = p.IdCampania INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante WHERE a.Nombre LIKE 'TEST CA29%') * 10
         + (SELECT COUNT(*) FROM publicidad.OrientacionPais AS o INNER JOIN publicidad.Pieza AS p ON p.IdPieza = o.IdPieza INNER JOIN publicidad.Campania AS c ON c.IdCampania = p.IdCampania INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante WHERE a.Nombre LIKE 'TEST CA29%');
    IF @ok = 4 AND @err = 5 AND @cantidad = 2333
       AND (SELECT COUNT(*) FROM eventos.LogImportacion WHERE NombreArchivo = 'test_campanias.csv') = 10
        PRINT '3.A: OK - segunda corrida sin duplicados: 2 anunciantes, 3 campañas, 3 piezas y 3 orientaciones.';
    ELSE
        PRINT '3.A: FALLÓ - procesadas ' + CAST(@ok AS VARCHAR(10)) + ', con error ' + CAST(@err AS VARCHAR(10))
              + ', totales (anunciantes, campañas, piezas, orientaciones) = ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 4, 5 y 2333).';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: modificación de Marca y Agencia
-- Antes se le cargan fechas a 'Campaña Única' para comprobar que la modificación las conserva.
-- Se cambian en el lote: Marca y Agencia de la fila 1, y solo las mayúsculas de la marca de Beta (filas 3 y 9).
-- =========================================================================
PRINT '--- TEST 4: modificación de datos ---';

UPDATE publicidad.Campania SET FechaDesde = '2026-06-11', FechaHasta = '2026-07-19' WHERE Titulo = 'Campaña Única';
UPDATE publicidad.StagingCampania SET Marca = 'Marca Uno Nueva', Agencia = 'Agencia Ñ Nueva'
WHERE NombreArchivo = 'test_campanias.csv' AND Titulo = 'Campaña Única';
UPDATE publicidad.StagingCampania SET Marca = 'MARCA BETA'
WHERE NombreArchivo = 'test_campanias.csv' AND Titulo = 'Campaña Beta';

-- 4.A Resultado esperado: 4 procesadas y 5 con error; 3 campañas (no se duplicó nada);
--   'Campaña Única': Marca 'Marca Uno Nueva', Agencia 'Agencia Ñ Nueva', fechas 2026-06-11 a 2026-07-19 intactas;
--   'Campaña Beta': Marca 'MARCA BETA' (el cambio de solo mayúsculas también se detecta);
--   'Segunda Campaña': sin cambios (marca NULL, agencia 'Agencia B').
BEGIN TRY
    EXEC publicidad.SP_IMPORTAR_CAMPANIAS_CSV @nombreArchivo = 'test_campanias.csv', @filasProcesadas = @ok OUTPUT,
         @filasConError = @err OUTPUT, @codigoISO3Pais = 'QYA', @crearPiezas = 1;
    IF @ok = 4 AND @err = 5
       AND (SELECT COUNT(*) FROM publicidad.Campania AS c INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante WHERE a.Nombre LIKE 'TEST CA29%') = 3
       AND EXISTS (SELECT 1 FROM publicidad.Campania
                   WHERE Titulo = 'Campaña Única' AND Marca = 'Marca Uno Nueva'
                     AND Agencia COLLATE Latin1_General_BIN2 = 'Agencia Ñ Nueva' COLLATE Latin1_General_BIN2
                     AND FechaDesde = '2026-06-11' AND FechaHasta = '2026-07-19')
       AND EXISTS (SELECT 1 FROM publicidad.Campania WHERE Titulo = 'Campaña Beta' AND Marca COLLATE Latin1_General_BIN2 = 'MARCA BETA' COLLATE Latin1_General_BIN2)
       AND EXISTS (SELECT 1 FROM publicidad.Campania WHERE Titulo = 'Segunda Campaña' AND Marca IS NULL AND Agencia = 'Agencia B')
        PRINT '4.A: OK - Marca y Agencia modificadas, fechas conservadas y sin campañas duplicadas.';
    ELSE
        PRINT '4.A: FALLÓ - procesadas ' + CAST(@ok AS VARCHAR(10)) + ', con error ' + CAST(@err AS VARCHAR(10)) + '; los datos no son los esperados.';
END TRY
BEGIN CATCH
    PRINT '4.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 5: país de origen inexistente
-- =========================================================================
PRINT '--- TEST 5: país inexistente ---';

INSERT INTO publicidad.StagingCampania (NombreArchivo, Anunciante, Marca, Titulo, Agencia)
VALUES ('test_campanias_pais.csv', 'TEST CA29 Anunciante Omega', 'Marca Omega', 'Campaña Omega', 'Agencia O'),
       ('test_campanias_pais.csv', 'TEST CA29 Anunciante Sigma', '',            'Campaña Sigma', '');

-- 5.A Resultado esperado: 0 procesadas, 2 con error ("El país de origen indicado no existe"), 2 registros en el log
-- con sus datos crudos, y ninguno de los dos anunciantes se creó.
BEGIN TRY
    EXEC publicidad.SP_IMPORTAR_CAMPANIAS_CSV @nombreArchivo = 'test_campanias_pais.csv', @filasProcesadas = @ok OUTPUT,
         @filasConError = @err OUTPUT, @codigoISO3Pais = 'ZZZ', @crearPiezas = 1;
    SELECT @cantidad = COUNT(*) FROM eventos.LogImportacion
    WHERE NombreArchivo = 'test_campanias_pais.csv' AND IdFilaStaging IS NOT NULL
      AND MensajeError LIKE '%El país de origen indicado no existe%'
      AND (DatosCrudos LIKE '%Omega%' OR DatosCrudos LIKE '%Sigma%');
    IF @ok = 0 AND @err = 2 AND @cantidad = 2
       AND NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE Nombre IN ('TEST CA29 Anunciante Omega', 'TEST CA29 Anunciante Sigma'))
        PRINT '5.A: OK - país inexistente: 2 filas al log y nada creado.';
    ELSE
        PRINT '5.A: FALLÓ - procesadas ' + CAST(@ok AS VARCHAR(10)) + ', con error ' + CAST(@err AS VARCHAR(10))
              + ', registros del log ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 0, 2 y 2).';
END TRY
BEGIN CATCH
    PRINT '5.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 6: @crearPiezas = 0
-- =========================================================================
PRINT '--- TEST 6: sin crear piezas ---';

-- 6.A Mismo lote con país QYA y @crearPiezas = 0. Resultado esperado: 2 procesadas, 0 con error; los anunciantes
-- Omega y Sigma y sus campañas se crean (con país QYA) y no tienen ninguna pieza.
BEGIN TRY
    EXEC publicidad.SP_IMPORTAR_CAMPANIAS_CSV @nombreArchivo = 'test_campanias_pais.csv', @filasProcesadas = @ok OUTPUT,
         @filasConError = @err OUTPUT, @codigoISO3Pais = 'QYA', @crearPiezas = 0;
    IF @ok = 2 AND @err = 0
       AND (SELECT COUNT(*) FROM publicidad.Campania AS c INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante
            WHERE a.Nombre IN ('TEST CA29 Anunciante Omega', 'TEST CA29 Anunciante Sigma') AND a.IdPais = @paisA) = 2
       AND NOT EXISTS (SELECT 1 FROM publicidad.Pieza AS p INNER JOIN publicidad.Campania AS c ON c.IdCampania = p.IdCampania
                       INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante
                       WHERE a.Nombre IN ('TEST CA29 Anunciante Omega', 'TEST CA29 Anunciante Sigma'))
        PRINT '6.A: OK - 2 campañas nuevas sin piezas.';
    ELSE
        PRINT '6.A: FALLÓ - procesadas ' + CAST(@ok AS VARCHAR(10)) + ', con error ' + CAST(@err AS VARCHAR(10)) + ' (esperado 2 y 0).';
END TRY
BEGIN CATCH
    PRINT '6.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 7: anunciante existente con otro país
-- =========================================================================
PRINT '--- TEST 7: cambio de país del anunciante ---';

INSERT INTO publicidad.StagingCampania (NombreArchivo, Anunciante, Marca, Titulo, Agencia)
VALUES ('test_campanias_pais_b.csv', 'TEST CA29 Anunciante Beta', 'MARCA BETA', 'Campaña Beta', '');

-- 7.A Resultado esperado: 1 procesada; el anunciante Beta pasa al país QZA; sigue 1 sola campaña y 1 sola pieza
-- 'Campaña Beta' (ahora con 2 orientaciones: QYA y QZA); sin anunciantes duplicados.
BEGIN TRY
    EXEC publicidad.SP_IMPORTAR_CAMPANIAS_CSV @nombreArchivo = 'test_campanias_pais_b.csv', @filasProcesadas = @ok OUTPUT,
         @filasConError = @err OUTPUT, @codigoISO3Pais = 'QZA', @crearPiezas = 1;
    IF @ok = 1 AND @err = 0
       AND (SELECT COUNT(*) FROM publicidad.Anunciante WHERE Nombre = 'TEST CA29 Anunciante Beta' AND IdPais = @paisB) = 1
       AND (SELECT COUNT(*) FROM publicidad.Campania AS c INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante
            WHERE a.Nombre = 'TEST CA29 Anunciante Beta') = 1
       AND (SELECT COUNT(*) FROM publicidad.Pieza WHERE Titulo = 'Campaña Beta') = 1
       AND (SELECT COUNT(*) FROM publicidad.OrientacionPais AS o INNER JOIN publicidad.Pieza AS p ON p.IdPieza = o.IdPieza
            WHERE p.Titulo = 'Campaña Beta' AND o.IdPais IN (@paisA, @paisB)) = 2
        PRINT '7.A: OK - Beta pasó al país QZA, sigue con 1 campaña y 1 pieza, y la pieza tiene 2 orientaciones.';
    ELSE
        PRINT '7.A: FALLÓ - procesadas ' + CAST(@ok AS VARCHAR(10)) + ', con error ' + CAST(@err AS VARCHAR(10)) + '; los datos no son los esperados.';
END TRY
BEGIN CATCH
    PRINT '7.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
SELECT 'Totales de prueba (esperado: Anunciantes=4, Campanias=5, Piezas=3)' AS Control,
       (SELECT COUNT(*) FROM publicidad.Anunciante WHERE Nombre LIKE 'TEST CA29%') AS Anunciantes,
       (SELECT COUNT(*) FROM publicidad.Campania AS c INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante WHERE a.Nombre LIKE 'TEST CA29%') AS Campanias,
       (SELECT COUNT(*) FROM publicidad.Pieza AS p INNER JOIN publicidad.Campania AS c ON c.IdCampania = p.IdCampania INNER JOIN publicidad.Anunciante AS a ON a.IdAnunciante = c.IdAnunciante WHERE a.Nombre LIKE 'TEST CA29%') AS Piezas;

ROLLBACK TRANSACTION;
GO
