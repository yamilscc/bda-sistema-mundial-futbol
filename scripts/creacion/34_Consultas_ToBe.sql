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
	- Completar las consultas del alcance "To BE" que no estaban cubiertas (Entrega 9) y
	  exponer los datos para la plataforma de BI. Todos los objetos son de solo lectura:
		  nucleo.vw_Fixture                         -> fixture completo (hora UTC y local de la sede, resultado).
		  nucleo.SP_CONSULTAR_FIXTURE               -> fixture filtrado por sede, fase, selección y fechas.
		  eventos.vw_Goleadores                     -> tabla de goleadores del torneo y por selección.
		  jugadores.vw_HistorialTitularidad         -> historial de titularidad de cada jugador.
		  eventos.vw_TarjetasPorSancionado          -> tarjetas por selección y sancionado, con suspensión activa.
		  nucleo.vw_HistorialArbitral               -> partidos dirigidos por cada árbitro, tarjetas y sanciones.
		  publicidad.vw_EspaciosPublicitariosUSD    -> espacios exhibidos con la tarifa convertida a USD.
		  publicidad.vw_OcupacionPublicitariaSede   -> ocupación e ingresos publicitarios por sede.
		  nucleo.vw_SedesMapa                       -> sedes con latitud y longitud (mapa del BI).
		  publicidad.vw_MercadosPrimeTimePorPartido -> mercados en prime time de cada partido.
	- 3FN: ningún objeto guarda ni recalcula el resultado de un partido; se lee de
	  nucleo.vw_PartidoResultado (script 25), que a su vez usa eventos.fn_ResultadoPartido.
	- Requiere ejecutados los scripts 01 a 28.
	- Test correspondiente: testing/34_Test_Consultas_ToBe.sql.
*/

USE MundialFutbol;
GO

/*
nucleo.vw_Fixture
Propósito: fixture completo del torneo, una fila por partido (To BE, punto A).
Columnas:
	IdPartido, NumeroPartido, IdFase, Fase, OrdenFase,
	FechaHoraUTC, FechaHoraLocalSede (hora local de la sede), FechaLocalSede (fecha local de la sede),
	IdSede, Estadio, Ciudad, PaisSede, HusoHorario,
	IdSeleccionLocal, SeleccionLocal (CodigoFIFA o 'A definir'), PaisLocal,
	IdSeleccionVisitante, SeleccionVisitante (CodigoFIFA o 'A definir'), PaisVisitante,
	Estado, Concurrencia,
	GolesLocal, GolesVisitante, PenalesLocal, PenalesVisitante, IdGanador, Ganador, DefinidoPorPenales.
Criterios:
	- La hora local sale de FechaHoraUTC convertida al huso de la ciudad de la sede (Ciudad.HusoHorario),
	  con el mismo mecanismo que nucleo.fn_MercadosEnPrimeTime (script 07).
	- El resultado se lee de nucleo.vw_PartidoResultado: es NULL mientras el partido está 'Programado'.
	- Un cruce eliminatorio sin definir muestra 'A definir' en la selección y NULL en el país.
*/
CREATE OR ALTER VIEW nucleo.vw_Fixture
AS
SELECT pr.IdPartido,
       pr.NumeroPartido,
       f.IdFase,
       f.Nombre AS Fase,
       f.Orden  AS OrdenFase,
       pr.FechaHoraUTC,
       hl.FechaHoraLocalSede,
       CAST(hl.FechaHoraLocalSede AS DATE) AS FechaLocalSede,
       s.IdSede,
       s.NombreEstadio AS Estadio,
       c.Nombre        AS Ciudad,
       ps.Nombre       AS PaisSede,
       c.HusoHorario,
       pr.IdSeleccionLocal,
       COALESCE(CAST(sl.CodigoFIFA AS VARCHAR(9)), 'A definir') AS SeleccionLocal,
       pl.Nombre AS PaisLocal,
       pr.IdSeleccionVisitante,
       COALESCE(CAST(sv.CodigoFIFA AS VARCHAR(9)), 'A definir') AS SeleccionVisitante,
       pv.Nombre AS PaisVisitante,
       pr.Estado,
       pr.Concurrencia,
       pr.GolesLocal,
       pr.GolesVisitante,
       pr.PenalesLocal,
       pr.PenalesVisitante,
       pr.IdGanador,
       CAST(sg.CodigoFIFA AS VARCHAR(9)) AS Ganador,
       pr.DefinidoPorPenales
