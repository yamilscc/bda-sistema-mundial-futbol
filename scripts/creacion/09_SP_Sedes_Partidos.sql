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
	- Generar los stored procedures de alta, modificación y baja de sedes y partidos:
		  nucleo.SP_ALTA_Sede, nucleo.SP_MODIFICACION_Sede, nucleo.SP_BAJA_Sede,
		  nucleo.SP_ALTA_Partido, nucleo.SP_MODIFICACION_Partido, nucleo.SP_BAJA_Partido

Convenciones de estos SP:
	- Cada SP acumula todas las condiciones incumplidas y las informa en UN solo mensaje
	  (THROW 52000). La operación corre dentro de una transacción explícita. Si el llamador
	  ya tiene una transacción abierta, el SP usa un savepoint (PuntoSP) y ante un error
	  solo deshace lo propio: un error de validación no cierra la transacción del llamador.
	- Los parámetros de ids y de número de partido son INT: así un valor fuera de rango
	  se informa dentro del mensaje consolidado y no como error de conversión al invocar.
	- Las validaciones comunes de Alta y Modificación están repetidas en ambos SP, en el mismo
	  orden y con el mismo texto, entre las marcas ">>> VALIDACIONES COMUNES" y
	  "<<< FIN VALIDACIONES COMUNES". Si se modifica una, hay que modificar la otra.
	- MODIFICACION reemplaza todos los campos: un NULL en un parámetro opcional es un valor
	  válido (cruce sin definir, sede sin capacidad o sin coordenadas).
	- Sede no guarda huso horario: lo hereda de Ciudad.HusoHorario.
	- Partido recibe la hora LOCAL de la sede y guarda solo FechaHoraUTC. El Alta siempre
	  crea el partido en estado 'Programado'. Estos SP no cargan Concurrencia
	  (eso ocurre al finalizar el partido). Partido no guarda el resultado: se deriva de
	  eventos.Gol con eventos.fn_ResultadoPartido.
	- Reglas de agenda (constantes declaradas al inicio de SP_ALTA_Partido y SP_MODIFICACION_Partido):
	  180 minutos mínimos entre dos partidos de la misma sede y 48 horas mínimas entre los
	  inicios de dos partidos de una selección.
	- En fases eliminatorias el cruce queda sin definir (NULL/NULL): las selecciones las
	  asigna nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO.
	- Se rechazan las horas locales inexistentes (salto de horario de verano) o ambiguas
	  (retroceso), porque el SP no recibe el offset para desambiguarlas.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- nucleo.SP_ALTA_Sede
-- Parámetros: @nombreEstadio, @idCiudad (obligatorios); @capacidad, @latitud y @longitud
--             (opcionales; latitud y longitud van juntas o ninguna);
--             @idSede (OUTPUT: id generado).
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_Sede
	@nombreEstadio VARCHAR(200),
	@idCiudad      INT,
	@capacidad     INT          = NULL,
	@latitud       DECIMAL(9,6) = NULL,
	@longitud      DECIMAL(9,6) = NULL,
	@idSede        TINYINT      = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(MAX) = N'',
	        @tranExterna BIT = IIF(@@TRANCOUNT > 0, 1, 0), -- 1 si el llamador ya abrió una transacción
	        @savepoint   BIT = 0,                          -- 1 cuando se tomó el savepoint PuntoSP
	        @mensaje NVARCHAR(2048),
	        @salto   NVARCHAR(2) = CHAR(13) + CHAR(10);

	BEGIN TRY
		SET @nombreEstadio = TRIM(@nombreEstadio);

		-- >>> VALIDACIONES COMUNES (mantener sincronizadas con SP_MODIFICACION_Sede)
		IF @nombreEstadio IS NULL OR @nombreEstadio = ''
			SET @errores += N'- El nombre del estadio es obligatorio.' + @salto;
		ELSE IF LEN(@nombreEstadio) > 100
			SET @errores += N'- El nombre del estadio no puede superar los 100 caracteres.' + @salto;

		IF @idCiudad IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Ciudad WHERE IdCiudad = @idCiudad)
			SET @errores += N'- La ciudad indicada no existe.' + @salto;

		IF @nombreEstadio <> '' AND @idCiudad IS NOT NULL
		   AND EXISTS (SELECT 1
		               FROM nucleo.Sede
		               WHERE NombreEstadio = @nombreEstadio
		                 AND IdCiudad = @idCiudad)
			SET @errores += N'- Ya existe una sede con ese nombre de estadio en esa ciudad.' + @salto;

		IF @capacidad IS NOT NULL AND @capacidad <= 0
			SET @errores += N'- La capacidad, si se informa, debe ser mayor a cero.' + @salto;

		IF (@latitud IS NULL AND @longitud IS NOT NULL) OR (@latitud IS NOT NULL AND @longitud IS NULL)
			SET @errores += N'- Latitud y longitud deben informarse juntas o ninguna.' + @salto;

		IF @latitud IS NOT NULL AND @latitud NOT BETWEEN -90 AND 90
			SET @errores += N'- La latitud debe estar entre -90 y 90.' + @salto;

		IF @longitud IS NOT NULL AND @longitud NOT BETWEEN -180 AND 180
			SET @errores += N'- La longitud debe estar entre -180 y 180.' + @salto;
		-- <<< FIN VALIDACIONES COMUNES

		IF LEN(@errores) > 0
		BEGIN
			SET @mensaje = LEFT(N'SP_ALTA_Sede - No se pudo completar la operación:' + @salto + @errores, 2048);
			THROW 52000, @mensaje, 1;
		END;

		IF @tranExterna = 0
			BEGIN TRANSACTION;
		ELSE
		BEGIN
			SAVE TRANSACTION PuntoSP;
			SET @savepoint = 1;
		END;

			INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, Latitud, Longitud, IdCiudad)
			VALUES (@nombreEstadio, @capacidad, @latitud, @longitud, @idCiudad);

			SET @idSede = SCOPE_IDENTITY();

		IF @tranExterna = 0
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		-- Solo se deshace lo propio: la transacción si la abrió este SP, o hasta el savepoint
		-- si corre dentro de una transacción del llamador (que queda abierta y a su cargo).
		IF @tranExterna = 0 AND @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;
		ELSE IF @savepoint = 1 AND XACT_STATE() = 1
			ROLLBACK TRANSACTION PuntoSP;
		THROW;
	END CATCH;
