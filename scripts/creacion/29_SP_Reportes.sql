/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner
Fecha: 2026-11-22
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Crear los Stored Procedures correspondientes a los 7 reportes de la Entrega 7:
            1. eventos.SP_REPORTE_GOLEADORES
               (tabular: goleadores por selección, fase y torneo)
            2. eventos.SP_REPORTE_TARJETAS_SUSPENSIONES
               (tabular: tarjetas amarillas/rojas por selección y jugador, con detalle de
                suspensiones activas por acumulación)
            3. nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES
               (XML #1: partidos dirigidos/designados por cada árbitro, con las
                amonestaciones/expulsiones señaladas cuando actuó como Principal)
            4. publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA
               (tabular: ocupación de los 4 espacios publicitarios por sede y partido,
                anunciantes exhibidos e ingresos generados por moneda)
            5. publicidad.SP_REPORTE_MATRIZ_PRIME_TIME
               (tabular PIVOT estático: tabla cruzada de partidos vs. mercados/países
                en prime time, sin uso de SQL dinámico)
            6. jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS
               (XML #2: listado de selecciones con cuerpo técnico y vector anidado de
                convocados: nombre, posición, club y dorsal)
            7. nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS
               (tabular: cronograma completo de encuentros, horarios UTC/local de sede,
                marcadores reglamentarios y de penales, ganador, concurrencia y árbitro)

          Notas técnicas:
            - Todos los procedimientos están implementados íntegramente en T-SQL estático
              (sin SQL dinámico), respetando la pauta general de la cátedra.
            - Todos los reportes admiten parámetros opcionales de filtrado y devuelven
              resultados representativos aun con datos parciales.
          Requiere ejecutados los scripts 01 a 24.
          Test correspondiente: testing/25_Test_SP_Reportes.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. eventos.SP_REPORTE_GOLEADORES
-- Reporte de goleadores por selección, fase y torneo.
-- Criterios:
--   - Excluye goles de la tanda 'Definicion por Penales' (no computan como
--     goles de torneo, mismo criterio que eventos.fn_ResultadoPartido).
--   - Por defecto (@incluirEnContra = 0) excluye goles 'En contra' del ranking
--     de goleadores; si @incluirEnContra = 1, los muestra desglosados aparte
--     sin sumarlos al total de goles válidos del jugador.
--   - Los totales y puestos del torneo se calculan sobre todo el campeonato
--     antes de aplicar los filtros opcionales @codigoFIFA y @idFase.
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_REPORTE_GOLEADORES
    @codigoFIFA      CHAR(3) = NULL,
    @idFase          TINYINT = NULL,
    @incluirEnContra BIT     = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @codigoFIFA = UPPER(NULLIF(LTRIM(RTRIM(@codigoFIFA)), ''));

    WITH GolesPorJugadorYFase AS (
        SELECT
            s.IdSeleccion,
            s.CodigoFIFA,
            pais.Nombre                                                         AS Seleccion,
            f.IdFase,
            f.Nombre                                                            AS Fase,
            f.Orden                                                             AS OrdenFase,
            j.IdJugador,
            c.Dorsal,
            CONCAT(j.Nombre, ' ', j.Apellido)                                   AS Jugador,
            j.Posicion,
            SUM(CASE WHEN tg.Descripcion <> 'En contra' THEN 1 ELSE 0 END)      AS GolesEnFase,
            SUM(CASE WHEN tg.Descripcion = 'Jugada'     THEN 1 ELSE 0 END)      AS GolesJugada,
            SUM(CASE WHEN tg.Descripcion = 'Cabezazo'   THEN 1 ELSE 0 END)      AS GolesCabezazo,
            SUM(CASE WHEN tg.Descripcion = 'Penal'      THEN 1 ELSE 0 END)      AS GolesPenal,
            SUM(CASE WHEN tg.Descripcion = 'Tiro Libre' THEN 1 ELSE 0 END)      AS GolesTiroLibre,
            SUM(CASE WHEN tg.Descripcion = 'En contra'  THEN 1 ELSE 0 END)      AS GolesEnContra,
            ISNULL(asisFase.AsistenciasEnFase, 0)                               AS AsistenciasEnFase,
            ISNULL(asisTorneo.TotalAsistenciasTorneo, 0)                        AS TotalAsistenciasTorneo
        FROM eventos.Gol AS g
        INNER JOIN jugadores.Jugador AS j
            ON j.IdJugador = g.IdJugadorAutor
        INNER JOIN jugadores.Convocatoria AS c
            ON c.IdJugador = j.IdJugador
        INNER JOIN nucleo.Seleccion AS s
            ON s.IdSeleccion = c.IdSeleccion
        INNER JOIN nucleo.Pais AS pais
            ON pais.IdPais = s.IdPais
        INNER JOIN nucleo.Partido AS p
            ON p.IdPartido = g.IdPartido
        INNER JOIN nucleo.Fase AS f
            ON f.IdFase = p.IdFase
        INNER JOIN eventos.TipoGol AS tg
            ON tg.IdTipoGol = g.IdTipoGol
        INNER JOIN eventos.Periodo AS per
            ON per.IdPeriodo = g.IdPeriodo
        OUTER APPLY (
            SELECT COUNT(*) AS AsistenciasEnFase
            FROM eventos.Gol AS ga
            INNER JOIN nucleo.Partido AS pa
                ON pa.IdPartido = ga.IdPartido
            INNER JOIN eventos.Periodo AS pera
                ON pera.IdPeriodo = ga.IdPeriodo
            WHERE ga.IdJugadorAsistencia = j.IdJugador
              AND pa.IdFase = f.IdFase
              AND pera.Descripcion <> 'Definicion por Penales'
        ) AS asisFase
        OUTER APPLY (
            SELECT COUNT(*) AS TotalAsistenciasTorneo
            FROM eventos.Gol AS gt
            INNER JOIN eventos.Periodo AS pert
                ON pert.IdPeriodo = gt.IdPeriodo
            WHERE gt.IdJugadorAsistencia = j.IdJugador
              AND pert.Descripcion <> 'Definicion por Penales'
        ) AS asisTorneo
        WHERE per.Descripcion <> 'Definicion por Penales'
          AND (@incluirEnContra = 1 OR tg.Descripcion <> 'En contra')
        GROUP BY
            s.IdSeleccion,
            s.CodigoFIFA,
            pais.Nombre,
            f.IdFase,
            f.Nombre,
            f.Orden,
            j.IdJugador,
            c.Dorsal,
            j.Nombre,
            j.Apellido,
            j.Posicion,
            asisFase.AsistenciasEnFase,
            asisTorneo.TotalAsistenciasTorneo
    ),
    AcumuladosTorneo AS (
        SELECT
            *,
            SUM(GolesEnFase) OVER (PARTITION BY IdJugador)   AS TotalGolesJugadorTorneo,
            SUM(GolesEnFase) OVER (PARTITION BY IdSeleccion) AS TotalGolesSeleccionTorneo
        FROM GolesPorJugadorYFase
    ),
    RankingCalculado AS (
        SELECT
            DENSE_RANK() OVER (
                ORDER BY TotalGolesJugadorTorneo DESC,
                         TotalAsistenciasTorneo  DESC
            )                                                AS PuestoTorneo,
            DENSE_RANK() OVER (
                PARTITION BY IdSeleccion
                ORDER BY TotalGolesJugadorTorneo DESC,
                         TotalAsistenciasTorneo  DESC
            )                                                AS PuestoEnSeleccion,
            CodigoFIFA,
            Seleccion,
            Dorsal,
            Jugador,
            Posicion,
            IdFase,
            Fase,
            OrdenFase,
            GolesEnFase,
            GolesJugada,
            GolesCabezazo,
            GolesPenal,
            GolesTiroLibre,
            GolesEnContra,
            AsistenciasEnFase,
            TotalGolesJugadorTorneo,
            TotalAsistenciasTorneo,
            TotalGolesSeleccionTorneo
        FROM AcumuladosTorneo
    )
    SELECT
        PuestoTorneo,
        PuestoEnSeleccion,
        CodigoFIFA,
        Seleccion,
        Dorsal,
        Jugador,
        Posicion,
        Fase,
        GolesEnFase,
        GolesJugada,
        GolesCabezazo,
        GolesPenal,
        GolesTiroLibre,
        GolesEnContra,
        AsistenciasEnFase,
        TotalGolesJugadorTorneo,
        TotalAsistenciasTorneo,
        TotalGolesSeleccionTorneo
    FROM RankingCalculado
    WHERE (@codigoFIFA IS NULL OR CodigoFIFA = @codigoFIFA)
      AND (@idFase IS NULL OR IdFase = @idFase)
    ORDER BY
        PuestoTorneo ASC,
        TotalGolesJugadorTorneo DESC,
        Jugador ASC,
        OrdenFase ASC;
