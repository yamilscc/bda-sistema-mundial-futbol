/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-14
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Stored procedures de registro de sedes, partidos y resultados, y cálculo de
          selecciones clasificadas:
          - nucleo.SP_ABM_Sede
          - nucleo.SP_ABM_Partido
          - nucleo.SP_REGISTRAR_RESULTADO_PARTIDO
          - nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS

Convenciones de estos SP:
  - @operacion = 'ALTA' | 'MODIFICACION' | 'BAJA'.
  - Todas las validaciones se acumulan y se informan en UN solo mensaje (THROW 52000).
    Una operación inválida o un parámetro mal formado de entrada corta antes (THROW 52001).
  - MODIFICACION reemplaza todos los campos con los parámetros recibidos.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- SP_ABM_Sede
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Sede
    @operacion     VARCHAR(12),
    @idSede        INT          = NULL OUTPUT,
    @nombreEstadio VARCHAR(100) = NULL,
    @idCiudad      INT          = NULL,
    @capacidad     INT          = NULL,
    @zonaHoraria   VARCHAR(60)  = NULL,
    @latitud       DECIMAL(9,6) = NULL,
    @longitud      DECIMAL(9,6) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombreEstadio = LTRIM(RTRIM(@nombreEstadio));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idSede IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdSede = @idSede)
            SET @errores += N'- La sede indicada no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombreEstadio IS NULL OR @nombreEstadio = ''
            SET @errores += N'- El nombre del estadio es obligatorio.' + @salto;
        ELSE IF EXISTS (SELECT 1 FROM nucleo.Sede
                        WHERE NombreEstadio = @nombreEstadio
                          AND (@operacion = 'ALTA' OR IdSede <> @idSede))
            SET @errores += N'- Ya existe otra sede con ese nombre de estadio.' + @salto;

        IF @idCiudad IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Ciudad WHERE IdCiudad = @idCiudad)
            SET @errores += N'- La ciudad indicada no existe.' + @salto;

        IF @capacidad IS NULL OR @capacidad <= 0
            SET @errores += N'- La capacidad debe ser mayor a cero.' + @salto;

        IF @zonaHoraria IS NULL
           OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @zonaHoraria)
            SET @errores += N'- La zona horaria no es válida (debe ser un nombre de sys.time_zone_info).' + @salto;

        IF (@latitud IS NULL AND @longitud IS NOT NULL) OR (@latitud IS NOT NULL AND @longitud IS NULL)
            SET @errores += N'- Latitud y longitud deben informarse juntas.' + @salto;

        IF @latitud IS NOT NULL AND @latitud NOT BETWEEN -90 AND 90
            SET @errores += N'- La latitud debe estar entre -90 y 90.' + @salto;

        IF @longitud IS NOT NULL AND @longitud NOT BETWEEN -180 AND 180
            SET @errores += N'- La longitud debe estar entre -180 y 180.' + @salto;
    END;

    IF @operacion = 'MODIFICACION'
       AND @capacidad IS NOT NULL
       AND EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdSede = @idSede AND Asistencia > @capacidad)
        SET @errores += N'- La nueva capacidad es menor a la asistencia ya registrada en partidos de la sede.' + @salto;

    IF @operacion = 'BAJA'
       AND EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdSede = @idSede)
        SET @errores += N'- La sede tiene partidos asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Sede (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Sede (NombreEstadio, IdCiudad, Capacidad, ZonaHoraria, Latitud, Longitud)
            VALUES (@nombreEstadio, @idCiudad, @capacidad, @zonaHoraria, @latitud, @longitud);

            SET @idSede = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Sede
            SET NombreEstadio = @nombreEstadio,
                IdCiudad      = @idCiudad,
                Capacidad     = @capacidad,
                ZonaHoraria   = @zonaHoraria,
                Latitud       = @latitud,
                Longitud      = @longitud
            WHERE IdSede = @idSede;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Sede WHERE IdSede = @idSede;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- SP_ABM_Partido
