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
Objetivo: Probar publicidad.SP_ASIGNAR_PUBLICIDAD (script 21_SP_AsignarPublicidad.sql), cuyo criterio
          depende del número de espacio y elige la pieza al azar:
          - Espacio 1: pieza del país de la selección local. Espacio 2: pieza del país de la visitante.
          - Espacio 3: pieza de alguno de los 3 países con mayor PBI per cápita.
          - Espacio 4: pieza de alguno de los países en prime time para el horario del partido.
          - Elección aleatoria (se verifica que el resultado pertenezca al conjunto del criterio y que
            con muchas corridas aparezcan piezas distintas), sin repetir piezas dentro de un partido.
          - Partido sin cruce definido (espacios 1 y 2 sin candidata: queda advertencia), espacios cargados
            a mano (se completan solo los libres), sin ninguna candidata y validaciones fallidas.
          Requiere ejecutados los scripts 01 a 21 (usa nucleo.SP_ALTA_Sede y nucleo.SP_ALTA_Partido).
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- PREPARACIÓN DEL ESCENARIO
-- Los partidos se juegan a las 20:00 de 'Argentina Standard Time' (23:00 UTC).
-- Con esa hora: los países con zona 'Argentina Standard Time' están en prime time (20:00) y
-- los de zona 'UTC' no (son las 23:00, y el prime time es de 19:00 a 22:59).
--
--   País   Zona        PBI      Prime time   Pieza (idioma de prueba)
--   AR1    Argentina   15000    sí           Z1  (selección local de 251 y 253)
--   AR2    UTC         48000    no           Z2  (selección visitante de 251 y 253)
--   UT9    UTC         50000    no           Z10 (mismo PBI que MK4: el desempate del top 3 es por IdPais, UT9 se crea antes)
--   MK3    Argentina   60000    sí           Z3
--   MK4    Argentina   50000    sí           Z4
--   MK5    Argentina   40000    sí           Z5
--   MK6    Argentina   30000    sí           Z6
--   MK7    Argentina   20000    sí           Z7
--   MK8    UTC         90000    no           Z8
--   (sin país de orientación)                Z9
-- Cada pieza apunta a un solo país, así que los conjuntos de cada criterio son exactos:
--   Espacio 3 (top 3 PBI: MK8, MK3, UT9)            -> Z8, Z3 o Z10.
--   Espacio 4 (prime time: AR1, MK3..MK7)           -> Z1, Z3, Z4, Z5, Z6 o Z7.
-- Países en prime time entre los de la prueba: AR1, MK3, MK4, MK5, MK6 y MK7 = 6 (más de cuatro).
-- =========================================================================
DELETE FROM publicidad.EspacioPublicitario;
DELETE FROM publicidad.OrientacionPais;
DELETE FROM publicidad.Pieza;
DELETE FROM publicidad.Anunciante;
DELETE FROM publicidad.Moneda;

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST PU21 Confederacion', 'TP21');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TP21');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, PBIPerCapitaUSD, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST PU21 AR1', 'QA', 'QAA', 15000.00, 'Argentina Standard Time', @idConf),
       ('TEST PU21 AR2', 'QB', 'QAB', 48000.00, 'UTC',                     @idConf),
       ('TEST PU21 UT9', 'QI', 'QAI', 50000.00, 'UTC',                     @idConf),
       ('TEST PU21 MK3', 'QC', 'QMC', 60000.00, 'Argentina Standard Time', @idConf),
       ('TEST PU21 MK4', 'QD', 'QMD', 50000.00, 'Argentina Standard Time', @idConf),
       ('TEST PU21 MK5', 'QE', 'QME', 40000.00, 'Argentina Standard Time', @idConf),
       ('TEST PU21 MK6', 'QF', 'QMF', 30000.00, 'Argentina Standard Time', @idConf),
       ('TEST PU21 MK7', 'QG', 'QMG', 20000.00, 'Argentina Standard Time', @idConf),
       ('TEST PU21 MK8', 'QH', 'QMH', 90000.00, 'UTC',                     @idConf);

-- Para que el top 3 de PBI dependa solo de los países de la prueba, se deja sin PBI a los demás
-- (si el seed está cargado, hay países reales con PBI más alto). Se deshace con el ROLLBACK final.
UPDATE nucleo.Pais SET PBIPerCapitaUSD = NULL WHERE CodigoISO3 NOT LIKE 'Q%';

