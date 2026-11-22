/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-15
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Funciones del módulo de jugadores, convocatoria y alineaciones:
          - jugadores.fn_EsquemaValido(@esquemaTactico): valida formato y que las líneas sumen 10.
          - jugadores.fn_JugadorEnCancha(@idPartido, @idJugador, @minuto): indica (BIT) si el jugador
            está en cancha en ese minuto (titular o entró en cambio, no salió y no fue expulsado).
          - jugadores.fn_JugadoresEnCancha(@idPartido, @minuto): tabla con los jugadores en cancha.
          - jugadores.fn_ValidarConvocatoria, jugadores.fn_ValidarFormacionJugador y
            jugadores.fn_ValidarSustitucion: validaciones compartidas por los SP de negocio y ABM.
          Requiere ejecutados los scripts 01 a 10.
          Test correspondiente: testing/14_Test_Funciones_Jugadores.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. fn_EsquemaValido
-- Verifica que el esquema respete el patrón '[1-9]-[1-9]-[1-9]' o
-- '[1-9]-[1-9]-[1-9]-[1-9]' y que la suma de sus dígitos sea igual a 10.
-- =========================================================================
CREATE OR ALTER FUNCTION jugadores.fn_EsquemaValido (@esquemaTactico VARCHAR(10))
RETURNS BIT
AS
BEGIN
    DECLARE @valido BIT = 0,
            @suma   INT = 0;

    IF @esquemaTactico LIKE '[1-9]-[1-9]-[1-9]'
    BEGIN
        SET @suma = CAST(SUBSTRING(@esquemaTactico, 1, 1) AS INT)
                  + CAST(SUBSTRING(@esquemaTactico, 3, 1) AS INT)
                  + CAST(SUBSTRING(@esquemaTactico, 5, 1) AS INT);
        IF @suma = 10
            SET @valido = 1;
    END
    ELSE IF @esquemaTactico LIKE '[1-9]-[1-9]-[1-9]-[1-9]'
    BEGIN
        SET @suma = CAST(SUBSTRING(@esquemaTactico, 1, 1) AS INT)
                  + CAST(SUBSTRING(@esquemaTactico, 3, 1) AS INT)
                  + CAST(SUBSTRING(@esquemaTactico, 5, 1) AS INT)
                  + CAST(SUBSTRING(@esquemaTactico, 7, 1) AS INT);
        IF @suma = 10
            SET @valido = 1;
    END;

    RETURN @valido;
END;
GO

