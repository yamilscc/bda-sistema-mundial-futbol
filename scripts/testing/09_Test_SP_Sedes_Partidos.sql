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
	- Probar los stored procedures del script 09_SP_Sedes_Partidos.sql:
		  nucleo.SP_ALTA_Sede, nucleo.SP_MODIFICACION_Sede, nucleo.SP_BAJA_Sede,
		  nucleo.SP_ALTA_Partido, nucleo.SP_MODIFICACION_Partido, nucleo.SP_BAJA_Partido
	- Requiere haber ejecutado antes los scripts 00, 01, 02, 03, 04, 06 y 09:
		  00_Reset_Total.sql                      (base y esquemas)
		  01_Tablas_Nucleo.sql                    (tablas del núcleo y datos de Fase)
		  02_Tablas_Jugadores_y_Alineaciones.sql  (jugadores.Formacion y jugadores.Sustitucion)
		  03_Tablas_Eventos.sql                   (eventos.Gol y eventos.Amonestacion)
		  04_Tablas_Publicidad.sql                (publicidad.EspacioPublicitario)
		  06_FK_Cruzadas.sql                      (FK hacia Partido)
		  09_SP_Sedes_Partidos.sql                (los SP que se prueban)
	  Los SP de Partido consultan las tablas de 02, 03 y 04 para detectar registros asociados.
	- Los datos base se insertan directamente (prefijo 'TEST', números de partido en el rango
	  reservado 240-255). Las altas, modificaciones y bajas de Sede y Partido que se prueban se
	  hacen SIEMPRE llamando a los SP; los SELECT muestran los datos manipulados como evidencia.
	- Para simular lo que ocurrirá más adelante en el flujo real, el test carga directamente
	  (solo como preparación): un partido Finalizado con su Concurrencia, una formación y una
	  designación arbitral.
	- Los datos de prueba se borran al inicio y al final del script, respetando el orden de las FK.
	- Convención de salida: "OK" si el caso se comportó como se esperaba; "OK (Bloqueado)" si el SP
	  rechazó la operación con el mensaje esperado (se imprime el mensaje consolidado);
	  "FALLÓ" en caso contrario.

Escenario:
	Sedes: TEST Estadio A (Buenos Aires, Argentina Standard Time, UTC-3 fijo) y
	       TEST Estadio A en Nueva York (Eastern Standard Time, UTC-4 en junio y UTC-5 en enero).
	Selecciones: Sel1, Sel2, Sel3, Sel5 y Sel6 del grupo Y; Sel4 del grupo Z.
	Reglas de agenda vigentes en los SP: 180 minutos entre partidos de una sede y
	48 horas entre los inicios de dos partidos de una selección.
*/

USE MundialFutbol;
GO

SET NOCOUNT ON;
GO

-- =========================================================================
-- LIMPIEZA PREVIA
-- =========================================================================
DELETE FROM nucleo.Sancion
WHERE IdDesignacionArbitral IN (SELECT d.IdDesignacionArbitral FROM nucleo.DesignacionArbitral AS d
                                INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido
                                INNER JOIN nucleo.Sede AS s ON s.IdSede = p.IdSede
                                WHERE s.NombreEstadio LIKE 'TEST%');
DELETE FROM jugadores.Formacion
WHERE IdPartido IN (SELECT p.IdPartido FROM nucleo.Partido AS p
                    INNER JOIN nucleo.Sede AS s ON s.IdSede = p.IdSede
                    WHERE s.NombreEstadio LIKE 'TEST%');
DELETE FROM nucleo.DesignacionArbitral
WHERE IdPartido IN (SELECT p.IdPartido FROM nucleo.Partido AS p
                    INNER JOIN nucleo.Sede AS s ON s.IdSede = p.IdSede
                    WHERE s.NombreEstadio LIKE 'TEST%');
DELETE FROM nucleo.Partido WHERE IdSede IN (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%');
DELETE FROM nucleo.Arbitro WHERE NombreApellido LIKE 'TEST%';
DELETE FROM nucleo.Categoria WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Grupo WHERE Nombre IN ('Y', 'Z');
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
GO

-- =========================================================================
-- DATOS BASE (INSERT directo)
-- =========================================================================
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST Confederacion', 'TST');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TST');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, PBIPerCapitaUSD, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST Pais A', 'XA', 'XAA', 13000.00, 'Argentina Standard Time', @idConf),
       ('TEST Pais B', 'XB', 'XAB', 80000.00, 'Eastern Standard Time',   @idConf),
       ('TEST Pais C', 'XC', 'XAC', 39000.00, 'Tokyo Standard Time',     @idConf),
       ('TEST Pais D', 'XD', 'XAD', 52000.00, 'UTC',                     @idConf),
       ('TEST Pais E', 'XE', 'XAE', 7000.00,  'UTC',                     @idConf),
       ('TEST Pais F', 'XF', 'XAF', 9000.00,  'UTC',                     @idConf);

DECLARE @paisA SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAA');
DECLARE @paisB SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAB');
DECLARE @paisC SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAC');
DECLARE @paisD SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAD');
DECLARE @paisE SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAE');
DECLARE @paisF SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'XAF');

-- Tres ciudades: dos con el mismo huso (Buenos Aires y Córdoba) y una con otro huso y horario de verano.
INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST Ciudad Buenos Aires', 'Argentina Standard Time', @paisA),
       ('TEST Ciudad Cordoba',      'Argentina Standard Time', @paisA),
       ('TEST Ciudad Nueva York',   'Eastern Standard Time',   @paisB);

DECLARE @ciudadBsAs    SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST Ciudad Buenos Aires');
DECLARE @ciudadCordoba SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST Ciudad Cordoba');
DECLARE @ciudadNY      SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST Ciudad Nueva York');

INSERT INTO nucleo.Grupo (Nombre) VALUES ('Y'), ('Z');
DECLARE @grupoY TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Y');
DECLARE @grupoZ TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
VALUES ('XAA', 1, @paisA, @grupoY),
       ('XAB', 2, @paisB, @grupoY),
       ('XAC', 3, @paisC, @grupoY),
       ('XAD', 4, @paisD, @grupoZ),
       ('XAE', 5, @paisE, @grupoY),
       ('XAF', 6, @paisF, @grupoY);

DECLARE @sel1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XAA');
DECLARE @sel2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XAB');
DECLARE @sel3 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XAC');
DECLARE @sel4 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XAD');
DECLARE @sel5 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XAE');
DECLARE @sel6 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'XAF');

INSERT INTO nucleo.Categoria (Nombre) VALUES ('TEST Categoria');
DECLARE @idCategoria TINYINT = (SELECT IdCategoria FROM nucleo.Categoria WHERE Nombre = 'TEST Categoria');
INSERT INTO nucleo.Arbitro (NombreApellido, FechaNacimiento, IdPais, IdCategoria)
VALUES ('TEST Arbitro', '1980-01-01', @paisC, @idCategoria);
DECLARE @idArbitro SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST Arbitro');