DECLARE @pAR1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QAA');
DECLARE @pAR2 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QAB');
DECLARE @pUT9 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QAI');
DECLARE @pMK3 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QMC');
DECLARE @pMK4 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QMD');
DECLARE @pMK5 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QME');
DECLARE @pMK6 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QMF');
DECLARE @pMK7 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QMG');
DECLARE @pMK8 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QMH');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
VALUES ('QAA', 101, 0, @pAR1, @idGrupo),
       ('QAB', 102, 0, @pAR2, @idGrupo);

DECLARE @idSel1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'QAA');
DECLARE @idSel2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'QAB');

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST PU21 Ciudad', 'Argentina Standard Time', @pAR1);
DECLARE @idCiudad SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST PU21 Ciudad');

DECLARE @idSede TINYINT;
EXEC nucleo.SP_ALTA_Sede
     @nombreEstadio = 'TEST PU21 Estadio',
     @idCiudad      = @idCiudad,
     @capacidad     = 60000,
     @idSede        = @idSede OUTPUT;

-- Cuatro partidos en fase 'Cuartos de final' (sin restricción de grupo), separados por más de 72 h.
--   251: AR1 vs AR2           252: cruce sin definir
--   253: AR1 vs AR2 (otra fecha, para el caso de espacios cargados a mano)
--   254: cruce sin definir (para las validaciones)
DECLARE @idFase TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Cuartos de final');
DECLARE @p251 SMALLINT, @p252 SMALLINT, @p253 SMALLINT, @p254 SMALLINT;

-- En fases eliminatorias SP_ALTA_Partido exige las selecciones en NULL.
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 251, @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = '2026-07-04 20:00', @idPartido = @p251 OUTPUT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 252, @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = '2026-07-08 20:00', @idPartido = @p252 OUTPUT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 253, @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = '2026-07-12 20:00', @idPartido = @p253 OUTPUT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 254, @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = '2026-07-16 20:00', @idPartido = @p254 OUTPUT;

-- Se asignan selecciones a 251 y 253 (252 y 254 quedan con cruce sin definir):
UPDATE nucleo.Partido
SET IdSeleccionLocal = @idSel1, IdSeleccionVisitante = @idSel2
WHERE IdPartido IN (@p251, @p253);

INSERT INTO nucleo.Idioma (Nombre) VALUES ('TEST PU21 Idioma');
DECLARE @idIdioma TINYINT = (SELECT IdIdioma FROM nucleo.Idioma WHERE Nombre = 'TEST PU21 Idioma');

DECLARE @idUSD INT;
EXEC publicidad.SP_ALTA_Moneda @idUSD OUTPUT, 'USD', 'Dolar Estadounidense';

-- Tres anunciantes y diez piezas. El orden de alta define el IdPieza (Z10 antes que Z4 a propósito).
DECLARE @idAnA INT, @idAnB INT, @idAnC INT;
EXEC publicidad.SP_ALTA_Anunciante @idAnA OUTPUT, 'TEST PU21 Anunciante A', @pAR1;
EXEC publicidad.SP_ALTA_Anunciante @idAnB OUTPUT, 'TEST PU21 Anunciante B', @pMK3;
EXEC publicidad.SP_ALTA_Anunciante @idAnC OUTPUT, 'TEST PU21 Anunciante C', @pMK5;

DECLARE @z1 INT, @z2 INT, @z3 INT, @z4 INT, @z5 INT, @z6 INT, @z7 INT, @z8 INT, @z9 INT, @z10 INT;
EXEC publicidad.SP_ALTA_Pieza @z1  OUTPUT, @idAnA, @idIdioma, 'Z1',  NULL;
EXEC publicidad.SP_ALTA_Pieza @z2  OUTPUT, @idAnA, @idIdioma, 'Z2',  NULL;
EXEC publicidad.SP_ALTA_Pieza @z10 OUTPUT, @idAnA, @idIdioma, 'Z10', NULL;
EXEC publicidad.SP_ALTA_Pieza @z3  OUTPUT, @idAnB, @idIdioma, 'Z3',  NULL;
EXEC publicidad.SP_ALTA_Pieza @z4  OUTPUT, @idAnB, @idIdioma, 'Z4',  NULL;
EXEC publicidad.SP_ALTA_Pieza @z5  OUTPUT, @idAnC, @idIdioma, 'Z5',  NULL;
EXEC publicidad.SP_ALTA_Pieza @z6  OUTPUT, @idAnC, @idIdioma, 'Z6',  NULL;
EXEC publicidad.SP_ALTA_Pieza @z7  OUTPUT, @idAnC, @idIdioma, 'Z7',  NULL;
EXEC publicidad.SP_ALTA_Pieza @z8  OUTPUT, @idAnA, @idIdioma, 'Z8',  NULL;
EXEC publicidad.SP_ALTA_Pieza @z9  OUTPUT, @idAnA, @idIdioma, 'Z9',  NULL;

