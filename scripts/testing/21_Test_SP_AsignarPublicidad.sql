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
Objetivo: Probar publicidad.SP_ASIGNAR_PUBLICIDAD (script 21_SP_AsignarPublicidad.sql):
          - Partido que cae en prime time en más de cuatro mercados candidatos: el SP elige solo cuatro.
          - Criterio 1 (país de una selección que juega), criterio 2 (PBI) y criterio 3 (prime time).
          - Partido sin cruce definido, y partido con espacios cargados a mano (se completan los libres).
          - Casos de validación fallida (un único mensaje con todos los errores).
          Requiere ejecutados los scripts 01 a 21 (usa nucleo.SP_ALTA_Sede y
          nucleo.SP_ALTA_Partido).
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
--   UT9    UTC         50000    no           Z10 (se crea ANTES que Z4, para probar el desempate por prime time)
--   MK3    Argentina   60000    sí           Z3
--   MK4    Argentina   50000    sí           Z4  (mismo PBI que UT9)
--   MK5    Argentina   40000    sí           Z5
--   MK6    Argentina   30000    sí           Z6
--   MK7    Argentina   20000    sí           Z7
--   MK8    UTC         90000    no           Z8
--   (sin país de orientación)                Z9
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
EXEC publicidad.SP_ABM_Moneda 'ALTA', @idUSD OUTPUT, 'USD', 'Dolar Estadounidense';

-- Tres anunciantes y diez piezas. El orden de alta define el IdPieza (Z10 antes que Z4 a propósito).
DECLARE @idAnA INT, @idAnB INT, @idAnC INT;
EXEC publicidad.SP_ABM_Anunciante 'ALTA', @idAnA OUTPUT, 'TEST PU21 Anunciante A', @pAR1;
EXEC publicidad.SP_ABM_Anunciante 'ALTA', @idAnB OUTPUT, 'TEST PU21 Anunciante B', @pMK3;
EXEC publicidad.SP_ABM_Anunciante 'ALTA', @idAnC OUTPUT, 'TEST PU21 Anunciante C', @pMK5;

DECLARE @z1 INT, @z2 INT, @z3 INT, @z4 INT, @z5 INT, @z6 INT, @z7 INT, @z8 INT, @z9 INT, @z10 INT;
EXEC publicidad.SP_ABM_Pieza 'ALTA', @z1  OUTPUT, @idAnA, @idIdioma, 'Z1',  NULL;
EXEC publicidad.SP_ABM_Pieza 'ALTA', @z2  OUTPUT, @idAnA, @idIdioma, 'Z2',  NULL;
EXEC publicidad.SP_ABM_Pieza 'ALTA', @z10 OUTPUT, @idAnA, @idIdioma, 'Z10', NULL;
EXEC publicidad.SP_ABM_Pieza 'ALTA', @z3  OUTPUT, @idAnB, @idIdioma, 'Z3',  NULL;
EXEC publicidad.SP_ABM_Pieza 'ALTA', @z4  OUTPUT, @idAnB, @idIdioma, 'Z4',  NULL;
EXEC publicidad.SP_ABM_Pieza 'ALTA', @z5  OUTPUT, @idAnC, @idIdioma, 'Z5',  NULL;
EXEC publicidad.SP_ABM_Pieza 'ALTA', @z6  OUTPUT, @idAnC, @idIdioma, 'Z6',  NULL;
EXEC publicidad.SP_ABM_Pieza 'ALTA', @z7  OUTPUT, @idAnC, @idIdioma, 'Z7',  NULL;
EXEC publicidad.SP_ABM_Pieza 'ALTA', @z8  OUTPUT, @idAnA, @idIdioma, 'Z8',  NULL;
EXEC publicidad.SP_ABM_Pieza 'ALTA', @z9  OUTPUT, @idAnA, @idIdioma, 'Z9',  NULL;

