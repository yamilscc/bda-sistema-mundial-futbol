/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Canseco Carrizo, Yamil Simón
Integrantes:
Casella, Mateo Ezequiel
Chungara Tenorio, Denis Abner
Torczuk, Elías Alexei
Canseco Carrizo, Yamil Simón
Objetivo:
	- Probar las consultas del script 34 (34_Consultas_ToBe.sql): nucleo.SP_CONSULTAR_FIXTURE (casos
	  exitosos y validaciones fallidas) y las vistas nucleo.vw_Fixture, eventos.vw_Goleadores,
	  jugadores.vw_HistorialTitularidad, eventos.vw_TarjetasPorSancionado, nucleo.vw_HistorialArbitral,
	  publicidad.vw_EspaciosPublicitariosUSD, publicidad.vw_OcupacionPublicitariaSede,
	  nucleo.vw_SedesMapa y publicidad.vw_MercadosPrimeTimePorPartido.
	- Requiere ejecutados los scripts 01 a 34. Puede correr con o sin el seed cargado: los controles
	  miran solo los datos de este test.
	- Todo se inserta directo (sin SP). Datos con prefijo 'TEST TB' / 'TEST_TB', monedas XTA y XTB y
	  NumeroPartido 230 a 233; se borran al inicio y el test corre dentro de una transacción que se
	  deshace al final (ROLLBACK), así no quedan datos de prueba.
	- Convención de salida: "OK" -> el caso se comportó como se esperaba; "OK (Bloqueado)" -> el SP
	  rechazó la consulta con el mensaje esperado; "FALLÓ" -> no.

Escenario (selecciones XTA, XTB y XTC; sede A en 'Argentina Standard Time' (UTC-3), sede C en 'UTC'):
	230 Fase de grupos, sede A, 2030-06-10 23:00 UTC (20:00 local), XTA 3 - XTB 1, Finalizado.
	    Goles: J1 (asist. J2), J1, J4 en contra (suma a XTA), J5 de penal.
	    Tarjetas: J4 amarilla, J5 roja directa (1 partido), ayudante de campo de XTA roja directa (1 partido).
	231 Fase de grupos, sede C, 2030-06-15 18:00 UTC, XTB vs XTC, Programado (con un gol de J6 cargado).
	232 Octavos de final, sede A, 2030-07-01 01:00 UTC (2030-06-30 22:00 local), XTA 1 - XTB 1,
	    penales 2 - 1, Finalizado. Goles: J2 (asist. J1), J4; tanda: J1, J3 (XTA) y J5 (XTB).
	    J4 amarilla (segunda, 1 partido de suspensión). Cambio: sale J2, entra J3 (minuto 75).
	233 Cuartos de final, sede C, 2030-07-05 19:00 UTC, cruce sin definir, Programado.
*/

USE MundialFutbol;
GO

-- Si una corrida anterior quedó con la transacción abierta, se deshace antes de empezar.
WHILE @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;

-- =========================================================================
-- LIMPIEZA PREVIA
-- =========================================================================
DELETE sa FROM nucleo.Sancion AS sa
INNER JOIN nucleo.DesignacionArbitral AS d ON d.IdDesignacionArbitral = sa.IdDesignacionArbitral
INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido
WHERE p.NumeroPartido BETWEEN 230 AND 233;
DELETE d FROM nucleo.DesignacionArbitral AS d
INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido
WHERE p.NumeroPartido BETWEEN 230 AND 233;
DELETE FROM publicidad.EspacioPublicitario WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 230 AND 233);
DELETE FROM eventos.Gol                    WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 230 AND 233);
DELETE FROM eventos.Amonestacion           WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 230 AND 233);
DELETE FROM jugadores.Sustitucion          WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 230 AND 233);
DELETE fj FROM jugadores.FormacionJugador AS fj
INNER JOIN jugadores.Formacion AS f ON f.IdFormacion = fj.IdFormacion
WHERE f.IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 230 AND 233);
DELETE FROM jugadores.Formacion            WHERE IdPartido IN (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido BETWEEN 230 AND 233);
DELETE FROM nucleo.Partido                 WHERE NumeroPartido BETWEEN 230 AND 233;
DELETE FROM publicidad.OrientacionPais     WHERE IdPieza IN (SELECT IdPieza FROM publicidad.Pieza WHERE Titulo LIKE 'TEST TB%');
DELETE FROM publicidad.Pieza               WHERE Titulo LIKE 'TEST TB%';
DELETE FROM publicidad.Campania            WHERE Titulo LIKE 'TEST TB%';
DELETE FROM publicidad.Anunciante          WHERE Nombre LIKE 'TEST TB%';
DELETE FROM publicidad.CotizacionMoneda    WHERE Moneda IN ('XTA', 'XTB') OR MonedaBase IN ('XTA', 'XTB');
DELETE FROM publicidad.Moneda              WHERE Codigo IN ('XTA', 'XTB');
DELETE FROM jugadores.Convocatoria         WHERE IdJugador IN (SELECT IdJugador FROM jugadores.Jugador WHERE Documento LIKE 'TEST_TB%');
DELETE FROM jugadores.Jugador              WHERE Documento LIKE 'TEST_TB%';
DELETE FROM nucleo.StaffTecnico            WHERE NombreApellido LIKE 'TEST TB%';
DELETE FROM nucleo.Arbitro                 WHERE NombreApellido LIKE 'TEST TB%';
DELETE FROM nucleo.Seleccion               WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST TB%');
DELETE FROM nucleo.Sede                    WHERE NombreEstadio LIKE 'TEST TB%';
DELETE FROM nucleo.Ciudad                  WHERE Nombre LIKE 'TEST TB%';
DELETE FROM nucleo.Pais                    WHERE Nombre LIKE 'TEST TB%';
DELETE FROM nucleo.Confederacion           WHERE Nombre LIKE 'TEST TB%';
DELETE FROM nucleo.Categoria               WHERE Nombre LIKE 'TEST TB%';
DELETE FROM nucleo.Idioma                  WHERE Nombre LIKE 'TEST TB%';
GO

DROP TABLE IF EXISTS #fx;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- DATOS DE PRUEBA
-- =========================================================================
-- Catálogos de referencia: se agregan solo si faltan (el ROLLBACK final los quita).
INSERT INTO eventos.TipoGol (Descripcion)
SELECT v.d FROM (VALUES ('Jugada'), ('Penal'), ('En contra')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.TipoGol AS t WHERE t.Descripcion = v.d);