END;
GO

-- =========================================================================
-- nucleo.SP_MODIFICACION_Sede
-- Parámetros: @idSede (sede a modificar) y los mismos campos que el alta, que reemplazan
--             los valores actuales.
-- Reglas propias: la nueva capacidad no puede ser menor a la Concurrencia ya registrada en
--                 partidos de la sede; si la sede tiene partidos, no se puede mover a una
--                 ciudad con otro huso horario (cambiaría en silencio la hora local de sus
--                 partidos, que se guardan en UTC).
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_Sede
	@idSede        INT,
	@nombreEstadio VARCHAR(200),
	@idCiudad      INT,
	@capacidad     INT          = NULL,
	@latitud       DECIMAL(9,6) = NULL,
	@longitud      DECIMAL(9,6) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(MAX) = N'',
	        @tranExterna BIT = IIF(@@TRANCOUNT > 0, 1, 0), -- 1 si el llamador ya abrió una transacción
	        @savepoint   BIT = 0,                          -- 1 cuando se tomó el savepoint PuntoSP
	        @mensaje NVARCHAR(2048),
	        @salto   NVARCHAR(2) = CHAR(13) + CHAR(10);

	BEGIN TRY
		SET @nombreEstadio = TRIM(@nombreEstadio);

		IF @idSede IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @idSede)
			SET @errores += N'- La sede indicada no existe.' + @salto;

		-- >>> VALIDACIONES COMUNES (mantener sincronizadas con SP_ALTA_Sede)
		IF @nombreEstadio IS NULL OR @nombreEstadio = ''
			SET @errores += N'- El nombre del estadio es obligatorio.' + @salto;
		ELSE IF LEN(@nombreEstadio) > 100
			SET @errores += N'- El nombre del estadio no puede superar los 100 caracteres.' + @salto;

		IF @idCiudad IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Ciudad WHERE IdCiudad = @idCiudad)
			SET @errores += N'- La ciudad indicada no existe.' + @salto;

		IF @nombreEstadio <> '' AND @idCiudad IS NOT NULL
		   AND EXISTS (SELECT 1
		               FROM nucleo.Sede
		               WHERE NombreEstadio = @nombreEstadio
		                 AND IdCiudad = @idCiudad
		                 AND IdSede <> @idSede) -- [solo MODIFICACION] excluye la propia sede
			SET @errores += N'- Ya existe una sede con ese nombre de estadio en esa ciudad.' + @salto;

		IF @capacidad IS NOT NULL AND @capacidad <= 0
			SET @errores += N'- La capacidad, si se informa, debe ser mayor a cero.' + @salto;

		IF (@latitud IS NULL AND @longitud IS NOT NULL) OR (@latitud IS NOT NULL AND @longitud IS NULL)
			SET @errores += N'- Latitud y longitud deben informarse juntas o ninguna.' + @salto;

		IF @latitud IS NOT NULL AND @latitud NOT BETWEEN -90 AND 90
			SET @errores += N'- La latitud debe estar entre -90 y 90.' + @salto;

		IF @longitud IS NOT NULL AND @longitud NOT BETWEEN -180 AND 180
			SET @errores += N'- La longitud debe estar entre -180 y 180.' + @salto;
		-- <<< FIN VALIDACIONES COMUNES

		-- Reglas propias de la modificación (solo si la sede existe).
		IF EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @idSede)
		BEGIN
			IF @capacidad IS NOT NULL
			   AND EXISTS (SELECT 1
			               FROM nucleo.Partido
			               WHERE IdSede = @idSede
			                 AND Concurrencia > @capacidad)
				SET @errores += N'- La nueva capacidad es menor a la concurrencia ya registrada en partidos de la sede.' + @salto;

			IF @idCiudad IS NOT NULL
			   AND EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdSede = @idSede)
			   AND EXISTS (SELECT 1
			               FROM nucleo.Sede AS s
			               INNER JOIN nucleo.Ciudad AS actual ON actual.IdCiudad = s.IdCiudad
			               INNER JOIN nucleo.Ciudad AS nueva  ON nueva.IdCiudad  = @idCiudad
			               WHERE s.IdSede = @idSede
			                 AND actual.HusoHorario <> nueva.HusoHorario)
				SET @errores += N'- La sede tiene partidos y la nueva ciudad tiene otro huso horario: cambiaría la hora local de esos partidos.' + @salto;
		END;

		IF LEN(@errores) > 0
		BEGIN
			SET @mensaje = LEFT(N'SP_MODIFICACION_Sede - No se pudo completar la operación:' + @salto + @errores, 2048);
			THROW 52000, @mensaje, 1;
		END;

		IF @tranExterna = 0
			BEGIN TRANSACTION;
		ELSE
		BEGIN
			SAVE TRANSACTION PuntoSP;
			SET @savepoint = 1;
		END;

			UPDATE nucleo.Sede
			SET NombreEstadio = @nombreEstadio,
			    Capacidad     = @capacidad,
			    Latitud       = @latitud,
			    Longitud      = @longitud,
			    IdCiudad      = @idCiudad
			WHERE IdSede = @idSede;

		IF @tranExterna = 0
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		-- Solo se deshace lo propio: la transacción si la abrió este SP, o hasta el savepoint
		-- si corre dentro de una transacción del llamador (que queda abierta y a su cargo).
		IF @tranExterna = 0 AND @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;
		ELSE IF @savepoint = 1 AND XACT_STATE() = 1
			ROLLBACK TRANSACTION PuntoSP;
		THROW;
	END CATCH;
