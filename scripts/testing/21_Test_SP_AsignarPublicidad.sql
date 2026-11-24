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
Objetivo: Probar publicidad.SP_ASIGNAR_PUBLICIDAD (script 21_SP_AsignarPublicidad.sql), que propone las
          piezas de los espacios libres con un ranking determinista:
            EsParticipante DESC, PBIMax DESC, EnPrimeTime DESC, IdPieza ASC
          (una pieza por anunciante en cada partido, contando los anunciantes que ya tienen espacio) y
          toma la tarifa de publicidad.Tarifa según la fase y la fecha del partido.
          Casos:
            1. Réplica del partido 1 (ARG vs BRA, 23:00 UTC, prime time en 6 mercados): las 4 piezas exactas.
            2. Determinismo: borrar los espacios y volver a asignar da exactamente lo mismo.
            3. @soloSimular = 1 devuelve la propuesta y no inserta nada.
            4. Partido sin cruce: decide el PBI, el prime time desempata y una pieza por anunciante.
            5. Espacios cargados a mano: solo se completan los libres y no se repite anunciante.
            6. Menos candidatas que espacios libres: asigna las que hay y devuelve advertencia.
            7. Errores agrupados: partido inexistente, sin espacios libres, finalizado, sin tarifa y sin
               candidatas.
            8. SP_ALTA_EspacioPublicitario rechazado en un partido finalizado.
          Requiere ejecutados los scripts 01 a 21 (usa nucleo.SP_ALTA_Sede).
          Funciona con la base recién creada o con el seed 04 cargado: los países y las selecciones ARG/BRA
          se reutilizan si existen, y las tablas de publicidad se vacían dentro de la transacción.
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- PREPARACIÓN DEL ESCENARIO
-- Se reproducen los 22 países y las 12 piezas del seed 04 (con el PBI fijado acá, porque en el seed
-- lo trae la API del Banco Mundial) y se suman tres piezas de prueba:
--   X1 (anunciante TEST X) -> SUI, CAN        X2 (anunciante TEST X) -> SUI
--   Y1 (anunciante TEST Y) -> sin país de orientación (nunca es candidata)
--
-- Todos los partidos son a las 23:00 UTC en junio/julio. A esa hora están en prime time (19:00 a 22:59
-- local) exactamente 6 mercados: ARG, BRA y URU (20:00), CHI, USA y CAN (19:00). COL (18:00), MEX
-- (17:00), Europa, Marruecos, Asia y Oceanía quedan afuera.
--
-- Por pieza (IdPieza en el orden de la tabla), sobre SUS países:
--   Pieza  Anunciante   Países        PBIMax         Prime time  ¿Participante en ARG vs BRA?
--   P1     Pampa        ARG,URU,CHI   22800 (URU)    sí          sí
--   P2     Pampa        ESP,ITA,FRA   44460 (FRA)    no          no
--   P3     Verde        BRA,POR       27280 (POR)    sí          sí
--   P4     Verde        USA,AUS,ENG   82770 (USA)    sí          no
--   P5     Sakura       JPN,USA,KOR   82770 (USA)    sí          no
--   P6     Sakura       MEX,COL,ARG   13930 (MEX)    sí          sí
--   P7     Nordic       NOR,SWE,CAN   87960 (NOR)    sí          no
--   P8     Helvetia     SUI,GER,ITA   99990 (SUI)    no          no
--   P9     Maple        CAN,USA       82770 (USA)    sí          no
--   P10    Liberty      ARG,BRA,URU   22800 (URU)    sí          sí
--   P11    Rhein        GER,NED,ESP   62540 (NED)    no          no
--   P12    Soleil       FRA,MAR,SUI   99990 (SUI)    no          no
--   X1     TEST X       SUI,CAN       99990 (SUI)    sí          no
--   X2     TEST X       SUI           99990 (SUI)    no          no
--
-- Tarifas (orden de alta = IdTarifa):
--   Fase de grupos   EUR  90000 desde 2026-06-01 | USD 100000 desde 2026-06-01 | USD 120000 desde 2026-06-12
--   Cuartos          USD 300000 desde 2026-06-01 | USD 350000 desde 2026-07-01
--   Semifinal        EUR 450000 desde 2026-06-01 (sin USD)
--   Final            sin tarifa
--
-- Partidos (insertados directo: el escenario necesita fecha UTC exacta y estado):
--   231 Fase de grupos  2026-06-11 23:00 UTC  ARG vs BRA   (réplica del partido 1)
--   232 Cuartos         2026-07-09 23:00 UTC  sin cruce
--   233 Cuartos         2026-07-10 23:00 UTC  sin cruce    (espacios cargados a mano)
--   234 Semifinal       2026-07-14 23:00 UTC  sin cruce    (menos candidatas que espacios)
--   235 Final           2026-07-19 23:00 UTC  ARG vs BRA   Finalizado (errores agrupados)
--   236 Fase de grupos  2026-06-20 23:00 UTC  ARG vs BRA   Finalizado
-- =========================================================================
DELETE FROM publicidad.EspacioPublicitario;
DELETE FROM publicidad.OrientacionPais;
DELETE FROM publicidad.Pieza;
DELETE FROM publicidad.Campania;
DELETE FROM publicidad.Anunciante;
DELETE FROM publicidad.Tarifa;
DELETE FROM publicidad.CotizacionMoneda;
DELETE FROM publicidad.Moneda;

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST PU21 Confederacion', 'TP21');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TP21');