EXEC publicidad.SP_ALTA_OrientacionPais @z1,  @pAR1;
EXEC publicidad.SP_ALTA_OrientacionPais @z2,  @pAR2;
EXEC publicidad.SP_ALTA_OrientacionPais @z10, @pUT9;
EXEC publicidad.SP_ALTA_OrientacionPais @z3,  @pMK3;
EXEC publicidad.SP_ALTA_OrientacionPais @z4,  @pMK4;
EXEC publicidad.SP_ALTA_OrientacionPais @z5,  @pMK5;
EXEC publicidad.SP_ALTA_OrientacionPais @z6,  @pMK6;
EXEC publicidad.SP_ALTA_OrientacionPais @z7,  @pMK7;
EXEC publicidad.SP_ALTA_OrientacionPais @z8,  @pMK8;
-- Z9 queda sin país de orientación: nunca es candidata.

DECLARE @resultado VARCHAR(200), @advertencia VARCHAR(200), @cantidad INT;
DECLARE @t1 VARCHAR(100), @t2 VARCHAR(100), @t3 VARCHAR(100), @t4 VARCHAR(100);

-- =========================================================================
-- TEST 1: Partido con cruce definido (251: AR1 vs AR2, 20:00 ART = 23:00 UTC)
-- =========================================================================
PRINT '--- TEST 1: un criterio por espacio ---';

-- 1.A Asignación. Resultado esperado (muestra el result set del SP, 4 filas con su criterio):
--   Espacio 1 = Z1  (país de la selección local, siempre)
--   Espacio 2 = Z2  (país de la selección visitante, siempre)
--   Espacio 3 = una de Z8, Z3, Z10  (top 3 de PBI; al azar)
--   Espacio 4 = una de Z3, Z4, Z5, Z6, Z7  (prime time; al azar; Z1 queda afuera porque ya está en el espacio 1)
-- Sin advertencia.
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p251, 25000.00, @idUSD, @advertencia OUTPUT;

    SELECT @t1 = MAX(CASE WHEN e.NumeroEspacio = 1 THEN pz.Titulo END),
           @t2 = MAX(CASE WHEN e.NumeroEspacio = 2 THEN pz.Titulo END),
           @t3 = MAX(CASE WHEN e.NumeroEspacio = 3 THEN pz.Titulo END),
           @t4 = MAX(CASE WHEN e.NumeroEspacio = 4 THEN pz.Titulo END)
    FROM publicidad.EspacioPublicitario AS e
    INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = e.IdPieza
    WHERE e.IdPartido = @p251;

    IF @t1 = 'Z1' AND @t2 = 'Z2'
       AND @t3 IN ('Z8', 'Z3', 'Z10')
       AND @t4 IN ('Z3', 'Z4', 'Z5', 'Z6', 'Z7')
       AND @advertencia IS NULL
        PRINT '1.A: OK - espacios 1 a 4 = ' + @t1 + ',' + @t2 + ',' + @t3 + ',' + @t4 + ' (sin advertencia).';
    ELSE
        PRINT '1.A: FALLÓ - se obtuvo ' + ISNULL(@t1, 'NULL') + ',' + ISNULL(@t2, 'NULL') + ',' + ISNULL(@t3, 'NULL') + ','
              + ISNULL(@t4, 'NULL') + ' (esperado Z1, Z2, una de Z8/Z3/Z10 y una de Z3/Z4/Z5/Z6/Z7).';
END TRY
BEGIN CATCH
    PRINT '1.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.B Cada franja quedó registrada con la tarifa y la moneda recibidas.
-- Resultado esperado: 4 espacios, todos con 25000.00 y la moneda USD.
SELECT @cantidad = COUNT(*)
FROM publicidad.EspacioPublicitario
WHERE IdPartido = @p251 AND TarifaPublicitaria = 25000.00 AND IdMoneda = @idUSD;
IF @cantidad = 4
    PRINT '1.B: OK - los 4 espacios quedaron con tarifa 25000.00 USD.';