DECLARE @fGrupos  TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Fase de grupos');
DECLARE @fOctavos TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');

-- Variables de trabajo
DECLARE @sedeA TINYINT, @sedeB TINYINT, @sedeBaja TINYINT;
DECLARE @p240 SMALLINT, @p241 SMALLINT, @p242 SMALLINT, @p243 SMALLINT, @p244 SMALLINT, @p245 SMALLINT;
DECLARE @msg NVARCHAR(MAX);

-- =========================================================================
-- TEST 1: SP_ALTA_Sede, SP_MODIFICACION_Sede y SP_BAJA_Sede (sedes sin partidos)
-- =========================================================================

-- 1.A Alta válida con capacidad y coordenadas.
-- Esperado: OK, se inserta 'TEST Estadio A' en Buenos Aires y @sedeA devuelve su id.
BEGIN TRY
	EXEC nucleo.SP_ALTA_Sede @nombreEstadio = 'TEST Estadio A', @idCiudad = @ciudadBsAs,
	     @capacidad = 50000, @latitud = -34.603722, @longitud = -58.381592, @idSede = @sedeA OUTPUT;

	SELECT s.IdSede, s.NombreEstadio, c.Nombre AS Ciudad, c.HusoHorario, s.Capacidad, s.Latitud, s.Longitud
	FROM nucleo.Sede AS s INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = s.IdCiudad
	WHERE s.IdSede = @sedeA;

	IF @sedeA IS NOT NULL AND EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @sedeA AND NombreEstadio = 'TEST Estadio A' AND Capacidad = 50000)
		PRINT 'TEST 1.A OK: sede insertada con id ' + CAST(@sedeA AS VARCHAR(5)) + '.';
	ELSE
		PRINT 'TEST 1.A FALLÓ: la sede no se insertó como se esperaba.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.A FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.B Alta con varios errores a la vez.
-- Parámetros: nombre en blanco, ciudad inexistente, capacidad 0, latitud 95 sin longitud.
-- Esperado: Bloqueado con UN solo mensaje que lista exactamente 5 condiciones: nombre obligatorio,
--           ciudad inexistente, capacidad mayor a cero, latitud y longitud juntas, latitud fuera de rango.
BEGIN TRY
	EXEC nucleo.SP_ALTA_Sede @nombreEstadio = '   ', @idCiudad = 32000, @capacidad = 0, @latitud = 95, @longitud = NULL;
	PRINT 'TEST 1.B FALLÓ: permitió el alta con varios errores.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000
	   AND @msg LIKE N'%nombre del estadio es obligatorio%'
	   AND @msg LIKE N'%ciudad indicada no existe%'
	   AND @msg LIKE N'%capacidad, si se informa, debe ser mayor a cero%'
	   AND @msg LIKE N'%Latitud y longitud deben informarse juntas%'
	   AND @msg LIKE N'%latitud debe estar entre -90 y 90%'
	   AND LEN(@msg) - LEN(REPLACE(@msg, CHAR(10), N'')) = 6
		PRINT 'TEST 1.B OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 1.B FALLÓ: el mensaje no consolida las 5 condiciones -> ' + @msg;
END CATCH;

-- 1.C Alta duplicada: mismo estadio en la misma ciudad.
-- Esperado: Bloqueado: "Ya existe una sede con ese nombre de estadio en esa ciudad".
BEGIN TRY
	EXEC nucleo.SP_ALTA_Sede @nombreEstadio = 'TEST Estadio A', @idCiudad = @ciudadBsAs, @capacidad = 30000;
	PRINT 'TEST 1.C FALLÓ: permitió una sede duplicada en la misma ciudad.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%Ya existe una sede con ese nombre de estadio en esa ciudad%'
		PRINT 'TEST 1.C OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 1.C FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 1.D Mismo nombre de estadio en otra ciudad.
-- Esperado: OK, se inserta 'TEST Estadio A' en Nueva York (la unicidad es por nombre y ciudad).
BEGIN TRY
	EXEC nucleo.SP_ALTA_Sede @nombreEstadio = 'TEST Estadio A', @idCiudad = @ciudadNY,
	     @capacidad = 40000, @idSede = @sedeB OUTPUT;

	SELECT s.IdSede, s.NombreEstadio, c.Nombre AS Ciudad, c.HusoHorario, s.Capacidad
	FROM nucleo.Sede AS s INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = s.IdCiudad
	WHERE s.NombreEstadio = 'TEST Estadio A';

	IF (SELECT COUNT(*) FROM nucleo.Sede WHERE NombreEstadio = 'TEST Estadio A') = 2
		PRINT 'TEST 1.D OK: el mismo nombre se aceptó en otra ciudad (2 sedes).';
	ELSE
		PRINT 'TEST 1.D FALLÓ: no se insertó la sede de Nueva York.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.D FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.E Alta mínima: sin capacidad ni coordenadas.
-- Esperado: OK, se inserta 'TEST Estadio Baja' con Capacidad, Latitud y Longitud en NULL.
BEGIN TRY
	EXEC nucleo.SP_ALTA_Sede @nombreEstadio = 'TEST Estadio Baja', @idCiudad = @ciudadCordoba, @idSede = @sedeBaja OUTPUT;

	SELECT s.IdSede, s.NombreEstadio, s.Capacidad, s.Latitud, s.Longitud FROM nucleo.Sede AS s WHERE s.IdSede = @sedeBaja;

	IF EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @sedeBaja AND Capacidad IS NULL AND Latitud IS NULL AND Longitud IS NULL)
		PRINT 'TEST 1.E OK: sede sin capacidad ni coordenadas insertada.';
	ELSE
		PRINT 'TEST 1.E FALLÓ: la sede mínima no quedó como se esperaba.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.E FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.F Modificación válida (reemplazo total).
-- Se cambia el nombre y la capacidad, y se quitan las coordenadas (NULL es un valor válido).
-- Esperado: OK, la sede A queda como 'TEST Estadio A Renovado', capacidad 60000, sin coordenadas.
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Sede @idSede = @sedeA, @nombreEstadio = 'TEST Estadio A Renovado',
	     @idCiudad = @ciudadBsAs, @capacidad = 60000, @latitud = NULL, @longitud = NULL;

	SELECT s.IdSede, s.NombreEstadio, s.Capacidad, s.Latitud, s.Longitud FROM nucleo.Sede AS s WHERE s.IdSede = @sedeA;

	IF EXISTS (SELECT 1 FROM nucleo.Sede
	           WHERE IdSede = @sedeA AND NombreEstadio = 'TEST Estadio A Renovado' AND Capacidad = 60000
	             AND Latitud IS NULL AND Longitud IS NULL)
		PRINT 'TEST 1.F OK: sede modificada.';
	ELSE
		PRINT 'TEST 1.F FALLÓ: la sede no quedó como se esperaba.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.F FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.G Modificación sin cambiar el nombre (la sede no choca consigo misma).