DECLARE @paises TABLE (Nombre VARCHAR(50), Iso2 CHAR(2), Iso3 CHAR(3), Huso VARCHAR(50), PBI DECIMAL(10,2));
INSERT INTO @paises (Nombre, Iso2, Iso3, Huso, PBI) VALUES
 ('Argentina', 'AR', 'ARG', 'Argentina Standard Time', 13730), ('Brasil', 'BR', 'BRA', 'E. South America Standard Time', 10040),
 ('Uruguay', 'UY', 'URU', 'Montevideo Standard Time', 22800),  ('Colombia', 'CO', 'COL', 'SA Pacific Standard Time', 6980),
 ('Chile', 'CL', 'CHI', 'Pacific SA Standard Time', 17090),    ('Estados Unidos', 'US', 'USA', 'Eastern Standard Time', 82770),
 ('México', 'MX', 'MEX', 'Central Standard Time (Mexico)', 13930), ('Canadá', 'CA', 'CAN', 'Eastern Standard Time', 53370),
 ('Países Bajos', 'NL', 'NED', 'W. Europe Standard Time', 62540), ('España', 'ES', 'ESP', 'Romance Standard Time', 33510),
 ('Francia', 'FR', 'FRA', 'Romance Standard Time', 44460),     ('Alemania', 'DE', 'GER', 'W. Europe Standard Time', 52750),
 ('Inglaterra', 'GB', 'ENG', 'GMT Standard Time', 48870),      ('Portugal', 'PT', 'POR', 'GMT Standard Time', 27280),
 ('Italia', 'IT', 'ITA', 'W. Europe Standard Time', 38370),    ('Suiza', 'CH', 'SUI', 'W. Europe Standard Time', 99990),
 ('Noruega', 'NO', 'NOR', 'W. Europe Standard Time', 87960),   ('Suecia', 'SE', 'SWE', 'W. Europe Standard Time', 55520),
 ('Marruecos', 'MA', 'MAR', 'Morocco Standard Time', 3670),    ('Japón', 'JP', 'JPN', 'Tokyo Standard Time', 33830),
 ('Corea del Sur', 'KR', 'KOR', 'Korea Standard Time', 33120), ('Australia', 'AU', 'AUS', 'AUS Eastern Standard Time', 64710);

-- Los países que ya existen (seed cargado) se reutilizan; los demás se crean. El PBI y el huso se fijan
-- acá para que el resultado no dependa de la importación del Banco Mundial.
INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, PBIPerCapitaUSD, HusoHorarioComercial, IdConfederacion)
SELECT p.Nombre, p.Iso2, p.Iso3, p.PBI, p.Huso, @idConf
FROM @paises AS p
WHERE NOT EXISTS (SELECT 1 FROM nucleo.Pais AS pa WHERE pa.CodigoISO3 = p.Iso3);

UPDATE pa
SET PBIPerCapitaUSD = p.PBI, HusoHorarioComercial = p.Huso
FROM nucleo.Pais AS pa
INNER JOIN @paises AS p ON p.Iso3 = pa.CodigoISO3;

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
SELECT v.Codigo, v.Ranking, 0, pa.IdPais, @idGrupo
FROM (VALUES ('ARG', 1), ('BRA', 5)) AS v (Codigo, Ranking)
INNER JOIN nucleo.Pais AS pa ON pa.CodigoISO3 = v.Codigo
WHERE NOT EXISTS (SELECT 1 FROM nucleo.Seleccion AS s WHERE s.IdPais = pa.IdPais);

DECLARE @selARG TINYINT = (SELECT s.IdSeleccion FROM nucleo.Seleccion AS s INNER JOIN nucleo.Pais AS pa ON pa.IdPais = s.IdPais WHERE pa.CodigoISO3 = 'ARG');
DECLARE @selBRA TINYINT = (SELECT s.IdSeleccion FROM nucleo.Seleccion AS s INNER JOIN nucleo.Pais AS pa ON pa.IdPais = s.IdPais WHERE pa.CodigoISO3 = 'BRA');

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST PU21 Ciudad', 'Central Standard Time (Mexico)', (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'MEX'));
DECLARE @idCiudad SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST PU21 Ciudad');

DECLARE @idSede TINYINT;
EXEC nucleo.SP_ALTA_Sede
     @nombreEstadio = 'TEST PU21 Estadio',
     @idCiudad      = @idCiudad,
     @capacidad     = 80000,
     @idSede        = @idSede OUTPUT;

DECLARE @fGrupos TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Fase de grupos'),
        @fCuartos TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Cuartos de final'),
        @fSemi    TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Semifinal'),
        @fFinal   TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Final');

INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (231, '2026-06-11 23:00', 'Programado', @fGrupos,  @idSede, @selARG, @selBRA),
       (232, '2026-07-09 23:00', 'Programado', @fCuartos, @idSede, NULL,    NULL),
       (233, '2026-07-10 23:00', 'Programado', @fCuartos, @idSede, NULL,    NULL),
       (234, '2026-07-14 23:00', 'Programado', @fSemi,    @idSede, NULL,    NULL),
       (235, '2026-07-19 23:00', 'Finalizado', @fFinal,   @idSede, @selARG, @selBRA),
       (236, '2026-06-20 23:00', 'Finalizado', @fGrupos,  @idSede, @selARG, @selBRA);

DECLARE @p231 INT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 231),
        @p232 INT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 232),
        @p233 INT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 233),
        @p234 INT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 234),
        @p235 INT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 235),
        @p236 INT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 236);

DECLARE @idEUR INT, @idUSD INT, @idTarifa INT;
EXEC publicidad.SP_ALTA_Moneda @idEUR OUTPUT, 'EUR', 'Euro';
EXEC publicidad.SP_ALTA_Moneda @idUSD OUTPUT, 'USD', 'Dolar Estadounidense';

