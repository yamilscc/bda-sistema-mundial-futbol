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
	- Crear nucleo.SP_FINALIZAR_PARTIDO: cierra un partido (Programado -> Finalizado) y registra
	  la concurrencia, después de validar que los goles cargados permiten definir el resultado.
	- Requiere ejecutados los scripts 01 a 25.
	- Test correspondiente: testing/26_Test_SP_FinalizarPartido.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- nucleo.SP_FINALIZAR_PARTIDO
-- Parámetros: @idPartido (partido a cerrar), @concurrencia (público; opcional).
-- Reglas (se informan todas juntas en un único mensaje):
--   - El partido existe, está 'Programado', tiene ambas selecciones definidas y ya se jugó
--     (FechaHoraUTC no futura).
--   - Concurrencia: si se informa, >= 0 y, cuando la sede tiene capacidad cargada, <= capacidad.
--     Es opcional porque los datasets externos pueden no traerla (la columna admite NULL).
--   - Todo gol del partido tiene un autor convocado en una de las dos selecciones del partido
--     (eventos.fn_ResultadoPartido no podría sumarlo a la selección correcta).
--   - En fase de grupos no hay definición por penales.
--   - En eliminación directa el partido tiene ganador (nucleo.fn_DefinicionPartido): gana por
--     goles o, si terminó empatado, por la tanda de penales. Se rechazan: empate sin tanda,
--     tanda igualada y tanda cargada en un partido que no terminó empatado.
-- Efecto: solo cambia Estado a 'Finalizado' y Concurrencia (3FN: el resultado no se guarda en
--         Partido; sigue derivándose de eventos.Gol con eventos.fn_ResultadoPartido).
-- Salida: la fila del partido en nucleo.vw_PartidoResultado.
-- Transacción: abre la propia o, si el llamador ya tiene una abierta, usa un savepoint y no la
--              deshace ante un error de validación.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_FINALIZAR_PARTIDO
	@idPartido    INT,
	@concurrencia INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(MAX) = N'',
	        @tranExterna BIT = IIF(@@TRANCOUNT > 0, 1, 0), -- 1 si el llamador ya abrió una transacción
	        @savepoint   BIT = 0,                          -- 1 cuando se tomó el savepoint PuntoSP
	        @mensaje NVARCHAR(2048),
	        @salto   NVARCHAR(2) = CHAR(13) + CHAR(10),
	        @existe BIT = 0,
	        @estado VARCHAR(10),
	        @fechaHoraUTC DATETIME2(0),
	        @idLocal TINYINT,
	        @idVisitante TINYINT,
	        @esEliminatoria BIT,
	        @capacidad INT,
	        @golesAjenos INT,
	        @golesLocal INT,
	        @golesVisitante INT,
	        @penalesLocal INT,
	        @penalesVisitante INT,
	        @idGanador TINYINT;

	BEGIN TRY
		-- ---- Validaciones ---------------------------------------------------
		SELECT @existe = 1,
		       @estado = p.Estado,
		       @fechaHoraUTC = p.FechaHoraUTC,
		       @idLocal = p.IdSeleccionLocal,
		       @idVisitante = p.IdSeleccionVisitante,
		       @esEliminatoria = f.EsEliminatoria,
		       @capacidad = s.Capacidad
		FROM nucleo.Partido AS p
		INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
		INNER JOIN nucleo.Sede AS s ON s.IdSede = p.IdSede
		WHERE p.IdPartido = @idPartido;

		IF @existe = 0
			SET @errores += N'- El partido indicado no existe.' + @salto;
		ELSE
		BEGIN
			IF @estado <> 'Programado'
				SET @errores += N'- El partido no está en estado Programado (ya fue finalizado).' + @salto;

			IF @idLocal IS NULL OR @idVisitante IS NULL
				SET @errores += N'- El partido no tiene definidas ambas selecciones.' + @salto;

			IF @fechaHoraUTC > SYSUTCDATETIME()
				SET @errores += N'- El partido todavía no se jugó (su fecha y hora UTC es futura).' + @salto;

			IF @concurrencia IS NOT NULL
			BEGIN
				IF @concurrencia < 0
					SET @errores += N'- La concurrencia no puede ser negativa.' + @salto;
				ELSE IF @capacidad IS NOT NULL AND @concurrencia > @capacidad
					SET @errores += N'- La concurrencia (' + CAST(@concurrencia AS NVARCHAR(12))
					              + N') supera la capacidad de la sede (' + CAST(@capacidad AS NVARCHAR(12)) + N').' + @salto;
			END;

			-- Las validaciones sobre los goles necesitan ambas selecciones.
			IF @idLocal IS NOT NULL AND @idVisitante IS NOT NULL
			BEGIN
				SELECT @golesAjenos = COUNT(*)
				FROM eventos.Gol AS g
				WHERE g.IdPartido = @idPartido
				  AND NOT EXISTS (SELECT 1
				                  FROM jugadores.Convocatoria AS c
				                  WHERE c.IdJugador = g.IdJugadorAutor
				                    AND c.IdSeleccion IN (@idLocal, @idVisitante));

				IF @golesAjenos > 0
					SET @errores += N'- Hay ' + CAST(@golesAjenos AS NVARCHAR(12))
					              + N' gol(es) cuyo autor no está convocado en ninguna de las dos selecciones del partido.' + @salto;

				SELECT @golesLocal = r.GolesLocal, @golesVisitante = r.GolesVisitante,
				       @penalesLocal = r.PenalesLocal, @penalesVisitante = r.PenalesVisitante
				FROM eventos.fn_ResultadoPartido(@idPartido) AS r;

				SELECT @idGanador = d.IdGanador
				FROM nucleo.fn_DefinicionPartido(CAST(@idPartido AS SMALLINT)) AS d;

				-- Los penales son NULL cuando no hay tanda cargada.
				IF @esEliminatoria = 0
				BEGIN
					IF @penalesLocal IS NOT NULL
						SET @errores += N'- En fase de grupos no hay definición por penales.' + @salto;
				END
				ELSE
				BEGIN
					IF @penalesLocal IS NOT NULL AND @golesLocal <> @golesVisitante
						SET @errores += N'- Hay goles de la definición por penales pero el partido no terminó empatado.' + @salto;
					ELSE IF @idGanador IS NULL
					BEGIN
						IF @penalesLocal IS NULL
							SET @errores += N'- El partido de eliminación directa terminó empatado y no tiene definición por penales.' + @salto;
						ELSE
							SET @errores += N'- La definición por penales está igualada: falta cargar algún penal.' + @salto;
					END;
				END;
			END;
		END;

		IF LEN(@errores) > 0
		BEGIN
			SET @mensaje = LEFT(N'SP_FINALIZAR_PARTIDO - No se pudo finalizar el partido:' + @salto + @errores, 2048);
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

		-- La condición Estado = 'Programado' evita pisar un cierre hecho por otra sesión en el medio.
		UPDATE nucleo.Partido
		SET Estado = 'Finalizado',
		    Concurrencia = @concurrencia
		WHERE IdPartido = @idPartido
		  AND Estado = 'Programado';

		IF @@ROWCOUNT = 0
			THROW 52000, N'SP_FINALIZAR_PARTIDO - El partido ya fue finalizado por otra operación.', 1;

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
