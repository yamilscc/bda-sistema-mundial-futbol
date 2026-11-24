/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-21
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Carga inicial (Seed Data) idempotente para los módulos de jugadores y eventos
          (Entrega 6), reutilizando los SP de la Entrega 5 sin SQL dinámico ni cursores:
          - Reglas y catálogos (ReglaConvocados, ReglaCambios, ReglaSuspension, TipoGol,
            Periodo, Tarjeta).
          - Plantel completo de 23 convocados por selección (16 x 23 = 368 convocados).
          - Formaciones titulares (11 con 1 arquero) y suplentes (7) de todos los partidos
            definidos (24 partidos), excluyendo jugadores suspendidos.
          - Sustituciones, goles y amonestaciones cubriendo los 4 casos obligatorios de juego:
            1) Expulsión por doble amarilla.
            2) Expulsión por roja directa.
            3) Jugador suspendido por acumulación fuera de la titular del partido siguiente.
            4) Cambio por lesión antes del minuto 20.
          Requiere ejecutados los scripts 01 a 24 y cargadas previamente las selecciones y
          partidos en estado 'Programado' (módulo nucleo).
*/

USE MundialFutbol;
GO

SET NOCOUNT ON;

-- =========================================================================
-- 1. REGLAS Y CATÁLOGOS DE JUGADORES Y EVENTOS (IDEMPOTENTE)
-- =========================================================================
DECLARE @idReglaConv INT,
        @idReglaCamb INT,
        @idReglaSusp INT,
        @idTipoGol   INT,
        @idPeriodo   INT,
        @idTarjeta   INT;

IF NOT EXISTS (SELECT 1 FROM jugadores.ReglaConvocados)
    EXEC jugadores.SP_ALTA_ReglaConvocados
        @idRegla   = @idReglaConv OUTPUT,
        @minimo    = 23,
        @maximo    = 26;

IF NOT EXISTS (SELECT 1 FROM jugadores.ReglaCambios)
    EXEC jugadores.SP_ALTA_ReglaCambios
        @idRegla                  = @idReglaCamb OUTPUT,
        @maxCambiosRegular        = 5,
        @maxVentanasRegular       = 3,
        @maxCambiosSuplementario  = 1,
        @maxVentanasSuplementario = 1;

IF NOT EXISTS (SELECT 1 FROM eventos.ReglaSuspension WHERE Criterio = 'Acumulacion Amarillas')
    EXEC eventos.SP_ALTA_ReglaSuspension
        @idReglaSuspension  = @idReglaSusp OUTPUT,
        @criterio           = 'Acumulacion Amarillas',
        @cantidadAmarillas  = 2,
        @partidosSuspension = 1;

IF NOT EXISTS (SELECT 1 FROM eventos.ReglaSuspension WHERE Criterio = 'Doble Amarilla')
    EXEC eventos.SP_ALTA_ReglaSuspension
        @idReglaSuspension  = @idReglaSusp OUTPUT,
        @criterio           = 'Doble Amarilla',
        @cantidadAmarillas  = NULL,
        @partidosSuspension = 1;

IF NOT EXISTS (SELECT 1 FROM eventos.ReglaSuspension WHERE Criterio = 'Roja Directa')
    EXEC eventos.SP_ALTA_ReglaSuspension
        @idReglaSuspension  = @idReglaSusp OUTPUT,
        @criterio           = 'Roja Directa',
        @cantidadAmarillas  = NULL,
        @partidosSuspension = 2;

-- Catálogo TipoGol
DECLARE @tiposGol TABLE (IdOrden INT IDENTITY(1,1) PRIMARY KEY, Descripcion VARCHAR(30));
INSERT INTO @tiposGol (Descripcion)
VALUES ('Jugada'), ('Penal'), ('Tiro Libre'), ('Cabezazo'), ('En contra');

DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @tiposGol), @desc VARCHAR(30);
WHILE @i <= @n
BEGIN
    SELECT @desc = Descripcion FROM @tiposGol WHERE IdOrden = @i;
    IF NOT EXISTS (SELECT 1 FROM eventos.TipoGol WHERE Descripcion = @desc)
        EXEC eventos.SP_ALTA_TipoGol @idTipoGol = @idTipoGol OUTPUT, @descripcion = @desc;
    SET @i += 1;