EXEC publicidad.SP_ALTA_Tarifa @idTarifa OUTPUT, @fGrupos,  @idEUR,  90000.00, '2026-06-01';
EXEC publicidad.SP_ALTA_Tarifa @idTarifa OUTPUT, @fGrupos,  @idUSD, 100000.00, '2026-06-01';
EXEC publicidad.SP_ALTA_Tarifa @idTarifa OUTPUT, @fGrupos,  @idUSD, 120000.00, '2026-06-12';
EXEC publicidad.SP_ALTA_Tarifa @idTarifa OUTPUT, @fCuartos, @idUSD, 300000.00, '2026-06-01';
EXEC publicidad.SP_ALTA_Tarifa @idTarifa OUTPUT, @fCuartos, @idUSD, 350000.00, '2026-07-01';
EXEC publicidad.SP_ALTA_Tarifa @idTarifa OUTPUT, @fSemi,    @idEUR, 450000.00, '2026-06-01';

INSERT INTO nucleo.Idioma (Nombre) VALUES ('TEST PU21 Idioma');
DECLARE @idIdioma TINYINT = (SELECT IdIdioma FROM nucleo.Idioma WHERE Nombre = 'TEST PU21 Idioma');

-- Anunciantes, una campaña por anunciante y las piezas en el orden de la tabla del encabezado
-- (INSERT ... SELECT ... ORDER BY asigna el IDENTITY en ese orden).
DECLARE @anunciantes TABLE (Orden INT, Nombre VARCHAR(100), Iso3 CHAR(3));
INSERT INTO @anunciantes (Orden, Nombre, Iso3) VALUES
 (1, 'Pampa Telecom', 'ARG'), (2, 'Verde Bebidas', 'BRA'), (3, 'Sakura Motors', 'JPN'), (4, 'Nordic Outdoor', 'NOR'),
 (5, 'Helvetia Watches', 'SUI'), (6, 'Maple Bank', 'CAN'), (7, 'Liberty Sportswear', 'USA'), (8, 'Rhein Auto', 'GER'),
 (9, 'Soleil Parfums', 'FRA'), (10, 'TEST PU21 Anunciante X', 'SUI'), (11, 'TEST PU21 Anunciante Y', 'ARG');

INSERT INTO publicidad.Anunciante (Nombre, IdPais)
SELECT a.Nombre, pa.IdPais
FROM @anunciantes AS a INNER JOIN nucleo.Pais AS pa ON pa.CodigoISO3 = a.Iso3
ORDER BY a.Orden;

INSERT INTO publicidad.Campania (IdAnunciante, Titulo)
SELECT an.IdAnunciante, 'Mundial 2026'
FROM publicidad.Anunciante AS an
ORDER BY an.IdAnunciante;

DECLARE @piezas TABLE (Orden INT, Anunciante VARCHAR(100), Titulo VARCHAR(100), Paises VARCHAR(100));
INSERT INTO @piezas (Orden, Anunciante, Titulo, Paises) VALUES
 (1,  'Pampa Telecom',          'Conectá el Mundial',  'ARG,URU,CHI'),
 (2,  'Pampa Telecom',          'Roaming Mundialista', 'ESP,ITA,FRA'),
 (3,  'Verde Bebidas',          'Sabor de Torcida',    'BRA,POR'),
 (4,  'Verde Bebidas',          'Refresh Every Goal',  'USA,AUS,ENG'),
 (5,  'Sakura Motors',          'Drive the Future',    'JPN,USA,KOR'),
 (6,  'Sakura Motors',          'Último Golpe',        'MEX,COL,ARG'),
 (7,  'Nordic Outdoor',         'Beyond the Pitch',    'NOR,SWE,CAN'),
 (8,  'Helvetia Watches',       'Tiempo de Campeones', 'SUI,GER,ITA'),
 (9,  'Maple Bank',             'Banking Goals',       'CAN,USA'),
 (10, 'Liberty Sportswear',     'Pura Pasión',         'ARG,BRA,URU'),
 (11, 'Rhein Auto',             'Fahrfreude',          'GER,NED,ESP'),
 (12, 'Soleil Parfums',         'Allez les Bleus',     'FRA,MAR,SUI'),
 (13, 'TEST PU21 Anunciante X', 'X1',                  'SUI,CAN'),
 (14, 'TEST PU21 Anunciante X', 'X2',                  'SUI'),
 (15, 'TEST PU21 Anunciante Y', 'Y1',                  '');

INSERT INTO publicidad.Pieza (IdCampania, IdIdioma, Titulo)
SELECT cp.IdCampania, @idIdioma, z.Titulo
FROM @piezas AS z
INNER JOIN publicidad.Anunciante AS an ON an.Nombre = z.Anunciante
INNER JOIN publicidad.Campania   AS cp ON cp.IdAnunciante = an.IdAnunciante
ORDER BY z.Orden;

INSERT INTO publicidad.OrientacionPais (IdPieza, IdPais)
SELECT pz.IdPieza, pa.IdPais
FROM @piezas AS z
INNER JOIN publicidad.Pieza AS pz ON pz.Titulo = z.Titulo
CROSS APPLY STRING_SPLIT(z.Paises, ',') AS s
INNER JOIN nucleo.Pais AS pa ON pa.CodigoISO3 = s.value;