INSERT INTO eventos.Periodo (Descripcion)
SELECT v.d FROM (VALUES ('Primer Tiempo'), ('Segundo Tiempo'), ('Definicion por Penales')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Periodo AS t WHERE t.Descripcion = v.d);

INSERT INTO eventos.Tarjeta (Tipo)
SELECT v.d FROM (VALUES ('Amarilla'), ('Roja directa')) AS v(d)
WHERE NOT EXISTS (SELECT 1 FROM eventos.Tarjeta AS t WHERE t.Tipo = v.d);

IF NOT EXISTS (SELECT 1 FROM publicidad.Moneda WHERE Codigo = 'USD')
	INSERT INTO publicidad.Moneda (Codigo, Nombre) VALUES ('USD', 'TEST TB Dolar estadounidense');
INSERT INTO publicidad.Moneda (Codigo, Nombre) VALUES ('XTA', 'TEST TB Moneda A'), ('XTB', 'TEST TB Moneda B');

-- Cotizaciones (base USD): 1 USD = 4 XTA en 2029 y 1 USD = 2 XTA en 2030 (la vista debe usar la de 2030).
-- XTB no tiene cotización.
INSERT INTO publicidad.CotizacionMoneda (MonedaBase, Moneda, Fecha, Tasa)
SELECT v.b, v.m, v.f, v.t
FROM (VALUES ('USD', 'USD', CAST('2029-01-01' AS DATE), 1),
             ('USD', 'USD', CAST('2030-01-01' AS DATE), 1),
             ('USD', 'XTA', CAST('2029-01-01' AS DATE), 4),
             ('USD', 'XTA', CAST('2030-01-01' AS DATE), 2)) AS v(b, m, f, t)
WHERE NOT EXISTS (SELECT 1 FROM publicidad.CotizacionMoneda AS c
                  WHERE c.MonedaBase = v.b AND c.Moneda = v.m AND c.Fecha = v.f);

DECLARE @tgJugada  INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'Jugada'),
        @tgPenal   INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'Penal'),
        @tgContra  INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'En contra'),
        @pePT      INT = (SELECT IdPeriodo FROM eventos.Periodo WHERE Descripcion = 'Primer Tiempo'),
        @peST      INT = (SELECT IdPeriodo FROM eventos.Periodo WHERE Descripcion = 'Segundo Tiempo'),
        @peTanda   INT = (SELECT IdPeriodo FROM eventos.Periodo WHERE Descripcion = 'Definicion por Penales'),
        @tAmarilla INT = (SELECT IdTarjeta FROM eventos.Tarjeta WHERE Tipo = 'Amarilla'),
        @tRoja     INT = (SELECT IdTarjeta FROM eventos.Tarjeta WHERE Tipo = 'Roja directa'),
        @fGrupos   TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Fase de grupos'),
        @fOctavos  TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final'),
        @fCuartos  TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Cuartos de final'),
        @monUSD    INT = (SELECT IdMoneda FROM publicidad.Moneda WHERE Codigo = 'USD'),
        @monXTA    INT = (SELECT IdMoneda FROM publicidad.Moneda WHERE Codigo = 'XTA'),
        @monXTB    INT = (SELECT IdMoneda FROM publicidad.Moneda WHERE Codigo = 'XTB');

-- Países, selecciones, ciudades y sedes.
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST TB Confederacion', 'TTB');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Nombre = 'TEST TB Confederacion');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, PBIPerCapitaUSD, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST TB Pais A', 'XT', 'XTA', 1000.00, 'Argentina Standard Time', @idConf),
       ('TEST TB Pais B', 'XU', 'XTB', 2000.00, 'Tokyo Standard Time',     @idConf),
       ('TEST TB Pais C', 'XV', 'XTC', 3000.00, 'UTC',                     @idConf);
DECLARE @paisA SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE Nombre = 'TEST TB Pais A'),
        @paisB SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE Nombre = 'TEST TB Pais B'),
        @paisC SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE Nombre = 'TEST TB Pais C');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
	INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
VALUES ('XTA', 201, @paisA, @idGrupo), ('XTB', 202, @paisB, @idGrupo), ('XTC', 203, @paisC, @idGrupo);
DECLARE @selA TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XTA'),
        @selB TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XTB'),
        @selC TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XTC');

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST TB Ciudad A', 'Argentina Standard Time', @paisA),
       ('TEST TB Ciudad C', 'UTC',                     @paisC);
INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, Latitud, Longitud, IdCiudad)
VALUES ('TEST TB Estadio A', 50000, -34.600000, -58.400000, (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST TB Ciudad A')),
       ('TEST TB Estadio C', 40000,  51.500000,  -0.100000, (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST TB Ciudad C'));
DECLARE @sedeA TINYINT = (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio = 'TEST TB Estadio A'),
        @sedeC TINYINT = (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio = 'TEST TB Estadio C');

INSERT INTO nucleo.StaffTecnico (NombreApellido, Rol, IdSeleccion) VALUES ('TEST TB DT A', 'Ayudante de campo 1', @selA); -- rol sin acentos: no depende de la codificación del 01
DECLARE @dtA SMALLINT = (SELECT IdStaffTecnico FROM nucleo.StaffTecnico WHERE NombreApellido = 'TEST TB DT A');

-- Jugadores: J1, J2, J3 (XTA); J4, J5, J7 (XTB); J6 (XTC).
INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion)
VALUES ('Jugador', 'TB01', 'TEST_TB_01', 'M', 'Delantero'),
       ('Jugador', 'TB02', 'TEST_TB_02', 'M', 'Mediocampista'),
       ('Jugador', 'TB03', 'TEST_TB_03', 'M', 'Delantero'),
       ('Jugador', 'TB04', 'TEST_TB_04', 'M', 'Defensor'),
       ('Jugador', 'TB05', 'TEST_TB_05', 'M', 'Delantero'),
       ('Jugador', 'TB06', 'TEST_TB_06', 'M', 'Delantero'),
       ('Jugador', 'TB07', 'TEST_TB_07', 'M', 'Mediocampista');
DECLARE @j1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_TB_01'),
        @j2 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_TB_02'),
        @j3 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_TB_03'),
        @j4 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_TB_04'),
        @j5 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_TB_05'),
        @j6 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_TB_06'),
        @j7 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_TB_07');

INSERT INTO jugadores.Convocatoria (IdSeleccion, IdJugador, Dorsal)
VALUES (@selA, @j1, 9), (@selA, @j2, 8), (@selA, @j3, 12),
       (@selB, @j4, 4), (@selB, @j5, 10), (@selB, @j7, 13),
       (@selC, @j6, 7);

-- Partidos 230 a 233.
INSERT INTO nucleo.Partido (NumeroPartido, Concurrencia, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (230, 45000, '2030-06-10 23:00', 'Finalizado', @fGrupos,  @sedeA, @selA, @selB),
       (231, NULL,  '2030-06-15 18:00', 'Programado', @fGrupos,  @sedeC, @selB, @selC),
       (232, 48000, '2030-07-01 01:00', 'Finalizado', @fOctavos, @sedeA, @selA, @selB),
       (233, NULL,  '2030-07-05 19:00', 'Programado', @fCuartos, @sedeC, NULL,  NULL);
DECLARE @p230 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 230),
        @p231 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 231),
        @p232 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 232),
        @p233 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 233);