END;

-- Catálogo Periodo
DECLARE @periodos TABLE (IdOrden INT IDENTITY(1,1) PRIMARY KEY, Descripcion VARCHAR(30));
INSERT INTO @periodos (Descripcion)
VALUES ('Primer Tiempo'), ('Segundo Tiempo'), ('Adicional PT'), ('Adicional ST'),
       ('Alargue PT'), ('Alargue ST'), ('Definicion por Penales');

SET @i = 1;
SET @n = (SELECT COUNT(*) FROM @periodos);
WHILE @i <= @n
BEGIN
    SELECT @desc = Descripcion FROM @periodos WHERE IdOrden = @i;
    IF NOT EXISTS (SELECT 1 FROM eventos.Periodo WHERE Descripcion = @desc)
        EXEC eventos.SP_ALTA_Periodo @idPeriodo = @idPeriodo OUTPUT, @descripcion = @desc;
    SET @i += 1;
END;

-- Catálogo Tarjeta
DECLARE @tarjetas TABLE (IdOrden INT IDENTITY(1,1) PRIMARY KEY, Tipo VARCHAR(30));
INSERT INTO @tarjetas (Tipo)
VALUES ('Amarilla'), ('Roja por doble amarilla'), ('Roja directa');

SET @i = 1;
SET @n = (SELECT COUNT(*) FROM @tarjetas);
WHILE @i <= @n
BEGIN
    SELECT @desc = Tipo FROM @tarjetas WHERE IdOrden = @i;
    IF NOT EXISTS (SELECT 1 FROM eventos.Tarjeta WHERE Tipo = @desc)
        EXEC eventos.SP_ALTA_Tarjeta @idTarjeta = @idTarjeta OUTPUT, @tipo = @desc;
    SET @i += 1;
END;

-- =========================================================================
-- 2. COMPLETAR 23 CONVOCADOS POR SELECCIÓN (16 x 23 = 368 CONVOCADOS)
-- Respeta los jugadores ya importados vía XML y completa los dorsales 1..23.
-- =========================================================================
DECLARE @clubesSeed TABLE (IdOrden INT IDENTITY(1,1) PRIMARY KEY, Nombre VARCHAR(100));
INSERT INTO @clubesSeed (Nombre)
VALUES ('Real Madrid'), ('Manchester City'), ('Bayern Munich'), ('Paris Saint-Germain'),
       ('Liverpool'), ('FC Barcelona'), ('Inter de Milan'), ('Atletico de Madrid'),
       ('Arsenal'), ('Boca Juniors'), ('River Plate'), ('Flamengo');

SET @i = 1;
SET @n = (SELECT COUNT(*) FROM @clubesSeed);
DECLARE @nombreClub VARCHAR(100), @idClubSeed INT;

WHILE @i <= @n
BEGIN
    SELECT @nombreClub = Nombre FROM @clubesSeed WHERE IdOrden = @i;
    IF NOT EXISTS (SELECT 1 FROM jugadores.Club WHERE Nombre = @nombreClub)
        EXEC jugadores.SP_ALTA_Club @idClub = @idClubSeed OUTPUT, @nombre = @nombreClub;
    SET @i += 1;
END;

DECLARE @selecciones TABLE (
    IdOrden     INT IDENTITY(1,1) PRIMARY KEY,
    IdSeleccion INT     NOT NULL,
    CodigoISO3  CHAR(3) NOT NULL
);

INSERT INTO @selecciones (IdSeleccion, CodigoISO3)
SELECT s.IdSeleccion, p.CodigoISO3
FROM nucleo.Seleccion AS s
INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais
ORDER BY s.IdSeleccion;

DECLARE @idxSel       INT = 1,
        @totSel       INT = (SELECT COUNT(*) FROM @selecciones),
        @idSelActual  INT,
        @isoActual    CHAR(3),
        @dorsal       INT,
        @activosSel   INT,
        @docJug       VARCHAR(20),
        @nomJug       VARCHAR(60),
        @apeJug       VARCHAR(60),
        @posJug       VARCHAR(20),
        @fecNacJug    DATE,
        @idClubJug    INT,
        @idJugNuevo   INT,
        @idConvNueva  INT;

