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
	- Crear nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS: valida que la fase de grupos esté
	  completa y devuelve las posiciones, los clasificados y la fase con la que empieza la
	  eliminación directa.
	- Requiere ejecutados los scripts 01 a 26 (usa nucleo.fn_SeleccionesClasificadas,
	  nucleo.fn_FaseEliminatoriaInicial y nucleo.fn_ValidarFaseGruposCompleta del script 25).
	- Test correspondiente: testing/27_Test_SP_CalculoSeleccionesClasificadas.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS
-- Solo lectura: no escribe nada (los cruces eliminatorios no se persisten pre-cargados; se
-- validan al cargar cada partido con nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO, script 28).
-- Parámetros de salida (opcionales, para que otro SP o un test use el resultado sin leer los
-- result sets): @idFaseInicial, @totalClasificados y @avisoDesempate.
-- Validaciones (se informan todas juntas en un único mensaje). Las tres primeras las hace
-- nucleo.fn_ValidarFaseGruposCompleta (script 25), compartida con SP_DEFINIR_CRUCE_ELIMINATORIO:
--   - Hay partidos de 'Fase de grupos' cargados.
--   - Todos esos partidos están 'Finalizado' (se listan hasta 20 números de partido y "y N más").
--   - Cada selección tiene cargados todos sus partidos de grupo (n - 1, con n = tamaño de su grupo):
--     detecta partidos que nunca se cargaron (se listan hasta 20 selecciones).
--   - Existe la fila de nucleo.ReglaClasificacion.
--   - El total de clasificados que da la regla corresponde a una fase (32, 16 u 8).
-- Result sets (cuando todo está bien):
--   1. Posiciones de todas las selecciones (nucleo.fn_SeleccionesClasificadas), por grupo y puesto.
--   2. Solo los clasificados: primero los directos (por grupo y puesto) y después el cupo adicional
--      (los "mejores terceros"), en el orden del ranking.
--   3. Fase con la que empieza la eliminación directa (nucleo.fn_FaseEliminatoriaInicial).
--
-- AVISO DE DESEMPATE POR IdSeleccion
-- El desempate de grupos es: puntos, diferencia de gol, goles a favor e IdSeleccion (ver script 25).
-- El último criterio es arbitrario: lo asigna la base al crear la selección. Si el CORTE de
-- clasificación se decide por ese criterio, el SP informa un aviso (PRINT y @avisoDesempate), NO un
-- error: no cambia ningún resultado, pero en un torneo real ese empate se resolvería por sorteo o
-- fair play y conviene que el organizador lo note. Se avisa cuando dos selecciones empatan en puntos,
-- diferencia de gol y goles a favor justo en el corte:
--   - dentro de un grupo, entre el último puesto que clasifica directo y el siguiente;
--   - en el ranking del cupo adicional, entre la última selección que entra y la primera que no.
-- Los empates que no cambian quién clasifica (por ejemplo, entre dos selecciones que igual clasifican)
-- no se avisan.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS
	@idFaseInicial     TINYINT = NULL OUTPUT,
	@totalClasificados INT = NULL OUTPUT,
	@avisoDesempate    NVARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(MAX) = N'',
	        @mensaje NVARCHAR(2048),
	        @salto   NVARCHAR(2) = CHAR(13) + CHAR(10),
	        @hayRegla BIT = 0,
	        @clasificadosPorGrupo TINYINT,
	        @mejoresTerceros TINYINT,
	        @total INT,
	        @idFase TINYINT,
	        @avisoGrupos NVARCHAR(MAX),
	        @avisoAdicional NVARCHAR(MAX);

	SET @idFaseInicial = NULL;
	SET @totalClasificados = NULL;
	SET @avisoDesempate = NULL;

	BEGIN TRY
		-- ---- Validaciones ---------------------------------------------------
		-- Fase de grupos completa (partidos cargados y finalizados): la validación vive en
		-- nucleo.fn_ValidarFaseGruposCompleta (script 25), que también usa SP_DEFINIR_CRUCE_ELIMINATORIO.
		SET @errores += nucleo.fn_ValidarFaseGruposCompleta();

		SELECT @hayRegla = 1,
		       @clasificadosPorGrupo = rc.ClasificadosPorGrupo,
		       @mejoresTerceros = rc.MejoresTerceros
		FROM nucleo.ReglaClasificacion AS rc;

		IF @hayRegla = 0
			SET @errores += N'- No hay regla de clasificación cargada (nucleo.ReglaClasificacion).' + @salto;
		ELSE
		BEGIN
			SELECT @total = COUNT(*) FROM nucleo.fn_SeleccionesClasificadas() WHERE Clasifica = 1;
			SELECT @idFase = f.IdFase FROM nucleo.fn_FaseEliminatoriaInicial() AS f;

			IF @idFase IS NULL
				SET @errores += N'- El total de clasificados (' + CAST(@total AS NVARCHAR(12))
				              + N') no corresponde a ninguna fase de eliminación directa: debe ser 8, 16 o 32.' + @salto;
		END;

		IF LEN(@errores) > 0
		BEGIN
			SET @mensaje = LEFT(N'SP_CALCULO_DE_SELECCIONES_CLASIFICADAS - No se pudo calcular los clasificados:'
			                    + @salto + @errores, 2048);
			THROW 52000, @mensaje, 1;
		END;

		-- ---- Aviso de desempate por IdSeleccion en el corte ------------------
		-- Dentro de un grupo: el último puesto que clasifica directo empata con el siguiente.
		SELECT @avisoGrupos = STRING_AGG(CAST(N'grupo ' + a.Grupo + N' (' + a.CodigoFIFA + N' y ' + b.CodigoFIFA + N')' AS NVARCHAR(MAX)), N'; ')
		                      WITHIN GROUP (ORDER BY a.Grupo)
		FROM nucleo.fn_SeleccionesClasificadas() AS a
		INNER JOIN nucleo.fn_SeleccionesClasificadas() AS b
		        ON b.IdGrupo = a.IdGrupo AND b.Posicion = a.Posicion + 1
		       AND b.Pts = a.Pts AND b.DG = a.DG AND b.GF = a.GF
		WHERE a.Posicion = @clasificadosPorGrupo;

		-- En el ranking del cupo adicional: la última que entra empata con la primera que no.
		IF @mejoresTerceros > 0
		BEGIN
			WITH Candidatas AS (
				SELECT t.CodigoFIFA, t.Pts, t.DG, t.GF,
				       ROW_NUMBER() OVER (ORDER BY t.Pts DESC, t.DG DESC, t.GF DESC, t.IdSeleccion) AS Rk
				FROM nucleo.fn_SeleccionesClasificadas() AS t
				WHERE t.Posicion = @clasificadosPorGrupo + 1
			)
			SELECT @avisoAdicional = a.CodigoFIFA + N' y ' + b.CodigoFIFA
			FROM Candidatas AS a
			INNER JOIN Candidatas AS b
			        ON b.Rk = a.Rk + 1 AND b.Pts = a.Pts AND b.DG = a.DG AND b.GF = a.GF
			WHERE a.Rk = @mejoresTerceros;
		END;

		IF @avisoGrupos IS NOT NULL OR @avisoAdicional IS NOT NULL
		BEGIN
			SET @avisoDesempate = N'Aviso: el corte de clasificación se decidió por IdSeleccion (empate en puntos, '
			                    + N'diferencia de gol y goles a favor) en: '
			                    + ISNULL(@avisoGrupos, N'')
			                    + CASE WHEN @avisoGrupos IS NOT NULL AND @avisoAdicional IS NOT NULL THEN N'; ' ELSE N'' END
			                    + ISNULL(N'cupo adicional (' + @avisoAdicional + N')', N'')
			                    + N'.';
			PRINT @avisoDesempate;
		END;

		-- ---- Salida ----------------------------------------------------------
		SET @idFaseInicial = @idFase;
		SET @totalClasificados = @total;

		-- 1. Posiciones.
		SELECT c.IdGrupo, c.Grupo, c.IdSeleccion, c.CodigoFIFA, c.PJ, c.PG, c.PE, c.PP,
		       c.GF, c.GC, c.DG, c.Pts, c.Posicion, c.Clasifica, c.ClasificaComo
		FROM nucleo.fn_SeleccionesClasificadas() AS c
		ORDER BY c.Grupo, c.Posicion;

		-- 2. Clasificados: primero los directos y después el cupo adicional, en el orden del ranking.
		SELECT c.IdGrupo, c.Grupo, c.IdSeleccion, c.CodigoFIFA, c.Posicion, c.Pts, c.DG, c.GF, c.ClasificaComo
		FROM nucleo.fn_SeleccionesClasificadas() AS c
		WHERE c.Clasifica = 1
		ORDER BY CASE WHEN c.ClasificaComo = 'Directo' THEN 0 ELSE 1 END,
		         CASE WHEN c.ClasificaComo = 'Directo' THEN c.Grupo END,
		         CASE WHEN c.ClasificaComo = 'Directo' THEN c.Posicion END,
		         c.Pts DESC, c.DG DESC, c.GF DESC, c.IdSeleccion;

		-- 3. Fase con la que empieza la eliminación directa.
		SELECT f.IdFase, f.Nombre, f.TotalClasificados
		FROM nucleo.fn_FaseEliminatoriaInicial() AS f;
	END TRY
	BEGIN CATCH
		THROW;
	END CATCH;
END;
GO