FROM nucleo.vw_PartidoResultado AS pr
INNER JOIN nucleo.Fase   AS f  ON f.IdFase   = pr.IdFase
INNER JOIN nucleo.Sede   AS s  ON s.IdSede   = pr.IdSede
INNER JOIN nucleo.Ciudad AS c  ON c.IdCiudad = s.IdCiudad
INNER JOIN nucleo.Pais   AS ps ON ps.IdPais  = c.IdPais
LEFT JOIN nucleo.Seleccion AS sl ON sl.IdSeleccion = pr.IdSeleccionLocal
LEFT JOIN nucleo.Pais      AS pl ON pl.IdPais      = sl.IdPais
LEFT JOIN nucleo.Seleccion AS sv ON sv.IdSeleccion = pr.IdSeleccionVisitante
LEFT JOIN nucleo.Pais      AS pv ON pv.IdPais      = sv.IdPais
LEFT JOIN nucleo.Seleccion AS sg ON sg.IdSeleccion = pr.IdGanador
CROSS APPLY (SELECT CAST((pr.FechaHoraUTC AT TIME ZONE 'UTC') AT TIME ZONE c.HusoHorario AS DATETIME2(0))
                    AS FechaHoraLocalSede) AS hl;
GO

/*
nucleo.SP_CONSULTAR_FIXTURE
Propósito: consultar el fixture filtrado por sede, fase, selección o fecha (To BE, punto A).
Parámetros (todos opcionales; NULL = sin filtro):
	@idSede      -> sede del partido.
	@idFase      -> fase del partido.
	@idSeleccion -> selección que juega el partido, como local o como visitante.
	@fechaDesde, @fechaHasta -> rango inclusivo sobre la FECHA LOCAL DE LA SEDE (la que figura en un
	                            fixture publicado); un partido a las 01:00 UTC en una sede de UTC-3 se
	                            juega el día anterior y se filtra por ese día.
Devuelve: las columnas de nucleo.vw_Fixture, ordenadas por FechaHoraUTC y NumeroPartido.
          Si ningún partido cumple los filtros, devuelve 0 filas (no es un error).
Validaciones (un único mensaje consolidado, THROW 52000):
	- La sede, la fase y la selección, si se informan, deben existir.
	- La fecha desde no puede ser posterior a la fecha hasta.
Los ids son INT (misma convención que el script 09): un valor fuera de rango se informa en el mensaje.
No usa transacción porque no escribe.
*/
CREATE OR ALTER PROCEDURE nucleo.SP_CONSULTAR_FIXTURE
	@idSede      INT  = NULL,
	@idFase      INT  = NULL,
	@idSeleccion INT  = NULL,
	@fechaDesde  DATE = NULL,
	@fechaHasta  DATE = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(MAX) = N'',
	        @mensaje NVARCHAR(2048),
	        @salto   NVARCHAR(2) = CHAR(13) + CHAR(10);

	BEGIN TRY
		IF @idSede IS NOT NULL AND NOT EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @idSede)
			SET @errores += N'- La sede indicada no existe.' + @salto;

		IF @idFase IS NOT NULL AND NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE IdFase = @idFase)
			SET @errores += N'- La fase indicada no existe.' + @salto;

		IF @idSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccion)
			SET @errores += N'- La selección indicada no existe.' + @salto;

		IF @fechaDesde IS NOT NULL AND @fechaHasta IS NOT NULL AND @fechaDesde > @fechaHasta
			SET @errores += N'- La fecha desde no puede ser posterior a la fecha hasta.' + @salto;

		IF LEN(@errores) > 0
		BEGIN
			SET @mensaje = LEFT(N'SP_CONSULTAR_FIXTURE - No se pudo completar la consulta:' + @salto + @errores, 2048);
			THROW 52000, @mensaje, 1;
		END;

		SELECT fx.IdPartido, fx.NumeroPartido, fx.IdFase, fx.Fase, fx.OrdenFase,
		       fx.FechaHoraUTC, fx.FechaHoraLocalSede, fx.FechaLocalSede,
		       fx.IdSede, fx.Estadio, fx.Ciudad, fx.PaisSede, fx.HusoHorario,
		       fx.IdSeleccionLocal, fx.SeleccionLocal, fx.PaisLocal,
		       fx.IdSeleccionVisitante, fx.SeleccionVisitante, fx.PaisVisitante,
		       fx.Estado, fx.Concurrencia,
		       fx.GolesLocal, fx.GolesVisitante, fx.PenalesLocal, fx.PenalesVisitante,
		       fx.IdGanador, fx.Ganador, fx.DefinidoPorPenales
		FROM nucleo.vw_Fixture AS fx
		WHERE (@idSede      IS NULL OR fx.IdSede = @idSede)
		  AND (@idFase      IS NULL OR fx.IdFase = @idFase)
		  AND (@idSeleccion IS NULL OR @idSeleccion IN (fx.IdSeleccionLocal, fx.IdSeleccionVisitante))
		  AND (@fechaDesde  IS NULL OR fx.FechaLocalSede >= @fechaDesde)
		  AND (@fechaHasta  IS NULL OR fx.FechaLocalSede <= @fechaHasta)
		ORDER BY fx.FechaHoraUTC, fx.NumeroPartido
		OPTION (RECOMPILE); -- filtros opcionales: un plan por combinación de parámetros
	END TRY
	BEGIN CATCH
		THROW;
	END CATCH;