WHILE @idxSel <= @totSel
BEGIN
    SELECT @idSelActual = IdSeleccion,
           @isoActual   = CodigoISO3
    FROM @selecciones
    WHERE IdOrden = @idxSel;

    SELECT @activosSel = COUNT(*)
    FROM jugadores.Convocatoria AS c
    WHERE c.IdSeleccion = @idSelActual
      AND NOT EXISTS (SELECT 1 FROM jugadores.Baja AS b WHERE b.IdConvocatoria = c.IdConvocatoria);

    SET @dorsal = 1;
    WHILE @dorsal <= 23 AND @activosSel < 23
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM jugadores.Convocatoria
            WHERE IdSeleccion = @idSelActual
              AND Dorsal = @dorsal
        )
        BEGIN
            SET @docJug = RTRIM(@isoActual) + '-SEED-' + RIGHT('00' + CAST(@dorsal AS VARCHAR(2)), 2);
            SET @nomJug = 'Jugador ' + CAST(@dorsal AS VARCHAR(2));
            SET @apeJug = RTRIM(@isoActual) + ' ' + CAST(@dorsal AS VARCHAR(2));

            -- Distribución equilibrada: 3 Arqueros, 8 Defensores, 7 Mediocampistas, 5 Delanteros
            SET @posJug = CASE
                WHEN @dorsal IN (1, 12, 23) THEN 'Arquero'
                WHEN @dorsal IN (2, 3, 4, 6, 13, 14, 15, 16) THEN 'Defensor'
                WHEN @dorsal IN (5, 7, 8, 10, 17, 18, 20) THEN 'Mediocampista'
                ELSE 'Delantero'
            END;

            SET @fecNacJug = DATEADD(DAY, -((22 * 365) + (@dorsal * 110) + (@idxSel * 17)), '2026-06-01');

            SELECT TOP (1) @idClubJug = IdClub
            FROM jugadores.Club
            ORDER BY (IdClub + @dorsal + @idxSel) % 12, IdClub;

            SET @idJugNuevo = NULL;   -- un SELECT sin filas no pisa la variable: sin esto queda el jugador de la vuelta anterior
            SELECT @idJugNuevo = IdJugador FROM jugadores.Jugador WHERE Documento = @docJug;

            IF @idJugNuevo IS NULL
                EXEC jugadores.SP_ALTA_Jugador
                    @idJugador       = @idJugNuevo OUTPUT,
                    @nombre          = @nomJug,
                    @apellido        = @apeJug,
                    @documento       = @docJug,
                    @fechaNacimiento = @fecNacJug,
                    @sexo            = 'M',
                    @posicion        = @posJug,
                    @idClub          = @idClubJug;

            EXEC jugadores.SP_CONVOCAR_JUGADOR
                @idSeleccion    = @idSelActual,
                @idJugador      = @idJugNuevo,
                @dorsal         = @dorsal,
                @fechaAlta      = '2026-05-20',
                @idConvocatoria = @idConvNueva OUTPUT;

            SET @activosSel += 1;
        END;

        SET @dorsal += 1;
    END;

    SET @idxSel += 1;
END;

-- =========================================================================
-- 3. CASO OBLIGATORIO DE SUSPENSIÓN POR ACUMULACIÓN + EVENTOS Y FORMACIONES
--    DE LOS 24 PARTIDOS EN ORDEN CRONOLÓGICO
-- =========================================================================
-- Identificar una selección que dispute al menos 3 partidos para aplicar
-- acumulación de amarillas en sus partidos 1 y 2, y verificar que el jugador
-- quede fuera de la formación en su partido 3.
DECLARE @idSelAcum      INT = NULL,
        @idJugAcum      INT = NULL,
        @idPartidoAcum1 INT = NULL,
        @idPartidoAcum2 INT = NULL;

SELECT TOP (1) @idSelAcum = s.IdSeleccion
FROM nucleo.Seleccion AS s
WHERE (
    SELECT COUNT(*)
    FROM nucleo.Partido AS p
    WHERE p.Estado = 'Programado'
      AND s.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
) >= 3
ORDER BY s.IdSeleccion;