-- =========================================================================
-- 2. fn_JugadorEnCancha (escalar)
-- Devuelve 1 si el jugador está en el campo de juego en @minuto de @idPartido:
--   - Minuto entre 1 y 135.
--   - Pertenece a una formación del partido como 'Titular', o como 'Suplente'
--     que ingresó en una sustitución con Minuto <= @minuto.
--   - No salió reemplazado en una sustitución con Minuto <= @minuto.
--   - No fue expulsado (roja directa o doble amarilla) con Minuto <= @minuto.
-- =========================================================================
CREATE OR ALTER FUNCTION jugadores.fn_JugadorEnCancha (
    @idPartido INT,
    @idJugador INT,
    @minuto    INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @enCancha BIT = 0;

    IF @idPartido IS NOT NULL AND @idJugador IS NOT NULL AND @minuto BETWEEN 1 AND 135
       AND EXISTS (
            SELECT 1
            FROM jugadores.Formacion AS f
            INNER JOIN jugadores.FormacionJugador AS fj ON fj.IdFormacion = f.IdFormacion
            WHERE f.IdPartido = @idPartido
              AND fj.IdJugador = @idJugador
              AND (
                     fj.EstadoTitularidad = 'Titular'
                  OR (fj.EstadoTitularidad = 'Suplente'
                      AND EXISTS (SELECT 1
                                  FROM jugadores.Sustitucion AS sIn
                                  WHERE sIn.IdPartido = @idPartido
                                    AND sIn.IdJugadorEntrante = @idJugador
                                    AND sIn.Minuto <= @minuto))
              )
              AND NOT EXISTS (
                  SELECT 1
                  FROM jugadores.Sustitucion AS sOut
                  WHERE sOut.IdPartido = @idPartido
                    AND sOut.IdJugadorSaliente = @idJugador
                    AND sOut.Minuto < @minuto
              )
              AND NOT EXISTS (
                  SELECT 1
                  FROM eventos.Amonestacion AS a
                  INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                  WHERE a.IdPartido = @idPartido
                    AND a.IdJugador = @idJugador
                    AND t.Tipo IN ('Roja por doble amarilla', 'Roja directa')
                    AND a.Minuto <= @minuto
              )
       )
        SET @enCancha = 1;

    RETURN @enCancha;
END;
GO

-- =========================================================================
-- 3. fn_JugadoresEnCancha (inline table-valued)
-- Devuelve la nómina de jugadores de ambas selecciones que se encuentran en
-- cancha en @minuto para @idPartido.
-- =========================================================================
CREATE OR ALTER FUNCTION jugadores.fn_JugadoresEnCancha (
    @idPartido INT,
    @minuto    INT
)
RETURNS TABLE
AS
RETURN
    SELECT f.IdPartido,
           f.Localia,
           CASE WHEN f.Localia = 'Local' THEN p.IdSeleccionLocal ELSE p.IdSeleccionVisitante END AS IdSeleccion,
           fj.IdJugador,
           j.Nombre,
           j.Apellido,
           fj.Dorsal,
           fj.EstadoTitularidad AS CondicionInicial,
           COALESCE(fj.PosicionEnCampo, j.Posicion) AS Posicion
    FROM jugadores.Formacion AS f
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = f.IdPartido
    INNER JOIN jugadores.FormacionJugador AS fj ON fj.IdFormacion = f.IdFormacion
    INNER JOIN jugadores.Jugador AS j ON j.IdJugador = fj.IdJugador
    WHERE f.IdPartido = @idPartido
      AND @minuto BETWEEN 1 AND 135
      AND jugadores.fn_JugadorEnCancha(@idPartido, fj.IdJugador, @minuto) = 1;
GO

-- =========================================================================
-- 4. fn_ValidarConvocatoria
-- Valida el alta o modificación de un jugador en jugadores.Convocatoria.
-- En un alta (@idConvocatoriaExcluir IS NULL) verifica que la cantidad de
-- convocados activos (sin baja en jugadores.Baja) no supere el máximo de
-- jugadores.ReglaConvocados.
-- =========================================================================
CREATE OR ALTER FUNCTION jugadores.fn_ValidarConvocatoria (
    @idSeleccion           INT,
    @idJugador             INT,
    @dorsal                INT,
    @fechaAlta             DATE,
    @idConvocatoriaExcluir INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores           NVARCHAR(MAX) = N'',
            @salto             NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @existeSeleccion   BIT = 0,
            @existeJugador     BIT = 0,
            @maxConvocados     INT,
            @convocadosActivos INT,
            @idSelActual       INT;

    IF @idSeleccion IS NOT NULL AND EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccion)
        SET @existeSeleccion = 1;
    ELSE
        SET @errores += N'- La selección indicada no existe.' + @salto;

    IF @idJugador IS NOT NULL AND EXISTS (SELECT 1 FROM jugadores.Jugador WHERE IdJugador = @idJugador)
        SET @existeJugador = 1;
    ELSE
        SET @errores += N'- El jugador indicado no existe.' + @salto;

    IF @dorsal IS NULL OR @dorsal NOT BETWEEN 1 AND 99
        SET @errores += N'- El dorsal es obligatorio y debe estar entre 1 y 99.' + @salto;

    IF @fechaAlta IS NULL
        SET @errores += N'- La fecha de alta es obligatoria.' + @salto;

    SELECT TOP (1) @maxConvocados = r.Maximo
    FROM jugadores.ReglaConvocados AS r
    ORDER BY r.IdRegla;

    IF @maxConvocados IS NULL
        SET @errores += N'- Falta parametrizar la regla de cupos en jugadores.ReglaConvocados.' + @salto;

    IF @existeJugador = 1
       AND EXISTS (SELECT 1
                   FROM jugadores.Convocatoria AS c
                   WHERE c.IdJugador = @idJugador
                     AND (@idConvocatoriaExcluir IS NULL OR c.IdConvocatoria <> @idConvocatoriaExcluir))
        SET @errores += N'- El jugador ya figura convocado.' + @salto;

    IF @existeSeleccion = 1 AND @dorsal BETWEEN 1 AND 99
       AND EXISTS (SELECT 1
                   FROM jugadores.Convocatoria AS c
                   WHERE c.IdSeleccion = @idSeleccion
                     AND c.Dorsal = @dorsal
                     AND (@idConvocatoriaExcluir IS NULL OR c.IdConvocatoria <> @idConvocatoriaExcluir))
        SET @errores += N'- Ese dorsal ya está asignado a otro jugador en la misma selección.' + @salto;

    -- Control de tope máximo de convocados activos (sin baja) en la selección destino.
    IF @existeSeleccion = 1 AND @maxConvocados IS NOT NULL
    BEGIN
        IF @idConvocatoriaExcluir IS NOT NULL
            SELECT @idSelActual = c.IdSeleccion
            FROM jugadores.Convocatoria AS c
            WHERE c.IdConvocatoria = @idConvocatoriaExcluir;

        IF @idConvocatoriaExcluir IS NULL OR @idSelActual <> @idSeleccion
        BEGIN
            SELECT @convocadosActivos = COUNT(*)
            FROM jugadores.Convocatoria AS c
            WHERE c.IdSeleccion = @idSeleccion
              AND NOT EXISTS (SELECT 1 FROM jugadores.Baja AS b WHERE b.IdConvocatoria = c.IdConvocatoria);

            IF @convocadosActivos >= @maxConvocados
                SET @errores += N'- La selección ya alcanzó el máximo de jugadores convocados activos ('
                                + CAST(@maxConvocados AS NVARCHAR(10)) + N').' + @salto;
        END;
    END;

    RETURN @errores;
END;
GO

-- =========================================================================
-- 5. fn_ValidarFormacionJugador
-- Valida la incorporación o modificación de un jugador en jugadores.FormacionJugador:
--   - Formación existente y partido no finalizado.
--   - Jugador existente, convocado en la selección de esa localía, sin baja a la
--     fecha del partido y no suspendido (eventos.fn_EstaSuspendido = 0).
--   - Coherencia entre EstadoTitularidad y PosicionEnCampo.
--   - Dorsal 1..99 y no repetido en la formación.
--   - Tope de 11 titulares y exactamente 1 arquero titular.
-- =========================================================================
CREATE OR ALTER FUNCTION jugadores.fn_ValidarFormacionJugador (
    @idFormacion       INT,
    @idJugador         INT,
    @estadoTitularidad VARCHAR(8),
    @posicionEnCampo   VARCHAR(20),
    @dorsal            INT,
    @esModificacion    BIT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores           NVARCHAR(MAX) = N'',
            @salto             NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartido         INT,
            @estadoPartido     VARCHAR(10),
            @fechaLocalPartido DATE,
            @idSelFormacion    INT,
            @idSelJugador      INT,
            @idConvocatoria    INT,
            @titularesActuales INT,
            @arquerosTitulares INT;

    SELECT @idPartido         = f.IdPartido,
           @estadoPartido     = p.Estado,
           @fechaLocalPartido = CAST(p.FechaHoraLocal AS DATE),
           @idSelFormacion    = CASE WHEN f.Localia = 'Local' THEN p.IdSeleccionLocal ELSE p.IdSeleccionVisitante END
    FROM jugadores.Formacion AS f
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = f.IdPartido
    WHERE f.IdFormacion = @idFormacion;

    IF @idPartido IS NULL
        SET @errores += N'- La formación indicada no existe.' + @salto;
    ELSE IF @estadoPartido = 'Finalizado'
        SET @errores += N'- El partido ya está finalizado: no se puede alterar la formación.' + @salto;

    IF @estadoTitularidad IS NULL OR @estadoTitularidad NOT IN ('Titular', 'Suplente')
        SET @errores += N'- El estado de titularidad debe ser Titular o Suplente.' + @salto;
    ELSE
    BEGIN
        IF @estadoTitularidad = 'Titular'
           AND (@posicionEnCampo IS NULL OR @posicionEnCampo NOT IN ('Arquero', 'Defensor', 'Mediocampista', 'Delantero'))
            SET @errores += N'- Un jugador titular debe tener PosicionEnCampo válida (Arquero, Defensor, Mediocampista o Delantero).' + @salto;

        IF @estadoTitularidad = 'Suplente' AND @posicionEnCampo IS NOT NULL
            SET @errores += N'- Un jugador suplente debe tener PosicionEnCampo en NULL.' + @salto;
    END;

    IF @dorsal IS NULL OR @dorsal NOT BETWEEN 1 AND 99
        SET @errores += N'- El dorsal debe estar entre 1 y 99.' + @salto;

    IF @idJugador IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.Jugador WHERE IdJugador = @idJugador)
        SET @errores += N'- El jugador indicado no existe.' + @salto;
    ELSE
    BEGIN
        SELECT @idConvocatoria = c.IdConvocatoria,
               @idSelJugador   = c.IdSeleccion
        FROM jugadores.Convocatoria AS c
        WHERE c.IdJugador = @idJugador;

        IF @idConvocatoria IS NULL
            SET @errores += N'- El jugador no está convocado en ninguna selección.' + @salto;
        ELSE IF @idPartido IS NOT NULL
        BEGIN
            IF @idSelJugador <> ISNULL(@idSelFormacion, -1)
                SET @errores += N'- El jugador no pertenece a la selección de esta formación.' + @salto;

            IF EXISTS (SELECT 1
                       FROM jugadores.Baja AS b
                       WHERE b.IdConvocatoria = @idConvocatoria
                         AND b.FechaBaja <= @fechaLocalPartido)
                SET @errores += N'- El jugador está dado de baja de la convocatoria para la fecha del partido.' + @salto;

            IF eventos.fn_EstaSuspendido(@idJugador, @idPartido) = 1
                SET @errores += N'- El jugador está suspendido para este partido y no puede integrar la planilla.' + @salto;
        END;
    END;

    IF @idPartido IS NOT NULL
    BEGIN
        IF @esModificacion = 0
           AND EXISTS (SELECT 1 FROM jugadores.FormacionJugador WHERE IdFormacion = @idFormacion AND IdJugador = @idJugador)
            SET @errores += N'- El jugador ya forma parte de esta formación.' + @salto;

        IF @dorsal BETWEEN 1 AND 99
           AND EXISTS (SELECT 1
                       FROM jugadores.FormacionJugador AS fj
                       WHERE fj.IdFormacion = @idFormacion
                         AND fj.Dorsal = @dorsal
                         AND (@esModificacion = 0 OR fj.IdJugador <> @idJugador))
            SET @errores += N'- Ese dorsal ya está utilizado por otro jugador en la misma formación.' + @salto;

        IF @estadoTitularidad = 'Titular'
        BEGIN
            SELECT @titularesActuales = COUNT(*),
                   @arquerosTitulares = ISNULL(SUM(CASE WHEN fj.PosicionEnCampo = 'Arquero' THEN 1 ELSE 0 END), 0)
            FROM jugadores.FormacionJugador AS fj
            WHERE fj.IdFormacion = @idFormacion
              AND fj.EstadoTitularidad = 'Titular'
              AND (@esModificacion = 0 OR fj.IdJugador <> @idJugador);

            IF @titularesActuales >= 11
                SET @errores += N'- La formación ya cuenta con el máximo de 11 jugadores titulares.' + @salto;

            IF @posicionEnCampo = 'Arquero' AND @arquerosTitulares >= 1
                SET @errores += N'- La formación ya tiene un arquero titular asignado.' + @salto;

            IF @posicionEnCampo <> 'Arquero' AND @titularesActuales = 10 AND @arquerosTitulares = 0
                SET @errores += N'- Entre los 11 titulares debe incluirse obligatoriamente un Arquero.' + @salto;
        END;
    END;

    RETURN @errores;
END;
GO

-- =========================================================================
-- 6. fn_ValidarSustitucion
-- Valida el alta o modificación de un cambio en jugadores.Sustitucion:
--   - Partido existente, definido, no finalizado y ya jugado.
--   - Período ('Regular' o 'Suplementario' en eliminatoria) y minuto coherente.
--   - Jugador saliente y entrante distintos y de la misma formación del partido.
--   - Saliente en cancha en ese momento y no expulsado; entrante suplente,
--     sin haber ingresado antes y no expulsado.
--   - Cumplimiento de topes de cambios y de ventanas según jugadores.ReglaCambios.
-- =========================================================================
CREATE OR ALTER FUNCTION jugadores.fn_ValidarSustitucion (
    @idPartido            INT,
    @idJugadorSaliente    INT,
    @idJugadorEntrante    INT,
    @minuto               INT,
    @periodo              VARCHAR(13),
    @motivo               VARCHAR(10),
    @permitirFechaFutura  BIT,
    @idSustitucionExcluir INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores           NVARCHAR(MAX) = N'',
            @salto             NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @existePartido     BIT = 0,
            @estadoPartido     VARCHAR(10),
            @esEliminatoria    BIT,
            @idLocal           INT,
            @idVisitante       INT,
            @fechaHoraUTC      DATETIME2(0),
            @idFormSaliente    INT,
            @estadoSaliente    VARCHAR(8),
            @idFormEntrante    INT,
            @estadoEntrante    VARCHAR(8),
            @maxCambiosReg     INT,
            @maxVentanasReg    INT,
            @maxCambiosSup     INT,
            @maxVentanasSup    INT,
            @cambiosRealizados INT,
            @ventanasUsadas    INT,
            @mismaVentana      BIT = 0;

    SELECT @existePartido  = 1,
           @estadoPartido  = p.Estado,
           @esEliminatoria = f.EsEliminatoria,
           @idLocal        = p.IdSeleccionLocal,
           @idVisitante    = p.IdSeleccionVisitante,
           @fechaHoraUTC   = p.FechaHoraUTC
    FROM nucleo.Partido AS p
    INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
    WHERE p.IdPartido = @idPartido;

    IF @existePartido = 0
        SET @errores += N'- El partido indicado no existe.' + @salto;
    ELSE
    BEGIN
        IF @idLocal IS NULL OR @idVisitante IS NULL
            SET @errores += N'- El partido no tiene definidas ambas selecciones.' + @salto;
        IF @estadoPartido = 'Finalizado'
            SET @errores += N'- El partido ya está finalizado: no se pueden registrar sustituciones.' + @salto;
        IF @permitirFechaFutura = 0 AND @fechaHoraUTC > SYSUTCDATETIME()
            SET @errores += N'- No se pueden registrar sustituciones en un partido que todavía no se jugó.' + @salto;
    END;

    IF @periodo IS NULL OR @periodo NOT IN ('Regular', 'Suplementario')
        SET @errores += N'- El período debe ser Regular o Suplementario.' + @salto;
    ELSE IF @periodo = 'Suplementario' AND @existePartido = 1 AND @esEliminatoria = 0
        SET @errores += N'- En fase de grupos no existe tiempo suplementario.' + @salto;

    IF @minuto IS NULL OR @minuto NOT BETWEEN 1 AND 135
        SET @errores += N'- El minuto debe estar entre 1 y 135.' + @salto;
    ELSE IF @periodo = 'Regular' AND @minuto > 90
        SET @errores += N'- En el período Regular el minuto debe estar entre 1 y 90.' + @salto;
    ELSE IF @periodo = 'Suplementario' AND @minuto < 91
        SET @errores += N'- En el período Suplementario el minuto debe estar entre 91 y 135.' + @salto;

    IF @motivo IS NULL OR @motivo NOT IN ('Tactico', 'Lesion', 'Precaucion')
        SET @errores += N'- El motivo debe ser Tactico, Lesion o Precaucion.' + @salto;

    SELECT TOP (1)
           @maxCambiosReg  = r.MaxCambiosRegular,
           @maxVentanasReg = r.MaxVentanasRegular,
           @maxCambiosSup  = r.MaxCambiosSuplementario,
           @maxVentanasSup = r.MaxVentanasSuplementario
    FROM jugadores.ReglaCambios AS r
    ORDER BY r.IdRegla;

    IF @maxCambiosReg IS NULL
        SET @errores += N'- Falta parametrizar la regla de cambios en jugadores.ReglaCambios.' + @salto;

    IF @idJugadorSaliente IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.Jugador WHERE IdJugador = @idJugadorSaliente)
        SET @errores += N'- El jugador saliente no existe.' + @salto;

    IF @idJugadorEntrante IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.Jugador WHERE IdJugador = @idJugadorEntrante)
        SET @errores += N'- El jugador entrante no existe.' + @salto;

    IF @idJugadorSaliente IS NOT NULL AND @idJugadorSaliente = @idJugadorEntrante
        SET @errores += N'- El jugador saliente y el jugador entrante no pueden ser el mismo.' + @salto;

    IF @existePartido = 1 AND @idJugadorSaliente IS NOT NULL AND @idJugadorEntrante IS NOT NULL
       AND @idJugadorSaliente <> @idJugadorEntrante
    BEGIN
        SELECT @idFormSaliente = f.IdFormacion,
               @estadoSaliente = fj.EstadoTitularidad
        FROM jugadores.Formacion AS f
        INNER JOIN jugadores.FormacionJugador AS fj ON fj.IdFormacion = f.IdFormacion
        WHERE f.IdPartido = @idPartido
          AND fj.IdJugador = @idJugadorSaliente;

        SELECT @idFormEntrante = f.IdFormacion,
               @estadoEntrante = fj.EstadoTitularidad
        FROM jugadores.Formacion AS f
        INNER JOIN jugadores.FormacionJugador AS fj ON fj.IdFormacion = f.IdFormacion
        WHERE f.IdPartido = @idPartido
          AND fj.IdJugador = @idJugadorEntrante;

        IF @idFormSaliente IS NULL
            SET @errores += N'- El jugador saliente no integra ninguna formación del partido.' + @salto;

        IF @idFormEntrante IS NULL
            SET @errores += N'- El jugador entrante no integra ninguna formación del partido.' + @salto;

        IF @idFormSaliente IS NOT NULL AND @idFormEntrante IS NOT NULL AND @idFormSaliente <> @idFormEntrante
            SET @errores += N'- El jugador saliente y el entrante deben pertenecer a la misma formación.' + @salto;

        -- Validaciones del jugador saliente
        IF @idFormSaliente IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1
                       FROM jugadores.Sustitucion AS s
                       WHERE s.IdPartido = @idPartido
                         AND s.IdJugadorSaliente = @idJugadorSaliente
                         AND (@idSustitucionExcluir IS NULL OR s.IdSustitucion <> @idSustitucionExcluir))
                SET @errores += N'- El jugador saliente ya fue reemplazado en este partido.' + @salto;

            IF @estadoSaliente = 'Suplente'
               AND (@minuto IS NULL
                    OR NOT EXISTS (SELECT 1
                                   FROM jugadores.Sustitucion AS sIn
                                   WHERE sIn.IdPartido = @idPartido
                                     AND sIn.IdJugadorEntrante = @idJugadorSaliente
                                     AND (@idSustitucionExcluir IS NULL OR sIn.IdSustitucion <> @idSustitucionExcluir)
                                     AND sIn.Minuto < @minuto))
                SET @errores += N'- El jugador saliente es suplente y no había ingresado al campo antes de ese minuto.' + @salto;

            IF @minuto IS NOT NULL
               AND EXISTS (SELECT 1
                           FROM eventos.Amonestacion AS a
                           INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                           WHERE a.IdPartido = @idPartido
                             AND a.IdJugador = @idJugadorSaliente
                             AND t.Tipo IN ('Roja por doble amarilla', 'Roja directa')
                             AND a.Minuto <= @minuto)
                SET @errores += N'- El jugador saliente ya estaba expulsado y no puede ser sustituido.' + @salto;
        END;

        -- Validaciones del jugador entrante
        IF @idFormEntrante IS NOT NULL
        BEGIN
            IF @estadoEntrante <> 'Suplente'
                SET @errores += N'- El jugador entrante debe estar registrado como Suplente en la formación.' + @salto;

            IF EXISTS (SELECT 1
                       FROM jugadores.Sustitucion AS s
                       WHERE s.IdPartido = @idPartido
                         AND s.IdJugadorEntrante = @idJugadorEntrante
                         AND (@idSustitucionExcluir IS NULL OR s.IdSustitucion <> @idSustitucionExcluir))
                SET @errores += N'- El jugador entrante ya ingresó previamente en este partido.' + @salto;

            IF @minuto IS NOT NULL
               AND EXISTS (SELECT 1
                           FROM eventos.Amonestacion AS a
                           INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                           WHERE a.IdPartido = @idPartido
                             AND a.IdJugador = @idJugadorEntrante
                             AND t.Tipo IN ('Roja por doble amarilla', 'Roja directa')
                             AND a.Minuto <= @minuto)
                SET @errores += N'- El jugador entrante fue expulsado y no puede ingresar.' + @salto;
        END;

        -- Validación de cupos de cambios y ventanas de la selección en ese período
        IF @idFormSaliente IS NOT NULL AND @idFormSaliente = @idFormEntrante
           AND @maxCambiosReg IS NOT NULL AND @periodo IN ('Regular', 'Suplementario') AND @minuto IS NOT NULL
        BEGIN
            SELECT @cambiosRealizados = COUNT(*),
                   @ventanasUsadas    = COUNT(DISTINCT s.Minuto),
                   @mismaVentana      = CASE WHEN EXISTS (
                                            SELECT 1
                                            FROM jugadores.Sustitucion AS s2
                                            INNER JOIN jugadores.FormacionJugador AS fj2
                                                ON fj2.IdFormacion = @idFormSaliente AND fj2.IdJugador = s2.IdJugadorSaliente
                                            WHERE s2.IdPartido = @idPartido
                                              AND s2.Periodo = @periodo
                                              AND s2.Minuto = @minuto
                                              AND (@idSustitucionExcluir IS NULL OR s2.IdSustitucion <> @idSustitucionExcluir)
                                        ) THEN 1 ELSE 0 END
            FROM jugadores.Sustitucion AS s
            INNER JOIN jugadores.FormacionJugador AS fj
                ON fj.IdFormacion = @idFormSaliente AND fj.IdJugador = s.IdJugadorSaliente
            WHERE s.IdPartido = @idPartido
              AND s.Periodo = @periodo
              AND (@idSustitucionExcluir IS NULL OR s.IdSustitucion <> @idSustitucionExcluir);

            IF @periodo = 'Regular'
            BEGIN
                IF @cambiosRealizados >= @maxCambiosReg
                    SET @errores += N'- La selección ya alcanzó el máximo de cambios permitidos en tiempo regular ('
                                    + CAST(@maxCambiosReg AS NVARCHAR(10)) + N').' + @salto;

                IF @mismaVentana = 0 AND @ventanasUsadas >= @maxVentanasReg
                    SET @errores += N'- La selección ya utilizó el máximo de ventanas de cambios en tiempo regular ('
                                    + CAST(@maxVentanasReg AS NVARCHAR(10)) + N').' + @salto;
            END
            ELSE
            BEGIN
                IF @cambiosRealizados >= @maxCambiosSup
                    SET @errores += N'- La selección ya alcanzó el máximo de cambios permitidos en tiempo suplementario ('
                                    + CAST(@maxCambiosSup AS NVARCHAR(10)) + N').' + @salto;

                IF @mismaVentana = 0 AND @ventanasUsadas >= @maxVentanasSup
                    SET @errores += N'- La selección ya utilizó el máximo de ventanas de cambios en tiempo suplementario ('
                                    + CAST(@maxVentanasSup AS NVARCHAR(10)) + N').' + @salto;
            END;
        END;
    END;

    RETURN @errores;
END;
GO