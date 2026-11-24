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
	- Probar las funciones creadas en 07_Funciones_Nucleo.sql:
		  nucleo.fn_SeleccionesDelPartido, nucleo.fn_MercadosEnPrimeTime,
		  nucleo.fn_SeleccionConPartidoCercano y nucleo.fn_PartidoTieneRegistros
	- Requiere haber ejecutado 01_Tablas_Nucleo.sql y 07_Funciones_Nucleo.sql.
	- Los datos de prueba se insertan directamente (sin usar SP), con prefijo 'TEST' y
	  números de partido en el rango reservado 240-255 (el torneo real no los usa).
	  Se borran al inicio y al final del script, respetando el orden de las FK.
	- Convención de salida: "OK" si el caso se comportó como se esperaba,
	  "FALLÓ" en caso contrario.

Escenario (junio 2026, salvo que se indique otra fecha):
	Países de prueba (código ISO de uso reservado XA..XI) y su zona horaria:
		A Argentina Standard Time     UTC-3 (sin horario de verano)
		B Tokyo Standard Time         UTC+9
		C W. Europe Standard Time     UTC+2 en junio / UTC+1 en enero (horario de verano)
		D Eastern Standard Time       UTC-4 en junio / UTC-5 en enero (horario de verano)
		E UTC                         UTC+0
		F SA Pacific Standard Time    UTC-5 (sin horario de verano)
		G Central Standard Time       UTC-5 en junio (horario de verano)
		H Mountain Standard Time      UTC-6 en junio (horario de verano)
		I Pacific Standard Time       UTC-7 en junio (horario de verano)
	Selecciones: Sel1 = país A (local), Sel2 = país D (visitante).
	Se filtra por Nombre LIKE 'TEST%' para ignorar los países reales del seed.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- LIMPIEZA PREVIA
-- =========================================================================
DELETE FROM nucleo.Partido WHERE IdSede IN (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%');
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Grupo WHERE Nombre = 'Z';
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
GO

-- =========================================================================
-- DATOS DE PRUEBA
-- =========================================================================
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST Confederacion', 'TST');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TST');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, PBIPerCapitaUSD, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST Pais A', 'XA', 'XAA', 13000.00, 'Argentina Standard Time',  @idConf),
       ('TEST Pais B', 'XB', 'XAB', 39000.00, 'Tokyo Standard Time',      @idConf),
       ('TEST Pais C', 'XC', 'XAC', 52000.00, 'W. Europe Standard Time',  @idConf),
       ('TEST Pais D', 'XD', 'XAD', 80000.00, 'Eastern Standard Time',    @idConf),
       ('TEST Pais E', 'XE', 'XAE', 1000.00,  'UTC',                      @idConf),
       ('TEST Pais F', 'XF', 'XAF', 7000.00,  'SA Pacific Standard Time', @idConf),
       ('TEST Pais G', 'XG', 'XAG', 11000.00, 'Central Standard Time',    @idConf),
       ('TEST Pais H', 'XH', 'XAH', 9000.00,  'Mountain Standard Time',   @idConf),
       ('TEST Pais I', 'XI', 'XAI', 60000.00, 'Pacific Standard Time',    @idConf);

DECLARE @idPaisA SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAA');
DECLARE @idPaisB SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAB');
DECLARE @idPaisC SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAC');
DECLARE @idPaisD SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAD');
DECLARE @idPaisE SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAE');
DECLARE @idPaisF SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAF');
DECLARE @idPaisG SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAG');
DECLARE @idPaisH SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAH');
DECLARE @idPaisI SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAI');

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais) VALUES ('TEST Ciudad', 'Eastern Standard Time', @idPaisD);
DECLARE @idCiudad SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST Ciudad');

INSERT INTO nucleo.Sede (NombreEstadio, IdCiudad) VALUES ('TEST Estadio', @idCiudad);
DECLARE @idSede TINYINT = (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio = 'TEST Estadio');

INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
VALUES ('XAA', 1, @idPaisA, @idGrupo),
       ('XAD', 2, @idPaisD, @idGrupo);
DECLARE @idSel1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XAA');
DECLARE @idSel2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XAD');

DECLARE @idFase TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Fase de grupos');