-- Result set del SP, resultados esperados y variables de control.
DECLARE @rs TABLE (NumeroEspacio TINYINT, IdPieza INT, Titulo VARCHAR(100), Anunciante VARCHAR(100),
                   TarifaPublicitaria DECIMAL(12,2), Moneda CHAR(3), Estado VARCHAR(10), Criterio VARCHAR(60));
DECLARE @primera TABLE (NumeroEspacio TINYINT, IdPieza INT, TarifaPublicitaria DECIMAL(12,2), IdMoneda INT, Criterio VARCHAR(60));
DECLARE @esperado TABLE (Caso VARCHAR(5), NumeroEspacio TINYINT, Titulo VARCHAR(100), TarifaPublicitaria DECIMAL(12,2),
                         Moneda CHAR(3), Estado VARCHAR(10), Criterio VARCHAR(60) NULL);
DECLARE @advertencia VARCHAR(200), @cantidad INT, @coinciden INT, @obtenido NVARCHAR(MAX), @mensaje NVARCHAR(2048),
        @lineas INT;

INSERT INTO @esperado (Caso, NumeroEspacio, Titulo, TarifaPublicitaria, Moneda, Estado, Criterio) VALUES
 -- 1.A Réplica del partido 1: solo las 4 piezas participantes (P3, P1, P10, P6) entran, ordenadas por PBIMax;
 --     P1 y P10 empatan en PBI (URU 22800) y prime time: gana el menor IdPieza (P1).
 ('1.A', 1, 'Sabor de Torcida',   100000.00, 'USD', 'Asignado', 'Participante | PBI 27280 (POR) | Prime time'),
 ('1.A', 2, 'Conectá el Mundial', 100000.00, 'USD', 'Asignado', 'Participante | PBI 22800 (URU) | Prime time'),
 ('1.A', 3, 'Pura Pasión',        100000.00, 'USD', 'Asignado', 'Participante | PBI 22800 (URU) | Prime time'),
 ('1.A', 4, 'Último Golpe',       100000.00, 'USD', 'Asignado', 'Participante | PBI 13930 (MEX) | Prime time'),
 -- 3.A (y 4.A) Partido sin cruce: X1 le gana a P8 (mismo PBI 99990) por prime time; P8 y P12 le ganan a P7 (prime time)
 --     porque el PBI pesa más; X2 sería la 4.a sin la regla de un anunciante por partido (X ya tiene X1).
 ('3.A', 1, 'X1',                  350000.00, 'USD', 'Propuesto', 'No participante | PBI 99990 (SUI) | Prime time'),
 ('3.A', 2, 'Tiempo de Campeones', 350000.00, 'USD', 'Propuesto', 'No participante | PBI 99990 (SUI) | Sin prime time'),
 ('3.A', 3, 'Allez les Bleus',     350000.00, 'USD', 'Propuesto', 'No participante | PBI 99990 (SUI) | Sin prime time'),
 ('3.A', 4, 'Beyond the Pitch',    350000.00, 'USD', 'Propuesto', 'No participante | PBI 87960 (NOR) | Prime time'),
 -- 5.B Partido 233 con los espacios 2 (X2) y 3 (P8) cargados a mano: X1 queda afuera por anunciante (X) y
 --     P8 por estar en el partido; se completan el 1 con P12 y el 4 con P7.
 ('5.B', 1, 'Allez les Bleus',     350000.00, 'USD', 'Asignado',   'No participante | PBI 99990 (SUI) | Sin prime time'),
 ('5.B', 2, 'X2',                    1000.00, 'USD', 'Ya ocupado', NULL),
 ('5.B', 3, 'Tiempo de Campeones',   1000.00, 'USD', 'Ya ocupado', NULL),
 ('5.B', 4, 'Beyond the Pitch',    350000.00, 'USD', 'Asignado',   'No participante | PBI 87960 (NOR) | Prime time'),
 -- 6.A Solo P1, P3 y P10 conservan país de orientación: tres espacios, tarifa de Semifinal en EUR.
 ('6.A', 1, 'Sabor de Torcida',   450000.00, 'EUR', 'Asignado', 'No participante | PBI 27280 (POR) | Prime time'),
 ('6.A', 2, 'Conectá el Mundial', 450000.00, 'EUR', 'Asignado', 'No participante | PBI 22800 (URU) | Prime time'),
 ('6.A', 3, 'Pura Pasión',        450000.00, 'EUR', 'Asignado', 'No participante | PBI 22800 (URU) | Prime time');

-- El caso 4.A espera lo mismo que la simulación 3.A, pero ya asignado.
INSERT INTO @esperado (Caso, NumeroEspacio, Titulo, TarifaPublicitaria, Moneda, Estado, Criterio)
SELECT '4.A', NumeroEspacio, Titulo, TarifaPublicitaria, Moneda, 'Asignado', Criterio FROM @esperado WHERE Caso = '3.A';

-- =========================================================================
-- TEST 0: precondición del caso obligatorio
-- =========================================================================
PRINT '--- TEST 0: prime time del partido 231 ---';

-- 0.A Resultado esperado: exactamente 6 mercados en prime time: ARG, BRA, CAN, CHI, URU, USA.
SELECT @obtenido = STRING_AGG(CodigoISO3, ',') WITHIN GROUP (ORDER BY CodigoISO3)
FROM nucleo.fn_MercadosEnPrimeTime(@p231);
IF @obtenido = 'ARG,BRA,CAN,CHI,URU,USA'
    PRINT '0.A: OK - prime time en 6 mercados: ' + @obtenido + '.';
ELSE
    PRINT '0.A: FALLÓ - mercados en prime time: ' + ISNULL(@obtenido, 'ninguno') + ' (esperado ARG,BRA,CAN,CHI,URU,USA).';