END;
GO

-- =========================================================================
-- nucleo.SP_BAJA_Sede
-- Parámetros: @idSede (sede a eliminar).
-- Regla: la sede no puede tener partidos asociados.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_Sede
	@idSede INT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(MAX) = N'',
	        @tranExterna BIT = IIF(@@TRANCOUNT > 0, 1, 0), -- 1 si el llamador ya abrió una transacción
	        @savepoint   BIT = 0,                          -- 1 cuando se tomó el savepoint PuntoSP
	        @mensaje NVARCHAR(2048),
	        @salto   NVARCHAR(2) = CHAR(13) + CHAR(10);

	BEGIN TRY
		IF @idSede IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @idSede)
			SET @errores += N'- La sede indicada no existe.' + @salto;
		ELSE IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdSede = @idSede)
			SET @errores += N'- La sede tiene partidos asociados y no puede eliminarse.' + @salto;

		IF LEN(@errores) > 0
		BEGIN
			SET @mensaje = LEFT(N'SP_BAJA_Sede - No se pudo completar la operación:' + @salto + @errores, 2048);
			THROW 52000, @mensaje, 1;
		END;

		IF @tranExterna = 0
			BEGIN TRANSACTION;
		ELSE
		BEGIN
			SAVE TRANSACTION PuntoSP;
			SET @savepoint = 1;
		END;

			DELETE FROM nucleo.Sede WHERE IdSede = @idSede;

		IF @tranExterna = 0
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		-- Solo se deshace lo propio: la transacción si la abrió este SP, o hasta el savepoint
		-- si corre dentro de una transacción del llamador (que queda abierta y a su cargo).
		IF @tranExterna = 0 AND @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;
		ELSE IF @savepoint = 1 AND XACT_STATE() = 1
			ROLLBACK TRANSACTION PuntoSP;
		THROW;
	END CATCH;
END;
GO