-- Esperado: OK, solo cambia la capacidad a 55000.
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Sede @idSede = @sedeA, @nombreEstadio = 'TEST Estadio A Renovado',
	     @idCiudad = @ciudadBsAs, @capacidad = 55000;

	SELECT s.IdSede, s.NombreEstadio, s.Capacidad FROM nucleo.Sede AS s WHERE s.IdSede = @sedeA;

	IF EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @sedeA AND Capacidad = 55000)
		PRINT 'TEST 1.G OK: la unicidad excluye a la propia sede.';
	ELSE
		PRINT 'TEST 1.G FALLÓ: no se actualizó la capacidad.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.G FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.H Modificación de una sede inexistente.
-- Esperado: Bloqueado: "La sede indicada no existe".
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Sede @idSede = 32000, @nombreEstadio = 'TEST Estadio X', @idCiudad = @ciudadBsAs;
	PRINT 'TEST 1.H FALLÓ: permitió modificar una sede inexistente.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%La sede indicada no existe%'
		PRINT 'TEST 1.H OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 1.H FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 1.I Modificación con los mismos errores que el alta (1.B), para comprobar que las
--     validaciones comunes están sincronizadas.
-- Esperado: Bloqueado con UN solo mensaje que lista las mismas 5 condiciones que 1.B.
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Sede @idSede = @sedeA, @nombreEstadio = '   ', @idCiudad = 32000,
	     @capacidad = 0, @latitud = 95, @longitud = NULL;
	PRINT 'TEST 1.I FALLÓ: permitió la modificación con varios errores.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000
	   AND @msg LIKE N'%nombre del estadio es obligatorio%'
	   AND @msg LIKE N'%ciudad indicada no existe%'
	   AND @msg LIKE N'%capacidad, si se informa, debe ser mayor a cero%'
	   AND @msg LIKE N'%Latitud y longitud deben informarse juntas%'
	   AND @msg LIKE N'%latitud debe estar entre -90 y 90%'
	   AND LEN(@msg) - LEN(REPLACE(@msg, CHAR(10), N'')) = 6
		PRINT 'TEST 1.I OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 1.I FALLÓ: el mensaje no coincide con el del alta -> ' + @msg;
END CATCH;

-- 1.J Modificación que duplica el nombre de otra sede en la misma ciudad.
-- Se intenta renombrar la sede de Nueva York como 'TEST Estadio A Renovado' y moverla a Buenos Aires.
-- Esperado: Bloqueado: "Ya existe una sede con ese nombre de estadio en esa ciudad".
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Sede @idSede = @sedeB, @nombreEstadio = 'TEST Estadio A Renovado',
	     @idCiudad = @ciudadBsAs, @capacidad = 40000;
	PRINT 'TEST 1.J FALLÓ: permitió duplicar una sede en la misma ciudad.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%Ya existe una sede con ese nombre de estadio en esa ciudad%'
		PRINT 'TEST 1.J OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 1.J FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 1.K Baja de una sede sin partidos.
-- Esperado: OK, la sede 'TEST Estadio Baja' deja de existir.
BEGIN TRY
	EXEC nucleo.SP_BAJA_Sede @idSede = @sedeBaja;

	SELECT COUNT(*) AS SedesConEseId_Esperado_0 FROM nucleo.Sede WHERE IdSede = @sedeBaja;

	IF NOT EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @sedeBaja)
		PRINT 'TEST 1.K OK: sede eliminada.';
	ELSE
		PRINT 'TEST 1.K FALLÓ: la sede sigue existiendo.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.K FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 1.L Baja de una sede que ya no existe.
-- Esperado: Bloqueado: "La sede indicada no existe".
BEGIN TRY
	EXEC nucleo.SP_BAJA_Sede @idSede = @sedeBaja;
	PRINT 'TEST 1.L FALLÓ: permitió eliminar una sede inexistente.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%La sede indicada no existe%'
		PRINT 'TEST 1.L OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 1.L FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- =========================================================================
-- TEST 2: SP_ALTA_Partido
-- =========================================================================

-- 2.A Alta de fase de grupos en la sede A (Buenos Aires, UTC-3).
-- Hora local 2026-06-12 20:00.
-- Esperado: OK, partido 240 Programado, Sel1 vs Sel2, con FechaHoraUTC = 2026-06-12 23:00:00.
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 240, @idFase = @fGrupos, @idSede = @sedeA,
	     @fechaHoraLocal = '2026-06-12 20:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel2, @idPartido = @p240 OUTPUT;

	SELECT p.NumeroPartido, f.Nombre AS Fase, se.NombreEstadio AS Sede, c.HusoHorario, p.FechaHoraUTC,
	       CAST((p.FechaHoraUTC AT TIME ZONE 'UTC') AT TIME ZONE c.HusoHorario AS DATETIME2(0)) AS HoraLocalSede,
	       p.Estado, lo.CodigoFIFA AS Local, vi.CodigoFIFA AS Visitante
	FROM nucleo.Partido AS p
	INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
	INNER JOIN nucleo.Sede AS se ON se.IdSede = p.IdSede
	INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = se.IdCiudad
	LEFT JOIN nucleo.Seleccion AS lo ON lo.IdSeleccion = p.IdSeleccionLocal
	LEFT JOIN nucleo.Seleccion AS vi ON vi.IdSeleccion = p.IdSeleccionVisitante
	WHERE p.IdPartido = @p240;

	IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @p240 AND Estado = 'Programado' AND FechaHoraUTC = '2026-06-12 23:00:00')
		PRINT 'TEST 2.A OK: partido de grupos creado; 20:00 local (UTC-3) = 23:00 UTC.';
	ELSE
		PRINT 'TEST 2.A FALLÓ: el partido no quedó Programado con FechaHoraUTC = 2026-06-12 23:00:00.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.A FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.B Conversión con horario de verano: sede de Nueva York (Eastern Standard Time) en junio.
-- Hora local 2026-06-16 20:00 (UTC-4).
-- Esperado: OK, partido 241 (Sel1 vs Sel3) con FechaHoraUTC = 2026-06-17 00:00:00.
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 241, @idFase = @fGrupos, @idSede = @sedeB,
	     @fechaHoraLocal = '2026-06-16 20:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel3, @idPartido = @p241 OUTPUT;

	SELECT p.NumeroPartido, se.NombreEstadio AS Sede, c.HusoHorario, p.FechaHoraUTC,
	       CAST((p.FechaHoraUTC AT TIME ZONE 'UTC') AT TIME ZONE c.HusoHorario AS DATETIME2(0)) AS HoraLocalSede, p.Estado
	FROM nucleo.Partido AS p
	INNER JOIN nucleo.Sede AS se ON se.IdSede = p.IdSede
	INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = se.IdCiudad
	WHERE p.IdPartido = @p241;

	IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @p241 AND FechaHoraUTC = '2026-06-17 00:00:00')
		PRINT 'TEST 2.B OK: en junio Nueva York está en UTC-4; 20:00 local = 00:00 UTC del día siguiente.';
	ELSE
		PRINT 'TEST 2.B FALLÓ: la conversión con horario de verano no dio 2026-06-17 00:00:00.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.B FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.C Conversión sin horario de verano: misma sede de Nueva York en enero.