END;
GO

/*
eventos.vw_Goleadores
Propósito: tabla de goleadores del torneo y por selección (To BE, puntos E y J).
Columnas (una fila por jugador con al menos un gol):
	IdJugador, Jugador ('Apellido, Nombre'), IdSeleccion, Seleccion (CodigoFIFA), PaisSeleccion,
	Goles, GolesDePenal (penales en juego, incluidos en Goles), Asistencias,
	PosicionTorneo    -> DENSE_RANK por goles entre todos los goleadores.
	PosicionSeleccion -> DENSE_RANK por goles dentro de su selección.
Criterios:
	- No cuentan los goles 'En contra' (suman al rival en el resultado, pero no al autor) ni los del
	  período 'Definicion por Penales' (la tanda no es parte del resultado del partido).
	- Solo cuentan los partidos 'Finalizado', igual que nucleo.vw_PartidoResultado.
	- La selección del jugador sale de jugadores.Convocatoria, igual que en eventos.fn_ResultadoPartido.
	- Asistencias: goles válidos (mismos criterios) en los que el jugador figura como IdJugadorAsistencia.
	- Para el ranking por selección se filtra por IdSeleccion o Seleccion.
*/
CREATE OR ALTER VIEW eventos.vw_Goleadores
AS
WITH GolesValidos AS (
	SELECT g.IdJugadorAutor,
	       g.IdJugadorAsistencia,
	       tg.Descripcion AS TipoGol
	FROM eventos.Gol AS g
	INNER JOIN nucleo.Partido  AS p  ON p.IdPartido  = g.IdPartido AND p.Estado = 'Finalizado'
	INNER JOIN eventos.TipoGol AS tg ON tg.IdTipoGol = g.IdTipoGol
	INNER JOIN eventos.Periodo AS pe ON pe.IdPeriodo = g.IdPeriodo
	WHERE tg.Descripcion <> 'En contra'
	  AND pe.Descripcion <> 'Definicion por Penales'
),
GolesPorJugador AS (
	SELECT IdJugadorAutor AS IdJugador,
	       COUNT(*) AS Goles,
	       SUM(CASE WHEN TipoGol = 'Penal' THEN 1 ELSE 0 END) AS GolesDePenal
	FROM GolesValidos
	GROUP BY IdJugadorAutor
),
AsistenciasPorJugador AS (
	SELECT IdJugadorAsistencia AS IdJugador,
	       COUNT(*) AS Asistencias
	FROM GolesValidos
	WHERE IdJugadorAsistencia IS NOT NULL
	GROUP BY IdJugadorAsistencia
)
SELECT j.IdJugador,
       j.Apellido + ', ' + j.Nombre AS Jugador,
       s.IdSeleccion,
       s.CodigoFIFA AS Seleccion,
       pa.Nombre    AS PaisSeleccion,
       gj.Goles,
       gj.GolesDePenal,
       ISNULL(aj.Asistencias, 0) AS Asistencias,
       DENSE_RANK() OVER (ORDER BY gj.Goles DESC) AS PosicionTorneo,
       DENSE_RANK() OVER (PARTITION BY s.IdSeleccion ORDER BY gj.Goles DESC) AS PosicionSeleccion
FROM GolesPorJugador AS gj
INNER JOIN jugadores.Jugador      AS j  ON j.IdJugador   = gj.IdJugador
INNER JOIN jugadores.Convocatoria AS c  ON c.IdJugador   = j.IdJugador
INNER JOIN nucleo.Seleccion       AS s  ON s.IdSeleccion = c.IdSeleccion
INNER JOIN nucleo.Pais            AS pa ON pa.IdPais     = s.IdPais
LEFT JOIN AsistenciasPorJugador   AS aj ON aj.IdJugador  = gj.IdJugador;
GO