-- Partidos (todos Programados, misma sede, horarios UTC distintos).
--   240: cruce NULL/NULL                           | 2026-06-19 01:00:00 UTC (5 mercados en prime time)
--   241: Argentina 18:59:59 (borde inferior, no)   | 2026-06-15 21:59:59 UTC
--   242: Argentina 19:00:00 (borde inferior, sí)   | 2026-06-15 22:00:00 UTC
--   243: Argentina 22:59:59 (borde superior, sí)   | 2026-06-16 01:59:59 UTC
--   244: Argentina 23:00:00 (borde superior, no)   | 2026-06-16 02:00:00 UTC
--   245: Sel1 vs Sel2, 5 mercados en prime time    | 2026-06-17 01:00:00 UTC
--   246: horario de verano Eastern (junio)         | 2026-06-18 23:30:00 UTC
--   247: sin horario de verano Eastern (enero)     | 2026-01-18 23:30:00 UTC
--   248: horario de verano W. Europe (junio)       | 2026-06-21 17:30:00 UTC
--   249: sin horario de verano W. Europe (enero)   | 2026-01-21 17:30:00 UTC
--   251: solo selección local definida             | 2026-06-20 01:00:00 UTC
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (240, '2026-06-19 01:00:00', 'Programado', @idFase, @idSede, NULL,     NULL),
       (241, '2026-06-15 21:59:59', 'Programado', @idFase, @idSede, @idSel1,  @idSel2),
       (242, '2026-06-15 22:00:00', 'Programado', @idFase, @idSede, @idSel1,  @idSel2),
       (243, '2026-06-16 01:59:59', 'Programado', @idFase, @idSede, @idSel1,  @idSel2),
       (244, '2026-06-16 02:00:00', 'Programado', @idFase, @idSede, @idSel1,  @idSel2),
       (245, '2026-06-17 01:00:00', 'Programado', @idFase, @idSede, @idSel1,  @idSel2),
       (246, '2026-06-18 23:30:00', 'Programado', @idFase, @idSede, @idSel1,  @idSel2),
       (247, '2026-01-18 23:30:00', 'Programado', @idFase, @idSede, @idSel1,  @idSel2),
       (248, '2026-06-21 17:30:00', 'Programado', @idFase, @idSede, @idSel1,  @idSel2),
       (249, '2026-01-21 17:30:00', 'Programado', @idFase, @idSede, @idSel1,  @idSel2),
       (251, '2026-06-20 01:00:00', 'Programado', @idFase, @idSede, @idSel1,  NULL);

DECLARE @p240 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 240);
DECLARE @p241 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 241);
DECLARE @p242 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 242);
DECLARE @p243 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 243);
DECLARE @p244 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 244);
DECLARE @p245 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 245);
DECLARE @p246 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 246);
DECLARE @p247 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 247);
DECLARE @p248 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 248);
DECLARE @p249 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 249);
DECLARE @p251 SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 251);

-- =========================================================================
-- TEST 1: nucleo.fn_SeleccionesDelPartido
-- =========================================================================

-- 1.A Partido 245 (cruce definido).
-- Esperado: 2 filas -> (Sel1, 'Local') y (Sel2, 'Visitante').
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionesDelPartido(@p245)) = 2
   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesDelPartido(@p245) WHERE IdSeleccion = @idSel1 AND Localia = 'Local')
   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesDelPartido(@p245) WHERE IdSeleccion = @idSel2 AND Localia = 'Visitante')
	PRINT 'TEST 1.A OK: 2 filas (Sel1 Local, Sel2 Visitante).';
ELSE
	PRINT 'TEST 1.A FALLÓ: no devolvió (Sel1, Local) y (Sel2, Visitante).';

-- 1.B Partido 240 (cruce NULL/NULL).
-- Esperado: 0 filas.
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionesDelPartido(@p240)) = 0
	PRINT 'TEST 1.B OK: 0 filas con el cruce sin definir.';
ELSE
	PRINT 'TEST 1.B FALLÓ: devolvió filas con el cruce sin definir.';

-- 1.C Partido 251 (solo la selección local definida).
-- Esperado: 1 fila -> (Sel1, 'Local'); ninguna fila 'Visitante'.
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionesDelPartido(@p251)) = 1
   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesDelPartido(@p251) WHERE IdSeleccion = @idSel1 AND Localia = 'Local')
	PRINT 'TEST 1.C OK: 1 fila (Sel1 Local).';