-- =========================================================================
-- nucleo.SP_ALTA_Partido
-- Parámetros: @numeroPartido, @idFase, @idSede y @fechaHoraLocal (hora local de la sede),
--             obligatorios; @idSeleccionLocal y @idSeleccionVisitante (obligatorias en fase
--             de grupos; NULL en fases eliminatorias); @idPartido (OUTPUT: id generado).
-- Crea el partido en estado 'Programado' y guarda solo FechaHoraUTC.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_Partido
	@numeroPartido        INT,
	@idFase               INT,
	@idSede               INT,
	@fechaHoraLocal       DATETIME2(0),
	@idSeleccionLocal     INT      = NULL,
	@idSeleccionVisitante INT      = NULL,
	@idPartido            SMALLINT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(MAX) = N'',
	        @tranExterna BIT = IIF(@@TRANCOUNT > 0, 1, 0), -- 1 si el llamador ya abrió una transacción
	        @savepoint   BIT = 0,                          -- 1 cuando se tomó el savepoint PuntoSP
	        @mensaje NVARCHAR(2048),
	        @salto   NVARCHAR(2) = CHAR(13) + CHAR(10),
	        @esEliminatoria   BIT,
	        @huso             VARCHAR(50),
	        @fechaHoraUTC     DATETIME2(0),
	        @horaValida       BIT = 0,
	        @idGrupoLocal     TINYINT,
	        @idGrupoVisitante TINYINT,
	        -- Reglas de agenda (si cambian, ajustar también en SP_MODIFICACION_Partido).
	        @minutosEntrePartidosSede INT = 180, -- mínimo entre dos partidos de la misma sede
	        @horasDescansoSeleccion   INT = 48;  -- mínimo entre los inicios de dos partidos de una selección

	BEGIN TRY
		SELECT @esEliminatoria = EsEliminatoria FROM nucleo.Fase WHERE IdFase = @idFase;

		SELECT @huso = c.HusoHorario
		FROM nucleo.Sede AS s
		INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = s.IdCiudad
		WHERE s.IdSede = @idSede;

		SELECT @idGrupoLocal     = IdGrupo FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionLocal;
		SELECT @idGrupoVisitante = IdGrupo FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionVisitante;

		-- >>> VALIDACIONES COMUNES (mantener sincronizadas con SP_MODIFICACION_Partido)
		-- Número de partido
		IF @numeroPartido IS NULL OR @numeroPartido NOT BETWEEN 1 AND 255
			SET @errores += N'- El número de partido es obligatorio y debe estar entre 1 y 255.' + @salto;
		ELSE IF EXISTS (SELECT 1
		                FROM nucleo.Partido AS p
		                WHERE p.NumeroPartido = @numeroPartido)
			SET @errores += N'- Ya existe otro partido con ese número.' + @salto;

		-- Fase, sede y horario
		IF @esEliminatoria IS NULL
			SET @errores += N'- La fase indicada no existe.' + @salto;

		IF @idSede IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @idSede)
			SET @errores += N'- La sede indicada no existe.' + @salto;

		IF @fechaHoraLocal IS NULL
			SET @errores += N'- La fecha y hora local del partido es obligatoria.' + @salto;

		IF @huso IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @huso)
			SET @errores += N'- El huso horario de la ciudad de la sede (' + @huso + N') no es válido: debe corregirse en la ciudad.' + @salto;

		-- Conversión hora local de la sede -> UTC (solo si el huso es válido).
		IF @fechaHoraLocal IS NOT NULL AND @huso IS NOT NULL
		   AND EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @huso)
		BEGIN
			SET @fechaHoraUTC = CAST((@fechaHoraLocal AT TIME ZONE @huso) AT TIME ZONE 'UTC' AS DATETIME2(0));

			-- Hora local inexistente (salto de horario de verano): la ida y vuelta no coincide.
			IF CAST((@fechaHoraUTC AT TIME ZONE 'UTC') AT TIME ZONE @huso AS DATETIME2(0)) <> @fechaHoraLocal
				SET @errores += N'- La hora local indicada no existe en el huso de la sede (salto de horario de verano).' + @salto;
			-- Hora local ambigua (retroceso de horario de verano): otra hora UTC cercana vuelve a la misma hora local.
			ELSE IF CAST((DATEADD(HOUR, 1, @fechaHoraUTC) AT TIME ZONE 'UTC') AT TIME ZONE @huso AS DATETIME2(0)) = @fechaHoraLocal
			     OR CAST((DATEADD(HOUR, -1, @fechaHoraUTC) AT TIME ZONE 'UTC') AT TIME ZONE @huso AS DATETIME2(0)) = @fechaHoraLocal
				SET @errores += N'- La hora local indicada es ambigua en el huso de la sede (retroceso de horario de verano).' + @salto;
			ELSE
				SET @horaValida = 1;
		END;

		-- Selecciones
		IF @idSeleccionLocal IS NOT NULL
		   AND NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionLocal)
			SET @errores += N'- La selección local indicada no existe.' + @salto;

		IF @idSeleccionVisitante IS NOT NULL
		   AND NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionVisitante)
			SET @errores += N'- La selección visitante indicada no existe.' + @salto;

		IF @idSeleccionLocal IS NOT NULL AND @idSeleccionLocal = @idSeleccionVisitante
			SET @errores += N'- Una selección no puede enfrentarse a sí misma.' + @salto;

		-- Fase de grupos: ambas selecciones, del mismo grupo y sin repetir el cruce.
		IF @esEliminatoria = 0
		BEGIN
			IF @idSeleccionLocal IS NULL OR @idSeleccionVisitante IS NULL
				SET @errores += N'- En fase de grupos ambas selecciones son obligatorias.' + @salto;
			ELSE IF @idSeleccionLocal <> @idSeleccionVisitante
			BEGIN
				IF @idGrupoLocal IS NOT NULL AND @idGrupoVisitante IS NOT NULL
				   AND @idGrupoLocal <> @idGrupoVisitante
					SET @errores += N'- En fase de grupos ambas selecciones deben pertenecer al mismo grupo.' + @salto;

				IF EXISTS (SELECT 1
				           FROM nucleo.Partido AS p
				           WHERE p.IdFase = @idFase
				             AND ((p.IdSeleccionLocal = @idSeleccionLocal AND p.IdSeleccionVisitante = @idSeleccionVisitante)
				               OR (p.IdSeleccionLocal = @idSeleccionVisitante AND p.IdSeleccionVisitante = @idSeleccionLocal)))
					SET @errores += N'- Ese cruce ya está programado en la fase de grupos.' + @salto;
			END;
		END;

		-- Fase eliminatoria: el cruce se asigna con SP_DEFINIR_CRUCE_ELIMINATORIO.
		-- [Alta: no se pueden informar selecciones | Modificación: no pueden diferir de las guardadas]
		IF @esEliminatoria = 1
		   AND (@idSeleccionLocal IS NOT NULL OR @idSeleccionVisitante IS NOT NULL)
			SET @errores += N'- En fases eliminatorias las selecciones no se cargan ni se cambian acá: se asignan con SP_DEFINIR_CRUCE_ELIMINATORIO.' + @salto;

		-- Agenda (solo si se pudo calcular el instante UTC)
		IF @horaValida = 1
		BEGIN
			IF EXISTS (SELECT 1
			           FROM nucleo.Partido AS p
			           WHERE p.IdSede = @idSede
			             AND p.FechaHoraUTC > DATEADD(MINUTE, -@minutosEntrePartidosSede, @fechaHoraUTC)
			             AND p.FechaHoraUTC < DATEADD(MINUTE,  @minutosEntrePartidosSede, @fechaHoraUTC))
				SET @errores += N'- La sede ya tiene otro partido a menos de ' + CAST(@minutosEntrePartidosSede AS NVARCHAR(10))
				              + N' minutos de ese horario.' + @salto;

			IF (@idSeleccionLocal IS NOT NULL OR @idSeleccionVisitante IS NOT NULL)
			   AND EXISTS (SELECT 1
			               FROM nucleo.Partido AS p
			               WHERE (p.IdSeleccionLocal IN (@idSeleccionLocal, @idSeleccionVisitante)
			                   OR p.IdSeleccionVisitante IN (@idSeleccionLocal, @idSeleccionVisitante))
			                 AND p.FechaHoraUTC > DATEADD(HOUR, -@horasDescansoSeleccion, @fechaHoraUTC)
			                 AND p.FechaHoraUTC < DATEADD(HOUR,  @horasDescansoSeleccion, @fechaHoraUTC))
				SET @errores += N'- Alguna de las selecciones tiene otro partido a menos de ' + CAST(@horasDescansoSeleccion AS NVARCHAR(10))
				              + N' horas de ese horario.' + @salto;
		END;
		-- <<< FIN VALIDACIONES COMUNES

		IF LEN(@errores) > 0
		BEGIN
			SET @mensaje = LEFT(N'SP_ALTA_Partido - No se pudo completar la operación:' + @salto + @errores, 2048);
			THROW 52000, @mensaje, 1;
		END;

		IF @tranExterna = 0
			BEGIN TRANSACTION;
		ELSE
		BEGIN
			SAVE TRANSACTION PuntoSP;
			SET @savepoint = 1;
		END;

			INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
			VALUES (@numeroPartido, @fechaHoraUTC, 'Programado', @idFase, @idSede, @idSeleccionLocal, @idSeleccionVisitante);

			SET @idPartido = SCOPE_IDENTITY();

		IF @tranExterna = 0
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		-- Solo se deshace lo propio: la transacción si la abrió este SP, o hasta el savepoint
		-- si corre dentro de una transacción del llamador (que queda abierta y a su cargo).
		IF @tranExterna = 0 AND @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;
		ELSE IF @savepoint = 1 AND XACT_STATE() = 1
			ROLLBACK TRANSACTION PuntoSP;
		THROW;
	END CATCH;