/*
jugadores.vw_HistorialTitularidad
Propósito: historial de titularidad de cada jugador a lo largo del torneo (To BE, punto C).
Columnas (una fila por jugador y partido en el que figura en una formación):
	IdJugador, Jugador, IdSeleccion, Seleccion, IdPartido, NumeroPartido, FechaHoraUTC, Fase, Estado,
	Rival (CodigoFIFA del rival), Localia, EsquemaTactico, EstadoTitularidad ('Titular' / 'Suplente'),
	PosicionEnCampo, Dorsal,
	MinutoIngreso -> minuto en que entró por una sustitución (NULL si no entró desde el banco).
	MinutoSalida  -> minuto en que salió por una sustitución (NULL si no salió reemplazado).
	Jugo          -> 1 si fue titular o ingresó desde el banco.
Criterios:
	- La selección es la de la formación (Localia), igual que jugadores.fn_JugadoresEnCancha.
	- Un jugador entra y sale a lo sumo una vez por partido (UQ_Sustitucion_Entrante / _Saliente).
	- Los totales por jugador (partidos como titular, como suplente, etc.) se obtienen agrupando.
*/
CREATE OR ALTER VIEW jugadores.vw_HistorialTitularidad
AS
SELECT fj.IdJugador,
       j.Apellido + ', ' + j.Nombre AS Jugador,
       sel.IdSeleccion,
       sel.CodigoFIFA AS Seleccion,
       p.IdPartido,
       p.NumeroPartido,
       p.FechaHoraUTC,
       fa.Nombre AS Fase,
       p.Estado,
       riv.CodigoFIFA AS Rival,
       f.Localia,
       f.EsquemaTactico,
       fj.EstadoTitularidad,
       fj.PosicionEnCampo,
       fj.Dorsal,
       sIn.Minuto  AS MinutoIngreso,
       sOut.Minuto AS MinutoSalida,
       CAST(CASE WHEN fj.EstadoTitularidad = 'Titular' OR sIn.IdSustitucion IS NOT NULL
                 THEN 1 ELSE 0 END AS BIT) AS Jugo
FROM jugadores.FormacionJugador AS fj
INNER JOIN jugadores.Formacion AS f  ON f.IdFormacion = fj.IdFormacion
INNER JOIN nucleo.Partido      AS p  ON p.IdPartido   = f.IdPartido
INNER JOIN nucleo.Fase         AS fa ON fa.IdFase     = p.IdFase
INNER JOIN jugadores.Jugador   AS j  ON j.IdJugador   = fj.IdJugador
LEFT JOIN nucleo.Seleccion AS sel
       ON sel.IdSeleccion = CASE WHEN f.Localia = 'Local' THEN p.IdSeleccionLocal ELSE p.IdSeleccionVisitante END
LEFT JOIN nucleo.Seleccion AS riv
       ON riv.IdSeleccion = CASE WHEN f.Localia = 'Local' THEN p.IdSeleccionVisitante ELSE p.IdSeleccionLocal END
LEFT JOIN jugadores.Sustitucion AS sIn
       ON sIn.IdPartido = p.IdPartido AND sIn.IdJugadorEntrante = fj.IdJugador
LEFT JOIN jugadores.Sustitucion AS sOut
       ON sOut.IdPartido = p.IdPartido AND sOut.IdJugadorSaliente = fj.IdJugador;
GO