ELSE
	PRINT 'TEST 1.C FALLÓ: no devolvió solo (Sel1, Local).';

-- 1.D Partido inexistente.
-- Esperado: 0 filas.
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionesDelPartido(-1)) = 0
	PRINT 'TEST 1.D OK: 0 filas con partido inexistente.';
ELSE
	PRINT 'TEST 1.D FALLÓ: devolvió filas con partido inexistente.';

-- =========================================================================
-- TEST 2: nucleo.fn_MercadosEnPrimeTime
-- (los bordes se verifican sobre el país A, Argentina UTC-3 sin horario de verano)
-- =========================================================================

-- 2.A Borde inferior: partido 241, 21:59:59 UTC = 18:59:59 en Argentina.
-- Esperado: 0 filas para el país A (18:59:59 no es prime time).
IF (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p241) WHERE IdPais = @idPaisA) = 0
	PRINT 'TEST 2.A OK: 18:59:59 local queda fuera del prime time.';
ELSE
	PRINT 'TEST 2.A FALLÓ: 18:59:59 local apareció en prime time.';

-- 2.B Borde inferior: partido 242, 22:00:00 UTC = 19:00:00 en Argentina.
-- Esperado: 1 fila para el país A con FechaHoraLocalMercado = 2026-06-15 19:00:00.
IF (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p242) WHERE IdPais = @idPaisA) = 1
   AND EXISTS (SELECT 1 FROM nucleo.fn_MercadosEnPrimeTime(@p242)
               WHERE IdPais = @idPaisA AND FechaHoraLocalMercado = '2026-06-15 19:00:00')
	PRINT 'TEST 2.B OK: 19:00:00 local entra al prime time.';
ELSE
	PRINT 'TEST 2.B FALLÓ: 19:00:00 local no apareció (o con hora local incorrecta).';

-- 2.C Borde superior: partido 243, 01:59:59 UTC = 22:59:59 (día anterior) en Argentina.
-- Esperado: 1 fila para el país A con FechaHoraLocalMercado = 2026-06-15 22:59:59.
IF (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p243) WHERE IdPais = @idPaisA) = 1
   AND EXISTS (SELECT 1 FROM nucleo.fn_MercadosEnPrimeTime(@p243)
               WHERE IdPais = @idPaisA AND FechaHoraLocalMercado = '2026-06-15 22:59:59')
	PRINT 'TEST 2.C OK: 22:59:59 local entra al prime time.';
ELSE
	PRINT 'TEST 2.C FALLÓ: 22:59:59 local no apareció (o con hora local incorrecta).';

-- 2.D Borde superior: partido 244, 02:00:00 UTC = 23:00:00 en Argentina.
-- Esperado: 0 filas para el país A (23:00:00 no es prime time).
IF (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p244) WHERE IdPais = @idPaisA) = 0
	PRINT 'TEST 2.D OK: 23:00:00 local queda fuera del prime time.';
ELSE
	PRINT 'TEST 2.D FALLÓ: 23:00:00 local apareció en prime time.';

-- 2.E Horario de verano, zona Eastern (país D): partido 246, 2026-06-18 23:30 UTC.
-- Junio: UTC-4 -> 19:30 local (prime time).
-- Esperado: 1 fila para el país D con FechaHoraLocalMercado = 2026-06-18 19:30:00.
IF (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p246) WHERE IdPais = @idPaisD) = 1
   AND EXISTS (SELECT 1 FROM nucleo.fn_MercadosEnPrimeTime(@p246)
               WHERE IdPais = @idPaisD AND FechaHoraLocalMercado = '2026-06-18 19:30:00')
	PRINT 'TEST 2.E OK: con horario de verano (UTC-4) 23:30 UTC = 19:30 local, entra.';
ELSE
	PRINT 'TEST 2.E FALLÓ: no aplicó el horario de verano de la zona Eastern.';