END;
GO

-- =========================================================================
-- 2. eventos.SP_REPORTE_TARJETAS_SUSPENSIONES
-- Reporte de tarjetas (amarillas y rojas) por selección y jugador, con
-- detalle de suspensiones activas por acumulación.
-- Criterios:
--   - Contabiliza tarjetas recibidas por cada jugador convocado (Amarilla,
--     Roja por doble amarilla y Roja directa).
--   - Una suspensión por acumulación ('Amarilla' con PartidosSuspension > 0)
--     está ACTIVA cuando PartidosSuspension supera la cantidad de partidos ya
--     finalizados por su selección con posterioridad al encuentro de la tarjeta
--     (consistente con eventos.fn_EstaSuspendido).
--   - Informa además el próximo partido programado que el jugador debe cumplir
--     de suspensión (verificado con eventos.fn_EstaSuspendido).
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_REPORTE_TARJETAS_SUSPENSIONES
    @codigoFIFA              CHAR(3) = NULL,
    @soloConSuspensionActiva BIT     = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @codigoFIFA = UPPER(NULLIF(LTRIM(RTRIM(@codigoFIFA)), ''));

    WITH AmonestacionesEvaluadas AS (
        SELECT
            s.IdSeleccion,
            s.CodigoFIFA,
            pais.Nombre                                                         AS Seleccion,
            j.IdJugador,
            c.Dorsal,
            CONCAT(j.Nombre, ' ', j.Apellido)                                   AS Jugador,
            t.Tipo                                                              AS TipoTarjeta,
            a.PartidosSuspension,
            CASE
                WHEN t.Tipo = 'Amarilla'
                     AND NOT EXISTS (
                         SELECT 1
                         FROM eventos.Amonestacion AS aDoble
                         INNER JOIN eventos.Tarjeta AS tDoble
                             ON tDoble.IdTarjeta = aDoble.IdTarjeta
                         WHERE aDoble.IdPartido = a.IdPartido
                           AND aDoble.IdJugador = a.IdJugador
                           AND tDoble.Tipo = 'Roja por doble amarilla'
                     )
                THEN 1
                ELSE 0
            END                                                                 AS EsAmarillaAcumulable,
            CASE
                WHEN t.Tipo = 'Amarilla'
                     AND a.PartidosSuspension > 0
                     AND a.PartidosSuspension > ISNULL(post.PartidosFinalizadosPost, 0)
                THEN a.PartidosSuspension - ISNULL(post.PartidosFinalizadosPost, 0)
                ELSE 0
            END                                                                 AS PartidosPendientesAcumulacion,
            CASE
                WHEN t.Tipo = 'Amarilla'
                     AND a.PartidosSuspension > 0
                     AND a.PartidosSuspension > ISNULL(post.PartidosFinalizadosPost, 0)
                THEN CONCAT(
                    'Partido #', p.NumeroPartido, ' (', f.Nombre, ', min ', a.Minuto, '): ',
                    a.PartidosSuspension - ISNULL(post.PartidosFinalizadosPost, 0),
                    ' fecha(s) pendiente(s) - Motivo: ', a.Motivo,
                    CASE
                        WHEN prox.NumeroPartido IS NOT NULL
                            THEN CONCAT(' [A cumplir en Partido #', prox.NumeroPartido, ' vs ', prox.Rival, ']')
                        ELSE ' [Sin próximo partido programado]'
                    END
                )
                ELSE NULL
            END                                                                 AS DetalleSuspensionActiva
        FROM eventos.Amonestacion AS a
        INNER JOIN eventos.Tarjeta AS t
            ON t.IdTarjeta = a.IdTarjeta
        INNER JOIN jugadores.Jugador AS j
            ON j.IdJugador = a.IdJugador
        INNER JOIN jugadores.Convocatoria AS c
            ON c.IdJugador = j.IdJugador
        INNER JOIN nucleo.Seleccion AS s
            ON s.IdSeleccion = c.IdSeleccion
        INNER JOIN nucleo.Pais AS pais
            ON pais.IdPais = s.IdPais
        INNER JOIN nucleo.Partido AS p
            ON p.IdPartido = a.IdPartido
        INNER JOIN nucleo.Fase AS f
            ON f.IdFase = p.IdFase
        OUTER APPLY (
            SELECT COUNT(*) AS PartidosFinalizadosPost
            FROM nucleo.Partido AS pPost
            WHERE pPost.Estado = 'Finalizado'
              AND pPost.FechaHoraUTC > p.FechaHoraUTC
              AND (pPost.IdSeleccionLocal = s.IdSeleccion
                   OR pPost.IdSeleccionVisitante = s.IdSeleccion)
        ) AS post
        OUTER APPLY (
            SELECT TOP (1)
                pNext.NumeroPartido,
                CASE
                    WHEN pNext.IdSeleccionLocal = s.IdSeleccion
                        THEN ISNULL(sVis.CodigoFIFA, 'TBD')
                    ELSE ISNULL(sLoc.CodigoFIFA, 'TBD')
                END AS Rival
            FROM nucleo.Partido AS pNext
            LEFT JOIN nucleo.Seleccion AS sLoc ON sLoc.IdSeleccion = pNext.IdSeleccionLocal
            LEFT JOIN nucleo.Seleccion AS sVis ON sVis.IdSeleccion = pNext.IdSeleccionVisitante
            WHERE pNext.Estado = 'Programado'
              AND pNext.FechaHoraUTC > p.FechaHoraUTC
              AND (pNext.IdSeleccionLocal = s.IdSeleccion
                   OR pNext.IdSeleccionVisitante = s.IdSeleccion)
              AND eventos.fn_EstaSuspendido(j.IdJugador, pNext.IdPartido) = 1
            ORDER BY pNext.FechaHoraUTC ASC
        ) AS prox
        WHERE a.IdJugador IS NOT NULL
          AND (@codigoFIFA IS NULL OR s.CodigoFIFA = @codigoFIFA)
    ),
    ResumenPorJugador AS (
        SELECT
            CodigoFIFA,
            Seleccion,
            IdJugador,
            Dorsal,
            Jugador,
            SUM(CASE WHEN TipoTarjeta = 'Amarilla' THEN 1 ELSE 0 END)                AS Amarillas,
            SUM(EsAmarillaAcumulable)                                                AS AmarillasAcumulables,
            SUM(CASE WHEN TipoTarjeta = 'Roja por doble amarilla' THEN 1 ELSE 0 END) AS RojasDobleAmarilla,
            SUM(CASE WHEN TipoTarjeta = 'Roja directa' THEN 1 ELSE 0 END)            AS RojasDirectas,
            COUNT(*)                                                                 AS TotalTarjetas,
            SUM(PartidosPendientesAcumulacion)                                       AS PartidosPendientesPorAcumulacion,
            ISNULL(
                STRING_AGG(DetalleSuspensionActiva, ' | '),
                'Sin suspensión activa por acumulación'
            )                                                                        AS DetalleSuspensionesAcumulacion
        FROM AmonestacionesEvaluadas
        GROUP BY
            CodigoFIFA,
            Seleccion,
            IdJugador,
            Dorsal,
            Jugador
    )
    SELECT
        CodigoFIFA,
        Seleccion,
        Dorsal,
        Jugador,
        Amarillas,
        AmarillasAcumulables,
        RojasDobleAmarilla,
        RojasDirectas,
        TotalTarjetas,
        CAST(CASE WHEN PartidosPendientesPorAcumulacion > 0 THEN 1 ELSE 0 END AS BIT) AS SuspensionActivaAcumulacion,
        PartidosPendientesPorAcumulacion,
        DetalleSuspensionesAcumulacion
    FROM ResumenPorJugador
    WHERE (@soloConSuspensionActiva = 0 OR PartidosPendientesPorAcumulacion > 0)
    ORDER BY
        SuspensionActivaAcumulacion DESC,
        TotalTarjetas DESC,
        Amarillas DESC,
        Seleccion ASC,
        Jugador ASC;