-- Hora local 2026-01-15 20:00 (UTC-5).
-- Esperado: OK, partido 242 (Sel2 vs Sel3) con FechaHoraUTC = 2026-01-16 01:00:00.
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 242, @idFase = @fGrupos, @idSede = @sedeB,
	     @fechaHoraLocal = '2026-01-15 20:00', @idSeleccionLocal = @sel2, @idSeleccionVisitante = @sel3, @idPartido = @p242 OUTPUT;

	SELECT p.NumeroPartido, se.NombreEstadio AS Sede, c.HusoHorario, p.FechaHoraUTC,
	       CAST((p.FechaHoraUTC AT TIME ZONE 'UTC') AT TIME ZONE c.HusoHorario AS DATETIME2(0)) AS HoraLocalSede, p.Estado
	FROM nucleo.Partido AS p
	INNER JOIN nucleo.Sede AS se ON se.IdSede = p.IdSede
	INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = se.IdCiudad
	WHERE p.IdPartido = @p242;

	IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @p242 AND FechaHoraUTC = '2026-01-16 01:00:00')
		PRINT 'TEST 2.C OK: en enero Nueva York está en UTC-5; 20:00 local = 01:00 UTC del día siguiente.';
	ELSE
		PRINT 'TEST 2.C FALLÓ: la conversión sin horario de verano no dio 2026-01-16 01:00:00.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.C FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.D Fase eliminatoria con el cruce sin definir (NULL/NULL).
-- Esperado: OK, partido 243 de Octavos de final Programado, con ambas selecciones en NULL.
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 243, @idFase = @fOctavos, @idSede = @sedeA,
	     @fechaHoraLocal = '2026-07-10 20:00', @idPartido = @p243 OUTPUT;

	SELECT p.NumeroPartido, f.Nombre AS Fase, p.FechaHoraUTC, p.Estado, p.IdSeleccionLocal, p.IdSeleccionVisitante
	FROM nucleo.Partido AS p INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
	WHERE p.IdPartido = @p243;

	IF EXISTS (SELECT 1 FROM nucleo.Partido
	           WHERE IdPartido = @p243 AND Estado = 'Programado' AND IdSeleccionLocal IS NULL AND IdSeleccionVisitante IS NULL)
		PRINT 'TEST 2.D OK: partido eliminatorio creado con el cruce sin definir.';
	ELSE
		PRINT 'TEST 2.D FALLÓ: el partido eliminatorio no quedó con el cruce NULL.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.D FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.E Alta con varios errores a la vez.
-- Parámetros: número 300, fase 99, sede 99, fecha NULL y Sel1 contra sí misma.
-- Esperado: Bloqueado con UN solo mensaje que lista exactamente 5 condiciones: número fuera de rango,
--           fase inexistente, sede inexistente, fecha obligatoria y selección contra sí misma.
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 300, @idFase = 99, @idSede = 99, @fechaHoraLocal = NULL,
	     @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel1;
	PRINT 'TEST 2.E FALLÓ: permitió el alta con varios errores.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000
	   AND @msg LIKE N'%número de partido es obligatorio y debe estar entre 1 y 255%'
	   AND @msg LIKE N'%fase indicada no existe%'
	   AND @msg LIKE N'%sede indicada no existe%'
	   AND @msg LIKE N'%fecha y hora local del partido es obligatoria%'
	   AND @msg LIKE N'%Una selección no puede enfrentarse a sí misma%'
	   AND LEN(@msg) - LEN(REPLACE(@msg, CHAR(10), N'')) = 6
		PRINT 'TEST 2.E OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 2.E FALLÓ: el mensaje no consolida las 5 condiciones -> ' + @msg;
END CATCH;

-- 2.F Número de partido repetido.
-- Esperado: Bloqueado: "Ya existe otro partido con ese número".
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 240, @idFase = @fOctavos, @idSede = @sedeA, @fechaHoraLocal = '2026-07-20 20:00';
	PRINT 'TEST 2.F FALLÓ: permitió un número de partido repetido.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%Ya existe otro partido con ese número%'
		PRINT 'TEST 2.F OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 2.F FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 2.G Fase de grupos con selecciones de distinto grupo (Sel1 del grupo Y y Sel4 del grupo Z).
-- Esperado: Bloqueado: "ambas selecciones deben pertenecer al mismo grupo".
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 250, @idFase = @fGrupos, @idSede = @sedeA,
	     @fechaHoraLocal = '2026-06-25 20:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel4;
	PRINT 'TEST 2.G FALLÓ: permitió un partido de grupos entre selecciones de distinto grupo.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%ambas selecciones deben pertenecer al mismo grupo%'
		PRINT 'TEST 2.G OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 2.G FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 2.H Fase de grupos con un cruce ya programado (Sel2 vs Sel1, en orden inverso al partido 240).
-- Esperado: Bloqueado: "Ese cruce ya está programado en la fase de grupos".
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 250, @idFase = @fGrupos, @idSede = @sedeA,
	     @fechaHoraLocal = '2026-07-01 20:00', @idSeleccionLocal = @sel2, @idSeleccionVisitante = @sel1;
	PRINT 'TEST 2.H FALLÓ: permitió repetir un cruce de la fase de grupos.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%Ese cruce ya está programado en la fase de grupos%'
		PRINT 'TEST 2.H OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 2.H FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 2.I Fase de grupos con una sola selección (visitante NULL).
-- Esperado: Bloqueado: "En fase de grupos ambas selecciones son obligatorias".
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 250, @idFase = @fGrupos, @idSede = @sedeA,
	     @fechaHoraLocal = '2026-07-05 20:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = NULL;
	PRINT 'TEST 2.I FALLÓ: permitió un partido de grupos con una sola selección.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%En fase de grupos ambas selecciones son obligatorias%'
		PRINT 'TEST 2.I OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 2.I FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 2.J Fase eliminatoria con selecciones informadas (el cruce lo asigna SP_DEFINIR_CRUCE_ELIMINATORIO).