-- =========================================================================
-- TEST 1: réplica del partido 1 (231: ARG vs BRA, 23:00 UTC, 13 candidatas para 4 espacios)
-- =========================================================================
PRINT '--- TEST 1: ranking del partido ARG vs BRA ---';

-- 1.A Resultado esperado (filas '1.A' de @esperado):
--   Espacio 1 = Sabor de Torcida   (P3)  Participante | PBI 27280 (POR) | Prime time
--   Espacio 2 = Conectá el Mundial (P1)  Participante | PBI 22800 (URU) | Prime time
--   Espacio 3 = Pura Pasión        (P10) Participante | PBI 22800 (URU) | Prime time
--   Espacio 4 = Último Golpe       (P6)  Participante | PBI 13930 (MEX) | Prime time
--   Tarifa 100000.00 USD (Fase de grupos vigente el 2026-06-11: se prefiere USD sobre el EUR del mismo
--   día aunque el EUR tenga menor IdTarifa; la de 120000 empieza el 2026-06-12). Sin advertencia.
BEGIN TRY
    DELETE FROM @rs;
    INSERT INTO @rs EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @p231, @advertencia = @advertencia OUTPUT;

    SELECT @coinciden = COUNT(*)
    FROM @rs AS r
    INNER JOIN @esperado AS e
            ON e.Caso = '1.A' AND e.NumeroEspacio = r.NumeroEspacio AND e.Titulo = r.Titulo
           AND e.TarifaPublicitaria = r.TarifaPublicitaria AND e.Moneda = r.Moneda
           AND e.Estado = r.Estado AND e.Criterio = r.Criterio;
    SELECT @obtenido = STRING_AGG(CAST(NumeroEspacio AS VARCHAR(1)) + '=' + Titulo, ', ') WITHIN GROUP (ORDER BY NumeroEspacio) FROM @rs;

    IF @coinciden = 4 AND (SELECT COUNT(*) FROM @rs) = 4 AND @advertencia IS NULL
        PRINT '1.A: OK - ' + @obtenido + ' (tarifa 100000.00 USD, sin advertencia).';
    ELSE
        PRINT '1.A: FALLÓ - se obtuvo ' + ISNULL(@obtenido, 'nada') + '; advertencia: ' + ISNULL(@advertencia, 'NULL')
              + ' (esperado 1=Sabor de Torcida, 2=Conectá el Mundial, 3=Pura Pasión, 4=Último Golpe).';
END TRY
BEGIN CATCH
    PRINT '1.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.B Lo guardado en la tabla coincide con lo informado: pieza, tarifa, moneda, criterio y FechaAsignacion.
-- Resultado esperado: 4 filas coincidentes.
SELECT @coinciden = COUNT(*)
FROM publicidad.EspacioPublicitario AS ep
INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = ep.IdPieza
INNER JOIN publicidad.Moneda AS mo ON mo.IdMoneda = ep.IdMoneda
INNER JOIN @esperado AS e
        ON e.Caso = '1.A' AND e.NumeroEspacio = ep.NumeroEspacio AND e.Titulo = pz.Titulo
       AND e.TarifaPublicitaria = ep.TarifaPublicitaria AND e.Moneda = mo.Codigo AND e.Criterio = ep.CriterioAsignacion
WHERE ep.IdPartido = @p231
  AND ep.FechaAsignacion IS NOT NULL;
IF @coinciden = 4
    PRINT '1.B: OK - los 4 espacios guardaron pieza, tarifa, moneda, criterio y fecha de asignación.';
ELSE
    PRINT '1.B: FALLÓ - espacios guardados como se esperaba: ' + CAST(@coinciden AS VARCHAR(10)) + ' (esperado 4).';

-- =========================================================================
-- TEST 2: determinismo (231)
-- =========================================================================
PRINT '--- TEST 2: dos corridas dan lo mismo ---';

-- 2.A Se guarda la primera asignación, se borran los espacios y se vuelve a asignar.
-- Resultado esperado: misma pieza, tarifa, moneda y criterio en los 4 espacios (0 diferencias).
BEGIN TRY
    INSERT INTO @primera (NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda, Criterio)
    SELECT NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda, CriterioAsignacion
    FROM publicidad.EspacioPublicitario WHERE IdPartido = @p231;

    DELETE FROM publicidad.EspacioPublicitario WHERE IdPartido = @p231;
    DELETE FROM @rs;
    INSERT INTO @rs EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @p231;

    SELECT @cantidad = COUNT(*)
    FROM ((SELECT NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda, Criterio FROM @primera
           EXCEPT
           SELECT NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda, CriterioAsignacion
           FROM publicidad.EspacioPublicitario WHERE IdPartido = @p231)
          UNION ALL
          (SELECT NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda, CriterioAsignacion
           FROM publicidad.EspacioPublicitario WHERE IdPartido = @p231
           EXCEPT
           SELECT NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda, Criterio FROM @primera)) AS d;

    IF @cantidad = 0 AND (SELECT COUNT(*) FROM @primera) = 4
        PRINT '2.A: OK - la segunda corrida asignó exactamente lo mismo que la primera.';
    ELSE
        PRINT '2.A: FALLÓ - diferencias entre corridas: ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 0).';
END TRY
BEGIN CATCH
    PRINT '2.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: @soloSimular = 1 (232: sin cruce)
-- =========================================================================
PRINT '--- TEST 3: simulación ---';