/*
eventos.vw_TarjetasPorSancionado
Propósito: tarjetas (amarillas y rojas) por selección y por sancionado, con indicación de suspensión
           activa (To BE, puntos F y J).
Columnas (una fila por jugador o miembro del staff técnico con al menos una tarjeta):
	TipoSancionado ('Jugador' o 'Staff técnico'), IdJugador, IdStaffTecnico, Sancionado (nombre),
	IdSeleccion, Seleccion (CodigoFIFA),
	Amarillas, RojasDobleAmarilla, RojasDirectas,
	PartidosSuspensionTotal -> suma de eventos.Amonestacion.PartidosSuspension.
	PartidosPendientes      -> partidos de suspensión que todavía no cumplió (el mayor entre sus sanciones).
	SuspensionActiva        -> 1 si PartidosPendientes > 0.
Criterios:
	- La selección del jugador sale de jugadores.Convocatoria; la del staff, de nucleo.StaffTecnico.
	- Una sanción se cumple con los partidos 'Finalizado' de su selección posteriores (por FechaHoraUTC)
	  al partido de la tarjeta: mismo conteo que eventos.fn_EstaSuspendido (script 10). Las sanciones
	  se cumplen en paralelo, por eso PartidosPendientes toma el máximo y no la suma.
	- Para "tarjetas por selección" se agrupa por IdSeleccion / Seleccion.
*/
CREATE OR ALTER VIEW eventos.vw_TarjetasPorSancionado
AS
WITH Tarjetas AS (
	SELECT a.IdJugador,
	       a.IdStaffTecnico,
	       a.PartidosSuspension,
	       t.Tipo,
	       CASE WHEN a.IdJugador IS NOT NULL THEN c.IdSeleccion ELSE st.IdSeleccion END AS IdSeleccion,
	       p.FechaHoraUTC
	FROM eventos.Amonestacion AS a
	INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
	INNER JOIN nucleo.Partido  AS p ON p.IdPartido = a.IdPartido
	LEFT JOIN jugadores.Convocatoria AS c  ON c.IdJugador       = a.IdJugador
	LEFT JOIN nucleo.StaffTecnico    AS st ON st.IdStaffTecnico = a.IdStaffTecnico
),
ConPendientes AS (
	SELECT tj.IdJugador,
	       tj.IdStaffTecnico,
	       tj.IdSeleccion,
	       tj.Tipo,
	       tj.PartidosSuspension,
	       CASE WHEN tj.PartidosSuspension > cu.Cumplidos
	            THEN tj.PartidosSuspension - cu.Cumplidos ELSE 0 END AS PartidosPendientes
	FROM Tarjetas AS tj
	CROSS APPLY (SELECT COUNT(*) AS Cumplidos
	             FROM nucleo.Partido AS pm
	             WHERE tj.IdSeleccion IN (pm.IdSeleccionLocal, pm.IdSeleccionVisitante)
	               AND pm.Estado = 'Finalizado'
	               AND pm.FechaHoraUTC > tj.FechaHoraUTC) AS cu
),
Totales AS (
	SELECT IdJugador,
	       IdStaffTecnico,
	       IdSeleccion,
	       SUM(CASE WHEN Tipo = 'Amarilla'                THEN 1 ELSE 0 END) AS Amarillas,
	       SUM(CASE WHEN Tipo = 'Roja por doble amarilla' THEN 1 ELSE 0 END) AS RojasDobleAmarilla,
	       SUM(CASE WHEN Tipo = 'Roja directa'            THEN 1 ELSE 0 END) AS RojasDirectas,
	       SUM(PartidosSuspension) AS PartidosSuspensionTotal,
	       MAX(PartidosPendientes) AS PartidosPendientes
	FROM ConPendientes
	GROUP BY IdJugador, IdStaffTecnico, IdSeleccion
)
SELECT CAST(CASE WHEN tt.IdJugador IS NOT NULL THEN 'Jugador' ELSE 'Staff técnico' END AS VARCHAR(20)) AS TipoSancionado,
       tt.IdJugador,
       tt.IdStaffTecnico,
       CASE WHEN tt.IdJugador IS NOT NULL THEN j.Apellido + ', ' + j.Nombre ELSE st.NombreApellido END AS Sancionado,
       tt.IdSeleccion,
       s.CodigoFIFA AS Seleccion,
       tt.Amarillas,
       tt.RojasDobleAmarilla,
       tt.RojasDirectas,
       tt.PartidosSuspensionTotal,
       tt.PartidosPendientes,
       CAST(CASE WHEN tt.PartidosPendientes > 0 THEN 1 ELSE 0 END AS BIT) AS SuspensionActiva
FROM Totales AS tt
LEFT JOIN jugadores.Jugador   AS j  ON j.IdJugador       = tt.IdJugador
LEFT JOIN nucleo.StaffTecnico AS st ON st.IdStaffTecnico = tt.IdStaffTecnico
LEFT JOIN nucleo.Seleccion    AS s  ON s.IdSeleccion     = tt.IdSeleccion;
GO