-- Esperado: Bloqueado: "En fases eliminatorias las selecciones no se cargan ni se cambian acá".
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 250, @idFase = @fOctavos, @idSede = @sedeA,
	     @fechaHoraLocal = '2026-07-12 20:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel2;
	PRINT 'TEST 2.J FALLÓ: permitió cargar selecciones en una fase eliminatoria.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%En fases eliminatorias las selecciones no se cargan ni se cambian acá%'
		PRINT 'TEST 2.J OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 2.J FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 2.K Conflicto de agenda de la sede: otro partido en la sede A a 60 minutos del partido 240
--     (21:00 local = 00:00 UTC; el 240 es a las 23:00 UTC).
-- Esperado: Bloqueado: "La sede ya tiene otro partido a menos de 180 minutos de ese horario".
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 250, @idFase = @fOctavos, @idSede = @sedeA, @fechaHoraLocal = '2026-06-12 21:00';
	PRINT 'TEST 2.K FALLÓ: permitió dos partidos de la sede a menos de 180 minutos.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%La sede ya tiene otro partido a menos de 180 minutos%'
		PRINT 'TEST 2.K OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 2.K FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 2.L Borde de la agenda de la sede: exactamente 180 minutos después del partido 240
--     (23:00 local = 02:00 UTC del día siguiente).
-- Esperado: OK, partido 244 creado (la regla exige "al menos" 180 minutos).
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 244, @idFase = @fOctavos, @idSede = @sedeA,
	     @fechaHoraLocal = '2026-06-12 23:00', @idPartido = @p244 OUTPUT;

	SELECT p.NumeroPartido, p.FechaHoraUTC, p.Estado FROM nucleo.Partido AS p WHERE p.IdPartido IN (@p240, @p244) ORDER BY p.FechaHoraUTC;

	IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @p244 AND FechaHoraUTC = '2026-06-13 02:00:00')
		PRINT 'TEST 2.L OK: 180 minutos exactos entre partidos de la sede están permitidos.';
	ELSE
		PRINT 'TEST 2.L FALLÓ: el partido a 180 minutos no se creó.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.L FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.M Descanso de selección: Sel1 vs Sel6 a 24 horas del partido 240 de Sel1
--     (2026-06-13 20:00 local = 23:00 UTC; el 240 fue el 06-12 a las 23:00 UTC).
-- Esperado: Bloqueado: "Alguna de las selecciones tiene otro partido a menos de 48 horas de ese horario".
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 250, @idFase = @fGrupos, @idSede = @sedeA,
	     @fechaHoraLocal = '2026-06-13 20:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel6;
	PRINT 'TEST 2.M FALLÓ: permitió dos partidos de una selección a menos de 48 horas.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%Alguna de las selecciones tiene otro partido a menos de 48 horas%'
		PRINT 'TEST 2.M OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 2.M FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 2.N Borde del descanso: Sel1 vs Sel5 exactamente 48 horas después del partido 240
--     (2026-06-14 20:00 local = 23:00 UTC).
-- Esperado: OK, partido 245 creado (la regla exige "al menos" 48 horas entre inicios).
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 245, @idFase = @fGrupos, @idSede = @sedeA,
	     @fechaHoraLocal = '2026-06-14 20:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel5, @idPartido = @p245 OUTPUT;

	SELECT p.NumeroPartido, p.FechaHoraUTC, lo.CodigoFIFA AS Local, vi.CodigoFIFA AS Visitante
	FROM nucleo.Partido AS p
	LEFT JOIN nucleo.Seleccion AS lo ON lo.IdSeleccion = p.IdSeleccionLocal
	LEFT JOIN nucleo.Seleccion AS vi ON vi.IdSeleccion = p.IdSeleccionVisitante
	WHERE p.IdPartido IN (@p240, @p245) ORDER BY p.FechaHoraUTC;

	IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @p245 AND FechaHoraUTC = '2026-06-14 23:00:00')
		PRINT 'TEST 2.N OK: 48 horas exactas entre partidos de una selección están permitidas.';
	ELSE
		PRINT 'TEST 2.N FALLÓ: el partido a 48 horas no se creó.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.N FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 2.O Hora local inexistente: sede de Nueva York el 2026-03-08 a las 02:30
--     (el reloj salta de 02:00 a 03:00 por el inicio del horario de verano).
-- Esperado: Bloqueado: "La hora local indicada no existe en el huso de la sede".
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 250, @idFase = @fOctavos, @idSede = @sedeB, @fechaHoraLocal = '2026-03-08 02:30';
	PRINT 'TEST 2.O FALLÓ: permitió una hora local inexistente.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%La hora local indicada no existe en el huso de la sede%'
		PRINT 'TEST 2.O OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 2.O FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 2.P Hora local ambigua: sede de Nueva York el 2026-11-01 a las 01:30
--     (la hora se repite al terminar el horario de verano).
-- Esperado: Bloqueado: "La hora local indicada es ambigua en el huso de la sede".
BEGIN TRY
	EXEC nucleo.SP_ALTA_Partido @numeroPartido = 250, @idFase = @fOctavos, @idSede = @sedeB, @fechaHoraLocal = '2026-11-01 01:30';
	PRINT 'TEST 2.P FALLÓ: permitió una hora local ambigua.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%La hora local indicada es ambigua en el huso de la sede%'
		PRINT 'TEST 2.P OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 2.P FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- =========================================================================
-- TEST 3: SP_MODIFICACION_Partido y SP_BAJA_Partido
-- =========================================================================

-- 3.A Modificación válida del partido 243 (eliminatoria, cruce NULL): se cambia el horario a las
--     2026-07-11 20:00 locales (reemplazo total).
-- Esperado: OK, FechaHoraUTC pasa de 2026-07-10 23:00:00 a 2026-07-11 23:00:00.
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Partido @idPartido = @p243, @numeroPartido = 243, @idFase = @fOctavos,
	     @idSede = @sedeA, @fechaHoraLocal = '2026-07-11 20:00';

	SELECT p.NumeroPartido, f.Nombre AS Fase, p.FechaHoraUTC, p.Estado, p.IdSeleccionLocal, p.IdSeleccionVisitante
	FROM nucleo.Partido AS p INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
	WHERE p.IdPartido = @p243;

	IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @p243 AND FechaHoraUTC = '2026-07-11 23:00:00')
		PRINT 'TEST 3.A OK: partido modificado.';
	ELSE
		PRINT 'TEST 3.A FALLÓ: el horario no se actualizó.';
END TRY
BEGIN CATCH
	PRINT 'TEST 3.A FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 3.B Modificación sin cambiar nada (el partido no choca consigo mismo en número, sede ni agenda).
-- Esperado: OK, no se produce ningún error de unicidad ni de agenda.
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Partido @idPartido = @p243, @numeroPartido = 243, @idFase = @fOctavos,
	     @idSede = @sedeA, @fechaHoraLocal = '2026-07-11 20:00';

	IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @p243 AND NumeroPartido = 243 AND FechaHoraUTC = '2026-07-11 23:00:00')
		PRINT 'TEST 3.B OK: las validaciones excluyen al propio partido.';
	ELSE
		PRINT 'TEST 3.B FALLÓ: el partido cambió o no se pudo modificar.';