-- 3.A Resultado esperado: la propuesta de las filas '3.A' (estado 'Propuesto', tarifa 350000.00 USD de
-- Cuartos, la vigente desde 2026-07-01) y 0 espacios insertados en el partido 232.
BEGIN TRY
    DELETE FROM @rs;
    INSERT INTO @rs EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @p232, @soloSimular = 1, @advertencia = @advertencia OUTPUT;

    SELECT @coinciden = COUNT(*)
    FROM @rs AS r
    INNER JOIN @esperado AS e
            ON e.Caso = '3.A' AND e.NumeroEspacio = r.NumeroEspacio AND e.Titulo = r.Titulo
           AND e.TarifaPublicitaria = r.TarifaPublicitaria AND e.Moneda = r.Moneda
           AND e.Estado = r.Estado AND e.Criterio = r.Criterio;
    SELECT @cantidad = COUNT(*) FROM publicidad.EspacioPublicitario WHERE IdPartido = @p232;
    SELECT @obtenido = STRING_AGG(CAST(NumeroEspacio AS VARCHAR(1)) + '=' + Titulo, ', ') WITHIN GROUP (ORDER BY NumeroEspacio) FROM @rs;

    IF @coinciden = 4 AND (SELECT COUNT(*) FROM @rs) = 4 AND @cantidad = 0 AND @advertencia IS NULL
        PRINT '3.A: OK - propuesta ' + @obtenido + ' y ningún espacio insertado.';
    ELSE
        PRINT '3.A: FALLÓ - propuesta ' + ISNULL(@obtenido, 'nada') + '; espacios insertados: ' + CAST(@cantidad AS VARCHAR(10))
              + ' (esperado 1=X1, 2=Tiempo de Campeones, 3=Allez les Bleus, 4=Beyond the Pitch y 0 insertados).';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: PBI, prime time y una pieza por anunciante (232: sin cruce, nadie es participante)
-- =========================================================================
PRINT '--- TEST 4: PBI, prime time y una pieza por anunciante ---';

-- 4.A Asignación real. Resultado esperado: lo mismo que la simulación (filas '4.A'):
--   Espacio 1 = X1                  No participante | PBI 99990 (SUI) | Prime time
--   Espacio 2 = Tiempo de Campeones No participante | PBI 99990 (SUI) | Sin prime time
--   Espacio 3 = Allez les Bleus     No participante | PBI 99990 (SUI) | Sin prime time
--   Espacio 4 = Beyond the Pitch    No participante | PBI 87960 (NOR) | Prime time
BEGIN TRY
    DELETE FROM @rs;
    INSERT INTO @rs EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @p232, @advertencia = @advertencia OUTPUT;

    SELECT @coinciden = COUNT(*)
    FROM @rs AS r
    INNER JOIN @esperado AS e
            ON e.Caso = '4.A' AND e.NumeroEspacio = r.NumeroEspacio AND e.Titulo = r.Titulo
           AND e.TarifaPublicitaria = r.TarifaPublicitaria AND e.Moneda = r.Moneda
           AND e.Estado = r.Estado AND e.Criterio = r.Criterio;
    SELECT @obtenido = STRING_AGG(CAST(NumeroEspacio AS VARCHAR(1)) + '=' + Titulo, ', ') WITHIN GROUP (ORDER BY NumeroEspacio) FROM @rs;

    IF @coinciden = 4 AND (SELECT COUNT(*) FROM @rs) = 4
       AND (SELECT COUNT(*) FROM publicidad.EspacioPublicitario WHERE IdPartido = @p232) = 4
        PRINT '4.A: OK - ' + @obtenido + ' (igual a la simulación).';
    ELSE
        PRINT '4.A: FALLÓ - se obtuvo ' + ISNULL(@obtenido, 'nada') + ' (esperado 1=X1, 2=Tiempo de Campeones, 3=Allez les Bleus, 4=Beyond the Pitch).';
END TRY
BEGIN CATCH
    PRINT '4.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 4.B Una pieza por anunciante: X2 (mismo PBI que X1, P8 y P12) quedó afuera porque X ya tiene X1.
-- Resultado esperado: X2 no está en el partido y no hay dos espacios del mismo anunciante.
SELECT @cantidad = COUNT(*)
FROM (SELECT cp.IdAnunciante
      FROM publicidad.EspacioPublicitario AS ep
      INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = ep.IdPieza
      INNER JOIN publicidad.Campania AS cp ON cp.IdCampania = pz.IdCampania
      WHERE ep.IdPartido = @p232
      GROUP BY cp.IdAnunciante
      HAVING COUNT(*) > 1) AS x;
IF @cantidad = 0
   AND NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario AS ep INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = ep.IdPieza
                   WHERE ep.IdPartido = @p232 AND pz.Titulo = 'X2')
    PRINT '4.B: OK - X2 quedó afuera y ningún anunciante repite en el partido.';
ELSE
    PRINT '4.B: FALLÓ - anunciantes repetidos: ' + CAST(@cantidad AS VARCHAR(10)) + ' (esperado 0 y X2 fuera del partido).';

-- =========================================================================
-- TEST 5: espacios cargados a mano (233: sin cruce)
-- =========================================================================
PRINT '--- TEST 5: se completan solo los espacios libres ---';

-- 5.A Se cargan a mano el espacio 2 con X2 y el 3 con Tiempo de Campeones (P8), a 1000.00 USD.
-- Resultado esperado: alta exitosa de 2 espacios.
BEGIN TRY
    DECLARE @idX2 INT = (SELECT IdPieza FROM publicidad.Pieza WHERE Titulo = 'X2'),
            @idP8 INT = (SELECT IdPieza FROM publicidad.Pieza WHERE Titulo = 'Tiempo de Campeones');
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p233, 2, @idX2, 1000.00, @idUSD;
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p233, 3, @idP8, 1000.00, @idUSD;
    PRINT '5.A: OK - espacios 2 y 3 cargados a mano.';