/*
nucleo.vw_HistorialArbitral
Propósito: historial de partidos arbitrados por cada árbitro, con las tarjetas del partido y las
           sanciones o informes post-partido que recibió (To BE, punto G).
Columnas (una fila por designación):
	IdDesignacionArbitral, IdArbitro, Arbitro, PaisArbitro, Categoria,
	IdPartido, NumeroPartido, FechaHoraUTC, Fase, Estadio, SeleccionLocal, SeleccionVisitante, Estado,
	Rol ('Principal', 'Asistente 1', 'Asistente 2', 'Cuarto', 'VAR'),
	AmarillasDelPartido, RojasDelPartido (rojas directas y por doble amarilla),
	CantidadSanciones, Sanciones ('Tipo: Descripción (aaaa-mm-dd)' separadas por ' | '; NULL si no tiene).
Criterios:
	- Las tarjetas son las del partido (eventos.Amonestacion); las muestra el árbitro principal, pero
	  se informan en cada designación para que el historial de cualquier rol tenga el contexto.
	- Las sanciones son las de esa designación (nucleo.Sancion.IdDesignacionArbitral).
*/
CREATE OR ALTER VIEW nucleo.vw_HistorialArbitral
AS
SELECT d.IdDesignacionArbitral,
       a.IdArbitro,
       a.NombreApellido AS Arbitro,
       pa.Nombre        AS PaisArbitro,
       cat.Nombre       AS Categoria,
       p.IdPartido,
       p.NumeroPartido,
       p.FechaHoraUTC,
       fa.Nombre        AS Fase,
       se.NombreEstadio AS Estadio,
       COALESCE(CAST(sl.CodigoFIFA AS VARCHAR(9)), 'A definir') AS SeleccionLocal,
       COALESCE(CAST(sv.CodigoFIFA AS VARCHAR(9)), 'A definir') AS SeleccionVisitante,
       p.Estado,
       d.Rol,
       tp.AmarillasDelPartido,
       tp.RojasDelPartido,
       sa.CantidadSanciones,
       sa.Sanciones
FROM nucleo.DesignacionArbitral AS d
INNER JOIN nucleo.Arbitro   AS a   ON a.IdArbitro     = d.IdArbitro
INNER JOIN nucleo.Pais      AS pa  ON pa.IdPais       = a.IdPais
INNER JOIN nucleo.Categoria AS cat ON cat.IdCategoria = a.IdCategoria
INNER JOIN nucleo.Partido   AS p   ON p.IdPartido     = d.IdPartido
INNER JOIN nucleo.Fase      AS fa  ON fa.IdFase       = p.IdFase
INNER JOIN nucleo.Sede      AS se  ON se.IdSede       = p.IdSede
LEFT JOIN nucleo.Seleccion  AS sl  ON sl.IdSeleccion  = p.IdSeleccionLocal
LEFT JOIN nucleo.Seleccion  AS sv  ON sv.IdSeleccion  = p.IdSeleccionVisitante
CROSS APPLY (SELECT ISNULL(SUM(CASE WHEN t.Tipo = 'Amarilla' THEN 1 ELSE 0 END), 0) AS AmarillasDelPartido,
                    ISNULL(SUM(CASE WHEN t.Tipo <> 'Amarilla' THEN 1 ELSE 0 END), 0) AS RojasDelPartido
             FROM eventos.Amonestacion AS am
             INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = am.IdTarjeta
             WHERE am.IdPartido = p.IdPartido) AS tp
CROSS APPLY (SELECT COUNT(*) AS CantidadSanciones,
                    STRING_AGG(CAST(sn.Tipo + ': ' + sn.Descripcion + ' (' + CONVERT(CHAR(10), sn.Fecha, 120) + ')'
                                    AS NVARCHAR(MAX)), N' | ')
                        WITHIN GROUP (ORDER BY sn.Fecha, sn.IdSancion) AS Sanciones
             FROM nucleo.Sancion AS sn
             WHERE sn.IdDesignacionArbitral = d.IdDesignacionArbitral) AS sa;
GO