END TRY
BEGIN CATCH
	PRINT 'TEST 3.B FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 3.C Modificación de un partido inexistente.
-- Esperado: Bloqueado: "El partido indicado no existe".
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Partido @idPartido = 32000, @numeroPartido = 243, @idFase = @fOctavos,
	     @idSede = @sedeA, @fechaHoraLocal = '2026-07-11 20:00';
	PRINT 'TEST 3.C FALLÓ: permitió modificar un partido inexistente.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%El partido indicado no existe%'
		PRINT 'TEST 3.C OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 3.C FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 3.D Modificación con los mismos errores que el alta (2.E), para comprobar que las validaciones
--     comunes están sincronizadas.
-- Esperado: Bloqueado con UN solo mensaje que lista las mismas 5 condiciones que 2.E.
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Partido @idPartido = @p243, @numeroPartido = 300, @idFase = 99, @idSede = 99,
	     @fechaHoraLocal = NULL, @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel1;
	PRINT 'TEST 3.D FALLÓ: permitió la modificación con varios errores.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000
	   AND @msg LIKE N'%número de partido es obligatorio y debe estar entre 1 y 255%'
	   AND @msg LIKE N'%fase indicada no existe%'
	   AND @msg LIKE N'%sede indicada no existe%'
	   AND @msg LIKE N'%fecha y hora local del partido es obligatoria%'
	   AND @msg LIKE N'%Una selección no puede enfrentarse a sí misma%'
	   AND LEN(@msg) - LEN(REPLACE(@msg, CHAR(10), N'')) = 6
		PRINT 'TEST 3.D OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 3.D FALLÓ: el mensaje no coincide con el del alta -> ' + @msg;
END CATCH;

-- 3.E Modificación que repite el cruce de otro partido: el partido 241 (Sel1 vs Sel3) pasa a Sel1 vs Sel2,
--     cruce que ya tiene el partido 240.
-- Esperado: Bloqueado: "Ese cruce ya está programado en la fase de grupos".
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Partido @idPartido = @p241, @numeroPartido = 241, @idFase = @fGrupos,
	     @idSede = @sedeB, @fechaHoraLocal = '2026-06-16 20:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel2;
	PRINT 'TEST 3.E FALLÓ: permitió repetir un cruce de grupos en la modificación.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%Ese cruce ya está programado en la fase de grupos%'
		PRINT 'TEST 3.E OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 3.E FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 3.F Modificación que carga selecciones en una fase eliminatoria (partido 243 con Sel1 vs Sel2).
-- Esperado: Bloqueado: "En fases eliminatorias las selecciones no se cargan ni se cambian acá".
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Partido @idPartido = @p243, @numeroPartido = 243, @idFase = @fOctavos,
	     @idSede = @sedeA, @fechaHoraLocal = '2026-07-11 20:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel2;
	PRINT 'TEST 3.F FALLÓ: permitió asignar selecciones a un partido eliminatorio.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%En fases eliminatorias las selecciones no se cargan ni se cambian acá%'
		PRINT 'TEST 3.F OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 3.F FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- Preparación: se carga una formación para el partido 241 (registro asociado).
INSERT INTO jugadores.Formacion (IdPartido, Localia, EsquemaTactico) VALUES (@p241, 'Local', '4-3-3');

-- 3.G Cambio de selecciones con una formación cargada: el partido 241 pasa de Sel1 vs Sel3 a Sel1 vs Sel6.
-- Esperado: Bloqueado: "no se pueden cambiar sus selecciones".
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Partido @idPartido = @p241, @numeroPartido = 241, @idFase = @fGrupos,
	     @idSede = @sedeB, @fechaHoraLocal = '2026-06-16 20:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel6;
	PRINT 'TEST 3.G FALLÓ: permitió cambiar las selecciones de un partido con formación.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%no se pueden cambiar sus selecciones%'
		PRINT 'TEST 3.G OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 3.G FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 3.H Cambio de fase con una formación cargada: el partido 241 pasa a Octavos de final con las mismas selecciones.
-- Esperado: Bloqueado: "no se puede cambiar su fase".
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Partido @idPartido = @p241, @numeroPartido = 241, @idFase = @fOctavos,
	     @idSede = @sedeB, @fechaHoraLocal = '2026-06-16 20:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel3;
	PRINT 'TEST 3.H FALLÓ: permitió cambiar la fase de un partido con formación.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%no se puede cambiar su fase%'
		PRINT 'TEST 3.H OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 3.H FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 3.I Cambio de horario con una formación cargada (selecciones y fase iguales): 21:00 local en vez de 20:00.
-- Esperado: OK (sin espacios publicitarios, el horario sí se puede cambiar): FechaHoraUTC = 2026-06-17 01:00:00.
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Partido @idPartido = @p241, @numeroPartido = 241, @idFase = @fGrupos,
	     @idSede = @sedeB, @fechaHoraLocal = '2026-06-16 21:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel3;

	SELECT p.NumeroPartido, p.FechaHoraUTC,
	       CAST((p.FechaHoraUTC AT TIME ZONE 'UTC') AT TIME ZONE c.HusoHorario AS DATETIME2(0)) AS HoraLocalSede,
	       lo.CodigoFIFA AS Local, vi.CodigoFIFA AS Visitante
	FROM nucleo.Partido AS p
	INNER JOIN nucleo.Sede AS se ON se.IdSede = p.IdSede
	INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = se.IdCiudad
	LEFT JOIN nucleo.Seleccion AS lo ON lo.IdSeleccion = p.IdSeleccionLocal
	LEFT JOIN nucleo.Seleccion AS vi ON vi.IdSeleccion = p.IdSeleccionVisitante
	WHERE p.IdPartido = @p241;

	IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @p241 AND FechaHoraUTC = '2026-06-17 01:00:00')
		PRINT 'TEST 3.I OK: el horario se pudo cambiar con la formación cargada.';
	ELSE
		PRINT 'TEST 3.I FALLÓ: el horario no se actualizó.';
END TRY
BEGIN CATCH
	PRINT 'TEST 3.I FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- Preparación: el partido 240 pasa a Finalizado (lo hará SP_FINALIZAR_PARTIDO en el flujo real), con
-- la concurrencia. Se actualiza directo; el resultado no se guarda en Partido (se deriva de eventos.Gol).
UPDATE nucleo.Partido
SET Estado = 'Finalizado', Concurrencia = 45000
WHERE IdPartido = @p240;