-- El horario se informa en hora local de la sede; el SP calcula FechaHoraUTC.
-- No registra el resultado (eso lo hace SP_REGISTRAR_RESULTADO_PARTIDO).
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Partido
    @operacion            VARCHAR(12),
    @idPartido            INT          = NULL OUTPUT,
    @numeroPartido        INT          = NULL,
    @idFase               INT          = NULL,
    @idSede               INT          = NULL,
    @fechaHoraLocal       DATETIME2(0) = NULL,
    @idSeleccionLocal     INT          = NULL,
    @idSeleccionVisitante INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @estadoActual    VARCHAR(10),
            @descripcionFase VARCHAR(30),
            @zonaSede        VARCHAR(60),
            @fechaHoraUTC    DATETIME2(0),
            @grupoLocal      INT,
            @grupoVisitante  INT,
            @idExcluido      INT,
            -- Reglas de agenda (ajustar acá si cambia el criterio).
            @minutosMinimosEntreSede INT = 180,       -- 3 h entre dos partidos de la misma sede
            @minutosDescansoSeleccion INT = 72 * 60;  -- 72 h de descanso entre partidos de una selección

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        SELECT @estadoActual = Estado FROM nucleo.Partido WHERE IdPartido = @idPartido;

        IF @estadoActual IS NULL
            SET @errores += N'- El partido indicado no existe.' + @salto;
        ELSE IF @estadoActual = 'Finalizado'
            SET @errores += N'- El partido ya está finalizado y no puede modificarse ni eliminarse.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        SET @idExcluido = ISNULL(@idPartido, 0);   -- en ALTA no hay partido propio que excluir

        SELECT @descripcionFase = Descripcion FROM nucleo.Fase WHERE IdFase = @idFase;
        SELECT @zonaSede        = ZonaHoraria FROM nucleo.Sede WHERE IdSede = @idSede;
        SELECT @grupoLocal      = IdGrupo     FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionLocal;
        SELECT @grupoVisitante  = IdGrupo     FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionVisitante;

        IF @numeroPartido IS NULL OR @numeroPartido <= 0
            SET @errores += N'- El número de partido es obligatorio y debe ser mayor a cero.' + @salto;
        ELSE IF EXISTS (SELECT 1 FROM nucleo.Partido
                        WHERE NumeroPartido = @numeroPartido AND IdPartido <> @idExcluido)
            SET @errores += N'- Ya existe otro partido con ese número.' + @salto;

        IF @descripcionFase IS NULL
            SET @errores += N'- La fase indicada no existe.' + @salto;

        IF @zonaSede IS NULL
            SET @errores += N'- La sede indicada no existe.' + @salto;

        IF @fechaHoraLocal IS NULL
            SET @errores += N'- La fecha y hora local del partido es obligatoria.' + @salto;

        IF @idSeleccionLocal IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionLocal)
            SET @errores += N'- La selección local indicada no existe.' + @salto;

        IF @idSeleccionVisitante IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccionVisitante)
            SET @errores += N'- La selección visitante indicada no existe.' + @salto;

        IF (@idSeleccionLocal IS NULL AND @idSeleccionVisitante IS NOT NULL)
           OR (@idSeleccionLocal IS NOT NULL AND @idSeleccionVisitante IS NULL)
            SET @errores += N'- Deben informarse ambas selecciones o ninguna (cruce a definir).' + @salto;

        IF @idSeleccionLocal IS NOT NULL AND @idSeleccionLocal = @idSeleccionVisitante
            SET @errores += N'- Una selección no puede enfrentarse a sí misma.' + @salto;

        -- Fase de grupos: ambas selecciones, del mismo grupo y sin repetir el cruce.
        IF @descripcionFase = 'Grupos'
        BEGIN
            IF @idSeleccionLocal IS NULL OR @idSeleccionVisitante IS NULL
                SET @errores += N'- En fase de grupos ambas selecciones son obligatorias.' + @salto;
            ELSE IF @idSeleccionLocal <> @idSeleccionVisitante
            BEGIN
                IF @grupoLocal IS NULL OR @grupoVisitante IS NULL OR @grupoLocal <> @grupoVisitante
                    SET @errores += N'- En fase de grupos ambas selecciones deben pertenecer al mismo grupo.' + @salto;

                IF EXISTS (SELECT 1 FROM nucleo.Partido
                           WHERE IdFase = @idFase
                             AND IdPartido <> @idExcluido
                             AND ((IdSeleccionLocal = @idSeleccionLocal AND IdSeleccionVisitante = @idSeleccionVisitante)
                               OR (IdSeleccionLocal = @idSeleccionVisitante AND IdSeleccionVisitante = @idSeleccionLocal)))
                    SET @errores += N'- Ese cruce ya está programado en la fase de grupos.' + @salto;
            END;
        END;

        -- Agenda: se evalúa solo si se puede calcular el instante UTC.
        IF @zonaSede IS NOT NULL AND @fechaHoraLocal IS NOT NULL
        BEGIN
            SET @fechaHoraUTC = CAST((@fechaHoraLocal AT TIME ZONE @zonaSede) AT TIME ZONE 'UTC' AS DATETIME2(0));

            IF EXISTS (SELECT 1 FROM nucleo.Partido
                       WHERE IdSede = @idSede
                         AND IdPartido <> @idExcluido
                         AND ABS(DATEDIFF(MINUTE, FechaHoraUTC, @fechaHoraUTC)) < @minutosMinimosEntreSede)
                SET @errores += N'- La sede ya tiene otro partido a menos de 3 horas de ese horario.' + @salto;

            IF (@idSeleccionLocal IS NOT NULL OR @idSeleccionVisitante IS NOT NULL)
               AND EXISTS (SELECT 1 FROM nucleo.Partido
                           WHERE IdPartido <> @idExcluido
                             AND (IdSeleccionLocal IN (@idSeleccionLocal, @idSeleccionVisitante)
                               OR IdSeleccionVisitante IN (@idSeleccionLocal, @idSeleccionVisitante))
                             AND ABS(DATEDIFF(MINUTE, FechaHoraUTC, @fechaHoraUTC)) < @minutosDescansoSeleccion)
                SET @errores += N'- Alguna de las selecciones tiene otro partido a menos de 72 horas de descanso.' + @salto;
        END;
    END;

    IF @operacion = 'BAJA' AND @estadoActual = 'Programado'
    BEGIN
        IF EXISTS (SELECT 1 FROM nucleo.DesignacionArbitral WHERE IdPartido = @idPartido)
            SET @errores += N'- El partido tiene designaciones arbitrales asociadas.' + @salto;
        IF EXISTS (SELECT 1 FROM jugadores.Formacion WHERE IdPartido = @idPartido)
            SET @errores += N'- El partido tiene formaciones cargadas.' + @salto;
        IF EXISTS (SELECT 1 FROM jugadores.Sustitucion WHERE IdPartido = @idPartido)
            SET @errores += N'- El partido tiene sustituciones cargadas.' + @salto;
        IF EXISTS (SELECT 1 FROM eventos.Gol WHERE IdPartido = @idPartido)
            SET @errores += N'- El partido tiene goles cargados.' + @salto;
        IF EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdPartido = @idPartido)
            SET @errores += N'- El partido tiene amonestaciones cargadas.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Partido (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Partido (NumeroPartido, IdFase, IdSede, FechaHoraLocal, FechaHoraUTC,
                                        IdSeleccionLocal, IdSeleccionVisitante)
            VALUES (@numeroPartido, @idFase, @idSede, @fechaHoraLocal, @fechaHoraUTC,
                    @idSeleccionLocal, @idSeleccionVisitante);

            SET @idPartido = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Partido
            SET NumeroPartido        = @numeroPartido,
                IdFase               = @idFase,
                IdSede               = @idSede,
                FechaHoraLocal       = @fechaHoraLocal,
                FechaHoraUTC         = @fechaHoraUTC,
                IdSeleccionLocal     = @idSeleccionLocal,
                IdSeleccionVisitante = @idSeleccionVisitante
            WHERE IdPartido = @idPartido;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Partido WHERE IdPartido = @idPartido;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- SP_REGISTRAR_RESULTADO_PARTIDO