-- 2.F Sin horario de verano, zona Eastern (país D): partido 247, 2026-01-18 23:30 UTC.
-- Enero: UTC-5 -> 18:30 local (fuera de franja). El país A (UTC-3 fijo) queda en 20:30 (control).
-- Esperado: 0 filas para el país D; 1 fila para el país A con FechaHoraLocalMercado = 2026-01-18 20:30:00.
IF (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p247) WHERE IdPais = @idPaisD) = 0
   AND EXISTS (SELECT 1 FROM nucleo.fn_MercadosEnPrimeTime(@p247)
               WHERE IdPais = @idPaisA AND FechaHoraLocalMercado = '2026-01-18 20:30:00')
	PRINT 'TEST 2.F OK: sin horario de verano (UTC-5) 23:30 UTC = 18:30 local, no entra; Argentina no cambia.';
ELSE
	PRINT 'TEST 2.F FALLÓ: el resultado de Eastern en enero no es el esperado.';

-- 2.G Horario de verano, zona W. Europe (país C): partidos 248 (junio) y 249 (enero), ambos 17:30 UTC.
-- Junio: UTC+2 -> 19:30 local (entra). Enero: UTC+1 -> 18:30 local (no entra).
-- Esperado: partido 248 -> 1 fila para el país C con FechaHoraLocalMercado = 2026-06-21 19:30:00;
--           partido 249 -> 0 filas para el país C.
IF EXISTS (SELECT 1 FROM nucleo.fn_MercadosEnPrimeTime(@p248)
           WHERE IdPais = @idPaisC AND FechaHoraLocalMercado = '2026-06-21 19:30:00')
   AND (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p249) WHERE IdPais = @idPaisC) = 0
	PRINT 'TEST 2.G OK: W. Europe entra en junio (UTC+2) y no entra en enero (UTC+1).';
ELSE
	PRINT 'TEST 2.G FALLÓ: el horario de verano de W. Europe no se aplicó como se esperaba.';

-- 2.H Más de 4 mercados en prime time: partido 245, 2026-06-17 01:00 UTC.
-- Horas locales: A 22:00 (sí), B 10:00 (no), C 03:00 (no), D 21:00 (sí), E 01:00 (no),
--                F 20:00 (sí), G 20:00 (sí), H 19:00 (sí), I 18:00 (no).
-- Esperado: 5 filas de países TEST (A, D, F, G, H); no aparecen B, C, E ni I.
IF (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p245) WHERE Nombre LIKE 'TEST%') = 5
   AND (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p245)
        WHERE IdPais IN (@idPaisA, @idPaisD, @idPaisF, @idPaisG, @idPaisH)) = 5
	PRINT 'TEST 2.H OK: 5 mercados en prime time (A, D, F, G, H); la función no limita a 4.';
ELSE
	PRINT 'TEST 2.H FALLÓ: el conjunto de mercados en prime time no es A, D, F, G, H.';

-- 2.I EsPaisParticipante con cruce definido: partido 245 (Sel1 = país A, Sel2 = país D).
-- Esperado: EsPaisParticipante = 1 solo en las filas de los países A y D (2 filas);
--           las filas de F, G y H tienen EsPaisParticipante = 0 (3 filas).
IF (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p245)
    WHERE Nombre LIKE 'TEST%' AND EsPaisParticipante = 1 AND IdPais IN (@idPaisA, @idPaisD)) = 2
   AND (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p245)
        WHERE Nombre LIKE 'TEST%' AND EsPaisParticipante = 0 AND IdPais IN (@idPaisF, @idPaisG, @idPaisH)) = 3
	PRINT 'TEST 2.I OK: solo A y D figuran como países participantes.';
ELSE
	PRINT 'TEST 2.I FALLÓ: EsPaisParticipante no coincide con las selecciones del partido.';

-- 2.J Cruce NULL/NULL: partido 240, 2026-06-19 01:00 UTC (mismos mercados que el 245).
-- Esperado: 5 filas de países TEST y ninguna con EsPaisParticipante = 1.
IF (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p240) WHERE Nombre LIKE 'TEST%') = 5
   AND (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p240)
        WHERE Nombre LIKE 'TEST%' AND EsPaisParticipante = 1) = 0
	PRINT 'TEST 2.J OK: con el cruce sin definir hay 5 mercados y ningún participante.';
ELSE
	PRINT 'TEST 2.J FALLÓ: con el cruce sin definir apareció un participante o cambió la cantidad de mercados.';