END TRY
BEGIN CATCH
    PRINT '5.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 5.B Resultado esperado (filas '5.B'):
--   Espacio 1 = Allez les Bleus (nuevo)       Espacio 2 = X2 (manual, 1000.00, criterio NULL)
--   Espacio 3 = Tiempo de Campeones (manual)   Espacio 4 = Beyond the Pitch (nuevo)
--   X1 no entra aunque es la mejor rankeada: su anunciante (X) ya ocupa el espacio 2.
BEGIN TRY
    DELETE FROM @rs;
    INSERT INTO @rs EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @p233, @advertencia = @advertencia OUTPUT;

    SELECT @coinciden = COUNT(*)
    FROM @rs AS r
    INNER JOIN @esperado AS e
            ON e.Caso = '5.B' AND e.NumeroEspacio = r.NumeroEspacio AND e.Titulo = r.Titulo
           AND e.TarifaPublicitaria = r.TarifaPublicitaria AND e.Moneda = r.Moneda
           AND e.Estado = r.Estado AND ISNULL(e.Criterio, '') = ISNULL(r.Criterio, '');
    SELECT @obtenido = STRING_AGG(CAST(NumeroEspacio AS VARCHAR(1)) + '=' + Titulo, ', ') WITHIN GROUP (ORDER BY NumeroEspacio) FROM @rs;

    IF @coinciden = 4 AND (SELECT COUNT(*) FROM @rs) = 4 AND @advertencia IS NULL
        PRINT '5.B: OK - ' + @obtenido + ' (los manuales no se tocaron).';
    ELSE
        PRINT '5.B: FALLÓ - se obtuvo ' + ISNULL(@obtenido, 'nada') + ' (esperado 1=Allez les Bleus, 2=X2, 3=Tiempo de Campeones, 4=Beyond the Pitch).';
END TRY
BEGIN CATCH
    PRINT '5.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 5.C En la tabla los manuales conservan tarifa 1000.00 y criterio NULL; los nuevos, 350000.00 y su criterio.
-- Resultado esperado: 4 filas coincidentes.
SELECT @coinciden = COUNT(*)
FROM publicidad.EspacioPublicitario AS ep
INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = ep.IdPieza
INNER JOIN @esperado AS e
        ON e.Caso = '5.B' AND e.NumeroEspacio = ep.NumeroEspacio AND e.Titulo = pz.Titulo
       AND e.TarifaPublicitaria = ep.TarifaPublicitaria AND ISNULL(e.Criterio, '') = ISNULL(ep.CriterioAsignacion, '')
WHERE ep.IdPartido = @p233;
IF @coinciden = 4
    PRINT '5.C: OK - manuales intactos y nuevos con tarifa y criterio de la corrida.';
ELSE
    PRINT '5.C: FALLÓ - espacios como se esperaba: ' + CAST(@coinciden AS VARCHAR(10)) + ' (esperado 4).';

-- =========================================================================
-- TEST 7 (parte 1): errores que no dependen de las piezas
-- Se corre antes del TEST 6 porque ese test quita países de orientación.
-- =========================================================================
PRINT '--- TEST 7: validaciones (partido inexistente, sin espacios libres, finalizado) ---';

-- 7.A Partido inexistente. Resultado esperado: error 52000 con 1 renglón ("El partido indicado no existe").
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = -1;
    PRINT '7.A: FALLÓ - permitió asignar en un partido inexistente.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 1 AND @mensaje LIKE '%El partido indicado no existe%'
        PRINT '7.A: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '7.A: FALLÓ - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 7.B Partido 231 con los cuatro espacios ocupados. Resultado esperado: 1 renglón ("ya tiene sus cuatro
-- espacios publicitarios asignados").
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @p231;
    PRINT '7.B: FALLÓ - permitió asignar en un partido sin espacios libres.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF @lineas = 1 AND @mensaje LIKE '%ya tiene sus cuatro espacios%'
        PRINT '7.B: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '7.B: FALLÓ - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 7.C Partido 236 Finalizado (con tarifa, espacios libres y candidatas). Resultado esperado: 1 renglón
-- ("ya está finalizado") y ningún espacio insertado.
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @p236;
    PRINT '7.C: FALLÓ - permitió asignar en un partido finalizado.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF @lineas = 1 AND @mensaje LIKE '%finalizado%'
       AND NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdPartido = @p236)
        PRINT '7.C: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '7.C: FALLÓ - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 7.D Con @soloSimular = 1 también se valida. Resultado esperado: el mismo error de 7.C.
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @p236, @soloSimular = 1;
    PRINT '7.D: FALLÓ - la simulación no validó el partido finalizado.';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%finalizado%'
        PRINT '7.D: OK (Bloqueado) - la simulación también rechaza el partido finalizado.';
    ELSE
        PRINT '7.D: FALLÓ - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 8: SP_ALTA_EspacioPublicitario en un partido finalizado (236)
-- =========================================================================
PRINT '--- TEST 8: alta manual en un partido finalizado ---';

-- 8.A Resultado esperado: error "ya está finalizado ... no admiten altas" y ningún espacio insertado.
BEGIN TRY
    DECLARE @idP1 INT = (SELECT IdPieza FROM publicidad.Pieza WHERE Titulo = 'Conectá el Mundial');
    EXEC publicidad.SP_ALTA_EspacioPublicitario @p236, 1, @idP1, 1000.00, @idUSD;
    PRINT '8.A: FALLÓ - permitió dar de alta un espacio en un partido finalizado.';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%finalizado%altas%'
       AND NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdPartido = @p236)
        PRINT '8.A: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '8.A: FALLÓ - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 6: menos candidatas que espacios libres (234: Semifinal, sin cruce)