END;
GO

-- =========================================================================
-- 3. nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES (FORMATO XML #1)
-- Reporte de designaciones arbitrales: partidos dirigidos/designados por cada
-- árbitro, con el detalle de las amonestaciones y expulsiones señaladas
-- cuando actuó como árbitro Principal.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES
    @idArbitro SMALLINT = NULL,
    @idFase    TINYINT  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.IdArbitro                                                         AS [@IdArbitro],
        CASE a.EstaHabilitado WHEN 'Y' THEN 'Si' ELSE 'No' END              AS [@Habilitado],
        a.NombreApellido                                                    AS [NombreApellido],
        pais.Nombre                                                         AS [Pais/@Nombre],
        pais.CodigoISO3                                                     AS [Pais/@CodigoISO3],
        cat.Nombre                                                          AS [Categoria],
        ISNULL((
            SELECT STRING_AGG(i.Nombre, ', ') WITHIN GROUP (ORDER BY i.Nombre)
            FROM nucleo.ArbitroIdioma AS ai
            INNER JOIN nucleo.Idioma AS i ON i.IdIdioma = ai.IdIdioma
            WHERE ai.IdArbitro = a.IdArbitro
        ), 'Sin idiomas registrados')                                       AS [Idiomas],
        (
            SELECT COUNT(*)
            FROM nucleo.DesignacionArbitral AS daCnt
            INNER JOIN nucleo.Partido AS pCnt ON pCnt.IdPartido = daCnt.IdPartido
            WHERE daCnt.IdArbitro = a.IdArbitro
              AND (@idFase IS NULL OR pCnt.IdFase = @idFase)
        )                                                                   AS [Resumen/TotalPartidosDesignado],
        (
            SELECT COUNT(*)
            FROM nucleo.DesignacionArbitral AS daPrinc
            INNER JOIN nucleo.Partido AS pPrinc ON pPrinc.IdPartido = daPrinc.IdPartido
            WHERE daPrinc.IdArbitro = a.IdArbitro
              AND daPrinc.Rol = 'Principal'
              AND (@idFase IS NULL OR pPrinc.IdFase = @idFase)
        )                                                                   AS [Resumen/PartidosComoPrincipal],
        (
            SELECT COUNT(*)
            FROM nucleo.DesignacionArbitral AS daAm
            INNER JOIN nucleo.Partido AS pAm ON pAm.IdPartido = daAm.IdPartido
            INNER JOIN eventos.Amonestacion AS amCnt ON amCnt.IdPartido = pAm.IdPartido
            INNER JOIN eventos.Tarjeta AS tCnt ON tCnt.IdTarjeta = amCnt.IdTarjeta
            WHERE daAm.IdArbitro = a.IdArbitro
              AND daAm.Rol = 'Principal'
              AND tCnt.Tipo = 'Amarilla'
              AND (@idFase IS NULL OR pAm.IdFase = @idFase)
        )                                                                   AS [Resumen/AmarillasSenaladas],
        (
            SELECT COUNT(*)
            FROM nucleo.DesignacionArbitral AS daRoj
            INNER JOIN nucleo.Partido AS pRoj ON pRoj.IdPartido = daRoj.IdPartido
            INNER JOIN eventos.Amonestacion AS amRoj ON amRoj.IdPartido = pRoj.IdPartido
            INNER JOIN eventos.Tarjeta AS tRoj ON tRoj.IdTarjeta = amRoj.IdTarjeta
            WHERE daRoj.IdArbitro = a.IdArbitro
              AND daRoj.Rol = 'Principal'
              AND tRoj.Tipo IN ('Roja por doble amarilla', 'Roja directa')
              AND (@idFase IS NULL OR pRoj.IdFase = @idFase)
        )                                                                   AS [Resumen/ExpulsionesSenaladas],
        (
            SELECT
                p.IdPartido                                                 AS [@IdPartido],
                p.NumeroPartido                                             AS [@NumeroPartido],
                da.Rol                                                      AS [@Rol],
                p.Estado                                                    AS [@Estado],
                f.Nombre                                                    AS [Fase],
                p.FechaHoraUTC                                              AS [FechaHoraUTC],
                CONCAT(sede.NombreEstadio, ' (', ciu.Nombre, ')')           AS [Sede],
                ISNULL(sLoc.CodigoFIFA, 'TBD') + ' vs ' + ISNULL(sVis.CodigoFIFA, 'TBD') AS [Encuentro],
                (
                    SELECT
                        am.IdAmonestacion                                   AS [@IdAmonestacion],
                        am.Minuto                                           AS [@Minuto],
                        t.Tipo                                              AS [TipoTarjeta],
                        CASE
                            WHEN am.IdJugador IS NOT NULL THEN 'Jugador'
                            ELSE 'Cuerpo Tecnico'
                        END                                                 AS [TipoSancionado],
                        CASE
                            WHEN am.IdJugador IS NOT NULL
                                THEN CONCAT(j.Nombre, ' ', j.Apellido)
                            ELSE CONCAT(st.NombreApellido, ' (', st.Rol, ')')
                        END                                                 AS [Sancionado],
                        COALESCE(selJ.CodigoFIFA, selSt.CodigoFIFA, '-')    AS [Seleccion],
                        am.Motivo                                           AS [Motivo],
                        am.PartidosSuspension                               AS [PartidosSuspension]
                    FROM eventos.Amonestacion AS am
                    INNER JOIN eventos.Tarjeta AS t
                        ON t.IdTarjeta = am.IdTarjeta
                    LEFT JOIN jugadores.Jugador AS j
                        ON j.IdJugador = am.IdJugador
                    LEFT JOIN jugadores.Convocatoria AS c
                        ON c.IdJugador = j.IdJugador
                    LEFT JOIN nucleo.Seleccion AS selJ
                        ON selJ.IdSeleccion = c.IdSeleccion
                    LEFT JOIN nucleo.StaffTecnico AS st
                        ON st.IdStaffTecnico = am.IdStaffTecnico
                    LEFT JOIN nucleo.Seleccion AS selSt
                        ON selSt.IdSeleccion = st.IdSeleccion
                    WHERE am.IdPartido = p.IdPartido
                      AND da.Rol = 'Principal'
                    ORDER BY am.Minuto ASC, am.IdAmonestacion ASC
                    FOR XML PATH('Tarjeta'), TYPE
                )                                                           AS [TarjetasSenaladas],
                (
                    SELECT
                        san.IdSancion                                       AS [@IdSancion],
                        san.Tipo                                            AS [Tipo],
                        san.Fecha                                           AS [Fecha],
                        san.Descripcion                                     AS [Descripcion]
                    FROM nucleo.Sancion AS san
                    WHERE san.IdDesignacionArbitral = da.IdDesignacionArbitral
                    ORDER BY san.Fecha ASC, san.IdSancion ASC
                    FOR XML PATH('SancionPostPartido'), TYPE
                )                                                           AS [SancionesEInformes]
            FROM nucleo.DesignacionArbitral AS da
            INNER JOIN nucleo.Partido AS p
                ON p.IdPartido = da.IdPartido
            INNER JOIN nucleo.Fase AS f
                ON f.IdFase = p.IdFase
            INNER JOIN nucleo.Sede AS sede
                ON sede.IdSede = p.IdSede
            INNER JOIN nucleo.Ciudad AS ciu
                ON ciu.IdCiudad = sede.IdCiudad
            LEFT JOIN nucleo.Seleccion AS sLoc
                ON sLoc.IdSeleccion = p.IdSeleccionLocal
            LEFT JOIN nucleo.Seleccion AS sVis
                ON sVis.IdSeleccion = p.IdSeleccionVisitante
            WHERE da.IdArbitro = a.IdArbitro
              AND (@idFase IS NULL OR p.IdFase = @idFase)
            ORDER BY p.FechaHoraUTC ASC, p.NumeroPartido ASC
            FOR XML PATH('Partido'), TYPE
        )                                                                   AS [PartidosDesignados]
    FROM nucleo.Arbitro AS a
    INNER JOIN nucleo.Pais AS pais
        ON pais.IdPais = a.IdPais
    INNER JOIN nucleo.Categoria AS cat
        ON cat.IdCategoria = a.IdCategoria
    WHERE (@idArbitro IS NULL OR a.IdArbitro = @idArbitro)
      AND (
          @idFase IS NULL
          OR EXISTS (
              SELECT 1
              FROM nucleo.DesignacionArbitral AS daF
              INNER JOIN nucleo.Partido AS pF
                  ON pF.IdPartido = daF.IdPartido
              WHERE daF.IdArbitro = a.IdArbitro
                AND pF.IdFase = @idFase
          )
      )
    ORDER BY a.NombreApellido ASC
    FOR XML PATH('Arbitro'), ROOT('DesignacionesArbitrales'), TYPE;
END;
GO

-- =========================================================================
-- 4. publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA
-- Reporte de ocupación publicitaria por sede y partido: anunciantes exhibidos
-- en los cuatro espacios (1..4) e ingresos generados.
-- Devuelve dos conjuntos de resultados:
--   - Result set 1: Detalle espacio por espacio (1 a 4) de cada partido y sede.
--   - Result set 2: Resumen consolidado de ocupación e ingresos por sede y
--                   moneda (evitando sumar importes de monedas distintas).
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA
    @idSede    TINYINT  = NULL,
    @idPartido SMALLINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: Detalle de los 4 espacios publicitarios por sede y partido
    SELECT
        sede.IdSede,
        sede.NombreEstadio                                                  AS Sede,
        ciu.Nombre                                                          AS Ciudad,
        paisSede.Nombre                                                     AS PaisSede,
        p.IdPartido,
        p.NumeroPartido,
        f.Nombre                                                            AS Fase,
        p.FechaHoraUTC,
        ISNULL(sLoc.CodigoFIFA, 'TBD') + ' vs ' + ISNULL(sVis.CodigoFIFA, 'TBD') AS Encuentro,
        esp.NumeroEspacio,
        CASE WHEN ep.IdPieza IS NOT NULL THEN 'Ocupado' ELSE 'Libre' END    AS EstadoEspacio,
        ISNULL(an.Nombre, '-')                                              AS Anunciante,
        ISNULL(paisAn.Nombre, '-')                                          AS PaisAnunciante,
        ISNULL(pz.Titulo, '-')                                              AS PiezaPublicitaria,
        ISNULL(idi.Nombre, '-')                                             AS IdiomaPieza,
        ISNULL(ep.TarifaPublicitaria, 0.00)                                 AS TarifaPublicitaria,
        ISNULL(m.Codigo, '-')                                               AS Moneda,
        COUNT(ep.IdPieza) OVER (PARTITION BY p.IdPartido)                   AS EspaciosOcupadosPartido,
        CAST(COUNT(ep.IdPieza) OVER (PARTITION BY p.IdPartido) * 100.0 / 4 AS DECIMAL(5,2)) AS PorcentajeOcupacionPartido
    FROM nucleo.Sede AS sede
    INNER JOIN nucleo.Ciudad AS ciu
        ON ciu.IdCiudad = sede.IdCiudad
    INNER JOIN nucleo.Pais AS paisSede
        ON paisSede.IdPais = ciu.IdPais
    INNER JOIN nucleo.Partido AS p
        ON p.IdSede = sede.IdSede
    INNER JOIN nucleo.Fase AS f
        ON f.IdFase = p.IdFase
    LEFT JOIN nucleo.Seleccion AS sLoc
        ON sLoc.IdSeleccion = p.IdSeleccionLocal
    LEFT JOIN nucleo.Seleccion AS sVis
        ON sVis.IdSeleccion = p.IdSeleccionVisitante
    CROSS JOIN (VALUES (1), (2), (3), (4)) AS esp (NumeroEspacio)
    LEFT JOIN publicidad.EspacioPublicitario AS ep
        ON ep.IdPartido = p.IdPartido
       AND ep.NumeroEspacio = esp.NumeroEspacio
    LEFT JOIN publicidad.Pieza AS pz
        ON pz.IdPieza = ep.IdPieza
    LEFT JOIN nucleo.Idioma AS idi
        ON idi.IdIdioma = pz.IdIdioma
    LEFT JOIN publicidad.Anunciante AS an
        ON an.IdAnunciante = pz.IdAnunciante
    LEFT JOIN nucleo.Pais AS paisAn
        ON paisAn.IdPais = an.IdPais
    LEFT JOIN publicidad.Moneda AS m
        ON m.IdMoneda = ep.IdMoneda
    WHERE (@idSede IS NULL OR sede.IdSede = @idSede)
      AND (@idPartido IS NULL OR p.IdPartido = @idPartido)
    ORDER BY
        sede.NombreEstadio ASC,
        p.FechaHoraUTC ASC,
        p.NumeroPartido ASC,
        esp.NumeroEspacio ASC;

    -- Result set 2: Resumen consolidado de ocupación e ingresos por sede y moneda
    SELECT
        sede.IdSede,
        sede.NombreEstadio                                                  AS Sede,
        ciu.Nombre                                                          AS Ciudad,
        paisSede.Nombre                                                     AS PaisSede,
        ISNULL(totSede.PartidosEnSede, 0)                                   AS PartidosEnSede,
        ISNULL(totSede.PartidosEnSede, 0) * 4                               AS CuposTotalesSede,
        SUM(COUNT(ep.IdPieza)) OVER (PARTITION BY sede.IdSede)              AS TotalEspaciosOcupadosSede,
        CAST(
            CASE
                WHEN ISNULL(totSede.PartidosEnSede, 0) = 0 THEN 0
                ELSE SUM(COUNT(ep.IdPieza)) OVER (PARTITION BY sede.IdSede) * 100.0
                     / (totSede.PartidosEnSede * 4)
            END AS DECIMAL(5,2)
        )                                                                   AS PorcentajeOcupacionSede,
        ISNULL(m.Codigo, 'SIN FACTURACION')                                 AS Moneda,
        COUNT(ep.IdPieza)                                                   AS EspaciosEnMoneda,
        SUM(ISNULL(ep.TarifaPublicitaria, 0.00))                            AS IngresosGenerados
    FROM nucleo.Sede AS sede
    INNER JOIN nucleo.Ciudad AS ciu
        ON ciu.IdCiudad = sede.IdCiudad
    INNER JOIN nucleo.Pais AS paisSede
        ON paisSede.IdPais = ciu.IdPais
    OUTER APPLY (
        SELECT COUNT(*) AS PartidosEnSede
        FROM nucleo.Partido AS pTot
        WHERE pTot.IdSede = sede.IdSede
          AND (@idPartido IS NULL OR pTot.IdPartido = @idPartido)
    ) AS totSede
    LEFT JOIN nucleo.Partido AS p
        ON p.IdSede = sede.IdSede
       AND (@idPartido IS NULL OR p.IdPartido = @idPartido)
    LEFT JOIN publicidad.EspacioPublicitario AS ep
        ON ep.IdPartido = p.IdPartido
    LEFT JOIN publicidad.Moneda AS m
        ON m.IdMoneda = ep.IdMoneda
    WHERE (@idSede IS NULL OR sede.IdSede = @idSede)
    GROUP BY
        sede.IdSede,
        sede.NombreEstadio,
        ciu.Nombre,
        paisSede.Nombre,
        totSede.PartidosEnSede,
        m.Codigo
    ORDER BY
        sede.NombreEstadio ASC,
        Moneda ASC;
END;
GO

-- =========================================================================
-- 5. publicidad.SP_REPORTE_MATRIZ_PRIME_TIME (PIVOT 100% ESTÁTICO)
-- Matriz de prime time: tabla cruzada (PIVOT) en T-SQL estático que muestra,
-- para cada partido, en qué mercados/países su horario cae en prime time
-- (19:00 a 22:59 hora local del mercado, calculado mediante la función
-- nucleo.fn_MercadosEnPrimeTime).
-- Convención de celdas en las columnas por código ISO3 de mercado:
--   - 'SI (HH:MM)' : el país está registrado en nucleo.Pais y el horario
--                    local del partido cae en prime time (19:00..22:59).
--   - 'NO'         : el país está registrado en nucleo.Pais y el partido se
--                    juega fuera de su franja prime time.
--   - 'N/D'        : el código ISO3 no fue cargado aún en nucleo.Pais.
-- Además, las columnas TotalMercadosPrimeTime y MercadosEnPrimeTimeDetalle
-- contabilizan y enumeran la totalidad de países de nucleo.Pais en prime
-- time para cada partido (incluso si se agregaran países adicionales).
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_REPORTE_MATRIZ_PRIME_TIME
    @idPartido SMALLINT = NULL,
    @idFase    TINYINT  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdPartido,
        NumeroPartido,
        Fase,
        FechaHoraUTC,
        Encuentro,
        TotalMercadosPrimeTime,
        MercadosEnPrimeTimeDetalle,
        [ALG], [ARG], [AUS], [AUT], [BEL], [BOL], [BRA], [CAN],
        [CHI], [CHN], [CIV], [CMR], [COL], [CRC], [CRO], [DEN],
        [ECU], [EGY], [ESP], [FRA], [GBR], [GER], [GHA], [IND],
        [IRN], [ITA], [JAM], [JPN], [KOR], [MAR], [MEX], [NED],
        [NGA], [NOR], [NZL], [PAN], [PAR], [PER], [POL], [POR],
        [QAT], [SAU], [SCO], [SEN], [SRB], [SUI], [SWE], [TUN],
        [TUR], [UKR], [URU], [USA], [VEN], [WAL]
    FROM (
        SELECT
            p.IdPartido,
            p.NumeroPartido,
            f.Nombre                                                                AS Fase,
            p.FechaHoraUTC,
            ISNULL(sLoc.CodigoFIFA, 'TBD') + ' vs ' + ISNULL(sVis.CodigoFIFA, 'TBD') AS Encuentro,
            (
                SELECT COUNT(*)
                FROM nucleo.fn_MercadosEnPrimeTime(p.IdPartido)
            )                                                                       AS TotalMercadosPrimeTime,
            ISNULL((
                SELECT STRING_AGG(
                           CONCAT(mptAll.CodigoISO3, ' (', CONVERT(CHAR(5), mptAll.FechaHoraLocalMercado, 108), ')'),
                           ', '
                       ) WITHIN GROUP (ORDER BY mptAll.CodigoISO3)
                FROM nucleo.fn_MercadosEnPrimeTime(p.IdPartido) AS mptAll
            ), 'Ninguno')                                                           AS MercadosEnPrimeTimeDetalle,
            m.CodigoISO3                                                            AS MercadoISO3,
            CASE
                WHEN pais.IdPais IS NULL
                    THEN 'N/D'
                WHEN mpt.IdPais IS NOT NULL
                    THEN 'SI (' + CONVERT(CHAR(5), mpt.FechaHoraLocalMercado, 108) + ')'
                ELSE 'NO'
            END                                                                     AS EstadoPrimeTime
        FROM nucleo.Partido AS p
        INNER JOIN nucleo.Fase AS f
            ON f.IdFase = p.IdFase
        LEFT JOIN nucleo.Seleccion AS sLoc
            ON sLoc.IdSeleccion = p.IdSeleccionLocal
        LEFT JOIN nucleo.Seleccion AS sVis
            ON sVis.IdSeleccion = p.IdSeleccionVisitante
        CROSS JOIN (
            VALUES
                ('ALG'), ('ARG'), ('AUS'), ('AUT'), ('BEL'), ('BOL'), ('BRA'), ('CAN'),
                ('CHI'), ('CHN'), ('CIV'), ('CMR'), ('COL'), ('CRC'), ('CRO'), ('DEN'),
                ('ECU'), ('EGY'), ('ESP'), ('FRA'), ('GBR'), ('GER'), ('GHA'), ('IND'),
                ('IRN'), ('ITA'), ('JAM'), ('JPN'), ('KOR'), ('MAR'), ('MEX'), ('NED'),
                ('NGA'), ('NOR'), ('NZL'), ('PAN'), ('PAR'), ('PER'), ('POL'), ('POR'),
                ('QAT'), ('SAU'), ('SCO'), ('SEN'), ('SRB'), ('SUI'), ('SWE'), ('TUN'),
                ('TUR'), ('UKR'), ('URU'), ('USA'), ('VEN'), ('WAL')
        ) AS m (CodigoISO3)
        LEFT JOIN nucleo.Pais AS pais
            ON pais.CodigoISO3 = m.CodigoISO3
                OUTER APPLY (
            SELECT
                x.IdPais,
                x.FechaHoraLocalMercado
            FROM nucleo.fn_MercadosEnPrimeTime(p.IdPartido) AS x
            WHERE x.IdPais = pais.IdPais
        ) AS mpt
        WHERE (@idPartido IS NULL OR p.IdPartido = @idPartido)
          AND (@idFase IS NULL OR p.IdFase = @idFase)
    ) AS Fuente
    PIVOT (
        MAX(EstadoPrimeTime)
        FOR MercadoISO3 IN (
            [ALG], [ARG], [AUS], [AUT], [BEL], [BOL], [BRA], [CAN],
            [CHI], [CHN], [CIV], [CMR], [COL], [CRC], [CRO], [DEN],
            [ECU], [EGY], [ESP], [FRA], [GBR], [GER], [GHA], [IND],
            [IRN], [ITA], [JAM], [JPN], [KOR], [MAR], [MEX], [NED],
            [NGA], [NOR], [NZL], [PAN], [PAR], [PER], [POL], [POR],
            [QAT], [SAU], [SCO], [SEN], [SRB], [SUI], [SWE], [TUN],
            [TUR], [UKR], [URU], [USA], [VEN], [WAL]
        )
    ) AS Matriz
    ORDER BY
        FechaHoraUTC ASC,
        NumeroPartido ASC;
END;
GO

-- =========================================================================
-- 6. jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS (FORMATO XML #2)
-- Reporte de selecciones y plantillas: listado de selecciones con cuerpo
-- técnico y vector anidado de convocados (nombre, posición, club, dorsal).
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS
    @codigoFIFA   CHAR(3) = NULL,
    @grupo        CHAR(1) = NULL,
    @incluirBajas BIT     = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @codigoFIFA = UPPER(NULLIF(LTRIM(RTRIM(@codigoFIFA)), ''));
    SET @grupo      = UPPER(NULLIF(LTRIM(RTRIM(@grupo)), ''));

    SELECT
        s.CodigoFIFA                                                        AS [@CodigoFIFA],
        g.Nombre                                                            AS [@Grupo],
        pais.Nombre                                                         AS [Pais],
        conf.Sigla                                                          AS [Confederacion],
        s.RankingFIFA                                                       AS [RankingFIFA],
        CASE s.EsAnfitrion WHEN 1 THEN 'Si' ELSE 'No' END                   AS [EsAnfitrion],
        (
            SELECT COUNT(*)
            FROM jugadores.Convocatoria AS cAct
            WHERE cAct.IdSeleccion = s.IdSeleccion
              AND NOT EXISTS (
                  SELECT 1
                  FROM jugadores.Baja AS bAct
                  WHERE bAct.IdConvocatoria = cAct.IdConvocatoria
              )
        )                                                                   AS [CantidadConvocadosActivos],
        (
            SELECT
                st.Rol                                                      AS [@Rol],
                st.NombreApellido                                           AS [NombreApellido]
            FROM nucleo.StaffTecnico AS st
            WHERE st.IdSeleccion = s.IdSeleccion
            ORDER BY
                CASE st.Rol
                    WHEN 'Director Técnico' THEN 1
                    WHEN 'Ayudante de campo 1' THEN 2
                    ELSE 3
                END
            FOR XML PATH('Integrante'), TYPE
        )                                                                   AS [CuerpoTecnico],
        (
            SELECT
                c.Dorsal                                                    AS [@Dorsal],
                CONCAT(j.Nombre, ' ', j.Apellido)                           AS [Nombre],
                j.Posicion                                                  AS [Posicion],
                ISNULL(cl.Nombre, 'Sin club')                               AS [Club],
                c.Dorsal                                                    AS [Dorsal],
                c.FechaAlta                                                 AS [FechaAlta],
                CASE
                    WHEN b.IdBaja IS NULL THEN 'Activo'
                    ELSE CONCAT('Baja (', CONVERT(VARCHAR(10), b.FechaBaja, 23), ': ', b.Motivo, ')')
                END                                                         AS [EstadoConvocatoria]
            FROM jugadores.Convocatoria AS c
            INNER JOIN jugadores.Jugador AS j
                ON j.IdJugador = c.IdJugador
            LEFT JOIN jugadores.Club AS cl
                ON cl.IdClub = j.IdClub
            LEFT JOIN jugadores.Baja AS b
                ON b.IdConvocatoria = c.IdConvocatoria
            WHERE c.IdSeleccion = s.IdSeleccion
              AND (@incluirBajas = 1 OR b.IdBaja IS NULL)
            ORDER BY c.Dorsal ASC
            FOR XML PATH('Jugador'), TYPE
        )                                                                   AS [Convocados]
    FROM nucleo.Seleccion AS s
    INNER JOIN nucleo.Pais AS pais
        ON pais.IdPais = s.IdPais
    INNER JOIN nucleo.Confederacion AS conf
        ON conf.IdConfederacion = pais.IdConfederacion
    INNER JOIN nucleo.Grupo AS g
        ON g.IdGrupo = s.IdGrupo
    WHERE (@codigoFIFA IS NULL OR s.CodigoFIFA = @codigoFIFA)
      AND (@grupo IS NULL OR g.Nombre = @grupo)
    ORDER BY
        g.Nombre ASC,
        s.RankingFIFA ASC
    FOR XML PATH('Seleccion'), ROOT('SeleccionesYPlantillas'), TYPE;
END;
GO

-- =========================================================================
-- 7. nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS
-- Reporte ilustrativo de resultados de los encuentros: muestra el fixture
-- completo con fecha/hora UTC y local de cada sede, marcador reglamentario y
-- de penales, selección ganadora, concurrencia, porcentaje de ocupación del
-- estadio y árbitro principal designado.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS
    @idFase     TINYINT     = NULL,
    @codigoFIFA CHAR(3)     = NULL,
    @estado     VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @codigoFIFA = UPPER(NULLIF(LTRIM(RTRIM(@codigoFIFA)), ''));
    SET @estado     = NULLIF(LTRIM(RTRIM(@estado)), '');

    SELECT
        p.IdPartido,
        p.NumeroPartido,
        f.Nombre                                                            AS Fase,
        CASE
            WHEN f.EsEliminatoria = 0 THEN CONCAT('Grupo ', ISNULL(gLoc.Nombre, '-'))
            ELSE 'Eliminación directa'
        END                                                                 AS Instancia,
        p.FechaHoraUTC,
        CAST((p.FechaHoraUTC AT TIME ZONE 'UTC') AT TIME ZONE ciu.HusoHorario AS DATETIME2(0)) AS FechaHoraLocalSede,
        ciu.HusoHorario                                                     AS HusoHorarioSede,
        sede.NombreEstadio                                                  AS Estadio,
        CONCAT(ciu.Nombre, ', ', paisSede.Nombre)                           AS CiudadPaisSede,
        p.Estado,
        ISNULL(CONCAT(paisLoc.Nombre, ' (', sLoc.CodigoFIFA, ')'), 'Por definir') AS SeleccionLocal,
        p.GolesLocal,
        p.GolesVisitante,
        p.PenalesLocal,
        p.PenalesVisitante,
        CASE
            WHEN p.Estado = 'Programado' THEN 'vs'
            WHEN p.PenalesLocal IS NOT NULL
                THEN CONCAT(p.GolesLocal, ' - ', p.GolesVisitante, ' (', p.PenalesLocal, ' - ', p.PenalesVisitante, ' pen.)')
            ELSE CONCAT(p.GolesLocal, ' - ', p.GolesVisitante)
        END                                                                 AS Marcador,
        ISNULL(CONCAT(paisVis.Nombre, ' (', sVis.CodigoFIFA, ')'), 'Por definir') AS SeleccionVisitante,
        CASE
            WHEN p.Estado = 'Programado'              THEN 'Pendiente'
            WHEN p.GolesLocal > p.GolesVisitante      THEN paisLoc.Nombre
            WHEN p.GolesVisitante > p.GolesLocal      THEN paisVis.Nombre
            WHEN p.PenalesLocal > p.PenalesVisitante  THEN CONCAT(paisLoc.Nombre, ' (penales)')
            WHEN p.PenalesVisitante > p.PenalesLocal  THEN CONCAT(paisVis.Nombre, ' (penales)')
            ELSE 'Empate'
        END                                                                 AS Ganador,
        p.Concurrencia                                                      AS ConcurrenciaPublico,
        sede.Capacidad                                                      AS CapacidadEstadio,
        CAST(p.Concurrencia * 100.0 / NULLIF(sede.Capacidad, 0) AS DECIMAL(5,2)) AS PorcentajeOcupacionEstadio,
        ISNULL(arb.NombreApellido, 'Sin designar')                          AS ArbitroPrincipal
    FROM nucleo.vw_PartidoResultado AS p
    INNER JOIN nucleo.Fase AS f
        ON f.IdFase = p.IdFase
    INNER JOIN nucleo.Sede AS sede
        ON sede.IdSede = p.IdSede
    INNER JOIN nucleo.Ciudad AS ciu
        ON ciu.IdCiudad = sede.IdCiudad
    INNER JOIN nucleo.Pais AS paisSede
        ON paisSede.IdPais = ciu.IdPais
    LEFT JOIN nucleo.Seleccion AS sLoc
        ON sLoc.IdSeleccion = p.IdSeleccionLocal
    LEFT JOIN nucleo.Pais AS paisLoc
        ON paisLoc.IdPais = sLoc.IdPais
    LEFT JOIN nucleo.Grupo AS gLoc
        ON gLoc.IdGrupo = sLoc.IdGrupo
    LEFT JOIN nucleo.Seleccion AS sVis
        ON sVis.IdSeleccion = p.IdSeleccionVisitante
    LEFT JOIN nucleo.Pais AS paisVis
        ON paisVis.IdPais = sVis.IdPais
    LEFT JOIN nucleo.DesignacionArbitral AS da
        ON da.IdPartido = p.IdPartido
       AND da.Rol = 'Principal'
    LEFT JOIN nucleo.Arbitro AS arb
        ON arb.IdArbitro = da.IdArbitro
    WHERE (@idFase IS NULL OR p.IdFase = @idFase)
      AND (@estado IS NULL OR p.Estado = @estado)
      AND (
          @codigoFIFA IS NULL
          OR sLoc.CodigoFIFA = @codigoFIFA
          OR sVis.CodigoFIFA = @codigoFIFA
      )
    ORDER BY
        p.FechaHoraUTC ASC,
        p.NumeroPartido ASC;
END;
GO