-- 2.K Solo la selección local definida: partido 251, 2026-06-20 01:00 UTC.
-- Esperado: 5 filas de países TEST; EsPaisParticipante = 1 solo en el país A (la selección visitante es NULL,
--           por lo que el país D, aunque esté en prime time, figura con EsPaisParticipante = 0).
IF (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p251) WHERE Nombre LIKE 'TEST%') = 5
   AND (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@p251)
        WHERE Nombre LIKE 'TEST%' AND EsPaisParticipante = 1) = 1
   AND EXISTS (SELECT 1 FROM nucleo.fn_MercadosEnPrimeTime(@p251) WHERE IdPais = @idPaisA AND EsPaisParticipante = 1)
	PRINT 'TEST 2.K OK: solo el país A figura como participante.';
ELSE
	PRINT 'TEST 2.K FALLÓ: EsPaisParticipante incorrecto con una sola selección definida.';

-- 2.L Columnas informativas: partido 245, país A.
-- Esperado: 1 fila con IdPartido = @p245, CodigoISO3 = 'XAA', PBIPerCapitaUSD = 13000.00,
--           HusoHorarioComercial = 'Argentina Standard Time' y FechaHoraLocalMercado = 2026-06-16 22:00:00.
IF EXISTS (SELECT 1 FROM nucleo.fn_MercadosEnPrimeTime(@p245)
           WHERE IdPais = @idPaisA
             AND IdPartido = @p245
             AND CodigoISO3 = 'XAA'
             AND PBIPerCapitaUSD = 13000.00
             AND HusoHorarioComercial = 'Argentina Standard Time'
             AND FechaHoraLocalMercado = '2026-06-16 22:00:00')
	PRINT 'TEST 2.L OK: las columnas devueltas coinciden con los datos del país A.';
ELSE
	PRINT 'TEST 2.L FALLÓ: alguna columna devuelta para el país A no coincide.';

-- 2.M Partido inexistente.
-- Esperado: 0 filas.
IF (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(-1)) = 0
	PRINT 'TEST 2.M OK: 0 filas con partido inexistente.';
ELSE
	PRINT 'TEST 2.M FALLÓ: devolvió filas con partido inexistente.';

-- =========================================================================
-- TEST 3: nucleo.fn_SeleccionConPartidoCercano (descanso de 48 horas entre partidos de una selección)
-- Partidos de las selecciones: 248 (Sel1 vs Sel2, 2026-06-21 17:30 UTC) y 251 (Sel1, 2026-06-20 01:00 UTC).
-- =========================================================================

-- 3.A Partido a programar el 2026-06-22 18:00 UTC (24 h 30 min después del 248) para Sel1 y Sel2.
-- Esperado: 2 filas, una por selección, con IdPartidoCercano = 248 y HorasDescanso = 48
--           (el 251 está a 65 horas y no cuenta).
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionConPartidoCercano(@idSel1, @idSel2, '2026-06-22 18:00', NULL)) = 2
   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionConPartidoCercano(@idSel1, @idSel2, '2026-06-22 18:00', NULL)
               WHERE IdSeleccion = @idSel1 AND IdPartidoCercano = @p248 AND HorasDescanso = 48)
   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionConPartidoCercano(@idSel1, @idSel2, '2026-06-22 18:00', NULL)
               WHERE IdSeleccion = @idSel2 AND IdPartidoCercano = @p248 AND HorasDescanso = 48)
	PRINT 'TEST 3.A OK: ambas selecciones tienen el partido 248 a menos de 48 horas.';
ELSE
	PRINT 'TEST 3.A FALLÓ: no informó el partido 248 para las dos selecciones.';

-- 3.B Borde: exactamente 48 horas después del 248 (2026-06-23 17:30:00 UTC).
-- Esperado: 0 filas (a exactamente 48 horas no hay conflicto).
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionConPartidoCercano(@idSel1, @idSel2, '2026-06-23 17:30:00', NULL)) = 0
	PRINT 'TEST 3.B OK: a exactamente 48 horas no hay conflicto.';
ELSE
	PRINT 'TEST 3.B FALLÓ: informó un conflicto a exactamente 48 horas.';

-- 3.C Borde: un segundo antes de cumplirse las 48 horas (2026-06-23 17:29:59 UTC).
-- Esperado: 2 filas (el 248 queda a 47 h 59 min 59 s).
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionConPartidoCercano(@idSel1, @idSel2, '2026-06-23 17:29:59', NULL)) = 2
	PRINT 'TEST 3.C OK: a un segundo de las 48 horas hay conflicto.';
