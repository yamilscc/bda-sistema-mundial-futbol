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
	- Crear nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO: asigna las dos selecciones de un partido de una fase
	  eliminatoria validando el cruce contra los clasificados y los resultados de la fase anterior.
	- Requiere ejecutados los scripts 01 a 27 (usa nucleo.fn_FaseEliminatoriaInicial,
	  nucleo.fn_SeleccionesClasificadas, nucleo.fn_ValidarFaseGruposCompleta y nucleo.fn_DefinicionPartido
	  del script 25, y nucleo.fn_SeleccionConPartidoCercano y nucleo.fn_PartidoTieneRegistros del 07).
	- Test correspondiente: testing/28_Test_SP_DefinirCruceEliminatorio.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO
-- Parámetros: @idPartido (partido eliminatorio 'Programado'), @idSeleccionLocal y
--             @idSeleccionVisitante (las dos son obligatorias).
-- Es el único camino para asignar selecciones en fases eliminatorias: SP_ALTA_Partido y
-- SP_MODIFICACION_Partido (script 09) no las cargan ni las cambian.
-- Reglas de cruce (no se persiste un árbol pre-cargado; cada cruce se valida al cargarlo):
--   - Fase inicial (la que deduce nucleo.fn_FaseEliminatoriaInicial del cupo de clasificados):
--     la fase de grupos debe estar completa (nucleo.fn_ValidarFaseGruposCompleta) y ambas selecciones
--     deben haber clasificado (nucleo.fn_SeleccionesClasificadas).
--   - Fases posteriores (Octavos, Cuartos, Semifinal y Final cuando no son la inicial): ambas selecciones
--     ganaron un partido 'Finalizado' de la fase eliminatoria anterior (nucleo.fn_DefinicionPartido; el
--     ganador puede haberse definido por penales). La Final mira a la Semifinal: el Tercer puesto no cuenta
--     como fase anterior.
--   - Tercer puesto: ambas selecciones PERDIERON una Semifinal 'Finalizado'.
--   - El partido de la fase anterior se jugó antes que este.
--   - Una fase anterior a la inicial no se juega con la regla de clasificación actual (por ejemplo,
--     Octavos cuando la eliminación empieza en Cuartos).
--   - NO se controla qué cruces son posibles entre selecciones de la misma fase (por ejemplo, que dos
--     selecciones del mismo grupo no se enfrenten en la fase inicial): el torneo no tiene un árbol fijo.
-- Reglas comunes (se informan todas juntas en un único mensaje):
--   - Partido existente, de una fase eliminatoria y 'Programado'; selecciones obligatorias, existentes y distintas.
--   - Ninguna de las dos está asignada a otro partido de la misma fase.
--   - Descanso: ninguna tiene otro partido a menos de 48 horas (nucleo.fn_SeleccionConPartidoCercano, la
--     misma regla que SP_ALTA_Partido y SP_MODIFICACION_Partido).
--   - Si el partido ya tiene formaciones, sustituciones, goles, amonestaciones, designaciones arbitrales,
--     sanciones o espacios publicitarios (nucleo.fn_PartidoTieneRegistros), no se pueden cambiar sus selecciones.
-- Reasignar el mismo cruce, o cambiarlo si el partido no tiene registros, está permitido; repetir
-- exactamente el cruce ya asignado no es un error ni cambia nada.
-- Efecto: solo cambian IdSeleccionLocal e IdSeleccionVisitante. Salida: la fila de nucleo.vw_PartidoResultado.
-- Transacción: abre la propia o, si el llamador ya tiene una abierta, usa un savepoint y no la deshace
--              ante un error de validación.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO
	@idPartido            INT,
	@idSeleccionLocal     INT,
	@idSeleccionVisitante INT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(MAX) = N'',
	        @tranExterna BIT = IIF(@@TRANCOUNT > 0, 1, 0), -- 1 si el llamador ya abrió una transacción
	        @savepoint   BIT = 0,                          -- 1 cuando se tomó el savepoint PuntoSP
	        @mensaje NVARCHAR(2048),
	        @salto   NVARCHAR(2) = CHAR(13) + CHAR(10),
	        -- Datos del partido
	        @existe BIT = 0,
	        @estadoActual VARCHAR(10),
	        @idFase TINYINT,
	        @nombreFase VARCHAR(28),
	        @ordenFase TINYINT,
	        @esEliminatoria BIT,
	        @fechaHoraUTC DATETIME2(0),
	        @localActual TINYINT,
	        @visitanteActual TINYINT,
	        -- Selecciones
	        @seleccionesValidas BIT = 0,
	        -- Fase inicial y fase anterior
	        @idFaseInicial TINYINT,
	        @nombreInicial VARCHAR(28),
	        @ordenInicial TINYINT,
	        @idFaseAnterior TINYINT,
	        @nombreAnterior VARCHAR(28),
	        @esTercerPuesto BIT = 0,
	        -- Auxiliares
	        @grupoIncompleto NVARCHAR(MAX),
	        @lista NVARCHAR(MAX),
	        @horasDescanso INT,
	        @seleccionesCambian BIT,
	        @tieneRegistros BIT;

	DECLARE @sel TABLE (IdSeleccion TINYINT, CodigoFIFA CHAR(3));

	BEGIN TRY
		-- ---- Validaciones ---------------------------------------------------
		SELECT @existe = 1,
		       @estadoActual = p.Estado,
		       @idFase = p.IdFase,
		       @nombreFase = f.Nombre,
		       @ordenFase = f.Orden,
		       @esEliminatoria = f.EsEliminatoria,
		       @fechaHoraUTC = p.FechaHoraUTC,
		       @localActual = p.IdSeleccionLocal,
		       @visitanteActual = p.IdSeleccionVisitante
		FROM nucleo.Partido AS p
		INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
		WHERE p.IdPartido = @idPartido;

		IF @existe = 0
			SET @errores += N'- El partido indicado no existe.' + @salto;
		ELSE
		BEGIN
			IF @esEliminatoria = 0
				SET @errores += N'- El partido no es de una fase eliminatoria: los cruces de la fase de grupos se cargan con SP_ALTA_Partido y SP_MODIFICACION_Partido.' + @salto;

			IF @estadoActual <> 'Programado'
				SET @errores += N'- Solo se pueden definir cruces de partidos en estado Programado.' + @salto;
		END;

		-- Selecciones
		IF @idSeleccionLocal IS NULL
			SET @errores += N'- La selección local es obligatoria.' + @salto;
		ELSE IF NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionLocal)
			SET @errores += N'- La selección local indicada no existe.' + @salto;

		IF @idSeleccionVisitante IS NULL
			SET @errores += N'- La selección visitante es obligatoria.' + @salto;
		ELSE IF NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionVisitante)
			SET @errores += N'- La selección visitante indicada no existe.' + @salto;

		IF @idSeleccionLocal IS NOT NULL AND @idSeleccionLocal = @idSeleccionVisitante
			SET @errores += N'- Una selección no puede enfrentarse a sí misma.' + @salto;

		IF @idSeleccionLocal IS NOT NULL AND @idSeleccionVisitante IS NOT NULL
		   AND @idSeleccionLocal <> @idSeleccionVisitante
		   AND EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionLocal)
		   AND EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionVisitante)
		BEGIN
			SET @seleccionesValidas = 1;

			INSERT INTO @sel (IdSeleccion, CodigoFIFA)
			SELECT s.IdSeleccion, s.CodigoFIFA
			FROM nucleo.Seleccion AS s
			WHERE s.IdSeleccion IN (@idSeleccionLocal, @idSeleccionVisitante);
		END;

		-- Reglas de cruce y de agenda: solo con un partido eliminatorio y dos selecciones válidas.
		IF @existe = 1 AND @esEliminatoria = 1 AND @seleccionesValidas = 1
		BEGIN
			SELECT @idFaseInicial = fi.IdFase, @nombreInicial = fi.Nombre
			FROM nucleo.fn_FaseEliminatoriaInicial() AS fi;

			SELECT @ordenInicial = f.Orden FROM nucleo.Fase AS f WHERE f.IdFase = @idFaseInicial;

			SET @esTercerPuesto = CASE WHEN @nombreFase = 'Tercer puesto' THEN 1 ELSE 0 END;

			IF @esTercerPuesto = 0 AND @idFaseInicial IS NULL
				SET @errores += N'- No se puede determinar con qué fase empieza la eliminación directa (el total de clasificados no es 8, 16 ni 32).' + @salto;
			ELSE IF @esTercerPuesto = 0 AND @ordenFase < @ordenInicial
				SET @errores += N'- ' + @nombreFase + N' no se juega con la regla de clasificación actual: la eliminación directa empieza en '
				              + @nombreInicial + N'.' + @salto;
			ELSE IF @esTercerPuesto = 0 AND @idFase = @idFaseInicial
			BEGIN
				-- Fase inicial: la fase de grupos debe estar completa y ambas selecciones deben haber clasificado.
				SET @grupoIncompleto = nucleo.fn_ValidarFaseGruposCompleta();

				IF LEN(@grupoIncompleto) > 0
					SET @errores += N'- La fase de grupos no está completa, por lo que todavía no se sabe quién clasificó:' + @salto
					              + @grupoIncompleto;
				ELSE
				BEGIN
					SET @lista = NULL;
					SELECT @lista = STRING_AGG(CAST(s.CodigoFIFA AS NVARCHAR(10)), N', ')
					FROM @sel AS s
					WHERE NOT EXISTS (SELECT 1
					                  FROM nucleo.fn_SeleccionesClasificadas() AS c
					                  WHERE c.IdSeleccion = s.IdSeleccion AND c.Clasifica = 1);

					IF @lista IS NOT NULL
						SET @errores += N'- No clasificaron a la eliminación directa: ' + @lista + N'.' + @salto;
				END;
			END
			ELSE
			BEGIN
				-- Fase posterior a la inicial: ganaron (o, en el Tercer puesto, perdieron) un partido de la fase anterior.
				IF @esTercerPuesto = 1
					SELECT @idFaseAnterior = f.IdFase, @nombreAnterior = f.Nombre
					FROM nucleo.Fase AS f
					WHERE f.Nombre = 'Semifinal';
				ELSE
					SELECT TOP (1) @idFaseAnterior = f.IdFase, @nombreAnterior = f.Nombre
					FROM nucleo.Fase AS f
					WHERE f.EsEliminatoria = 1 AND f.Nombre <> 'Tercer puesto' AND f.Orden < @ordenFase
					ORDER BY f.Orden DESC;

				IF @idFaseAnterior IS NOT NULL
				BEGIN
					SET @lista = NULL;
					SELECT @lista = STRING_AGG(CAST(s.CodigoFIFA AS NVARCHAR(10)), N', ')
					FROM @sel AS s
					WHERE NOT EXISTS (SELECT 1
					                  FROM nucleo.Partido AS pa
					                  CROSS APPLY nucleo.fn_DefinicionPartido(pa.IdPartido) AS d
					                  WHERE pa.IdFase = @idFaseAnterior
					                    AND pa.Estado = 'Finalizado'
					                    AND s.IdSeleccion = CASE WHEN @esTercerPuesto = 1 THEN d.IdPerdedor ELSE d.IdGanador END);

					IF @lista IS NOT NULL
						SET @errores += N'- No ' + CASE WHEN @esTercerPuesto = 1 THEN N'perdieron' ELSE N'ganaron' END
						              + N' un partido finalizado de ' + @nombreAnterior + N': ' + @lista + N'.' + @salto;

					-- Ganaron (o perdieron) ese partido, pero se jugó después de este.
					SET @lista = NULL;
					SELECT @lista = STRING_AGG(CAST(s.CodigoFIFA AS NVARCHAR(10)), N', ')
					FROM @sel AS s
					WHERE EXISTS (SELECT 1
					              FROM nucleo.Partido AS pa
					              CROSS APPLY nucleo.fn_DefinicionPartido(pa.IdPartido) AS d
					              WHERE pa.IdFase = @idFaseAnterior
					                AND pa.Estado = 'Finalizado'
					                AND s.IdSeleccion = CASE WHEN @esTercerPuesto = 1 THEN d.IdPerdedor ELSE d.IdGanador END)
					  AND NOT EXISTS (SELECT 1
					                  FROM nucleo.Partido AS pa
					                  CROSS APPLY nucleo.fn_DefinicionPartido(pa.IdPartido) AS d
					                  WHERE pa.IdFase = @idFaseAnterior
					                    AND pa.Estado = 'Finalizado'
					                    AND pa.FechaHoraUTC < @fechaHoraUTC
					                    AND s.IdSeleccion = CASE WHEN @esTercerPuesto = 1 THEN d.IdPerdedor ELSE d.IdGanador END);

					IF @lista IS NOT NULL
						SET @errores += N'- El partido de ' + @nombreAnterior + N' que '
						              + CASE WHEN @esTercerPuesto = 1 THEN N'perdieron' ELSE N'ganaron' END
						              + N' no es anterior a este partido: ' + @lista + N'.' + @salto;
				END;
			END;

			-- Ninguna de las dos selecciones puede estar asignada a otro partido de la misma fase.
			SET @lista = NULL;
			SELECT @lista = STRING_AGG(CAST(s.CodigoFIFA AS NVARCHAR(10)), N', ')
			FROM @sel AS s
			WHERE EXISTS (SELECT 1
			              FROM nucleo.Partido AS p
			              WHERE p.IdFase = @idFase
			                AND p.IdPartido <> @idPartido
			                AND s.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante));

			IF @lista IS NOT NULL
				SET @errores += N'- Ya están asignadas a otro partido de ' + @nombreFase + N': ' + @lista + N'.' + @salto;

			-- Descanso entre partidos (la regla vive en nucleo.fn_SeleccionConPartidoCercano).
			SET @lista = NULL;
			SELECT @lista = STRING_AGG(CAST(x.CodigoFIFA AS NVARCHAR(10)), N', '),
			       @horasDescanso = MAX(x.HorasDescanso)
			FROM (SELECT DISTINCT s.CodigoFIFA, c.HorasDescanso
			      FROM nucleo.fn_SeleccionConPartidoCercano(@idSeleccionLocal, @idSeleccionVisitante, @fechaHoraUTC, @idPartido) AS c
			      INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = c.IdSeleccion) AS x;

			IF @lista IS NOT NULL
				SET @errores += N'- Tienen otro partido a menos de ' + CAST(@horasDescanso AS NVARCHAR(10))
				              + N' horas de este: ' + @lista + N'.' + @salto;

			-- Con registros asociados no se pueden cambiar las selecciones (repetir el mismo cruce sí se puede).
			SET @seleccionesCambian = CASE WHEN ISNULL(@idSeleccionLocal, 0) <> ISNULL(@localActual, 0)
			                                 OR ISNULL(@idSeleccionVisitante, 0) <> ISNULL(@visitanteActual, 0)
			                               THEN 1 ELSE 0 END;

			SELECT @tieneRegistros = r.TieneAlguno FROM nucleo.fn_PartidoTieneRegistros(@idPartido) AS r;

			IF @seleccionesCambian = 1 AND @tieneRegistros = 1
				SET @errores += N'- El partido tiene registros asociados (formaciones, sustituciones, goles, amonestaciones, designaciones arbitrales, sanciones o espacios publicitarios): no se pueden cambiar sus selecciones.' + @salto;
		END;

		IF LEN(@errores) > 0
		BEGIN
			SET @mensaje = LEFT(N'SP_DEFINIR_CRUCE_ELIMINATORIO - No se pudo definir el cruce:' + @salto + @errores, 2048);
			THROW 52000, @mensaje, 1;
		END;

		-- ---- Operación ------------------------------------------------------
		IF @tranExterna = 0
			BEGIN TRANSACTION;
		ELSE
		BEGIN
			SAVE TRANSACTION PuntoSP;
			SET @savepoint = 1;
		END;

		-- La condición Estado = 'Programado' evita pisar un cambio hecho por otra sesión en el medio.
		UPDATE nucleo.Partido
		SET IdSeleccionLocal = @idSeleccionLocal,
		    IdSeleccionVisitante = @idSeleccionVisitante
		WHERE IdPartido = @idPartido
		  AND Estado = 'Programado';

		IF @@ROWCOUNT = 0
			THROW 52000, N'SP_DEFINIR_CRUCE_ELIMINATORIO - El partido fue finalizado por otra operación.', 1;

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

	SELECT v.*
	FROM nucleo.vw_PartidoResultado AS v
	WHERE v.IdPartido = @idPartido;
END;
GO