/*
publicidad.vw_EspaciosPublicitariosUSD
Propósito: registro de lo exhibido en cada partido (para facturar) con la tarifa convertida a USD
           (To BE, puntos H y J).
Columnas (una fila por espacio publicitario):
	IdPartido, NumeroPartido, FechaHoraUTC, Fase, IdSede, Estadio, Ciudad,
	NumeroEspacio, IdAnunciante, Anunciante, PaisAnunciante, IdCampania, Campania, IdPieza, Pieza,
	TarifaPublicitaria, Moneda (código ISO 4217),
	TarifaUSD       -> tarifa en USD (NULL si no hay cotización para la moneda).
	FechaCotizacion -> fecha de la cotización usada (NULL si la moneda es USD o no hay cotización).
Criterios:
	- El anunciante de la pieza se obtiene a través de su campaña (Anunciante 1-N Campania 1-N Pieza,
	  script 04).
	- Conversión con publicidad.CotizacionMoneda (1 MonedaBase = Tasa Moneda): tarifa / tasa(moneda)
	  * tasa(USD), ambas contra la misma base y fecha, tomando la última fecha que tenga las dos.
	  Es la misma regla que publicidad.SP_IMPORTAR_PAUTA_JSON (script 22).
	- Si la moneda es USD, la tarifa no se convierte.
	- Una moneda sin cotización (por ejemplo ARS, que Frankfurter no publica) deja TarifaUSD en NULL.
*/
CREATE OR ALTER VIEW publicidad.vw_EspaciosPublicitariosUSD
AS
SELECT e.IdPartido,
       p.NumeroPartido,
       p.FechaHoraUTC,
       fa.Nombre        AS Fase,
       se.IdSede,
       se.NombreEstadio AS Estadio,
       ci.Nombre        AS Ciudad,
       e.NumeroEspacio,
       an.IdAnunciante,
       an.Nombre        AS Anunciante,
       pan.Nombre       AS PaisAnunciante,
       ca.IdCampania,
       ca.Titulo        AS Campania,
       pz.IdPieza,
       pz.Titulo        AS Pieza,
       e.TarifaPublicitaria,
       m.Codigo         AS Moneda,
       CAST(CASE WHEN m.Codigo = 'USD' THEN e.TarifaPublicitaria
                 ELSE e.TarifaPublicitaria / co.TasaMoneda * co.TasaUSD
            END AS DECIMAL(14,2)) AS TarifaUSD,
       CASE WHEN m.Codigo = 'USD' THEN NULL ELSE co.Fecha END AS FechaCotizacion
FROM publicidad.EspacioPublicitario AS e
INNER JOIN publicidad.Moneda     AS m   ON m.IdMoneda      = e.IdMoneda
INNER JOIN publicidad.Pieza      AS pz  ON pz.IdPieza      = e.IdPieza
INNER JOIN publicidad.Campania   AS ca  ON ca.IdCampania   = pz.IdCampania
INNER JOIN publicidad.Anunciante AS an  ON an.IdAnunciante = ca.IdAnunciante
INNER JOIN nucleo.Pais           AS pan ON pan.IdPais      = an.IdPais
INNER JOIN nucleo.Partido        AS p   ON p.IdPartido     = e.IdPartido
INNER JOIN nucleo.Fase           AS fa  ON fa.IdFase       = p.IdFase
INNER JOIN nucleo.Sede           AS se  ON se.IdSede       = p.IdSede
INNER JOIN nucleo.Ciudad         AS ci  ON ci.IdCiudad     = se.IdCiudad
OUTER APPLY (SELECT TOP (1) o.Tasa AS TasaMoneda, d.Tasa AS TasaUSD, o.Fecha
             FROM publicidad.CotizacionMoneda AS o
             INNER JOIN publicidad.CotizacionMoneda AS d
                     ON d.MonedaBase = o.MonedaBase AND d.Fecha = o.Fecha
             WHERE o.Moneda = m.Codigo
               AND d.Moneda = 'USD'
             ORDER BY o.Fecha DESC, o.MonedaBase) AS co;
GO

/*
publicidad.vw_OcupacionPublicitariaSede
Propósito: ocupación publicitaria e ingresos estimados por sede (To BE, punto J).
Columnas (una fila por sede, tenga o no partidos):
	IdSede, Estadio, Ciudad, Pais,
	Partidos              -> partidos programados o jugados en la sede.
	EspaciosDisponibles   -> Partidos x 4 (cuatro espacios por partido).
	EspaciosOcupados      -> espacios con una pieza asignada.
	PorcentajeOcupacion   -> EspaciosOcupados / EspaciosDisponibles x 100 (0 si la sede no tiene partidos).
	IngresosUSD           -> suma de TarifaUSD de publicidad.vw_EspaciosPublicitariosUSD.
	EspaciosSinCotizacion -> espacios cuya tarifa no se pudo convertir (no suman a IngresosUSD).
Criterios: el detalle por partido es publicidad.vw_EspaciosPublicitariosUSD agrupada por IdPartido.
*/
CREATE OR ALTER VIEW publicidad.vw_OcupacionPublicitariaSede
AS
SELECT se.IdSede,
       se.NombreEstadio AS Estadio,
       ci.Nombre        AS Ciudad,
       pa.Nombre        AS Pais,
       pt.Partidos,
       pt.Partidos * 4  AS EspaciosDisponibles,
       es.EspaciosOcupados,
       CAST(CASE WHEN pt.Partidos = 0 THEN 0
                 ELSE 100.0 * es.EspaciosOcupados / (pt.Partidos * 4)
            END AS DECIMAL(5,2)) AS PorcentajeOcupacion,
       es.IngresosUSD,
       es.EspaciosSinCotizacion