-- =========================================================================
PRINT '--- TEST 6: menos candidatas que espacios libres ---';

-- Solo conservan país de orientación P1, P3 y P10 (tres anunciantes distintos).
DELETE op
FROM publicidad.OrientacionPais AS op
INNER JOIN publicidad.Pieza AS pz ON pz.IdPieza = op.IdPieza
WHERE pz.Titulo NOT IN ('Conectá el Mundial', 'Sabor de Torcida', 'Pura Pasión');

-- 6.A Resultado esperado (filas '6.A'): 1 = Sabor de Torcida, 2 = Conectá el Mundial, 3 = Pura Pasión,
-- tarifa 450000.00 EUR (Semifinal no tiene USD), espacio 4 libre y advertencia exacta:
-- 'Advertencia: solo hubo 3 pieza(s) candidata(s) para 4 espacio(s) libre(s); quedan sin asignar los espacios 4.'
BEGIN TRY
    DELETE FROM @rs;
    INSERT INTO @rs EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @p234, @advertencia = @advertencia OUTPUT;

    SELECT @coinciden = COUNT(*)
    FROM @rs AS r
    INNER JOIN @esperado AS e
            ON e.Caso = '6.A' AND e.NumeroEspacio = r.NumeroEspacio AND e.Titulo = r.Titulo
           AND e.TarifaPublicitaria = r.TarifaPublicitaria AND e.Moneda = r.Moneda
           AND e.Estado = r.Estado AND e.Criterio = r.Criterio;
    SELECT @obtenido = STRING_AGG(CAST(NumeroEspacio AS VARCHAR(1)) + '=' + Titulo, ', ') WITHIN GROUP (ORDER BY NumeroEspacio) FROM @rs;

    IF @coinciden = 3 AND (SELECT COUNT(*) FROM @rs) = 3
       AND NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdPartido = @p234 AND NumeroEspacio = 4)
       AND @advertencia = 'Advertencia: solo hubo 3 pieza(s) candidata(s) para 4 espacio(s) libre(s); quedan sin asignar los espacios 4.'
        PRINT '6.A: OK - ' + @obtenido + '. ' + @advertencia;
    ELSE
        PRINT '6.A: FALLÓ - se obtuvo ' + ISNULL(@obtenido, 'nada') + '; advertencia: ' + ISNULL(@advertencia, 'NULL') + '.';
END TRY
BEGIN CATCH
    PRINT '6.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 7 (parte 2): errores que dependen de las piezas
-- =========================================================================
PRINT '--- TEST 7: validaciones (sin candidatas, sin tarifa, errores agrupados) ---';

-- 7.E Partido 234 con el espacio 4 libre: las tres piezas con país ya están en el partido.
-- Resultado esperado: 1 renglón ("No hay piezas publicitarias candidatas").
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @p234;
    PRINT '7.E: FALLÓ - permitió asignar sin piezas candidatas.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF @lineas = 1 AND @mensaje LIKE '%No hay piezas publicitarias candidatas%'
        PRINT '7.E: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '7.E: FALLÓ - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 7.F Partido 235 (Final, Finalizado) sin ninguna pieza con país de orientación: no hay tarifa para la
-- Final ni candidatas. Resultado esperado: un único error con 3 renglones (finalizado, sin tarifa y sin
-- candidatas) y ningún espacio insertado.
DELETE FROM publicidad.OrientacionPais;
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @p235;
    PRINT '7.F: FALLÓ - permitió asignar con tres validaciones incumplidas.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF @lineas = 3
       AND @mensaje LIKE '%finalizado%'
       AND @mensaje LIKE '%No hay tarifa vigente%'
       AND @mensaje LIKE '%No hay piezas publicitarias candidatas%'
       AND NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdPartido = @p235)
        PRINT '7.F: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '7.F: FALLÓ - renglones: ' + CAST(@lineas AS VARCHAR(10)) + ' - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 7.G Sin tarifa solo: el partido 235 pasa a Programado y se le devuelve una pieza con país.
-- Resultado esperado: 1 renglón ("No hay tarifa vigente").
UPDATE nucleo.Partido SET Estado = 'Programado' WHERE IdPartido = @p235;
INSERT INTO publicidad.OrientacionPais (IdPieza, IdPais)
SELECT pz.IdPieza, pa.IdPais
FROM publicidad.Pieza AS pz CROSS JOIN nucleo.Pais AS pa
WHERE pz.Titulo = 'X1' AND pa.CodigoISO3 = 'SUI';
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @p235;
    PRINT '7.G: FALLÓ - permitió asignar sin tarifa para la fase.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF @lineas = 1 AND @mensaje LIKE '%No hay tarifa vigente%'
        PRINT '7.G: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '7.G: FALLÓ - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
SELECT 'Espacios por partido (esperado: 231=4, 232=4, 233=4, 234=3, 235=0, 236=0)' AS Control,
       pa.NumeroPartido, COUNT(e.NumeroEspacio) AS Espacios
FROM nucleo.Partido AS pa
LEFT JOIN publicidad.EspacioPublicitario AS e ON e.IdPartido = pa.IdPartido
WHERE pa.NumeroPartido BETWEEN 231 AND 236
GROUP BY pa.NumeroPartido
ORDER BY pa.NumeroPartido;

ROLLBACK TRANSACTION;
GO