-- Goles.
INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
VALUES (@p230, @j1, @j2,  @tgJugada, @pePT,    10),
       (@p230, @j4, NULL, @tgContra, @pePT,    30),  -- en contra: suma a XTA, no al autor
       (@p230, @j1, NULL, @tgJugada, @peST,    50),
       (@p230, @j5, NULL, @tgPenal,  @peST,    70),
       (@p231, @j6, NULL, @tgJugada, @pePT,    20),  -- partido Programado: no cuenta
       (@p232, @j2, @j1,  @tgJugada, @peST,    60),
       (@p232, @j4, NULL, @tgJugada, @peST,    80),
       (@p232, @j1, NULL, @tgPenal,  @peTanda, 121), -- tanda: no cuenta como gol
       (@p232, @j3, NULL, @tgPenal,  @peTanda, 122),
       (@p232, @j5, NULL, @tgPenal,  @peTanda, 123);

-- Tarjetas.
INSERT INTO eventos.Amonestacion (IdPartido, IdTarjeta, IdJugador, IdStaffTecnico, Minuto, Motivo, PartidosSuspension)
VALUES (@p230, @tAmarilla, @j4,  NULL, 20, 'TEST TB juego brusco',     0),
       (@p230, @tRoja,     @j5,  NULL, 75, 'TEST TB juego violento',   1),
       (@p230, @tRoja,     NULL, @dtA, 80, 'TEST TB protesta',         1),
       (@p232, @tAmarilla, @j4,  NULL, 40, 'TEST TB acumulación',      1);

-- Formaciones y sustitución.
INSERT INTO jugadores.Formacion (IdPartido, Localia, EsquemaTactico)
VALUES (@p230, 'Local', '4-4-2'), (@p232, 'Local', '4-3-3'), (@p232, 'Visitante', '4-4-2');
DECLARE @f230A INT = (SELECT IdFormacion FROM jugadores.Formacion WHERE IdPartido = @p230 AND Localia = 'Local'),
        @f232A INT = (SELECT IdFormacion FROM jugadores.Formacion WHERE IdPartido = @p232 AND Localia = 'Local'),
        @f232B INT = (SELECT IdFormacion FROM jugadores.Formacion WHERE IdPartido = @p232 AND Localia = 'Visitante');

INSERT INTO jugadores.FormacionJugador (IdFormacion, IdJugador, EstadoTitularidad, PosicionEnCampo, Dorsal)
VALUES (@f230A, @j1, 'Titular',  'Delantero',     9),
       (@f230A, @j2, 'Titular',  'Mediocampista', 8),
       (@f230A, @j3, 'Suplente', NULL,            12),
       (@f232A, @j1, 'Titular',  'Delantero',     9),
       (@f232A, @j2, 'Titular',  'Mediocampista', 8),
       (@f232A, @j3, 'Suplente', NULL,            12),
       (@f232B, @j4, 'Titular',  'Defensor',      4),
       (@f232B, @j5, 'Titular',  'Delantero',     10),
       (@f232B, @j7, 'Suplente', NULL,            13);

INSERT INTO jugadores.Sustitucion (IdPartido, IdJugadorSaliente, IdJugadorEntrante, Minuto, Periodo, Motivo)
VALUES (@p232, @j2, @j3, 75, 'Regular', 'Tactico');

-- Árbitros, designaciones y sanción.
INSERT INTO nucleo.Categoria (Nombre) VALUES ('TEST TB Categoria');
INSERT INTO nucleo.Arbitro (NombreApellido, Sexo, FechaNacimiento, IdPais, IdCategoria)
VALUES ('TEST TB Arbitro Uno', 'M', '1985-05-05', @paisC, (SELECT IdCategoria FROM nucleo.Categoria WHERE Nombre = 'TEST TB Categoria')),
       ('TEST TB Arbitro Dos', 'F', '1987-07-07', @paisC, (SELECT IdCategoria FROM nucleo.Categoria WHERE Nombre = 'TEST TB Categoria'));
DECLARE @arb1 SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST TB Arbitro Uno'),
        @arb2 SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST TB Arbitro Dos');

INSERT INTO nucleo.DesignacionArbitral (Rol, IdArbitro, IdPartido)
VALUES ('Principal', @arb1, @p230), ('VAR', @arb1, @p232), ('Principal', @arb2, @p232);
INSERT INTO nucleo.Sancion (Tipo, Descripcion, Fecha, IdDesignacionArbitral)
VALUES ('Informe', 'TEST TB informe post-partido', '2030-06-11',
        (SELECT IdDesignacionArbitral FROM nucleo.DesignacionArbitral WHERE IdPartido = @p230 AND Rol = 'Principal'));