IF @idSelAcum IS NOT NULL
BEGIN
    SELECT TOP (1) @idJugAcum = c.IdJugador
    FROM jugadores.Convocatoria AS c
    INNER JOIN jugadores.Jugador AS j ON j.IdJugador = c.IdJugador
    WHERE c.IdSeleccion = @idSelAcum
      AND j.Posicion = 'Mediocampista'
      AND NOT EXISTS (SELECT 1 FROM jugadores.Baja AS b WHERE b.IdConvocatoria = c.IdConvocatoria)
    ORDER BY c.Dorsal;

    ;WITH PartidosSel AS (
        SELECT p.IdPartido,
               ROW_NUMBER() OVER (ORDER BY p.FechaHoraUTC ASC, p.NumeroPartido ASC) AS NroEncuentro
        FROM nucleo.Partido AS p
        WHERE p.Estado = 'Programado'
          AND @idSelAcum IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
    )
    SELECT @idPartidoAcum1 = MAX(CASE WHEN NroEncuentro = 1 THEN IdPartido END),
           @idPartidoAcum2 = MAX(CASE WHEN NroEncuentro = 2 THEN IdPartido END)
    FROM PartidosSel;
END;

-- Tabla temporal en memoria con los partidos programados en orden cronológico
DECLARE @partidos TABLE (
    IdOrden              INT IDENTITY(1,1) PRIMARY KEY,
    IdPartido            INT NOT NULL,
    NumeroPartido        INT NOT NULL,
    IdSeleccionLocal     INT NOT NULL,
    IdSeleccionVisitante INT NOT NULL
);

INSERT INTO @partidos (IdPartido, NumeroPartido, IdSeleccionLocal, IdSeleccionVisitante)
SELECT IdPartido, NumeroPartido, IdSeleccionLocal, IdSeleccionVisitante
FROM nucleo.Partido
WHERE Estado = 'Programado'
  AND IdSeleccionLocal IS NOT NULL
  AND IdSeleccionVisitante IS NOT NULL
ORDER BY FechaHoraUTC ASC, NumeroPartido ASC;

DECLARE @idxPart       INT = 1,
        @totPart       INT = (SELECT COUNT(*) FROM @partidos),
        @idPart        INT,
        @numPart       INT,
        @idLoc         INT,
        @idVis         INT,
        @lado          INT,
        @localia       VARCHAR(9),
        @idSelLado     INT,
        @idForm        INT,
        @idxPlantilla  INT,
        @totPlantilla  INT,
        @idJugPlant    INT,
        @posPlant      VARCHAR(20),
        @estTit        VARCHAR(8),
        @posCampo      VARCHAR(20),
        @idJugSal      INT,
        @idJugEnt      INT,
        @idJugGol1     INT,
        @idJugAsist1   INT,
        @idJugCard1    INT,
        @idJugCard2    INT,
        @idSustOut     INT,
        @idGolOut      INT,
        @idAmonOut     INT;

DECLARE @plantilla TABLE (
    IdOrden     INT PRIMARY KEY,   -- sin IDENTITY: DELETE no lo reinicia y el segundo equipo empezaría en 19
    IdJugador   INT         NOT NULL,
    Posicion    VARCHAR(20) NOT NULL
);