ELSE
    PRINT '1.B: FALLÓ - espacios con la tarifa esperada: ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 4).';

-- 1.C Un partido con los cuatro espacios ocupados no admite otra asignación.
-- Resultado esperado: error "ya tiene sus cuatro espacios publicitarios asignados".
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p251, 25000.00, @idUSD;
    PRINT '1.C: FALLÓ - permitió asignar sobre un partido con los cuatro espacios ocupados.';
END TRY
BEGIN CATCH
    PRINT '1.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 2: Elección aleatoria (252: sin cruce definido)
-- =========================================================================
PRINT '--- TEST 2: partido sin cruce y elección aleatoria ---';

-- 2.A Sin selecciones no hay país local ni visitante: los espacios 1 y 2 quedan libres con advertencia;
-- los espacios 3 y 4 se completan con sus criterios.
-- Resultado esperado: espacios 3 y 4 ocupados (Z8/Z3/Z10 y Z3/Z4/Z5/Z6/Z7), 1 y 2 libres y advertencia
-- "sin pieza candidata para los espacios 1, 2".
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p252, 18000.00, @idUSD, @advertencia OUTPUT;

    SELECT @cantidad = COUNT(*) FROM publicidad.EspacioPublicitario WHERE IdPartido = @p252 AND NumeroEspacio IN (1, 2);
    SELECT @t3 = MAX(CASE WHEN e.NumeroEspacio = 3 THEN pz.Titulo END),
           @t4 = MAX(CASE WHEN e.NumeroEspacio = 4 THEN pz.Titulo END)
    FROM publicidad.EspacioPublicitario AS e
    INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = e.IdPieza
    WHERE e.IdPartido = @p252;

    IF @cantidad = 0
       AND @t3 IN ('Z8', 'Z3', 'Z10')
       AND @t4 IN ('Z3', 'Z4', 'Z5', 'Z6', 'Z7')
       AND @advertencia LIKE '%espacios 1, 2%'
        PRINT '2.A: OK - espacios 3 y 4 = ' + @t3 + ',' + @t4 + '; 1 y 2 libres. ' + @advertencia;
    ELSE
        PRINT '2.A: FALLÓ - espacios 3 y 4 = ' + ISNULL(@t3, 'NULL') + ',' + ISNULL(@t4, 'NULL') + '; espacios 1 y 2 ocupados: '
              + CAST(@cantidad AS VARCHAR(10)) + '; advertencia: ' + ISNULL(@advertencia, 'NULL') + '.';
END TRY
BEGIN CATCH
    PRINT '2.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.B Se repite la asignación 30 veces (liberando antes los espacios 3 y 4) y se juntan las piezas
-- elegidas. Resultado esperado: el espacio 3 siempre cae en Z8/Z3/Z10, el 4 en Z3/Z4/Z5/Z6/Z7, nunca la
-- misma pieza en ambos, y en total aparecen al menos 2 piezas distintas en cada espacio (con 3 y 5
-- opciones al azar, la probabilidad de que salga siempre la misma en 30 corridas es despreciable).
DECLARE @vuelta INT = 1, @malas INT = 0, @repetidas INT = 0;
DECLARE @elegidasTest TABLE (Vuelta INT, Espacio TINYINT, Titulo VARCHAR(100));
DECLARE @descarte TABLE (NumeroEspacio TINYINT, IdPieza INT, Titulo VARCHAR(100), Anunciante VARCHAR(100),
                         TarifaPublicitaria DECIMAL(12,2), Moneda CHAR(3), AsignadoAhora BIT, Criterio VARCHAR(60));