EXEC publicidad.SP_ABM_OrientacionPais 'ALTA', @z1,  @pAR1;
EXEC publicidad.SP_ABM_OrientacionPais 'ALTA', @z2,  @pAR2;
EXEC publicidad.SP_ABM_OrientacionPais 'ALTA', @z10, @pUT9;
EXEC publicidad.SP_ABM_OrientacionPais 'ALTA', @z3,  @pMK3;
EXEC publicidad.SP_ABM_OrientacionPais 'ALTA', @z4,  @pMK4;
EXEC publicidad.SP_ABM_OrientacionPais 'ALTA', @z5,  @pMK5;
EXEC publicidad.SP_ABM_OrientacionPais 'ALTA', @z6,  @pMK6;
EXEC publicidad.SP_ABM_OrientacionPais 'ALTA', @z7,  @pMK7;
EXEC publicidad.SP_ABM_OrientacionPais 'ALTA', @z8,  @pMK8;
-- Z9 queda sin país de orientación: nunca es candidata.

DECLARE @resultado VARCHAR(200), @advertencia VARCHAR(200), @cantidad INT;

-- =========================================================================
-- TEST 1: Partido en prime time en más de cuatro mercados (251: AR1 vs AR2)
-- =========================================================================
PRINT '--- TEST 1: prime time en más de cuatro mercados, se eligen solo cuatro ---';

-- 1.A Precondición: el partido cae en prime time en 6 de los países de la prueba.
-- Resultado esperado: 6.
SELECT @cantidad = COUNT(*)
FROM nucleo.fn_MercadosEnPrimeTime(@p251)
WHERE IdPais IN (@pAR1, @pAR2, @pUT9, @pMK3, @pMK4, @pMK5, @pMK6, @pMK7, @pMK8);
IF @cantidad = 6
    PRINT '1.A: OK - el partido 251 cae en prime time en 6 mercados de la prueba (más de cuatro).';
ELSE
    PRINT '1.A: FALLÓ - mercados en prime time: ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 6).';

-- 1.B Asignación. Resultado esperado (muestra el result set del SP, 4 filas):
--   Espacio 1 = Z2  (criterio 1: país de la selección visitante, PBI 48000)
--   Espacio 2 = Z1  (criterio 1: país de la selección local, PBI 15000)
--   Espacio 3 = Z8  (no participa; el mayor PBI de las restantes: 90000; no está en prime time)
--   Espacio 4 = Z3  (PBI 60000, en prime time)
-- Z4 a Z7 y Z10 quedan afuera por prioridad; Z9 no tiene países de orientación.
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p251, 25000.00, @idUSD, @advertencia OUTPUT;

    SELECT @resultado = STRING_AGG(pz.Titulo, ',') WITHIN GROUP (ORDER BY e.NumeroEspacio)
    FROM publicidad.EspacioPublicitario AS e
    INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = e.IdPieza
    WHERE e.IdPartido = @p251;

    IF @resultado = 'Z2,Z1,Z8,Z3' AND @advertencia IS NULL
        PRINT '1.B: OK - espacios 1 a 4 = ' + @resultado + ' (sin advertencia).';
    ELSE
        PRINT '1.B: FALLÓ - se obtuvo ' + ISNULL(@resultado, 'NULL') + ' (esperado Z2,Z1,Z8,Z3).';
END TRY
BEGIN CATCH
    PRINT '1.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.C Cada franja quedó registrada con la tarifa y la moneda recibidas.
-- Resultado esperado: 4 espacios, todos con 25000.00 y la moneda USD.
SELECT @cantidad = COUNT(*)
FROM publicidad.EspacioPublicitario
WHERE IdPartido = @p251 AND TarifaPublicitaria = 25000.00 AND IdMoneda = @idUSD;
IF @cantidad = 4
    PRINT '1.C: OK - los 4 espacios quedaron con tarifa 25000.00 USD.';
ELSE
    PRINT '1.C: FALLÓ - espacios con la tarifa esperada: ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 4).';

-- 1.D Un partido con los cuatro espacios ocupados no admite otra asignación.
-- Resultado esperado: error "ya tiene sus cuatro espacios publicitarios asignados".
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p251, 25000.00, @idUSD;
    PRINT '1.D: FALLÓ - permitió asignar sobre un partido con los cuatro espacios ocupados.';
END TRY
BEGIN CATCH
    PRINT '1.D: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 2: Partido sin cruce definido (252): no hay criterio 1; decide el PBI y desempata el prime time
-- =========================================================================
PRINT '--- TEST 2: sin selecciones definidas, criterios 2 y 3 ---';