-- Cierra el partido (Estado = 'Finalizado') con goles, penales y asistencia.
-- Se puede volver a llamar para corregir un resultado ya cargado.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_REGISTRAR_RESULTADO_PARTIDO
    @idPartido           INT,
    @golesLocal          INT,
    @golesVisitante      INT,
    @penalesLocal        INT = NULL,
    @penalesVisitante    INT = NULL,
    @asistencia          INT = NULL,
    @permitirFechaFutura BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @existe          BIT = 0,
            @esEliminatoria  BIT,
            @idLocal         INT,
            @idVisitante     INT,
            @fechaHoraUTC    DATETIME2(0),
            @capacidad       INT;

    SELECT @existe         = 1,
           @esEliminatoria = f.EsEliminatoria,
           @idLocal        = p.IdSeleccionLocal,
           @idVisitante    = p.IdSeleccionVisitante,
           @fechaHoraUTC   = p.FechaHoraUTC,
           @capacidad      = s.Capacidad
    FROM nucleo.Partido AS p
    INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
    INNER JOIN nucleo.Sede AS s ON s.IdSede = p.IdSede
    WHERE p.IdPartido = @idPartido;

    -- ---- Validaciones ----------------------------------------------------
    IF @existe = 0
        SET @errores += N'- El partido indicado no existe.' + @salto;
    ELSE
    BEGIN
        IF @idLocal IS NULL OR @idVisitante IS NULL
            SET @errores += N'- El partido no tiene definidas ambas selecciones.' + @salto;

        IF @permitirFechaFutura = 0 AND @fechaHoraUTC > SYSUTCDATETIME()
            SET @errores += N'- No se puede registrar el resultado de un partido que todavía no se jugó.' + @salto;

        IF @asistencia IS NOT NULL AND (@asistencia < 0 OR @asistencia > @capacidad)
            SET @errores += N'- La asistencia debe estar entre 0 y la capacidad de la sede ('
                            + CAST(@capacidad AS NVARCHAR(12)) + N').' + @salto;

        IF (@penalesLocal IS NULL AND @penalesVisitante IS NOT NULL)
           OR (@penalesLocal IS NOT NULL AND @penalesVisitante IS NULL)
            SET @errores += N'- Los penales deben informarse para ambas selecciones o ninguna.' + @salto;

        IF @esEliminatoria = 0 AND (@penalesLocal IS NOT NULL OR @penalesVisitante IS NOT NULL)
            SET @errores += N'- En fase de grupos no hay definición por penales.' + @salto;

        IF @esEliminatoria = 1 AND @golesLocal IS NOT NULL AND @golesVisitante IS NOT NULL
        BEGIN
            IF @golesLocal = @golesVisitante AND (@penalesLocal IS NULL OR @penalesVisitante IS NULL)
                SET @errores += N'- En eliminación directa un empate requiere definición por penales.' + @salto;

            IF @golesLocal = @golesVisitante AND @penalesLocal IS NOT NULL AND @penalesLocal = @penalesVisitante
                SET @errores += N'- La definición por penales no puede terminar empatada.' + @salto;

            IF @golesLocal <> @golesVisitante AND (@penalesLocal IS NOT NULL OR @penalesVisitante IS NOT NULL)
                SET @errores += N'- No corresponde informar penales si el partido no terminó empatado.' + @salto;
        END;
    END;

    -- Los goles se validan siempre (también si el partido no existe).
    IF @golesLocal IS NULL OR @golesVisitante IS NULL OR @golesLocal < 0 OR @golesVisitante < 0
        SET @errores += N'- Los goles de ambas selecciones son obligatorios y no pueden ser negativos.' + @salto;

    IF (@penalesLocal IS NOT NULL AND @penalesLocal < 0) OR (@penalesVisitante IS NOT NULL AND @penalesVisitante < 0)
        SET @errores += N'- Los penales no pueden ser negativos.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_REGISTRAR_RESULTADO_PARTIDO - No se pudo registrar el resultado:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE nucleo.Partido
        SET Estado           = 'Finalizado',
            GolesLocal       = @golesLocal,
            GolesVisitante   = @golesVisitante,
            PenalesLocal     = @penalesLocal,
            PenalesVisitante = @penalesVisitante,
            Asistencia       = @asistencia
        WHERE IdPartido = @idPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT p.IdPartido, p.NumeroPartido, p.Estado, p.GolesLocal, p.GolesVisitante,
           p.PenalesLocal, p.PenalesVisitante, p.Asistencia
    FROM nucleo.Partido AS p
    WHERE p.IdPartido = @idPartido;