END;
GO

-- =========================================================================
-- nucleo.SP_MODIFICACION_Partido
-- Parámetros: @idPartido (partido a modificar) y los mismos campos que el alta, que
--             reemplazan los valores actuales.
-- Reglas propias: solo se modifican partidos 'Programado'. Si el partido tiene formaciones,
--                 sustituciones, goles, amonestaciones, designaciones arbitrales, sanciones
--                 o espacios publicitarios, no se pueden cambiar sus selecciones ni su fase;
--                 y si tiene espacios publicitarios, tampoco su sede ni su horario (el
--                 prime time se calculó con ese horario). En fases eliminatorias las
--                 selecciones recibidas deben ser iguales a las guardadas.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_Partido
	@idPartido            INT,
	@numeroPartido        INT,
	@idFase               INT,
	@idSede               INT,
	@fechaHoraLocal       DATETIME2(0),
	@idSeleccionLocal     INT = NULL,
	@idSeleccionVisitante INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(MAX) = N'',
	        @tranExterna BIT = IIF(@@TRANCOUNT > 0, 1, 0), -- 1 si el llamador ya abrió una transacción
	        @savepoint   BIT = 0,                          -- 1 cuando se tomó el savepoint PuntoSP
	        @mensaje NVARCHAR(2048),
	        @salto   NVARCHAR(2) = CHAR(13) + CHAR(10),
	        @esEliminatoria   BIT,
	        @huso             VARCHAR(50),
	        @fechaHoraUTC     DATETIME2(0),
	        @horaValida       BIT = 0,
	        @idGrupoLocal     TINYINT,
	        @idGrupoVisitante TINYINT,
	        -- Datos actuales del partido
	        @existe              BIT = 0,
	        @estadoActual        VARCHAR(10),
	        @faseActual          TINYINT,
	        @sedeActual          TINYINT,
	        @fechaHoraUTCActual  DATETIME2(0),
	        @localActual         TINYINT,
	        @visitanteActual     TINYINT,
	        @tieneDependientes   BIT = 0,
	        @tieneEspacios       BIT = 0,
	        @seleccionesCambian  BIT = 0,
	        -- Reglas de agenda (si cambian, ajustar también en SP_ALTA_Partido).
	        @minutosEntrePartidosSede INT = 180, -- mínimo entre dos partidos de la misma sede
	        @horasDescansoSeleccion   INT = 48;  -- mínimo entre los inicios de dos partidos de una selección

	BEGIN TRY
		SELECT @existe             = 1,
		       @estadoActual       = p.Estado,
		       @faseActual         = p.IdFase,
		       @sedeActual         = p.IdSede,
		       @fechaHoraUTCActual = p.FechaHoraUTC,
		       @localActual        = p.IdSeleccionLocal,
		       @visitanteActual    = p.IdSeleccionVisitante
		FROM nucleo.Partido AS p
		WHERE p.IdPartido = @idPartido;

		SELECT @esEliminatoria = EsEliminatoria FROM nucleo.Fase WHERE IdFase = @idFase;

		SELECT @huso = c.HusoHorario
		FROM nucleo.Sede AS s
		INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = s.IdCiudad
		WHERE s.IdSede = @idSede;

		SELECT @idGrupoLocal     = IdGrupo FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionLocal;
		SELECT @idGrupoVisitante = IdGrupo FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionVisitante;

		-- Estado del partido
		IF @existe = 0
			SET @errores += N'- El partido indicado no existe.' + @salto;
		ELSE IF @estadoActual <> 'Programado'
			SET @errores += N'- Solo se pueden modificar partidos en estado Programado.' + @salto;

		-- >>> VALIDACIONES COMUNES (mantener sincronizadas con SP_ALTA_Partido)
		-- Número de partido
		IF @numeroPartido IS NULL OR @numeroPartido NOT BETWEEN 1 AND 255
			SET @errores += N'- El número de partido es obligatorio y debe estar entre 1 y 255.' + @salto;
		ELSE IF EXISTS (SELECT 1
		                FROM nucleo.Partido AS p
		                WHERE p.NumeroPartido = @numeroPartido
		                  AND p.IdPartido <> @idPartido) -- [solo MODIFICACION] excluye el propio partido
			SET @errores += N'- Ya existe otro partido con ese número.' + @salto;

		-- Fase, sede y horario
		IF @esEliminatoria IS NULL
			SET @errores += N'- La fase indicada no existe.' + @salto;

		IF @idSede IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @idSede)
			SET @errores += N'- La sede indicada no existe.' + @salto;

		IF @fechaHoraLocal IS NULL
			SET @errores += N'- La fecha y hora local del partido es obligatoria.' + @salto;

		IF @huso IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @huso)
			SET @errores += N'- El huso horario de la ciudad de la sede (' + @huso + N') no es válido: debe corregirse en la ciudad.' + @salto;

		-- Conversión hora local de la sede -> UTC (solo si el huso es válido).
		IF @fechaHoraLocal IS NOT NULL AND @huso IS NOT NULL
		   AND EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @huso)
		BEGIN
			SET @fechaHoraUTC = CAST((@fechaHoraLocal AT TIME ZONE @huso) AT TIME ZONE 'UTC' AS DATETIME2(0));

			-- Hora local inexistente (salto de horario de verano): la ida y vuelta no coincide.
			IF CAST((@fechaHoraUTC AT TIME ZONE 'UTC') AT TIME ZONE @huso AS DATETIME2(0)) <> @fechaHoraLocal
				SET @errores += N'- La hora local indicada no existe en el huso de la sede (salto de horario de verano).' + @salto;
			-- Hora local ambigua (retroceso de horario de verano): otra hora UTC cercana vuelve a la misma hora local.
			ELSE IF CAST((DATEADD(HOUR, 1, @fechaHoraUTC) AT TIME ZONE 'UTC') AT TIME ZONE @huso AS DATETIME2(0)) = @fechaHoraLocal
			     OR CAST((DATEADD(HOUR, -1, @fechaHoraUTC) AT TIME ZONE 'UTC') AT TIME ZONE @huso AS DATETIME2(0)) = @fechaHoraLocal
				SET @errores += N'- La hora local indicada es ambigua en el huso de la sede (retroceso de horario de verano).' + @salto;
			ELSE
				SET @horaValida = 1;
		END;

		-- Selecciones
		IF @idSeleccionLocal IS NOT NULL
		   AND NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionLocal)
			SET @errores += N'- La selección local indicada no existe.' + @salto;

		IF @idSeleccionVisitante IS NOT NULL
		   AND NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionVisitante)
			SET @errores += N'- La selección visitante indicada no existe.' + @salto;

		IF @idSeleccionLocal IS NOT NULL AND @idSeleccionLocal = @idSeleccionVisitante
			SET @errores += N'- Una selección no puede enfrentarse a sí misma.' + @salto;

		-- Fase de grupos: ambas selecciones, del mismo grupo y sin repetir el cruce.
		IF @esEliminatoria = 0
		BEGIN
			IF @idSeleccionLocal IS NULL OR @idSeleccionVisitante IS NULL
				SET @errores += N'- En fase de grupos ambas selecciones son obligatorias.' + @salto;
			ELSE IF @idSeleccionLocal <> @idSeleccionVisitante
			BEGIN
				IF @idGrupoLocal IS NOT NULL AND @idGrupoVisitante IS NOT NULL
				   AND @idGrupoLocal <> @idGrupoVisitante
					SET @errores += N'- En fase de grupos ambas selecciones deben pertenecer al mismo grupo.' + @salto;

				IF EXISTS (SELECT 1
				           FROM nucleo.Partido AS p
				           WHERE p.IdFase = @idFase
				             AND p.IdPartido <> @idPartido -- [solo MODIFICACION] excluye el propio partido
				             AND ((p.IdSeleccionLocal = @idSeleccionLocal AND p.IdSeleccionVisitante = @idSeleccionVisitante)
				               OR (p.IdSeleccionLocal = @idSeleccionVisitante AND p.IdSeleccionVisitante = @idSeleccionLocal)))
					SET @errores += N'- Ese cruce ya está programado en la fase de grupos.' + @salto;
			END;
		END;

		-- Fase eliminatoria: el cruce se asigna con SP_DEFINIR_CRUCE_ELIMINATORIO.
		-- [Alta: no se pueden informar selecciones | Modificación: no pueden diferir de las guardadas]
		IF @esEliminatoria = 1
		   AND (ISNULL(@idSeleccionLocal, 0) <> ISNULL(@localActual, 0)
		     OR ISNULL(@idSeleccionVisitante, 0) <> ISNULL(@visitanteActual, 0))
			SET @errores += N'- En fases eliminatorias las selecciones no se cargan ni se cambian acá: se asignan con SP_DEFINIR_CRUCE_ELIMINATORIO.' + @salto;

		-- Agenda (solo si se pudo calcular el instante UTC)
		IF @horaValida = 1
		BEGIN
			IF EXISTS (SELECT 1
			           FROM nucleo.Partido AS p
			           WHERE p.IdSede = @idSede
			             AND p.IdPartido <> @idPartido -- [solo MODIFICACION] excluye el propio partido
			             AND p.FechaHoraUTC > DATEADD(MINUTE, -@minutosEntrePartidosSede, @fechaHoraUTC)
			             AND p.FechaHoraUTC < DATEADD(MINUTE,  @minutosEntrePartidosSede, @fechaHoraUTC))
				SET @errores += N'- La sede ya tiene otro partido a menos de ' + CAST(@minutosEntrePartidosSede AS NVARCHAR(10))
				              + N' minutos de ese horario.' + @salto;

			IF (@idSeleccionLocal IS NOT NULL OR @idSeleccionVisitante IS NOT NULL)
			   AND EXISTS (SELECT 1
			               FROM nucleo.Partido AS p
			               WHERE p.IdPartido <> @idPartido -- [solo MODIFICACION] excluye el propio partido
			                 AND (p.IdSeleccionLocal IN (@idSeleccionLocal, @idSeleccionVisitante)
			                   OR p.IdSeleccionVisitante IN (@idSeleccionLocal, @idSeleccionVisitante))
			                 AND p.FechaHoraUTC > DATEADD(HOUR, -@horasDescansoSeleccion, @fechaHoraUTC)
			                 AND p.FechaHoraUTC < DATEADD(HOUR,  @horasDescansoSeleccion, @fechaHoraUTC))
				SET @errores += N'- Alguna de las selecciones tiene otro partido a menos de ' + CAST(@horasDescansoSeleccion AS NVARCHAR(10))
				              + N' horas de ese horario.' + @salto;
		END;
		-- <<< FIN VALIDACIONES COMUNES

		-- Reglas propias de la modificación: partidos con registros asociados (solo si el partido existe).
		IF @existe = 1
		BEGIN
			SET @tieneEspacios = CASE WHEN EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdPartido = @idPartido)
			                          THEN 1 ELSE 0 END;

			SET @tieneDependientes = CASE
				WHEN @tieneEspacios = 1
				  OR EXISTS (SELECT 1 FROM jugadores.Formacion WHERE IdPartido = @idPartido)
				  OR EXISTS (SELECT 1 FROM jugadores.Sustitucion WHERE IdPartido = @idPartido)
				  OR EXISTS (SELECT 1 FROM eventos.Gol WHERE IdPartido = @idPartido)
				  OR EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdPartido = @idPartido)
				  OR EXISTS (SELECT 1 FROM nucleo.DesignacionArbitral WHERE IdPartido = @idPartido)
				  OR EXISTS (SELECT 1
				             FROM nucleo.Sancion AS sa
				             INNER JOIN nucleo.DesignacionArbitral AS d ON d.IdDesignacionArbitral = sa.IdDesignacionArbitral
				             WHERE d.IdPartido = @idPartido)
				THEN 1 ELSE 0 END;

			SET @seleccionesCambian = CASE
				WHEN ISNULL(@idSeleccionLocal, 0) <> ISNULL(@localActual, 0)
				  OR ISNULL(@idSeleccionVisitante, 0) <> ISNULL(@visitanteActual, 0)
				THEN 1 ELSE 0 END;

			-- En fases eliminatorias el cambio de selecciones ya se informó arriba.
			IF @tieneDependientes = 1 AND @seleccionesCambian = 1 AND ISNULL(@esEliminatoria, 0) = 0
				SET @errores += N'- El partido tiene formaciones, sustituciones, goles, amonestaciones, designaciones arbitrales, sanciones o espacios publicitarios: no se pueden cambiar sus selecciones.' + @salto;

			IF @tieneDependientes = 1 AND @idFase IS NOT NULL AND @idFase <> @faseActual
				SET @errores += N'- El partido tiene registros asociados (formaciones, sustituciones, goles, amonestaciones, designaciones arbitrales, sanciones o espacios publicitarios): no se puede cambiar su fase.' + @salto;

			IF @tieneEspacios = 1
			   AND ((@idSede IS NOT NULL AND @idSede <> @sedeActual)
			     OR (@horaValida = 1 AND @fechaHoraUTC <> @fechaHoraUTCActual))
				SET @errores += N'- El partido tiene espacios publicitarios asignados: no se puede cambiar su sede ni su horario.' + @salto;
		END;

		IF LEN(@errores) > 0
		BEGIN
			SET @mensaje = LEFT(N'SP_MODIFICACION_Partido - No se pudo completar la operación:' + @salto + @errores, 2048);
			THROW 52000, @mensaje, 1;
		END;

		IF @tranExterna = 0
			BEGIN TRANSACTION;
		ELSE
		BEGIN
			SAVE TRANSACTION PuntoSP;
			SET @savepoint = 1;
		END;

			UPDATE nucleo.Partido
			SET NumeroPartido        = @numeroPartido,
			    FechaHoraUTC         = @fechaHoraUTC,
			    IdFase               = @idFase,
			    IdSede               = @idSede,
			    IdSeleccionLocal     = @idSeleccionLocal,
			    IdSeleccionVisitante = @idSeleccionVisitante
			WHERE IdPartido = @idPartido;

		IF @tranExterna = 0
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		-- Solo se deshace lo propio: la transacción si la abrió este SP, o hasta el savepoint
		-- si corre dentro de una transacción del llamador (que queda abierta y a su cargo).
		IF @tranExterna = 0 AND @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;
		ELSE IF @savepoint = 1 AND XACT_STATE() = 1
			ROLLBACK TRANSACTION PuntoSP;
		THROW;
	END CATCH;