BEGIN TRY
    WHILE @vuelta <= 30
    BEGIN
        DELETE FROM publicidad.EspacioPublicitario WHERE IdPartido = @p252;
        DELETE FROM @descarte;
        INSERT INTO @descarte EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p252, 18000.00, @idUSD;   -- el result set no se usa

        INSERT INTO @elegidasTest (Vuelta, Espacio, Titulo)
        SELECT @vuelta, e.NumeroEspacio, pz.Titulo
        FROM publicidad.EspacioPublicitario AS e
        INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = e.IdPieza
        WHERE e.IdPartido = @p252;

        SET @vuelta += 1;
    END;

    SELECT @malas = COUNT(*) FROM @elegidasTest
    WHERE (Espacio = 3 AND Titulo NOT IN ('Z8', 'Z3', 'Z10'))
       OR (Espacio = 4 AND Titulo NOT IN ('Z3', 'Z4', 'Z5', 'Z6', 'Z7'));

    SELECT @repetidas = COUNT(*)
    FROM (SELECT Vuelta FROM @elegidasTest GROUP BY Vuelta HAVING COUNT(DISTINCT Titulo) < COUNT(*)) AS x;

    DECLARE @distintas3 INT = (SELECT COUNT(DISTINCT Titulo) FROM @elegidasTest WHERE Espacio = 3),
            @distintas4 INT = (SELECT COUNT(DISTINCT Titulo) FROM @elegidasTest WHERE Espacio = 4);

    IF @malas = 0 AND @repetidas = 0 AND @distintas3 >= 2 AND @distintas4 >= 2
        PRINT '2.B: OK - en 30 corridas: ' + CAST(@distintas3 AS VARCHAR(10)) + ' piezas distintas en el espacio 3 y '
              + CAST(@distintas4 AS VARCHAR(10)) + ' en el espacio 4, todas dentro de su criterio y sin repetir pieza.';
    ELSE
        PRINT '2.B: FALLÓ - fuera de criterio: ' + CAST(@malas AS VARCHAR(10)) + ', corridas con pieza repetida: '
              + CAST(@repetidas AS VARCHAR(10)) + ', distintas en espacio 3: ' + CAST(@distintas3 AS VARCHAR(10))
              + ', en espacio 4: ' + CAST(@distintas4 AS VARCHAR(10)) + '.';
END TRY
BEGIN CATCH
    PRINT '2.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: Partido con espacios cargados a mano (253: AR1 vs AR2): se completan solo los libres
-- =========================================================================
PRINT '--- TEST 3: se completan solo los espacios libres ---';

-- 3.A Se cargan a mano los espacios 2 (Z5) y 4 (Z6) con tarifa 1000.00.
-- Resultado esperado: alta exitosa de 2 espacios.
BEGIN TRY
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p253, 2, @z5, 1000.00, @idUSD;
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p253, 4, @z6, 1000.00, @idUSD;
    PRINT '3.A: OK - espacios 2 y 4 cargados a mano.';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.B Asignación automática con tarifa 30000.00. Resultado esperado:
--   Espacio 1 = Z1 (nuevo, país de la selección local)   Espacio 2 = Z5 (manual, no se toca)
--   Espacio 3 = una de Z8, Z3, Z10 (nuevo, top 3 de PBI) Espacio 4 = Z6 (manual, no se toca)
-- El espacio 2 NO se completa con la visitante (Z2): el número ocupado no se toca.
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p253, 30000.00, @idUSD, @advertencia OUTPUT;

    SELECT @t1 = MAX(CASE WHEN e.NumeroEspacio = 1 THEN pz.Titulo END),
           @t2 = MAX(CASE WHEN e.NumeroEspacio = 2 THEN pz.Titulo END),
           @t3 = MAX(CASE WHEN e.NumeroEspacio = 3 THEN pz.Titulo END),
           @t4 = MAX(CASE WHEN e.NumeroEspacio = 4 THEN pz.Titulo END)
    FROM publicidad.EspacioPublicitario AS e
    INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = e.IdPieza
    WHERE e.IdPartido = @p253;

    IF @t1 = 'Z1' AND @t2 = 'Z5' AND @t3 IN ('Z8', 'Z3', 'Z10') AND @t4 = 'Z6' AND @advertencia IS NULL
        PRINT '3.B: OK - espacios 1 a 4 = ' + @t1 + ',' + @t2 + ',' + @t3 + ',' + @t4 + '.';
    ELSE
        PRINT '3.B: FALLÓ - se obtuvo ' + ISNULL(@t1, 'NULL') + ',' + ISNULL(@t2, 'NULL') + ',' + ISNULL(@t3, 'NULL') + ','
              + ISNULL(@t4, 'NULL') + ' (esperado Z1,Z5,una de Z8/Z3/Z10,Z6).';
END TRY
BEGIN CATCH
    PRINT '3.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.C Los espacios cargados a mano conservan su tarifa; los nuevos toman la de la corrida.