END;
GO

-- =========================================================================
-- SP_CALCULO_DE_SELECCIONES_CLASIFICADAS
-- Arma la tabla de posiciones de cada grupo con los partidos finalizados de la fase
-- de grupos (3 pts victoria, 1 empate) y marca quién clasifica:
--   @clasificadosPorGrupo: los N primeros de cada grupo clasifican directo.
--   @mejoresTerceros: cantidad de mejores ubicados en la posición N+1 que también pasan
--                     (formato 48 selecciones: 2 y 8; formato de 16 selecciones: 2 y 0).
-- Desempate dentro del grupo: puntos, diferencia de gol, goles a favor y, por último,
-- IdSeleccion (determinístico). No aplica enfrentamiento directo ni fair play.
-- Es de solo lectura: devuelve el resultado, no modifica tablas.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS
    @clasificadosPorGrupo INT = 2,
    @mejoresTerceros      INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    -- ---- Validaciones ----------------------------------------------------
    IF @clasificadosPorGrupo IS NULL OR @clasificadosPorGrupo < 1
        SET @errores += N'- La cantidad de clasificados por grupo debe ser al menos 1.' + @salto;

    IF @mejoresTerceros IS NULL OR @mejoresTerceros < 0
        SET @errores += N'- La cantidad de mejores terceros no puede ser negativa.' + @salto;

    IF NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdGrupo IS NOT NULL)
        SET @errores += N'- No hay selecciones asignadas a grupos.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_CALCULO_DE_SELECCIONES_CLASIFICADAS - Parámetros inválidos:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

        -- ---- Cálculo ---------------------------------------------------------
    CREATE TABLE #Posiciones (
        IdGrupo                 INT,
        NombreGrupo             VARCHAR(10),
        Posicion                INT,
        IdSeleccion             INT,
        Pais                    VARCHAR(80),
        PartidosJugados         INT,
        Ganados                 INT,
        Empatados               INT,
        Perdidos                INT,
        GolesFavor              INT,
        GolesContra             INT,
        Diferencia              INT,
        Puntos                  INT,
        PartidosPendientesGrupo INT,
        ClasificaComo           VARCHAR(20) NULL
    );

    -- Todos los grupos en una sola sentencia (set-based).
    INSERT INTO #Posiciones (IdGrupo, NombreGrupo, Posicion, IdSeleccion, Pais, PartidosJugados,
                             Ganados, Empatados, Perdidos, GolesFavor, GolesContra, Diferencia,
                             Puntos, PartidosPendientesGrupo)
    SELECT x.IdGrupo,
           x.NombreGrupo,
           ROW_NUMBER() OVER (PARTITION BY x.IdGrupo
                              ORDER BY x.G * 3 + x.E DESC, x.GF - x.GC DESC, x.GF DESC, x.IdSeleccion),
           x.IdSeleccion,
           x.Pais,
           x.PJ, x.G, x.E, x.P, x.GF, x.GC,
           x.GF - x.GC,
           x.G * 3 + x.E,
           ISNULL(pen.Pendientes, 0)
    FROM (
        SELECT g.IdGrupo,
               g.Nombre AS NombreGrupo,
               s.IdSeleccion,
               pa.Nombre AS Pais,
               COUNT(r.IdSeleccion)                                      AS PJ,
               ISNULL(SUM(CASE WHEN r.GF >  r.GC THEN 1 ELSE 0 END), 0)  AS G,
               ISNULL(SUM(CASE WHEN r.GF =  r.GC THEN 1 ELSE 0 END), 0)  AS E,
               ISNULL(SUM(CASE WHEN r.GF <  r.GC THEN 1 ELSE 0 END), 0)  AS P,
               ISNULL(SUM(r.GF), 0)                                      AS GF,
               ISNULL(SUM(r.GC), 0)                                      AS GC
        FROM nucleo.Seleccion AS s
        INNER JOIN nucleo.Grupo AS g  ON g.IdGrupo = s.IdGrupo
        INNER JOIN nucleo.Pais  AS pa ON pa.IdPais = s.IdPais
        LEFT JOIN (
            SELECT p.IdSeleccionLocal AS IdSeleccion, p.GolesLocal AS GF, p.GolesVisitante AS GC
            FROM nucleo.Partido AS p
            INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
            WHERE f.Descripcion = 'Grupos' AND p.Estado = 'Finalizado'
            UNION ALL
            SELECT p.IdSeleccionVisitante, p.GolesVisitante, p.GolesLocal
            FROM nucleo.Partido AS p
            INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
            WHERE f.Descripcion = 'Grupos' AND p.Estado = 'Finalizado'
        ) AS r ON r.IdSeleccion = s.IdSeleccion
        GROUP BY g.IdGrupo, g.Nombre, s.IdSeleccion, pa.Nombre
    ) AS x
    LEFT JOIN (
        -- Partidos de grupos todavía sin jugar, por grupo.
        SELECT s.IdGrupo, COUNT(*) AS Pendientes
        FROM nucleo.Partido AS p
        INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
        INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = p.IdSeleccionLocal
        WHERE f.Descripcion = 'Grupos'
          AND s.IdGrupo IS NOT NULL
          AND p.Estado <> 'Finalizado'
        GROUP BY s.IdGrupo
    ) AS pen ON pen.IdGrupo = x.IdGrupo;

    -- Clasificados directos.
    UPDATE #Posiciones
    SET ClasificaComo = 'Directo'
    WHERE Posicion <= @clasificadosPorGrupo;

    -- Mejores ubicados en la posición siguiente (mejores terceros en el formato habitual).
    IF @mejoresTerceros > 0
    BEGIN
        ;WITH Candidatos AS (
            SELECT IdSeleccion,
                   ROW_NUMBER() OVER (ORDER BY Puntos DESC, Diferencia DESC, GolesFavor DESC, IdSeleccion) AS Orden
            FROM #Posiciones
            WHERE Posicion = @clasificadosPorGrupo + 1
        )
        UPDATE p
        SET ClasificaComo = 'Mejor ' + CAST(@clasificadosPorGrupo + 1 AS VARCHAR(3)) + 'º'
        FROM #Posiciones AS p
        INNER JOIN Candidatos AS c ON c.IdSeleccion = p.IdSeleccion
        WHERE c.Orden <= @mejoresTerceros;
    END;

    SELECT NombreGrupo, Posicion, IdSeleccion, Pais, PartidosJugados, Ganados, Empatados, Perdidos,
           GolesFavor, GolesContra, Diferencia, Puntos,
           CAST(CASE WHEN PartidosPendientesGrupo = 0 THEN 1 ELSE 0 END AS BIT) AS GrupoCompleto,
           CAST(CASE WHEN ClasificaComo IS NULL THEN 0 ELSE 1 END AS BIT)       AS Clasifica,
           ClasificaComo
    FROM #Posiciones
    ORDER BY NombreGrupo, Posicion;

    DROP TABLE #Posiciones;
END;
GO
