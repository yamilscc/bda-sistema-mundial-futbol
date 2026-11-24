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
	- Funciones y vista que derivan, a partir de los goles, la definición de cada partido y la
	  clasificación de la fase de grupos:
		  nucleo.fn_DefinicionPartido(@IdPartido)  -> ganador, perdedor y si se definió por penales.
		  nucleo.fn_SeleccionesClasificadas()      -> tabla de posiciones por grupo y clasificados.
		  nucleo.fn_FaseEliminatoriaInicial()      -> fase con la que empieza la eliminación directa.
		  nucleo.vw_PartidoResultado               -> partido + resultado + definición (reportes y BI).
	- Requiere ejecutados los scripts 01 a 24 (usa nucleo.ReglaClasificacion, jugadores.Convocatoria
	  y eventos.fn_ResultadoPartido).
	- Test correspondiente: testing/25_Test_Funciones_Partidos.sql.

DECISIONES DE DISEÑO (documentadas acá porque son reglas del grupo, no del reglamento oficial)

  1. 3FN: nucleo.Partido no guarda el resultado. Todo se obtiene de eventos.fn_ResultadoPartido
     (a partir de eventos.Gol). Estas funciones no leen goles, penales ni asistencia de Partido.
     Precondición: todo gol debe tener un autor convocado en una de las dos selecciones del partido
     (nucleo.SP_FINALIZAR_PARTIDO, script 26, lo valida antes de cerrar el partido).

  2. Cupo de clasificados (nucleo.ReglaClasificacion, una sola fila):
       ClasificadosPorGrupo = cuántas selecciones clasifican directo por grupo (puestos 1..N).
       MejoresTerceros      = cuántas selecciones más clasifican entre los grupos, tomadas del puesto
                              inmediatamente inferior a los directos (puesto ClasificadosPorGrupo + 1).
     Con 2 por grupo ese puesto es el tercero (de ahí el nombre); con otro valor de ClasificadosPorGrupo
     es el puesto siguiente (con 1 por grupo, los "mejores segundos"). ClasificaComo = 'Mejor tercero'
     identifica a esas selecciones del cupo adicional, sea cual sea ese puesto.
     Presets: (2, 0) = modalidad de 8 grupos de 4 equipos (Catar 2022, por ejemplo): 16 clasificados.
              (2, 8) = modalidad de 12 grupos de 4 equipos (Mundial 2026, por ejemplo): 32 clasificados.
     Limitación: el ranking de mejores terceros compara selecciones de grupos distintos con los mismos
     criterios; no normaliza grupos de distinto tamaño (todos los presets usan grupos de 4).

  3. Desempate dentro del grupo (y entre los mejores terceros): puntos, diferencia de gol,
     goles a favor e IdSeleccion (menor primero). El último criterio hace el orden determinístico.
     No se usan fair play ni sorteo.

  4. Fase de grupos: 3 puntos por victoria, 1 por empate. La tanda de penales no cuenta en grupos:
     fn_DefinicionPartido la ignora en partidos de grupos (el resultado queda como empate).

  5. Fase inicial de la eliminación directa: se deduce del total de clasificados reales:
     32 -> 'Dieciseisavos de final', 16 -> 'Octavos de final', 8 -> 'Cuartos de final'.
     Cualquier otro total (incluida una regla inexistente) es inválido: la función devuelve 0 filas.
*/

USE MundialFutbol;
GO