-- 2.A Resultado esperado:
--   Espacio 1 = Z8   (PBI 90000)
--   Espacio 2 = Z3   (PBI 60000)
--   Espacio 3 = Z4   (PBI 50000 y en prime time: gana el desempate a Z10 aunque Z10 tenga menor IdPieza)
--   Espacio 4 = Z10  (PBI 50000, fuera de prime time: queda adelante de Z2, que tiene PBI 48000)
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p252, 18000.00, @idUSD, @advertencia OUTPUT;

    SELECT @resultado = STRING_AGG(pz.Titulo, ',') WITHIN GROUP (ORDER BY e.NumeroEspacio)
    FROM publicidad.EspacioPublicitario AS e
    INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = e.IdPieza
    WHERE e.IdPartido = @p252;

    IF @resultado = 'Z8,Z3,Z4,Z10'
        PRINT '2.A: OK - espacios 1 a 4 = ' + @resultado + '.';
    ELSE
        PRINT '2.A: FALLÓ - se obtuvo ' + ISNULL(@resultado, 'NULL') + ' (esperado Z8,Z3,Z4,Z10).';
END TRY
BEGIN CATCH
    PRINT '2.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: Partido con espacios cargados a mano (253: AR1 vs AR2): se completan solo los libres
-- =========================================================================
PRINT '--- TEST 3: se completan solo los espacios libres ---';

-- 3.A Se cargan a mano los espacios 2 (Z5) y 4 (Z6) con tarifa 1000.00.
-- Resultado esperado: alta exitosa de 2 espacios.
BEGIN TRY
    EXEC publicidad.SP_ABM_EspacioPublicitario 'ALTA', @p253, 2, @z5, 1000.00, @idUSD;
    EXEC publicidad.SP_ABM_EspacioPublicitario 'ALTA', @p253, 4, @z6, 1000.00, @idUSD;
    PRINT '3.A: OK - espacios 2 y 4 cargados a mano.';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.B Asignación automática con tarifa 30000.00. Resultado esperado:
--   Espacio 1 = Z2 (nuevo, criterio 1)      Espacio 2 = Z5 (manual, no se toca)
--   Espacio 3 = Z1 (nuevo, criterio 1)      Espacio 4 = Z6 (manual, no se toca)
-- Z5 y Z6 no se repiten porque ya están asignadas en el partido.
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p253, 30000.00, @idUSD, @advertencia OUTPUT;

    SELECT @resultado = STRING_AGG(pz.Titulo, ',') WITHIN GROUP (ORDER BY e.NumeroEspacio)
    FROM publicidad.EspacioPublicitario AS e
    INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = e.IdPieza
    WHERE e.IdPartido = @p253;

    IF @resultado = 'Z2,Z5,Z1,Z6'
        PRINT '3.B: OK - espacios 1 a 4 = ' + @resultado + '.';
    ELSE
        PRINT '3.B: FALLÓ - se obtuvo ' + ISNULL(@resultado, 'NULL') + ' (esperado Z2,Z5,Z1,Z6).';
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
-- TEST 4: Pocas candidatas: se asigna lo que hay y se informa una advertencia (254)
-- =========================================================================
PRINT '--- TEST 4: menos candidatas que espacios libres ---';

-- 4.A Se cargan a mano los espacios 1 a 3 (Z1, Z2 y Z3) y se quita la orientación de Z5, Z6, Z7, Z8 y Z10.
-- Queda 1 espacio libre (el 4) y una sola candidata con orientación (Z4).
-- Resultado esperado: Z4 se asigna al espacio 4 y no hay advertencia.
BEGIN TRY
    EXEC publicidad.SP_ABM_EspacioPublicitario 'ALTA', @p254, 1, @z1, 500.00, @idUSD;
    EXEC publicidad.SP_ABM_EspacioPublicitario 'ALTA', @p254, 2, @z2, 500.00, @idUSD;
    EXEC publicidad.SP_ABM_EspacioPublicitario 'ALTA', @p254, 3, @z3, 500.00, @idUSD;

    EXEC publicidad.SP_ABM_OrientacionPais 'BAJA', @z5,  @pMK5;
    EXEC publicidad.SP_ABM_OrientacionPais 'BAJA', @z6,  @pMK6;
    EXEC publicidad.SP_ABM_OrientacionPais 'BAJA', @z7,  @pMK7;
    EXEC publicidad.SP_ABM_OrientacionPais 'BAJA', @z8,  @pMK8;
    EXEC publicidad.SP_ABM_OrientacionPais 'BAJA', @z10, @pUT9;

    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p254, 500.00, @idUSD, @advertencia OUTPUT;

    SELECT @resultado = STRING_AGG(pz.Titulo, ',') WITHIN GROUP (ORDER BY e.NumeroEspacio)
    FROM publicidad.EspacioPublicitario AS e
    INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = e.IdPieza
    WHERE e.IdPartido = @p254;

    IF @resultado = 'Z1,Z2,Z3,Z4' AND @advertencia IS NULL
        PRINT '4.A: OK - el espacio 4 se completó con Z4 (sin advertencia).';
    ELSE
        PRINT '4.A: FALLÓ - se obtuvo ' + ISNULL(@resultado, 'NULL') + ' (esperado Z1,Z2,Z3,Z4).';