-- Publicidad: 3 espacios en el partido 230 (USD, XTA con cotización y XTB sin cotización).
INSERT INTO nucleo.Idioma (Nombre) VALUES ('TEST TB Idioma');
-- Jerarquía del script 04: Anunciante 1-N Campania 1-N Pieza.
INSERT INTO publicidad.Anunciante (Nombre, IdPais) VALUES ('TEST TB Anunciante', @paisA);
INSERT INTO publicidad.Campania (IdAnunciante, Titulo)
SELECT IdAnunciante, 'TEST TB Campania' FROM publicidad.Anunciante WHERE Nombre = 'TEST TB Anunciante';
INSERT INTO publicidad.Pieza (IdCampania, IdIdioma, Titulo)
SELECT ca.IdCampania, (SELECT IdIdioma FROM nucleo.Idioma WHERE Nombre = 'TEST TB Idioma'), v.t
FROM publicidad.Campania AS ca
CROSS JOIN (VALUES ('TEST TB Pieza 1'), ('TEST TB Pieza 2'), ('TEST TB Pieza 3')) AS v(t)
WHERE ca.Titulo = 'TEST TB Campania';

INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
VALUES (@p230, 1, (SELECT IdPieza FROM publicidad.Pieza WHERE Titulo = 'TEST TB Pieza 1'), 1000.00, @monUSD),
       (@p230, 2, (SELECT IdPieza FROM publicidad.Pieza WHERE Titulo = 'TEST TB Pieza 2'), 1000.00, @monXTA),
       (@p230, 3, (SELECT IdPieza FROM publicidad.Pieza WHERE Titulo = 'TEST TB Pieza 3'), 1000.00, @monXTB);

-- Tabla para capturar la salida de nucleo.SP_CONSULTAR_FIXTURE (mismas columnas que nucleo.vw_Fixture).
CREATE TABLE #fx (
	IdPartido SMALLINT, NumeroPartido TINYINT, IdFase TINYINT, Fase VARCHAR(28), OrdenFase TINYINT,
	FechaHoraUTC DATETIME2(0), FechaHoraLocalSede DATETIME2(0), FechaLocalSede DATE,
	IdSede TINYINT, Estadio VARCHAR(100), Ciudad VARCHAR(100), PaisSede VARCHAR(50), HusoHorario VARCHAR(50),
	IdSeleccionLocal TINYINT, SeleccionLocal VARCHAR(9), PaisLocal VARCHAR(50),
	IdSeleccionVisitante TINYINT, SeleccionVisitante VARCHAR(9), PaisVisitante VARCHAR(50),
	Estado VARCHAR(10), Concurrencia INT,
	GolesLocal INT, GolesVisitante INT, PenalesLocal INT, PenalesVisitante INT,
	IdGanador TINYINT, Ganador VARCHAR(9), DefinidoPorPenales BIT
);

-- =========================================================================
-- 1. SP_CONSULTAR_FIXTURE: casos exitosos
-- =========================================================================