/*
fn_DefinicionPartido
Devuelve UNA fila con el ganador y el perdedor del partido; 0 filas si el partido no existe, está
'Programado' o no tiene ambas selecciones definidas.
Criterios:
	- Gana la selección con más goles (DefinidoPorPenales = 0).
	- Con goles iguales en una fase eliminatoria, si hubo tanda con diferente cantidad de penales gana
	  quien convirtió más (DefinidoPorPenales = 1).
	- En cualquier otro caso (empate en fase de grupos, eliminatoria sin tanda o con tanda igualada)
	  IdGanador e IdPerdedor son NULL y DefinidoPorPenales = 0. Los dos últimos son datos inválidos
	  que nucleo.SP_FINALIZAR_PARTIDO impide.
*/
CREATE OR ALTER FUNCTION nucleo.fn_DefinicionPartido (@IdPartido SMALLINT)
RETURNS TABLE
AS
RETURN
(
	SELECT p.IdPartido,
	       CASE WHEN r.GolesLocal > r.GolesVisitante THEN p.IdSeleccionLocal
	            WHEN r.GolesLocal < r.GolesVisitante THEN p.IdSeleccionVisitante
	            WHEN f.EsEliminatoria = 1 AND r.PenalesLocal > r.PenalesVisitante THEN p.IdSeleccionLocal
	            WHEN f.EsEliminatoria = 1 AND r.PenalesLocal < r.PenalesVisitante THEN p.IdSeleccionVisitante
	       END AS IdGanador,
	       CASE WHEN r.GolesLocal > r.GolesVisitante THEN p.IdSeleccionVisitante
	            WHEN r.GolesLocal < r.GolesVisitante THEN p.IdSeleccionLocal
	            WHEN f.EsEliminatoria = 1 AND r.PenalesLocal > r.PenalesVisitante THEN p.IdSeleccionVisitante
	            WHEN f.EsEliminatoria = 1 AND r.PenalesLocal < r.PenalesVisitante THEN p.IdSeleccionLocal
	       END AS IdPerdedor,
	       CAST(CASE WHEN r.GolesLocal = r.GolesVisitante
	                  AND f.EsEliminatoria = 1
	                  AND r.PenalesLocal <> r.PenalesVisitante
	                 THEN 1 ELSE 0 END AS BIT) AS DefinidoPorPenales
	FROM nucleo.Partido AS p
	INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
	CROSS APPLY eventos.fn_ResultadoPartido(p.IdPartido) AS r
	WHERE p.IdPartido = @IdPartido
	  AND p.Estado = 'Finalizado'
	  AND p.IdSeleccionLocal IS NOT NULL
	  AND p.IdSeleccionVisitante IS NOT NULL
);
GO

/*
fn_SeleccionesClasificadas
Devuelve una fila por selección con su tabla de posiciones en el grupo y si clasifica.
Columnas:
	IdGrupo, Grupo, IdSeleccion, CodigoFIFA,
	PJ, PG, PE, PP, GF, GC, DG, Pts, Posicion (1 = primero del grupo),
	Clasifica (1 si clasifica),
	ClasificaComo ('Directo', 'Mejor tercero' o NULL; ver decisión de diseño 2 del encabezado).
Criterios:
	- Solo cuentan los partidos 'Finalizado' de 'Fase de grupos' con ambas selecciones.
	- Una selección sin partidos jugados aparece con todo en cero.
	- Si nucleo.ReglaClasificacion no tiene fila, devuelve igual las posiciones con Clasifica = 0.
	- Es provisoria mientras queden partidos de grupos sin finalizar (SP_CALCULO_DE_SELECCIONES_CLASIFICADAS,
	  script 27, exige la fase completa).
	- Recorre todas las selecciones de la base; para acotar a un grupo, filtrar por IdGrupo.
*/
CREATE OR ALTER FUNCTION nucleo.fn_SeleccionesClasificadas ()
RETURNS TABLE
AS
RETURN
(
	WITH PartidosGrupos AS (
		SELECT p.IdSeleccionLocal, p.IdSeleccionVisitante, r.GolesLocal, r.GolesVisitante
		FROM nucleo.Partido AS p
		INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase AND f.Nombre = 'Fase de grupos'
		CROSS APPLY eventos.fn_ResultadoPartido(p.IdPartido) AS r
		WHERE p.Estado = 'Finalizado'
		  AND p.IdSeleccionLocal IS NOT NULL
		  AND p.IdSeleccionVisitante IS NOT NULL
	),
	FilasPorSeleccion AS (
		SELECT IdSeleccionLocal AS IdSeleccion, GolesLocal AS GF, GolesVisitante AS GC
		FROM PartidosGrupos
		UNION ALL
		SELECT IdSeleccionVisitante, GolesVisitante, GolesLocal
		FROM PartidosGrupos
	),
	Acumulado AS (
		SELECT s.IdGrupo, s.IdSeleccion, s.CodigoFIFA,
		       COUNT(fs.IdSeleccion) AS PJ,
		       ISNULL(SUM(CASE WHEN fs.GF > fs.GC THEN 1 ELSE 0 END), 0) AS PG,
		       ISNULL(SUM(CASE WHEN fs.GF = fs.GC THEN 1 ELSE 0 END), 0) AS PE,
		       ISNULL(SUM(CASE WHEN fs.GF < fs.GC THEN 1 ELSE 0 END), 0) AS PP,
		       ISNULL(SUM(fs.GF), 0) AS GF,
		       ISNULL(SUM(fs.GC), 0) AS GC
		FROM nucleo.Seleccion AS s
		LEFT JOIN FilasPorSeleccion AS fs ON fs.IdSeleccion = s.IdSeleccion
		GROUP BY s.IdGrupo, s.IdSeleccion, s.CodigoFIFA
	),
	Calculo AS (
		SELECT a.*, a.GF - a.GC AS DG, a.PG * 3 + a.PE AS Pts
		FROM Acumulado AS a
	),
	Posiciones AS (
		SELECT c.*,
		       ROW_NUMBER() OVER (PARTITION BY c.IdGrupo
		                          ORDER BY c.Pts DESC, c.DG DESC, c.GF DESC, c.IdSeleccion) AS Posicion
		FROM Calculo AS c
	),
	CupoAdicional AS (
		-- Selecciones del puesto ClasificadosPorGrupo + 1 de cada grupo, rankeadas entre grupos.
		SELECT po.IdSeleccion,
		       ROW_NUMBER() OVER (ORDER BY po.Pts DESC, po.DG DESC, po.GF DESC, po.IdSeleccion) AS RankAdicional
		FROM Posiciones AS po
		INNER JOIN nucleo.ReglaClasificacion AS rc ON po.Posicion = rc.ClasificadosPorGrupo + 1
	)
	SELECT po.IdGrupo,
	       g.Nombre AS Grupo,
	       po.IdSeleccion,
	       po.CodigoFIFA,
	       po.PJ, po.PG, po.PE, po.PP, po.GF, po.GC, po.DG, po.Pts, po.Posicion,
	       CAST(CASE WHEN cl.ClasificaComo IS NULL THEN 0 ELSE 1 END AS BIT) AS Clasifica,
	       cl.ClasificaComo
	FROM Posiciones AS po
	INNER JOIN nucleo.Grupo AS g ON g.IdGrupo = po.IdGrupo
	OUTER APPLY (
		SELECT CAST(CASE WHEN po.Posicion <= rc.ClasificadosPorGrupo THEN 'Directo'
		                 WHEN ca.RankAdicional <= rc.MejoresTerceros THEN 'Mejor tercero'
		            END AS VARCHAR(13)) AS ClasificaComo
		FROM nucleo.ReglaClasificacion AS rc
		LEFT JOIN CupoAdicional AS ca ON ca.IdSeleccion = po.IdSeleccion
	) AS cl
);
GO