-- 3.J Modificación de un partido Finalizado.
-- Esperado: Bloqueado: "Solo se pueden modificar partidos en estado Programado".
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Partido @idPartido = @p240, @numeroPartido = 240, @idFase = @fGrupos,
	     @idSede = @sedeA, @fechaHoraLocal = '2026-06-12 20:00', @idSeleccionLocal = @sel1, @idSeleccionVisitante = @sel2;
	PRINT 'TEST 3.J FALLÓ: permitió modificar un partido Finalizado.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%Solo se pueden modificar partidos en estado Programado%'
		PRINT 'TEST 3.J OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 3.J FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 3.K Baja de un partido Finalizado.
-- Esperado: Bloqueado: "Solo se pueden eliminar partidos en estado Programado"; el partido sigue existiendo.
BEGIN TRY
	EXEC nucleo.SP_BAJA_Partido @idPartido = @p240;
	PRINT 'TEST 3.K FALLÓ: permitió eliminar un partido Finalizado.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%Solo se pueden eliminar partidos en estado Programado%'
	   AND EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @p240)
		PRINT 'TEST 3.K OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 3.K FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- Preparación: se asigna una designación arbitral al partido 241 (que ya tiene formación).
INSERT INTO nucleo.DesignacionArbitral (Rol, IdArbitro, IdPartido) VALUES ('Principal', @idArbitro, @p241);

-- 3.L Baja de un partido con registros asociados (una formación y una designación arbitral).
-- Esperado: Bloqueado con UN solo mensaje que lista "formaciones cargadas" y "designaciones arbitrales
--           asociadas"; el partido sigue existiendo.
BEGIN TRY
	EXEC nucleo.SP_BAJA_Partido @idPartido = @p241;
	PRINT 'TEST 3.L FALLÓ: permitió eliminar un partido con registros asociados.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000
	   AND @msg LIKE N'%tiene formaciones cargadas%'
	   AND @msg LIKE N'%tiene designaciones arbitrales asociadas%'
	   AND LEN(@msg) - LEN(REPLACE(@msg, CHAR(10), N'')) = 3
	   AND EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @p241)
		PRINT 'TEST 3.L OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 3.L FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 3.L1 nucleo.fn_PartidoTieneRegistros (script 07) sobre el partido 241: tiene formación y designación
--      arbitral; se le agrega una sanción a esa designación. El partido 245 no tiene ningún registro.
-- Esperado: antes de la sanción, TieneFormaciones = 1, TieneDesignaciones = 1, TieneSanciones = 0 y
--           TieneAlguno = 1; después, TieneSanciones = 1. Para el 245 todos los indicadores son 0.
IF EXISTS (SELECT 1 FROM nucleo.fn_PartidoTieneRegistros(@p241)
           WHERE TieneFormaciones = 1 AND TieneDesignaciones = 1 AND TieneSanciones = 0 AND TieneAlguno = 1)
   AND EXISTS (SELECT 1 FROM nucleo.fn_PartidoTieneRegistros(@p245)
               WHERE TieneFormaciones = 0 AND TieneSustituciones = 0 AND TieneGoles = 0 AND TieneAmonestaciones = 0
                 AND TieneDesignaciones = 0 AND TieneSanciones = 0 AND TieneEspacios = 0 AND TieneAlguno = 0)
BEGIN
	INSERT INTO nucleo.Sancion (Tipo, Descripcion, IdDesignacionArbitral)
	SELECT 'Advertencia', 'TEST Sancion', d.IdDesignacionArbitral
	FROM nucleo.DesignacionArbitral AS d WHERE d.IdPartido = @p241;

	IF EXISTS (SELECT 1 FROM nucleo.fn_PartidoTieneRegistros(@p241) WHERE TieneSanciones = 1 AND TieneAlguno = 1)
		PRINT 'TEST 3.L1 OK: fn_PartidoTieneRegistros informa formación, designación y sanción.';
	ELSE
		PRINT 'TEST 3.L1 FALLÓ: no informó la sanción del partido 241.';
END
ELSE
	PRINT 'TEST 3.L1 FALLÓ: los indicadores de los partidos 241 y 245 no son los esperados.';

-- 3.M Baja de un partido inexistente.
-- Esperado: Bloqueado: "El partido indicado no existe".
BEGIN TRY
	EXEC nucleo.SP_BAJA_Partido @idPartido = 32000;
	PRINT 'TEST 3.M FALLÓ: permitió eliminar un partido inexistente.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%El partido indicado no existe%'
		PRINT 'TEST 3.M OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 3.M FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 3.N Baja válida: el partido 243 está Programado y no tiene registros asociados.
-- Esperado: OK, el partido 243 deja de existir.
BEGIN TRY
	EXEC nucleo.SP_BAJA_Partido @idPartido = @p243;

	SELECT COUNT(*) AS PartidosConEseId_Esperado_0 FROM nucleo.Partido WHERE IdPartido = @p243;

	IF NOT EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @p243)
		PRINT 'TEST 3.N OK: partido eliminado.';
	ELSE
		PRINT 'TEST 3.N FALLÓ: el partido sigue existiendo.';
END TRY
BEGIN CATCH
	PRINT 'TEST 3.N FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: SP_MODIFICACION_Sede y SP_BAJA_Sede con partidos asociados
-- (la sede A tiene partidos; el partido 240 tiene Concurrencia = 45000)
-- =========================================================================

-- 4.A Baja de una sede con partidos.
-- Esperado: Bloqueado: "La sede tiene partidos asociados y no puede eliminarse"; la sede sigue existiendo.
BEGIN TRY
	EXEC nucleo.SP_BAJA_Sede @idSede = @sedeA;
	PRINT 'TEST 4.A FALLÓ: permitió eliminar una sede con partidos.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%La sede tiene partidos asociados y no puede eliminarse%'
	   AND EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @sedeA)
		PRINT 'TEST 4.A OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 4.A FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 4.B Capacidad menor a la concurrencia ya registrada (40000 < 45000 del partido 240).
-- Esperado: Bloqueado: "La nueva capacidad es menor a la concurrencia ya registrada".
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Sede @idSede = @sedeA, @nombreEstadio = 'TEST Estadio A Renovado',
	     @idCiudad = @ciudadBsAs, @capacidad = 40000;
	PRINT 'TEST 4.B FALLÓ: permitió una capacidad menor a la concurrencia registrada.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%La nueva capacidad es menor a la concurrencia ya registrada%'
		PRINT 'TEST 4.B OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 4.B FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 4.C Capacidad igual a la concurrencia registrada (45000).
-- Esperado: OK, la capacidad queda en 45000.
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Sede @idSede = @sedeA, @nombreEstadio = 'TEST Estadio A Renovado',
	     @idCiudad = @ciudadBsAs, @capacidad = 45000;

	SELECT s.IdSede, s.NombreEstadio, s.Capacidad FROM nucleo.Sede AS s WHERE s.IdSede = @sedeA;

	IF EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @sedeA AND Capacidad = 45000)
		PRINT 'TEST 4.C OK: capacidad igual a la concurrencia registrada.';
	ELSE
		PRINT 'TEST 4.C FALLÓ: la capacidad no se actualizó.';