FROM nucleo.Sede AS se
INNER JOIN nucleo.Ciudad AS ci ON ci.IdCiudad = se.IdCiudad
INNER JOIN nucleo.Pais   AS pa ON pa.IdPais   = ci.IdPais
CROSS APPLY (SELECT COUNT(*) AS Partidos
             FROM nucleo.Partido AS p
             WHERE p.IdSede = se.IdSede) AS pt
CROSS APPLY (SELECT COUNT(*) AS EspaciosOcupados,
                    CAST(ISNULL(SUM(v.TarifaUSD), 0) AS DECIMAL(16,2)) AS IngresosUSD,
                    ISNULL(SUM(CASE WHEN v.TarifaUSD IS NULL THEN 1 ELSE 0 END), 0) AS EspaciosSinCotizacion
             FROM publicidad.vw_EspaciosPublicitariosUSD AS v
             WHERE v.IdSede = se.IdSede) AS es;
GO

/*
nucleo.vw_SedesMapa
Propósito: sedes con su ubicación para el mapa de la plataforma de BI (Entrega 9).
Columnas (una fila por sede):
	IdSede, Estadio, Ciudad, Pais, CodigoISO2, Ubicacion ('Ciudad, País', para geocodificar si faltan
	las coordenadas), HusoHorario, Capacidad, Latitud, Longitud (NULL si no se cargaron),
	CantidadPartidos.
*/
CREATE OR ALTER VIEW nucleo.vw_SedesMapa
AS
SELECT se.IdSede,
       se.NombreEstadio AS Estadio,
       ci.Nombre        AS Ciudad,
       pa.Nombre        AS Pais,
       pa.CodigoISO2,
       CAST(ci.Nombre + ', ' + pa.Nombre AS VARCHAR(152)) AS Ubicacion,
       ci.HusoHorario,
       se.Capacidad,
       se.Latitud,
       se.Longitud,
       pt.CantidadPartidos
FROM nucleo.Sede AS se
INNER JOIN nucleo.Ciudad AS ci ON ci.IdCiudad = se.IdCiudad
INNER JOIN nucleo.Pais   AS pa ON pa.IdPais   = ci.IdPais
CROSS APPLY (SELECT COUNT(*) AS CantidadPartidos
             FROM nucleo.Partido AS p
             WHERE p.IdSede = se.IdSede) AS pt;
GO

/*
publicidad.vw_MercadosPrimeTimePorPartido
Propósito: para cada partido, los mercados (países) en los que su horario cae en prime time, para
           analizar el impacto del prime time en la pauta (To BE, puntos H y J).
Columnas (una fila por partido y país en prime time):
	IdPartido, NumeroPartido, FechaHoraUTC, Fase, IdPais, Pais, CodigoISO3, PBIPerCapitaUSD,
	HusoHorarioComercial, FechaHoraLocalMercado, EsPaisParticipante.
Criterios: reutiliza nucleo.fn_MercadosEnPrimeTime (script 07), que es la única fuente de la regla
           (19:00 a 23:00 hora local del mercado; feriados fuera de alcance).
*/
CREATE OR ALTER VIEW publicidad.vw_MercadosPrimeTimePorPartido
AS
SELECT p.IdPartido,
       p.NumeroPartido,
       p.FechaHoraUTC,
       fa.Nombre AS Fase,
       m.IdPais,
       m.Nombre  AS Pais,
       m.CodigoISO3,
       m.PBIPerCapitaUSD,
       m.HusoHorarioComercial,
       m.FechaHoraLocalMercado,
       m.EsPaisParticipante
FROM nucleo.Partido AS p
INNER JOIN nucleo.Fase AS fa ON fa.IdFase = p.IdFase
CROSS APPLY nucleo.fn_MercadosEnPrimeTime(p.IdPartido) AS m;
GO