/*
fn_FaseEliminatoriaInicial
Devuelve UNA fila con la fase con la que empieza la eliminación directa, deducida del total de
selecciones clasificadas (32 -> Dieciseisavos, 16 -> Octavos, 8 -> Cuartos); 0 filas si el total no
corresponde a ninguna fase. Cuenta los clasificados definidos por el cupo (no depende de los
resultados), por lo que se puede consultar antes de que termine la fase de grupos.
*/
CREATE OR ALTER FUNCTION nucleo.fn_FaseEliminatoriaInicial ()
RETURNS TABLE
AS
RETURN
(
	SELECT f.IdFase, f.Nombre, t.TotalClasificados
	FROM (
		SELECT CAST(COUNT(*) AS INT) AS TotalClasificados
		FROM nucleo.fn_SeleccionesClasificadas()
		WHERE Clasifica = 1
	) AS t
	INNER JOIN nucleo.Fase AS f
	        ON f.Nombre = CASE t.TotalClasificados
	                           WHEN 32 THEN 'Dieciseisavos de final'
	                           WHEN 16 THEN 'Octavos de final'
	                           WHEN 8  THEN 'Cuartos de final'
	                      END
);
GO

/*
vw_PartidoResultado
Camino de lectura del resultado para reportes y BI: el partido con su resultado (derivado de los goles)
y su definición. Los goles y penales son NULL mientras el partido está 'Programado' (sin ese filtro
eventos.fn_ResultadoPartido devolvería un 0 a 0 que parece un resultado).
*/
CREATE OR ALTER VIEW nucleo.vw_PartidoResultado
AS
SELECT p.IdPartido,
       p.NumeroPartido,
       p.FechaHoraUTC,
       p.Estado,
       p.Concurrencia,
       p.IdFase,
       p.IdSede,
       p.IdSeleccionLocal,
       p.IdSeleccionVisitante,
       CASE WHEN p.Estado = 'Finalizado' THEN r.GolesLocal END       AS GolesLocal,
       CASE WHEN p.Estado = 'Finalizado' THEN r.GolesVisitante END   AS GolesVisitante,
       CASE WHEN p.Estado = 'Finalizado' THEN r.PenalesLocal END     AS PenalesLocal,
       CASE WHEN p.Estado = 'Finalizado' THEN r.PenalesVisitante END AS PenalesVisitante,
       d.IdGanador,
       d.IdPerdedor,
       d.DefinidoPorPenales
FROM nucleo.Partido AS p
OUTER APPLY eventos.fn_ResultadoPartido(p.IdPartido) AS r
OUTER APPLY nucleo.fn_DefinicionPartido(p.IdPartido) AS d;
GO