END TRY
BEGIN CATCH
    PRINT '4.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 4.B Se liberan los espacios 3 y 4 y se quita la orientación de Z4. Quedan 2 espacios libres (3 y 4)
-- y una sola candidata (Z3, que volvió a estar disponible al liberar el espacio 3).
-- Resultado esperado: Z3 se asigna al espacio 3, el 4 queda libre y se informa la advertencia
-- (1 pieza candidata para 2 espacios libres).
BEGIN TRY
    EXEC publicidad.SP_ABM_EspacioPublicitario 'BAJA', @p254, 3;
    EXEC publicidad.SP_ABM_EspacioPublicitario 'BAJA', @p254, 4;
    EXEC publicidad.SP_ABM_OrientacionPais 'BAJA', @z4, @pMK4;

    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p254, 500.00, @idUSD, @advertencia OUTPUT;

    SELECT @resultado = STRING_AGG(pz.Titulo, ',') WITHIN GROUP (ORDER BY e.NumeroEspacio)
    FROM publicidad.EspacioPublicitario AS e
    INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = e.IdPieza
    WHERE e.IdPartido = @p254;

    IF @resultado = 'Z1,Z2,Z3' AND @advertencia IS NOT NULL
        PRINT '4.B: OK - se asignó Z3 y se informó: ' + @advertencia;
    ELSE
        PRINT '4.B: FALLÓ - se obtuvo ' + ISNULL(@resultado, 'NULL') + ' (esperado Z1,Z2,Z3 con advertencia).';
END TRY
BEGIN CATCH
    PRINT '4.B: FALLÓ - ' + ERROR_MESSAGE();
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

-- 5.B Tarifa y moneda en NULL sobre el partido 252, que ya tiene sus cuatro espacios.
-- Resultado esperado: un único error con 3 renglones (tarifa, moneda y partido sin espacios libres).
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @p252, NULL, NULL;
    PRINT '5.B: FALLÓ - permitió tarifa y moneda NULL.';
END TRY
BEGIN CATCH
    PRINT '5.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 5.C Partido sin piezas candidatas: se quita la orientación de todas las piezas que quedaban.
-- Resultado esperado: error "No hay piezas publicitarias candidatas".
-- Se usa un partido nuevo sin espacios (255, sin cruce).
DECLARE @p255 SMALLINT;
EXEC nucleo.SP_ALTA_Partido @numeroPartido = 255, @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = '2026-07-20 20:00', @idPartido = @p255 OUTPUT;
EXEC publicidad.SP_ABM_OrientacionPais 'BAJA', @z1, @pAR1;
EXEC publicidad.SP_ABM_OrientacionPais 'BAJA', @z2, @pAR2;
EXEC publicidad.SP_ABM_OrientacionPais 'BAJA', @z3, @pMK3;
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
SELECT 'Espacios por partido (esperado: 251=4, 252=4, 253=4, 254=3, 255=0)' AS Control,
       pa.NumeroPartido, COUNT(e.NumeroEspacio) AS Espacios
FROM nucleo.Partido AS pa
LEFT JOIN publicidad.EspacioPublicitario AS e ON e.IdPartido = pa.IdPartido
WHERE pa.NumeroPartido BETWEEN 251 AND 255
GROUP BY pa.NumeroPartido
ORDER BY pa.NumeroPartido;

ROLLBACK TRANSACTION;
GO