-- Resultado esperado: espacios 2 y 4 con 1000.00; espacios 1 y 3 con 30000.00.
SELECT @cantidad = COUNT(*)
FROM publicidad.EspacioPublicitario
WHERE IdPartido = @p253
  AND ((NumeroEspacio IN (2, 4) AND TarifaPublicitaria = 1000.00)
    OR (NumeroEspacio IN (1, 3) AND TarifaPublicitaria = 30000.00));
IF @cantidad = 4
    PRINT '3.C: OK - tarifas manuales intactas y tarifas nuevas correctas.';
ELSE
    PRINT '3.C: FALLÓ - espacios con la tarifa esperada: ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 4).';

-- =========================================================================
-- TEST 4: Sin candidatas para los espacios libres (254)
-- =========================================================================
PRINT '--- TEST 4: ninguna pieza candidata para el espacio libre ---';

-- 4.A Se cargan a mano los espacios 1, 2 y 4 con Z8, Z3 y Z10, que son todas las piezas del top 3 de PBI.
-- Queda libre el espacio 3 y no queda ninguna pieza de su criterio sin usar en el partido.
-- Resultado esperado: error "No hay piezas publicitarias candidatas" y el espacio 3 sigue libre.
BEGIN TRY
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p254, 1, @z1, 500.00, @idUSD;
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p254, 2, @z2, 500.00, @idUSD;
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p254, 3, @z3, 500.00, @idUSD;

    EXEC publicidad.SP_BAJA_OrientacionPais @z5,  @pMK5;
    EXEC publicidad.SP_BAJA_OrientacionPais @z6,  @pMK6;
    EXEC publicidad.SP_BAJA_OrientacionPais @z7,  @pMK7;
    EXEC publicidad.SP_BAJA_OrientacionPais @z8,  @pMK8;
    EXEC publicidad.SP_BAJA_OrientacionPais @z10, @pUT9;

    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p254, 500.00, @idUSD;
    PRINT '4.A: FALLÓ - permitió asignar sin piezas candidatas.';
END TRY
BEGIN CATCH
    SELECT @cantidad = COUNT(*) FROM publicidad.EspacioPublicitario WHERE IdPartido = @p254 AND NumeroEspacio = 3;
    IF @cantidad = 0 AND ERROR_MESSAGE() LIKE '%No hay piezas publicitarias candidatas%'
        PRINT '4.A: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '4.A: FALLÓ - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 5: Validaciones fallidas (cada caso informa todos los errores en un único mensaje)
-- =========================================================================
PRINT '--- TEST 5: validaciones ---';

-- 5.A Partido inexistente, tarifa negativa y moneda inexistente juntos.
-- Resultado esperado: un único error con 3 renglones (partido, tarifa y moneda).
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD -1, -10.00, -1;
    PRINT '5.A: FALLÓ - permitió partido, tarifa y moneda inválidos.';
END TRY
BEGIN CATCH
    PRINT '5.A: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 5.B Tarifa y moneda en NULL sobre el partido 251, que ya tiene sus cuatro espacios.
-- Resultado esperado: un único error con 3 renglones (tarifa, moneda y partido sin espacios libres).
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p251, NULL, NULL;
    PRINT '5.B: FALLÓ - permitió tarifa y moneda NULL.';
END TRY
BEGIN CATCH
    PRINT '5.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 5.C Partido sin piezas candidatas: se quita la orientación de todas las piezas.
-- Resultado esperado: error "No hay piezas publicitarias candidatas".
-- Se usa un partido nuevo sin espacios (255, sin cruce).
DECLARE @p255 SMALLINT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 255, @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = '2026-07-20 20:00', @idPartido = @p255 OUTPUT;
DELETE FROM publicidad.OrientacionPais;
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p255, 500.00, @idUSD;
    PRINT '5.C: FALLÓ - permitió asignar sin piezas candidatas.';
END TRY
BEGIN CATCH
    PRINT '5.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
SELECT 'Espacios por partido (esperado: 251=4, 252=2, 253=4, 254=3, 255=0)' AS Control,
       pa.NumeroPartido, COUNT(e.NumeroEspacio) AS Espacios
FROM nucleo.Partido AS pa
LEFT JOIN publicidad.EspacioPublicitario AS e ON e.IdPartido = pa.IdPartido
WHERE pa.NumeroPartido BETWEEN 251 AND 255
GROUP BY pa.NumeroPartido
ORDER BY pa.NumeroPartido;

ROLLBACK TRANSACTION;
GO