-- 1.A Sin filtros.
-- Esperado: OK. Aparecen los 4 partidos del test (230 a 233), además de los que tenga la base.
TRUNCATE TABLE #fx;
BEGIN TRY
	INSERT INTO #fx EXEC nucleo.SP_CONSULTAR_FIXTURE;
	IF (SELECT COUNT(*) FROM #fx WHERE NumeroPartido BETWEEN 230 AND 233) = 4
		PRINT 'TEST 1.A OK: el fixture sin filtros trae los 4 partidos del test.';
	ELSE
		PRINT 'TEST 1.A FALLÓ: se esperaban 4 partidos del test.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.A FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- Evidencia: fixture de los partidos del test.
SELECT NumeroPartido, Fase, FechaHoraUTC, FechaHoraLocalSede, Estadio, SeleccionLocal, SeleccionVisitante,
       Estado, GolesLocal, GolesVisitante, PenalesLocal, PenalesVisitante, Ganador
FROM #fx WHERE NumeroPartido BETWEEN 230 AND 233 ORDER BY FechaHoraUTC;

-- 1.B Filtro por sede (sede C).
-- Esperado: OK. Solo partidos de la sede C: 231 y 233.
TRUNCATE TABLE #fx;
BEGIN TRY
	INSERT INTO #fx EXEC nucleo.SP_CONSULTAR_FIXTURE @idSede = @sedeC;
	IF (SELECT COUNT(*) FROM #fx) = 2
	   AND NOT EXISTS (SELECT 1 FROM #fx WHERE IdSede <> @sedeC)
	   AND EXISTS (SELECT 1 FROM #fx WHERE NumeroPartido = 231)
	   AND EXISTS (SELECT 1 FROM #fx WHERE NumeroPartido = 233)
		PRINT 'TEST 1.B OK: filtro por sede (partidos 231 y 233).';
	ELSE
		PRINT 'TEST 1.B FALLÓ: el filtro por sede devolvió otros partidos.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.B FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.C Filtro por fase (Octavos de final).
-- Esperado: OK. Todas las filas son de octavos; del test, solo el 232.
TRUNCATE TABLE #fx;
BEGIN TRY
	INSERT INTO #fx EXEC nucleo.SP_CONSULTAR_FIXTURE @idFase = @fOctavos;
	IF NOT EXISTS (SELECT 1 FROM #fx WHERE IdFase <> @fOctavos)
	   AND (SELECT COUNT(*) FROM #fx WHERE NumeroPartido BETWEEN 230 AND 233) = 1
	   AND EXISTS (SELECT 1 FROM #fx WHERE NumeroPartido = 232)
		PRINT 'TEST 1.C OK: filtro por fase (solo el 232 entre los del test).';
	ELSE
		PRINT 'TEST 1.C FALLÓ: el filtro por fase devolvió otros partidos.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.C FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.D Filtro por selección (XTB, como local o visitante).
-- Esperado: OK. Partidos 230 (visitante), 231 (local) y 232 (visitante).
TRUNCATE TABLE #fx;
BEGIN TRY
	INSERT INTO #fx EXEC nucleo.SP_CONSULTAR_FIXTURE @idSeleccion = @selB;
	IF (SELECT COUNT(*) FROM #fx) = 3
	   AND NOT EXISTS (SELECT 1 FROM #fx WHERE @selB NOT IN (ISNULL(IdSeleccionLocal, 0), ISNULL(IdSeleccionVisitante, 0)))
	   AND (SELECT COUNT(*) FROM #fx WHERE NumeroPartido IN (230, 231, 232)) = 3
		PRINT 'TEST 1.D OK: filtro por selección como local o visitante (230, 231 y 232).';
	ELSE
		PRINT 'TEST 1.D FALLÓ: el filtro por selección devolvió otros partidos.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.D FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.E Rango de fechas sobre la fecha LOCAL de la sede.
-- Esperado: OK. El 232 (2030-07-01 01:00 UTC) se juega el 2030-06-30 a las 22:00 en la sede A (UTC-3):
--           entra con desde = hasta = 2030-06-30 y no entra con desde = hasta = 2030-07-01.
TRUNCATE TABLE #fx;
BEGIN TRY
	INSERT INTO #fx EXEC nucleo.SP_CONSULTAR_FIXTURE @fechaDesde = '2030-06-30', @fechaHasta = '2030-06-30';
	DECLARE @enFechaLocal INT = (SELECT COUNT(*) FROM #fx WHERE NumeroPartido = 232);
	TRUNCATE TABLE #fx;
	INSERT INTO #fx EXEC nucleo.SP_CONSULTAR_FIXTURE @fechaDesde = '2030-07-01', @fechaHasta = '2030-07-01';
	DECLARE @enFechaUTC INT = (SELECT COUNT(*) FROM #fx WHERE NumeroPartido = 232);
	IF @enFechaLocal = 1 AND @enFechaUTC = 0
		PRINT 'TEST 1.E OK: el rango de fechas usa la fecha local de la sede (232 entra el 30/06, no el 01/07).';
	ELSE
		PRINT 'TEST 1.E FALLÓ: el rango de fechas no usó la fecha local de la sede.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.E FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.F Hora local de la sede.
-- Esperado: OK. 232 en la sede A (UTC-3): 2030-06-30 22:00 local; 231 en la sede C (UTC): igual a la UTC.
TRUNCATE TABLE #fx;
BEGIN TRY
	INSERT INTO #fx EXEC nucleo.SP_CONSULTAR_FIXTURE @fechaDesde = '2030-06-01', @fechaHasta = '2030-07-31';
	IF EXISTS (SELECT 1 FROM #fx WHERE NumeroPartido = 232
	                                AND FechaHoraLocalSede = '2030-06-30 22:00' AND FechaLocalSede = '2030-06-30')
	   AND EXISTS (SELECT 1 FROM #fx WHERE NumeroPartido = 231 AND FechaHoraLocalSede = FechaHoraUTC)
		PRINT 'TEST 1.F OK: hora local de la sede (UTC-3 en la sede A, UTC en la sede C).';
	ELSE
		PRINT 'TEST 1.F FALLÓ: la hora local de la sede no es la esperada.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.F FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.G Resultado (leído de nucleo.vw_PartidoResultado).
-- Esperado: OK. 230: 3-1 sin penales, gana XTA (el gol en contra de J4 suma a XTA).
--           231: Programado, goles NULL. 232: 1-1, penales 2-1, gana XTA por penales.
--           233: cruce sin definir ('A definir' en las dos selecciones).
TRUNCATE TABLE #fx;
BEGIN TRY
	INSERT INTO #fx EXEC nucleo.SP_CONSULTAR_FIXTURE @fechaDesde = '2030-06-01', @fechaHasta = '2030-07-31';
	IF EXISTS (SELECT 1 FROM #fx WHERE NumeroPartido = 230 AND GolesLocal = 3 AND GolesVisitante = 1
	                                AND PenalesLocal IS NULL AND Ganador = 'XTA' AND DefinidoPorPenales = 0)
	   AND EXISTS (SELECT 1 FROM #fx WHERE NumeroPartido = 231 AND Estado = 'Programado'
	                                AND GolesLocal IS NULL AND GolesVisitante IS NULL AND Ganador IS NULL)
	   AND EXISTS (SELECT 1 FROM #fx WHERE NumeroPartido = 232 AND GolesLocal = 1 AND GolesVisitante = 1
	                                AND PenalesLocal = 2 AND PenalesVisitante = 1 AND Ganador = 'XTA' AND DefinidoPorPenales = 1)
	   AND EXISTS (SELECT 1 FROM #fx WHERE NumeroPartido = 233
	                                AND SeleccionLocal = 'A definir' AND SeleccionVisitante = 'A definir')
		PRINT 'TEST 1.G OK: resultados derivados de los goles (en contra, penales, programado y cruce sin definir).';
	ELSE
		PRINT 'TEST 1.G FALLÓ: algún resultado no es el esperado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.G FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.H Filtros combinados sin coincidencias (sede C y octavos).
-- Esperado: OK. 0 filas, sin error.
TRUNCATE TABLE #fx;
BEGIN TRY
	INSERT INTO #fx EXEC nucleo.SP_CONSULTAR_FIXTURE @idSede = @sedeC, @idFase = @fOctavos;
	IF (SELECT COUNT(*) FROM #fx) = 0
		PRINT 'TEST 1.H OK: filtros sin coincidencias devuelven 0 filas sin error.';
	ELSE
		PRINT 'TEST 1.H FALLÓ: se esperaban 0 filas.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.H FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- 2. SP_CONSULTAR_FIXTURE: validaciones fallidas
-- =========================================================================

-- 2.A Sede inexistente (999: IdSede es TINYINT, no puede existir).
-- Esperado: Bloqueado: "- La sede indicada no existe."
BEGIN TRY
	EXEC nucleo.SP_CONSULTAR_FIXTURE @idSede = 999;
	PRINT 'TEST 2.A FALLÓ: aceptó una sede inexistente.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%La sede indicada no existe.%'
		PRINT 'TEST 2.A OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
	ELSE
		PRINT 'TEST 2.A FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.B Fase inexistente.
-- Esperado: Bloqueado: "- La fase indicada no existe."
BEGIN TRY
	EXEC nucleo.SP_CONSULTAR_FIXTURE @idFase = 99;
	PRINT 'TEST 2.B FALLÓ: aceptó una fase inexistente.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%La fase indicada no existe.%'
		PRINT 'TEST 2.B OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
	ELSE
		PRINT 'TEST 2.B FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.C Selección inexistente.
-- Esperado: Bloqueado: "- La selección indicada no existe."
BEGIN TRY
	EXEC nucleo.SP_CONSULTAR_FIXTURE @idSeleccion = 999;
	PRINT 'TEST 2.C FALLÓ: aceptó una selección inexistente.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%La selección indicada no existe.%'
		PRINT 'TEST 2.C OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
	ELSE
		PRINT 'TEST 2.C FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.D Fecha desde posterior a la fecha hasta.
-- Esperado: Bloqueado: "- La fecha desde no puede ser posterior a la fecha hasta."
BEGIN TRY
	EXEC nucleo.SP_CONSULTAR_FIXTURE @fechaDesde = '2030-07-02', @fechaHasta = '2030-07-01';
	PRINT 'TEST 2.D FALLÓ: aceptó un rango de fechas invertido.';
END TRY
BEGIN CATCH
	IF ERROR_MESSAGE() LIKE '%La fecha desde no puede ser posterior a la fecha hasta.%'
		PRINT 'TEST 2.D OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
	ELSE
		PRINT 'TEST 2.D FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.E Todas las condiciones incumplidas a la vez.
-- Esperado: Bloqueado con UN solo mensaje que empieza con "SP_CONSULTAR_FIXTURE - No se pudo completar
--           la consulta:" y trae las 4 líneas (sede, fase, selección y rango de fechas).
BEGIN TRY
	EXEC nucleo.SP_CONSULTAR_FIXTURE @idSede = 999, @idFase = 99, @idSeleccion = 999,
	                                 @fechaDesde = '2030-07-02', @fechaHasta = '2030-07-01';
	PRINT 'TEST 2.E FALLÓ: aceptó parámetros inválidos.';
END TRY
BEGIN CATCH
	IF ERROR_NUMBER() = 52000
	   AND ERROR_MESSAGE() LIKE 'SP_CONSULTAR_FIXTURE - No se pudo completar la consulta:%'
	   AND ERROR_MESSAGE() LIKE '%La sede indicada no existe.%'
	   AND ERROR_MESSAGE() LIKE '%La fase indicada no existe.%'
	   AND ERROR_MESSAGE() LIKE '%La selección indicada no existe.%'
	   AND ERROR_MESSAGE() LIKE '%La fecha desde no puede ser posterior a la fecha hasta.%'
		PRINT 'TEST 2.E OK (Bloqueado): ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
	ELSE
		PRINT 'TEST 2.E FALLÓ: mensaje inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- 3. eventos.vw_Goleadores
-- Esperado: OK.
--   J1: 2 goles, 0 de penal, 1 asistencia, 1.º de XTA (su penal de la tanda no cuenta).
--   J2: 1 gol, 1 asistencia, 2.º de XTA.
--   J4: 1 gol (el gol en contra del 230 no cuenta). J5: 1 gol, 1 de penal (la tanda no cuenta).
--   J4 y J5 empatan en el 1.º puesto de XTB.
--   J3 (solo un penal de la tanda) y J6 (gol en un partido Programado) no aparecen.
-- =========================================================================
BEGIN TRY
	IF EXISTS (SELECT 1 FROM eventos.vw_Goleadores WHERE IdJugador = @j1 AND Goles = 2 AND GolesDePenal = 0
	                                                 AND Asistencias = 1 AND PosicionSeleccion = 1 AND Seleccion = 'XTA')
	   AND EXISTS (SELECT 1 FROM eventos.vw_Goleadores WHERE IdJugador = @j2 AND Goles = 1 AND Asistencias = 1
	                                                     AND PosicionSeleccion = 2)
	   AND EXISTS (SELECT 1 FROM eventos.vw_Goleadores WHERE IdJugador = @j4 AND Goles = 1 AND PosicionSeleccion = 1)
	   AND EXISTS (SELECT 1 FROM eventos.vw_Goleadores WHERE IdJugador = @j5 AND Goles = 1 AND GolesDePenal = 1
	                                                     AND PosicionSeleccion = 1)
	   AND NOT EXISTS (SELECT 1 FROM eventos.vw_Goleadores WHERE IdJugador IN (@j3, @j6))
		PRINT 'TEST 3 OK: goleadores sin goles en contra, sin tanda de penales y solo de partidos finalizados.';
	ELSE
		PRINT 'TEST 3 FALLÓ: la tabla de goleadores no es la esperada.';
END TRY
BEGIN CATCH
	PRINT 'TEST 3 FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

SELECT Jugador, Seleccion, Goles, GolesDePenal, Asistencias, PosicionSeleccion
FROM eventos.vw_Goleadores WHERE Seleccion IN ('XTA', 'XTB', 'XTC') ORDER BY Seleccion, PosicionSeleccion;

-- =========================================================================
-- 4. jugadores.vw_HistorialTitularidad
-- Esperado: OK. J1 figura en 2 partidos, titular en el 230 con rival XTB.
--           J3: suplente sin ingreso en el 230 (Jugo = 0) e ingreso en el 232 al minuto 75 (Jugo = 1).
--           J2 sale en el 232 al minuto 75. J7 (XTB) suplente sin ingreso en el 232, rival XTA.
-- =========================================================================
BEGIN TRY
	IF (SELECT COUNT(*) FROM jugadores.vw_HistorialTitularidad WHERE IdJugador = @j1) = 2
	   AND EXISTS (SELECT 1 FROM jugadores.vw_HistorialTitularidad
	               WHERE IdJugador = @j1 AND NumeroPartido = 230 AND EstadoTitularidad = 'Titular'
	                 AND Jugo = 1 AND Rival = 'XTB' AND Seleccion = 'XTA')
	   AND EXISTS (SELECT 1 FROM jugadores.vw_HistorialTitularidad
	               WHERE IdJugador = @j3 AND NumeroPartido = 230 AND EstadoTitularidad = 'Suplente' AND Jugo = 0)
	   AND EXISTS (SELECT 1 FROM jugadores.vw_HistorialTitularidad
	               WHERE IdJugador = @j3 AND NumeroPartido = 232 AND MinutoIngreso = 75 AND Jugo = 1)
	   AND EXISTS (SELECT 1 FROM jugadores.vw_HistorialTitularidad
	               WHERE IdJugador = @j2 AND NumeroPartido = 232 AND MinutoSalida = 75)
	   AND EXISTS (SELECT 1 FROM jugadores.vw_HistorialTitularidad
	               WHERE IdJugador = @j7 AND NumeroPartido = 232 AND Jugo = 0 AND Seleccion = 'XTB' AND Rival = 'XTA')
		PRINT 'TEST 4 OK: historial de titularidad con ingresos y salidas.';
	ELSE
		PRINT 'TEST 4 FALLÓ: el historial de titularidad no es el esperado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 4 FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

SELECT Jugador, Seleccion, NumeroPartido, Rival, EstadoTitularidad, PosicionEnCampo, MinutoIngreso, MinutoSalida, Jugo
FROM jugadores.vw_HistorialTitularidad WHERE NumeroPartido BETWEEN 230 AND 233 ORDER BY NumeroPartido, Seleccion, Jugador;

-- =========================================================================
-- 5. eventos.vw_TarjetasPorSancionado
-- Esperado: OK.
--   J4: 2 amarillas, suspensión de 1 partido por la del 232; XTB no jugó ningún partido finalizado
--       después -> SuspensionActiva = 1 y PartidosPendientes = 1.
--   J5: roja directa en el 230 (1 partido); XTB jugó el 232 (finalizado) después -> cumplida
--       (SuspensionActiva = 0).
--   ayudante de campo de XTA: roja directa como 'Staff técnico' de XTA, cumplida con el 232.
-- =========================================================================
BEGIN TRY
	IF EXISTS (SELECT 1 FROM eventos.vw_TarjetasPorSancionado
	           WHERE IdJugador = @j4 AND TipoSancionado = 'Jugador' AND Seleccion = 'XTB' AND Amarillas = 2
	             AND RojasDirectas = 0 AND PartidosPendientes = 1 AND SuspensionActiva = 1)
	   AND EXISTS (SELECT 1 FROM eventos.vw_TarjetasPorSancionado
	               WHERE IdJugador = @j5 AND RojasDirectas = 1 AND PartidosSuspensionTotal = 1
	                 AND PartidosPendientes = 0 AND SuspensionActiva = 0)
	   AND EXISTS (SELECT 1 FROM eventos.vw_TarjetasPorSancionado
	               WHERE IdStaffTecnico = @dtA AND TipoSancionado = 'Staff técnico' AND IdSeleccion = @selA
	                 AND RojasDirectas = 1 AND SuspensionActiva = 0)
		PRINT 'TEST 5 OK: tarjetas por sancionado con suspensión activa y cumplida.';
	ELSE
		PRINT 'TEST 5 FALLÓ: el reporte de tarjetas no es el esperado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 5 FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- Evidencia: detalle y totales por selección (agrupando la vista).
SELECT TipoSancionado, Sancionado, Seleccion, Amarillas, RojasDobleAmarilla, RojasDirectas,
       PartidosSuspensionTotal, PartidosPendientes, SuspensionActiva
FROM eventos.vw_TarjetasPorSancionado WHERE Seleccion IN ('XTA', 'XTB', 'XTC') ORDER BY Seleccion, Sancionado;
SELECT Seleccion, SUM(Amarillas) AS Amarillas, SUM(RojasDobleAmarilla + RojasDirectas) AS Rojas
FROM eventos.vw_TarjetasPorSancionado WHERE Seleccion IN ('XTA', 'XTB', 'XTC') GROUP BY Seleccion;

-- =========================================================================
-- 6. nucleo.vw_HistorialArbitral
-- Esperado: OK. Árbitro Uno con 2 designaciones: Principal en el 230 (1 amarilla, 2 rojas y la sanción
--           'Informe: TEST TB informe post-partido (2030-06-11)') y VAR en el 232 (1 amarilla, 0 rojas,
--           sin sanciones).
-- =========================================================================
BEGIN TRY
	IF (SELECT COUNT(*) FROM nucleo.vw_HistorialArbitral WHERE IdArbitro = @arb1) = 2
	   AND EXISTS (SELECT 1 FROM nucleo.vw_HistorialArbitral
	               WHERE IdArbitro = @arb1 AND NumeroPartido = 230 AND Rol = 'Principal'
	                 AND AmarillasDelPartido = 1 AND RojasDelPartido = 2 AND CantidadSanciones = 1
	                 AND Sanciones = N'Informe: TEST TB informe post-partido (2030-06-11)')
	   AND EXISTS (SELECT 1 FROM nucleo.vw_HistorialArbitral
	               WHERE IdArbitro = @arb1 AND NumeroPartido = 232 AND Rol = 'VAR'
	                 AND AmarillasDelPartido = 1 AND RojasDelPartido = 0 AND CantidadSanciones = 0 AND Sanciones IS NULL)
		PRINT 'TEST 6 OK: historial arbitral con rol, tarjetas del partido y sanciones.';
	ELSE
		PRINT 'TEST 6 FALLÓ: el historial arbitral no es el esperado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 6 FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

SELECT Arbitro, NumeroPartido, Rol, SeleccionLocal, SeleccionVisitante, AmarillasDelPartido, RojasDelPartido,
       CantidadSanciones, Sanciones
FROM nucleo.vw_HistorialArbitral WHERE IdArbitro IN (@arb1, @arb2) ORDER BY Arbitro, NumeroPartido;

-- =========================================================================
-- 7. publicidad.vw_EspaciosPublicitariosUSD y publicidad.vw_OcupacionPublicitariaSede
-- Esperado: OK.
--   Espacio 1 (1000 USD) -> 1000.00 USD, sin fecha de cotización; anunciante y campaña TEST TB
--   (el anunciante se obtiene a través de la campaña de la pieza).
--   Espacio 2 (1000 XTA) -> 500.00 USD con la cotización más reciente (2030-01-01, 1 USD = 2 XTA).
--   Espacio 3 (1000 XTB, sin cotización) -> TarifaUSD NULL.
--   Sede A: 2 partidos, 8 espacios disponibles, 3 ocupados (37.50 %), 1500.00 USD, 1 sin cotización.
--   Sede C: 2 partidos, 0 ocupados (0 %), 0.00 USD.
-- =========================================================================
BEGIN TRY
	IF EXISTS (SELECT 1 FROM publicidad.vw_EspaciosPublicitariosUSD
	           WHERE IdPartido = @p230 AND NumeroEspacio = 1 AND TarifaUSD = 1000.00 AND FechaCotizacion IS NULL
	             AND Anunciante = 'TEST TB Anunciante' AND Campania = 'TEST TB Campania')
	   AND EXISTS (SELECT 1 FROM publicidad.vw_EspaciosPublicitariosUSD
	               WHERE IdPartido = @p230 AND NumeroEspacio = 2 AND Moneda = 'XTA'
	                 AND TarifaUSD = 500.00 AND FechaCotizacion = '2030-01-01')
	   AND EXISTS (SELECT 1 FROM publicidad.vw_EspaciosPublicitariosUSD
	               WHERE IdPartido = @p230 AND NumeroEspacio = 3 AND TarifaUSD IS NULL)
		PRINT 'TEST 7.A OK: tarifas convertidas a USD con la última cotización (NULL sin cotización).';
	ELSE
		PRINT 'TEST 7.A FALLÓ: la conversión a USD no es la esperada.';

	IF EXISTS (SELECT 1 FROM publicidad.vw_OcupacionPublicitariaSede
	           WHERE IdSede = @sedeA AND Partidos = 2 AND EspaciosDisponibles = 8 AND EspaciosOcupados = 3
	             AND PorcentajeOcupacion = 37.50 AND IngresosUSD = 1500.00 AND EspaciosSinCotizacion = 1)
	   AND EXISTS (SELECT 1 FROM publicidad.vw_OcupacionPublicitariaSede
	               WHERE IdSede = @sedeC AND Partidos = 2 AND EspaciosOcupados = 0
	                 AND PorcentajeOcupacion = 0 AND IngresosUSD = 0)
		PRINT 'TEST 7.B OK: ocupación e ingresos publicitarios por sede.';
	ELSE
		PRINT 'TEST 7.B FALLÓ: la ocupación por sede no es la esperada.';
END TRY
BEGIN CATCH
	PRINT 'TEST 7 FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

SELECT NumeroPartido, Estadio, NumeroEspacio, Anunciante, Pieza, TarifaPublicitaria, Moneda, TarifaUSD, FechaCotizacion
FROM publicidad.vw_EspaciosPublicitariosUSD WHERE IdPartido = @p230 ORDER BY NumeroEspacio;
SELECT Estadio, Partidos, EspaciosDisponibles, EspaciosOcupados, PorcentajeOcupacion, IngresosUSD, EspaciosSinCotizacion
FROM publicidad.vw_OcupacionPublicitariaSede WHERE IdSede IN (@sedeA, @sedeC);

-- =========================================================================
-- 8. nucleo.vw_SedesMapa
-- Esperado: OK. Sede A con latitud -34.6, longitud -58.4, huso 'Argentina Standard Time',
--           2 partidos y ubicación 'TEST TB Ciudad A, TEST TB Pais A'.
-- =========================================================================
BEGIN TRY
	IF EXISTS (SELECT 1 FROM nucleo.vw_SedesMapa
	           WHERE IdSede = @sedeA AND Latitud = -34.600000 AND Longitud = -58.400000
	             AND HusoHorario = 'Argentina Standard Time' AND Capacidad = 50000 AND CantidadPartidos = 2
	             AND Ubicacion = 'TEST TB Ciudad A, TEST TB Pais A')
		PRINT 'TEST 8 OK: sede con coordenadas, huso y cantidad de partidos para el mapa.';
	ELSE
		PRINT 'TEST 8 FALLÓ: los datos de la sede para el mapa no son los esperados.';
END TRY
BEGIN CATCH
	PRINT 'TEST 8 FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

SELECT Estadio, Ciudad, Pais, HusoHorario, Capacidad, Latitud, Longitud, CantidadPartidos
FROM nucleo.vw_SedesMapa WHERE IdSede IN (@sedeA, @sedeC);

-- =========================================================================
-- 9. publicidad.vw_MercadosPrimeTimePorPartido
-- Esperado: OK. El 230 (23:00 UTC) cae en prime time en el país A (20:00 local, país participante);
--           no en el país B (Tokio, 08:00) ni en el C (UTC, 23:00: el límite superior no entra).
-- =========================================================================
-- Verificación previa: nucleo.fn_MercadosEnPrimeTime convierte la hora a la zona de TODOS los países;
-- con un HusoHorarioComercial que no exista en sys.time_zone_info la consulta falla por ese dato
-- (del seed, no del script 34), así que el caso se omite.
-- Esperado (si se omite): "TEST 9 OMITIDO: hay países con huso horario inválido (dato de seed, no del script 34)".
IF EXISTS (SELECT 1 FROM nucleo.Pais AS pa
           WHERE NOT EXISTS (SELECT 1 FROM sys.time_zone_info AS tz
                             WHERE tz.name COLLATE DATABASE_DEFAULT = pa.HusoHorarioComercial))
	PRINT 'TEST 9 OMITIDO: hay países con huso horario inválido (dato de seed, no del script 34)';
ELSE
BEGIN
	BEGIN TRY
		IF EXISTS (SELECT 1 FROM publicidad.vw_MercadosPrimeTimePorPartido
		           WHERE IdPartido = @p230 AND IdPais = @paisA AND EsPaisParticipante = 1
		             AND FechaHoraLocalMercado = '2030-06-10 20:00')
		   AND NOT EXISTS (SELECT 1 FROM publicidad.vw_MercadosPrimeTimePorPartido
		                   WHERE IdPartido = @p230 AND IdPais IN (@paisB, @paisC))
			PRINT 'TEST 9 OK: mercados en prime time por partido.';
		ELSE
			PRINT 'TEST 9 FALLÓ: los mercados en prime time no son los esperados.';
	END TRY
	BEGIN CATCH
		PRINT 'TEST 9 FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
	END CATCH;
END;

-- =========================================================================
-- LIMPIEZA FINAL: se deshace todo lo insertado por el test.
-- =========================================================================
ROLLBACK TRANSACTION;
DROP TABLE IF EXISTS #fx;
GO

-- Esperado: 0 filas de datos de prueba remanentes.
SELECT (SELECT COUNT(*) FROM nucleo.Partido WHERE NumeroPartido BETWEEN 230 AND 233)
     + (SELECT COUNT(*) FROM nucleo.Pais    WHERE Nombre LIKE 'TEST TB%')
     + (SELECT COUNT(*) FROM nucleo.Sede    WHERE NombreEstadio LIKE 'TEST TB%')
     + (SELECT COUNT(*) FROM publicidad.Moneda WHERE Codigo IN ('XTA', 'XTB')) AS DatosTest_Esperado_0;
GO