ELSE
	PRINT 'TEST 3.C FALLÓ: no informó el conflicto a 47 h 59 min 59 s.';

-- 3.D Excluir el propio partido: se evalúa el mismo horario del 248 (2026-06-21 17:30) excluyéndolo.
-- Esperado: 1 fila: Sel1 con el partido 251 (a 40 h 30 min); Sel2 no tiene otros partidos cercanos.
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionConPartidoCercano(@idSel1, @idSel2, '2026-06-21 17:30', @p248)) = 1
   AND EXISTS (SELECT 1 FROM nucleo.fn_SeleccionConPartidoCercano(@idSel1, @idSel2, '2026-06-21 17:30', @p248)
               WHERE IdSeleccion = @idSel1 AND IdPartidoCercano = @p251)
	PRINT 'TEST 3.D OK: excluido el 248, solo Sel1 tiene cerca el 251.';
ELSE
	PRINT 'TEST 3.D FALLÓ: la exclusión del propio partido no se aplicó como se esperaba.';

-- 3.E Una sola selección informada (la visitante es NULL).
-- Esperado: 1 fila (Sel1 con el 248) para el 2026-06-22 18:00.
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionConPartidoCercano(@idSel1, NULL, '2026-06-22 18:00', NULL)) = 1
	PRINT 'TEST 3.E OK: con una sola selección informada devuelve una fila.';
ELSE
	PRINT 'TEST 3.E FALLÓ: no devolvió exactamente una fila con una sola selección.';

-- 3.F Ambas selecciones NULL, y una fecha lejana sin partidos.
-- Esperado: 0 filas en los dos casos.
IF (SELECT COUNT(*) FROM nucleo.fn_SeleccionConPartidoCercano(NULL, NULL, '2026-06-22 18:00', NULL)) = 0
   AND (SELECT COUNT(*) FROM nucleo.fn_SeleccionConPartidoCercano(@idSel1, @idSel2, '2030-01-01 00:00', NULL)) = 0
	PRINT 'TEST 3.F OK: sin selecciones o sin partidos cercanos no hay filas.';
ELSE
	PRINT 'TEST 3.F FALLÓ: devolvió filas sin selecciones o con una fecha lejana.';

-- =========================================================================
-- TEST 4: nucleo.fn_PartidoTieneRegistros
-- (los casos con registros asociados se prueban en 09_Test_SP_Sedes_Partidos.sql, caso 3.L1, y a través de
--  los SP de partidos que la usan: 3.L en la baja, 3.G y siguientes en la modificación)
-- =========================================================================

-- 4.A Partido 245 sin ningún registro asociado.
-- Esperado: 1 fila con los 7 indicadores y TieneAlguno en 0.
IF (SELECT COUNT(*) FROM nucleo.fn_PartidoTieneRegistros(@p245)) = 1
   AND EXISTS (SELECT 1 FROM nucleo.fn_PartidoTieneRegistros(@p245)
               WHERE TieneFormaciones = 0 AND TieneSustituciones = 0 AND TieneGoles = 0 AND TieneAmonestaciones = 0
                 AND TieneDesignaciones = 0 AND TieneSanciones = 0 AND TieneEspacios = 0 AND TieneAlguno = 0)
	PRINT 'TEST 4.A OK: un partido sin registros devuelve todos los indicadores en 0.';
ELSE
	PRINT 'TEST 4.A FALLÓ: los indicadores del partido 245 no son todos 0.';

-- 4.B Partido inexistente.
-- Esperado: igualmente 1 fila con todo en 0 (la función no distingue un partido inexistente).
IF (SELECT COUNT(*) FROM nucleo.fn_PartidoTieneRegistros(-1)) = 1
   AND EXISTS (SELECT 1 FROM nucleo.fn_PartidoTieneRegistros(-1) WHERE TieneAlguno = 0)
	PRINT 'TEST 4.B OK: un partido inexistente devuelve una fila con todo en 0.';
ELSE
	PRINT 'TEST 4.B FALLÓ: un partido inexistente no devolvió una fila con todo en 0.';
GO

-- =========================================================================
-- LIMPIEZA FINAL
-- =========================================================================
DELETE FROM nucleo.Partido WHERE IdSede IN (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%');
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Grupo WHERE Nombre = 'Z';
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
GO