END;
GO

-- =========================================================================
-- nucleo.SP_BAJA_Partido
-- Parámetros: @idPartido (partido a eliminar).
-- Reglas: solo se eliminan partidos 'Programado' que no tengan formaciones, sustituciones,
--         goles, amonestaciones, designaciones arbitrales, sanciones ni espacios publicitarios.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_Partido
	@idPartido INT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(MAX) = N'',
	        @tranExterna BIT = IIF(@@TRANCOUNT > 0, 1, 0), -- 1 si el llamador ya abrió una transacción
	        @savepoint   BIT = 0,                          -- 1 cuando se tomó el savepoint PuntoSP
	        @mensaje NVARCHAR(2048),
	        @salto   NVARCHAR(2) = CHAR(13) + CHAR(10),
	        @existe  BIT = 0,
	        @estadoActual VARCHAR(10);

	BEGIN TRY
		SELECT @existe = 1, @estadoActual = Estado
		FROM nucleo.Partido
		WHERE IdPartido = @idPartido;

		IF @existe = 0
			SET @errores += N'- El partido indicado no existe.' + @salto;
		ELSE
		BEGIN
			IF @estadoActual <> 'Programado'
				SET @errores += N'- Solo se pueden eliminar partidos en estado Programado.' + @salto;

			IF EXISTS (SELECT 1 FROM jugadores.Formacion WHERE IdPartido = @idPartido)
				SET @errores += N'- El partido tiene formaciones cargadas.' + @salto;

			IF EXISTS (SELECT 1 FROM jugadores.Sustitucion WHERE IdPartido = @idPartido)
				SET @errores += N'- El partido tiene sustituciones cargadas.' + @salto;

			IF EXISTS (SELECT 1 FROM eventos.Gol WHERE IdPartido = @idPartido)
				SET @errores += N'- El partido tiene goles cargados.' + @salto;

			IF EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdPartido = @idPartido)
				SET @errores += N'- El partido tiene amonestaciones cargadas.' + @salto;

			IF EXISTS (SELECT 1 FROM nucleo.DesignacionArbitral WHERE IdPartido = @idPartido)
				SET @errores += N'- El partido tiene designaciones arbitrales asociadas.' + @salto;

			IF EXISTS (SELECT 1
			           FROM nucleo.Sancion AS sa
			           INNER JOIN nucleo.DesignacionArbitral AS d ON d.IdDesignacionArbitral = sa.IdDesignacionArbitral
			           WHERE d.IdPartido = @idPartido)
				SET @errores += N'- El partido tiene sanciones arbitrales asociadas.' + @salto;

			IF EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdPartido = @idPartido)
				SET @errores += N'- El partido tiene espacios publicitarios asignados.' + @salto;
		END;

		IF LEN(@errores) > 0
		BEGIN
			SET @mensaje = LEFT(N'SP_BAJA_Partido - No se pudo completar la operación:' + @salto + @errores, 2048);
			THROW 52000, @mensaje, 1;
		END;

		IF @tranExterna = 0
			BEGIN TRANSACTION;
		ELSE
		BEGIN
			SAVE TRANSACTION PuntoSP;
			SET @savepoint = 1;
		END;

			DELETE FROM nucleo.Partido WHERE IdPartido = @idPartido;

		IF @tranExterna = 0
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		-- Solo se deshace lo propio: la transacción si la abrió este SP, o hasta el savepoint
		-- si corre dentro de una transacción del llamador (que queda abierta y a su cargo).
		IF @tranExterna = 0 AND @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;
		ELSE IF @savepoint = 1 AND XACT_STATE() = 1
			ROLLBACK TRANSACTION PuntoSP;
		THROW;
	END CATCH;
END;
GO