WHILE @idxPart <= @totPart
BEGIN
    SELECT @idPart = IdPartido,
           @numPart = NumeroPartido,
           @idLoc  = IdSeleccionLocal,
           @idVis  = IdSeleccionVisitante
    FROM @partidos
    WHERE IdOrden = @idxPart;

    -- 3.A Cargar formación Local (lado = 1) y Visitante (lado = 2)
    SET @lado = 1;
    WHILE @lado <= 2
    BEGIN
        SET @localia   = CASE WHEN @lado = 1 THEN 'Local' ELSE 'Visitante' END;
        SET @idSelLado = CASE WHEN @lado = 1 THEN @idLoc  ELSE @idVis      END;

        IF NOT EXISTS (
            SELECT 1
            FROM jugadores.Formacion
            WHERE IdPartido = @idPart
              AND Localia = @localia
        )
        BEGIN
            EXEC jugadores.SP_REGISTRAR_FORMACION
                @idPartido               = @idPart,
                @localia                 = @localia,
                @esquemaTactico          = '4-3-3',
                @validarMinimoConvocados = 1,
                @idFormacion             = @idForm OUTPUT;

            DELETE FROM @plantilla;

            -- Seleccionar 1 Arquero, 4 Defensores, 3 Mediocampistas, 3 Delanteros (11 titulares)
            -- + 7 suplentes entre convocados activos NO suspendidos para este partido.
            ;WITH Elegibles AS (
                SELECT c.IdJugador,
                       j.Posicion,
                       c.Dorsal,
                       ROW_NUMBER() OVER (PARTITION BY j.Posicion ORDER BY c.Dorsal ASC) AS RnPos
                FROM jugadores.Convocatoria AS c
                INNER JOIN jugadores.Jugador AS j ON j.IdJugador = c.IdJugador
                WHERE c.IdSeleccion = @idSelLado
                  AND NOT EXISTS (SELECT 1 FROM jugadores.Baja AS b WHERE b.IdConvocatoria = c.IdConvocatoria)
                  AND eventos.fn_EstaSuspendido(c.IdJugador, @idPart) = 0
            ),
            Titulares AS (
                SELECT IdJugador, Posicion, Dorsal, 1 AS EsTitular
                FROM Elegibles
                WHERE (Posicion = 'Arquero'       AND RnPos = 1)
                   OR (Posicion = 'Defensor'      AND RnPos <= 4)
                   OR (Posicion = 'Mediocampista' AND RnPos <= 3)
                   OR (Posicion = 'Delantero'     AND RnPos <= 3)
            ),
            Suplentes AS (
                SELECT TOP (7) e.IdJugador, e.Posicion, e.Dorsal, 0 AS EsTitular
                FROM Elegibles AS e
                WHERE NOT EXISTS (SELECT 1 FROM Titulares AS t WHERE t.IdJugador = e.IdJugador)
                ORDER BY e.Dorsal ASC
            )
            INSERT INTO @plantilla (IdOrden, IdJugador, Posicion)
            SELECT ROW_NUMBER() OVER (ORDER BY u.EsTitular DESC, u.Dorsal ASC), IdJugador, Posicion
            FROM (
                SELECT IdJugador, Posicion, Dorsal, EsTitular FROM Titulares
                UNION ALL
                SELECT IdJugador, Posicion, Dorsal, EsTitular FROM Suplentes
            ) AS u
            ORDER BY u.EsTitular DESC, u.Dorsal ASC;

            SET @idxPlantilla = 1;
            SET @totPlantilla = (SELECT COUNT(*) FROM @plantilla);

            WHILE @idxPlantilla <= @totPlantilla
            BEGIN
                SELECT @idJugPlant = IdJugador,
                       @posPlant   = Posicion
                FROM @plantilla
                WHERE IdOrden = @idxPlantilla;

                IF @idxPlantilla <= 11
                BEGIN
                    SET @estTit   = 'Titular';
                    SET @posCampo = @posPlant;
                END
                ELSE
                BEGIN
                    SET @estTit   = 'Suplente';
                    SET @posCampo = NULL;
                END;

                EXEC jugadores.SP_AGREGAR_JUGADOR_FORMACION
                    @idFormacion       = @idForm,
                    @idJugador         = @idJugPlant,
                    @estadoTitularidad = @estTit,
                    @posicionEnCampo   = @posCampo,
                    @dorsal            = NULL;

                SET @idxPlantilla += 1;
            END;
        END;

        SET @lado += 1;
    END;

    -- 3.B Casos obligatorios en el primer partido cronológico (@idxPart = 1)
    IF @idxPart = 1
    BEGIN
        -- Caso obligatorio 4: Cambio por lesión antes del minuto 20 (Local, min 14)
        SELECT TOP (1) @idJugSal = fj.IdJugador
        FROM jugadores.Formacion AS f
        INNER JOIN jugadores.FormacionJugador AS fj ON fj.IdFormacion = f.IdFormacion
        WHERE f.IdPartido = @idPart
          AND f.Localia = 'Local'
          AND fj.EstadoTitularidad = 'Titular'
          AND fj.PosicionEnCampo = 'Defensor'
        ORDER BY fj.Dorsal ASC;

        SELECT TOP (1) @idJugEnt = fj.IdJugador
        FROM jugadores.Formacion AS f
        INNER JOIN jugadores.FormacionJugador AS fj ON fj.IdFormacion = f.IdFormacion
        WHERE f.IdPartido = @idPart
          AND f.Localia = 'Local'
          AND fj.EstadoTitularidad = 'Suplente'
        ORDER BY fj.Dorsal ASC;

        IF @idJugSal IS NOT NULL AND @idJugEnt IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM jugadores.Sustitucion WHERE IdPartido = @idPart AND Minuto = 14)
        BEGIN
            EXEC jugadores.SP_REGISTRAR_SUSTITUCION
                @idPartido           = @idPart,
                @idJugadorSaliente   = @idJugSal,
                @idJugadorEntrante   = @idJugEnt,
                @minuto              = 14,
                @periodo             = 'Regular',
                @motivo              = 'Lesion',
                @permitirFechaFutura = 1,
                @idSustitucion       = @idSustOut OUTPUT;
        END;

        -- Caso obligatorio 1: Expulsión por doble amarilla (Local, min 24 y 61)
        SELECT TOP (1) @idJugCard1 = fj.IdJugador
        FROM jugadores.Formacion AS f
        INNER JOIN jugadores.FormacionJugador AS fj ON fj.IdFormacion = f.IdFormacion
        WHERE f.IdPartido = @idPart
          AND f.Localia = 'Local'
          AND fj.EstadoTitularidad = 'Titular'
          AND fj.PosicionEnCampo = 'Defensor'
          AND fj.IdJugador <> ISNULL(@idJugSal, -1)
        ORDER BY fj.Dorsal DESC;

        IF @idJugCard1 IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdPartido = @idPart AND IdJugador = @idJugCard1)
        BEGIN
            EXEC eventos.SP_REGISTRAR_AMONESTACION
                @idPartido           = @idPart,
                @tipoTarjeta         = 'Amarilla',
                @minuto              = 24,
                @motivo              = 'Falta tactica en retroceso',
                @idJugador           = @idJugCard1,
                @permitirFechaFutura = 1,
                @idAmonestacion      = @idAmonOut OUTPUT;

            EXEC eventos.SP_REGISTRAR_AMONESTACION
                @idPartido           = @idPart,
                @tipoTarjeta         = 'Amarilla',
                @minuto              = 61,
                @motivo              = 'Segunda amarilla por juego brusco',
                @idJugador           = @idJugCard1,
                @permitirFechaFutura = 1,
                @idAmonestacion      = @idAmonOut OUTPUT;
        END;

        -- Caso obligatorio 2: Expulsión por roja directa (Visitante, min 68)
        SELECT TOP (1) @idJugCard2 = fj.IdJugador
        FROM jugadores.Formacion AS f
        INNER JOIN jugadores.FormacionJugador AS fj ON fj.IdFormacion = f.IdFormacion
        WHERE f.IdPartido = @idPart
          AND f.Localia = 'Visitante'
          AND fj.EstadoTitularidad = 'Titular'
          AND fj.PosicionEnCampo = 'Defensor'
        ORDER BY fj.Dorsal ASC;

        IF @idJugCard2 IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdPartido = @idPart AND IdJugador = @idJugCard2)
        BEGIN
            EXEC eventos.SP_REGISTRAR_AMONESTACION
                @idPartido           = @idPart,
                @tipoTarjeta         = 'Roja directa',
                @minuto              = 68,
                @motivo              = 'Conducta violenta',
                @idJugador           = @idJugCard2,
                @permitirFechaFutura = 1,
                @idAmonestacion      = @idAmonOut OUTPUT;
        END;
    END;

    -- 3.C Caso obligatorio 3: Acumulación de amarillas (partidos 1 y 2 de @idSelAcum)
    IF @idJugAcum IS NOT NULL AND @idPart IN (@idPartidoAcum1, @idPartidoAcum2)
       AND NOT EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdPartido = @idPart AND IdJugador = @idJugAcum)
    BEGIN
        EXEC eventos.SP_REGISTRAR_AMONESTACION
            @idPartido           = @idPart,
            @tipoTarjeta         = 'Amarilla',
            @minuto              = 42,
            @motivo              = 'Amonestacion por infraccion reiterada',
            @idJugador           = @idJugAcum,
            @permitirFechaFutura = 1,
            @idAmonestacion      = @idAmonOut OUTPUT;
    END;

    -- 3.D Goles y sustitución táctica estándar en cada partido
    SELECT TOP (1) @idJugGol1 = fj.IdJugador
    FROM jugadores.Formacion AS f
    INNER JOIN jugadores.FormacionJugador AS fj ON fj.IdFormacion = f.IdFormacion
    WHERE f.IdPartido = @idPart
      AND f.Localia = 'Local'
      AND fj.EstadoTitularidad = 'Titular'
      AND fj.PosicionEnCampo = 'Delantero'
    ORDER BY fj.Dorsal ASC;

    SELECT TOP (1) @idJugAsist1 = fj.IdJugador
    FROM jugadores.Formacion AS f
    INNER JOIN jugadores.FormacionJugador AS fj ON fj.IdFormacion = f.IdFormacion
    WHERE f.IdPartido = @idPart
      AND f.Localia = 'Local'
      AND fj.EstadoTitularidad = 'Titular'
      AND fj.PosicionEnCampo = 'Mediocampista'
      AND fj.IdJugador <> ISNULL(@idJugAcum, -1)
    ORDER BY fj.Dorsal ASC;

    IF @idJugGol1 IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM eventos.Gol WHERE IdPartido = @idPart AND Minuto = 33)
    BEGIN
        EXEC eventos.SP_REGISTRAR_GOL
            @idPartido           = @idPart,
            @idJugadorAutor      = @idJugGol1,
            @tipoGol             = 'Jugada',
            @periodo             = 'Primer Tiempo',
            @minuto              = 33,
            @idJugadorAsistencia = @idJugAsist1,
            @permitirFechaFutura = 1,
            @idGol               = @idGolOut OUTPUT;
    END;

    -- Cambio táctico en Visitante al minuto 65
    SELECT TOP (1) @idJugSal = fj.IdJugador
    FROM jugadores.Formacion AS f
    INNER JOIN jugadores.FormacionJugador AS fj ON fj.IdFormacion = f.IdFormacion
    WHERE f.IdPartido = @idPart
      AND f.Localia = 'Visitante'
      AND fj.EstadoTitularidad = 'Titular'
      AND fj.PosicionEnCampo = 'Delantero'
    ORDER BY fj.Dorsal ASC;

    SELECT TOP (1) @idJugEnt = fj.IdJugador
    FROM jugadores.Formacion AS f
    INNER JOIN jugadores.FormacionJugador AS fj ON fj.IdFormacion = f.IdFormacion
    WHERE f.IdPartido = @idPart
      AND f.Localia = 'Visitante'
      AND fj.EstadoTitularidad = 'Suplente'
    ORDER BY fj.Dorsal ASC;

    IF @idJugSal IS NOT NULL AND @idJugEnt IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM jugadores.Sustitucion WHERE IdPartido = @idPart AND Minuto = 65)
    BEGIN
        EXEC jugadores.SP_REGISTRAR_SUSTITUCION
            @idPartido           = @idPart,
            @idJugadorSaliente   = @idJugSal,
            @idJugadorEntrante   = @idJugEnt,
            @minuto              = 65,
            @periodo             = 'Regular',
            @motivo              = 'Tactico',
            @permitirFechaFutura = 1,
            @idSustitucion       = @idSustOut OUTPUT;
    END;

    SET @idxPart += 1;
END;

-- Resumen de verificación de volúmenes y casos obligatorios cargados
SELECT (SELECT COUNT(*) FROM jugadores.Convocatoria AS c
        WHERE NOT EXISTS (SELECT 1 FROM jugadores.Baja AS b WHERE b.IdConvocatoria = c.IdConvocatoria)) AS ConvocadosActivos,
       (SELECT COUNT(*) FROM jugadores.Formacion)                                                       AS FormacionesCargadas,
       (SELECT COUNT(*) FROM jugadores.Sustitucion)                                                     AS SustitucionesCargadas,
       (SELECT COUNT(*) FROM eventos.Gol)                                                               AS GolesCargados,
       (SELECT COUNT(*) FROM eventos.Amonestacion)                                                      AS TarjetasCargadas;
GO