END TRY
BEGIN CATCH
	PRINT 'TEST 4.C FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- 4.D Mover una sede con partidos a una ciudad con otro huso horario (Buenos Aires -> Nueva York).
-- Esperado: Bloqueado: "la nueva ciudad tiene otro huso horario".
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Sede @idSede = @sedeA, @nombreEstadio = 'TEST Estadio A Renovado',
	     @idCiudad = @ciudadNY, @capacidad = 45000;
	PRINT 'TEST 4.D FALLÓ: permitió mover una sede con partidos a otro huso horario.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @msg LIKE N'%la nueva ciudad tiene otro huso horario%'
		PRINT 'TEST 4.D OK (Bloqueado): ' + @msg;
	ELSE
		PRINT 'TEST 4.D FALLÓ: error inesperado -> ' + @msg;
END CATCH;

-- 4.E Mover una sede con partidos a una ciudad con el mismo huso horario (Buenos Aires -> Córdoba).
-- Esperado: OK, la sede queda en Córdoba y sus partidos conservan su FechaHoraUTC.
BEGIN TRY
	EXEC nucleo.SP_MODIFICACION_Sede @idSede = @sedeA, @nombreEstadio = 'TEST Estadio A Renovado',
	     @idCiudad = @ciudadCordoba, @capacidad = 45000;

	SELECT s.IdSede, s.NombreEstadio, c.Nombre AS Ciudad, c.HusoHorario FROM nucleo.Sede AS s
	INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = s.IdCiudad WHERE s.IdSede = @sedeA;
	SELECT p.NumeroPartido, p.FechaHoraUTC FROM nucleo.Partido AS p WHERE p.IdSede = @sedeA ORDER BY p.FechaHoraUTC;

	IF EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @sedeA AND IdCiudad = @ciudadCordoba)
	   AND EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @p240 AND FechaHoraUTC = '2026-06-12 23:00:00')
		PRINT 'TEST 4.E OK: la sede cambió de ciudad con el mismo huso y sus partidos no se alteraron.';
	ELSE
		PRINT 'TEST 4.E FALLÓ: la sede no cambió de ciudad o se alteró el horario de sus partidos.';
END TRY
BEGIN CATCH
	PRINT 'TEST 4.E FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 5: llamadas dentro de una transacción del llamador (savepoint PuntoSP)
-- =========================================================================

-- 5.A Alta inválida (nombre en blanco) dentro de una transacción abierta por el llamador.
-- Esperado: OK (Bloqueado): el SP rechaza el alta pero NO cierra la transacción del llamador
--           (@@TRANCOUNT sigue en 1 dentro del CATCH).
BEGIN TRANSACTION;
BEGIN TRY
	EXEC nucleo.SP_ALTA_Sede @nombreEstadio = '   ', @idCiudad = @ciudadNY;
	PRINT 'TEST 5.A FALLÓ: permitió el alta con nombre en blanco.';
END TRY
BEGIN CATCH
	SET @msg = ERROR_MESSAGE();
	IF ERROR_NUMBER() = 52000 AND @@TRANCOUNT = 1 AND @msg LIKE N'%nombre del estadio es obligatorio%'
		PRINT 'TEST 5.A OK (Bloqueado): la transacción del llamador sigue abierta -> ' + @msg;
	ELSE
		PRINT 'TEST 5.A FALLÓ: @@TRANCOUNT = ' + CAST(@@TRANCOUNT AS VARCHAR(5)) + ' -> ' + @msg;
END CATCH;
IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;

-- 5.B Alta válida dentro de una transacción del llamador que después se deshace.
-- Esperado: OK: el SP no confirma la transacción ajena (@@TRANCOUNT = 1 después del EXEC) y,
--           tras el ROLLBACK del llamador, 'TEST Estadio Transaccion' no existe.
DECLARE @sedeTran TINYINT, @tranDespues INT;
BEGIN TRANSACTION;
BEGIN TRY
	EXEC nucleo.SP_ALTA_Sede @nombreEstadio = 'TEST Estadio Transaccion', @idCiudad = @ciudadNY,
	     @idSede = @sedeTran OUTPUT;
	SET @tranDespues = @@TRANCOUNT;
END TRY
BEGIN CATCH
	PRINT 'TEST 5.B FALLÓ: error inesperado -> ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;

IF @tranDespues = 1
   AND NOT EXISTS (SELECT 1 FROM nucleo.Sede WHERE NombreEstadio = 'TEST Estadio Transaccion')
	PRINT 'TEST 5.B OK: el SP respetó la transacción del llamador y el ROLLBACK deshizo el alta.';
ELSE
	PRINT 'TEST 5.B FALLÓ: @@TRANCOUNT después del EXEC = ' + ISNULL(CAST(@tranDespues AS VARCHAR(5)), 'NULL')
	      + ' o la sede quedó insertada.';
GO

-- =========================================================================
-- LIMPIEZA FINAL
-- =========================================================================
DELETE FROM nucleo.Sancion
WHERE IdDesignacionArbitral IN (SELECT d.IdDesignacionArbitral FROM nucleo.DesignacionArbitral AS d
                                INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido
                                INNER JOIN nucleo.Sede AS s ON s.IdSede = p.IdSede
                                WHERE s.NombreEstadio LIKE 'TEST%');
DELETE FROM jugadores.Formacion
WHERE IdPartido IN (SELECT p.IdPartido FROM nucleo.Partido AS p
                    INNER JOIN nucleo.Sede AS s ON s.IdSede = p.IdSede
                    WHERE s.NombreEstadio LIKE 'TEST%');
DELETE FROM nucleo.DesignacionArbitral
WHERE IdPartido IN (SELECT p.IdPartido FROM nucleo.Partido AS p
                    INNER JOIN nucleo.Sede AS s ON s.IdSede = p.IdSede
                    WHERE s.NombreEstadio LIKE 'TEST%');
DELETE FROM nucleo.Partido WHERE IdSede IN (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%');
DELETE FROM nucleo.Arbitro WHERE NombreApellido LIKE 'TEST%';
DELETE FROM nucleo.Categoria WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Seleccion WHERE IdPais IN (SELECT IdPais FROM nucleo.Pais WHERE Nombre LIKE 'TEST%');
DELETE FROM nucleo.Sede WHERE NombreEstadio LIKE 'TEST%';
DELETE FROM nucleo.Ciudad WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Grupo WHERE Nombre IN ('Y', 'Z');
DELETE FROM nucleo.Pais WHERE Nombre LIKE 'TEST%';
DELETE FROM nucleo.Confederacion WHERE Nombre LIKE 'TEST%';
GO

SET NOCOUNT OFF;
GO
