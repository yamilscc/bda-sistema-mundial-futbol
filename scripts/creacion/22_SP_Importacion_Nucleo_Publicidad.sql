/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-23
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Procesos de importación de los módulos nucleo y publicidad (sin SQL dinámico ni cursores):
          1. nucleo.SP_IMPORTAR_PBI_JSON          -> API Banco Mundial (NY.GDP.PCAP.CD), actualiza Pais.PBIPerCapitaUSD.
          2. publicidad.SP_IMPORTAR_COTIZACIONES_JSON -> API Frankfurter, carga publicidad.CotizacionMoneda.
          3. publicidad.SP_IMPORTAR_PAUTA_JSON    -> convierte montos a la moneda destino en T-SQL y carga
                                                    publicidad.EspacioPublicitario con SP_ABM_EspacioPublicitario.
          4. nucleo.SP_IMPORTAR_FIXTURE_CSV       -> web scraping (fixture_sedes.csv): Upsert de Ciudad, Sede y Partido.
          Todos son idempotentes (Upsert por clave natural) y registran los errores por fila en
          eventos.LogImportacion sin abortar el lote válido.
          Requiere ejecutados los scripts 01 a 21.
          Test correspondiente: testing/22_Test_SP_Importacion_Nucleo_Publicidad.sql.
*/
USE MundialFutbol;
GO

-- =========================================================================
-- Objetos auxiliares
-- =========================================================================
-- Staging del fixture (CSV). Mismo patrón que eventos.StagingEvento: NombreArchivo con default
-- 'PENDIENTE' para cargar por BULK INSERT estático a través de una vista de aterrizaje.
IF OBJECT_ID('eventos.StagingFixture', 'U') IS NULL
CREATE TABLE eventos.StagingFixture (
    IdFila             INT IDENTITY(1,1) CONSTRAINT PK_StagingFixture PRIMARY KEY,
    NombreArchivo      VARCHAR(255) NOT NULL CONSTRAINT DF_StagingFixture_NombreArchivo DEFAULT ('PENDIENTE'),
    NumeroPartido      VARCHAR(20)  NULL,
    Fase               VARCHAR(50)  NULL,
    NombreEstadio      VARCHAR(100) NULL,
    Ciudad             VARCHAR(100) NULL,
    PaisISO3           VARCHAR(10)  NULL,
    HusoHorario        VARCHAR(50)  NULL,
    Capacidad          VARCHAR(20)  NULL,
    Latitud            VARCHAR(20)  NULL,
    Longitud           VARCHAR(20)  NULL,
    FechaHoraLocal     VARCHAR(30)  NULL,
    SeleccionLocal     VARCHAR(10)  NULL,
    SeleccionVisitante VARCHAR(10)  NULL
);
GO

CREATE OR ALTER VIEW eventos.vw_CargaStagingFixture
AS
SELECT NumeroPartido, Fase, NombreEstadio, Ciudad, PaisISO3, HusoHorario, Capacidad,
       Latitud, Longitud, FechaHoraLocal, SeleccionLocal, SeleccionVisitante
FROM eventos.StagingFixture;
GO

-- Cotizaciones de Frankfurter: 1 unidad de MonedaBase = Tasa unidades de Moneda, a la Fecha indicada.
IF OBJECT_ID('publicidad.CotizacionMoneda', 'U') IS NULL
CREATE TABLE publicidad.CotizacionMoneda (
    MonedaBase CHAR(3)       NOT NULL,
    Moneda     CHAR(3)       NOT NULL,
    Fecha      DATE          NOT NULL,
    Tasa       DECIMAL(18,8) NOT NULL,
    CONSTRAINT PK_CotizacionMoneda PRIMARY KEY (MonedaBase, Moneda, Fecha),
    CONSTRAINT CK_CotizacionMoneda_Tasa CHECK (Tasa > 0),
    CONSTRAINT FK_CotizacionMoneda_MonedaBase FOREIGN KEY (MonedaBase) REFERENCES publicidad.Moneda (Codigo),
    CONSTRAINT FK_CotizacionMoneda_Moneda     FOREIGN KEY (Moneda)     REFERENCES publicidad.Moneda (Codigo)
);
GO

-- =========================================================================
-- nucleo.SP_IMPORTAR_PBI_JSON
-- Entrada: respuesta cruda de https://api.worldbank.org/v2/country/<ISO2;...>/indicator/NY.GDP.PCAP.CD?format=json
--          (arreglo de 2 elementos: [metadatos, [registros]]).
-- Clave natural: country.id del Banco Mundial = Pais.CodigoISO2. (Se usa ISO2 y no ISO3 porque algunos
--          CodigoISO3 del torneo son códigos FIFA: NED, GER, ENG, SUI, CHI, etc.)
-- Por país toma el último año con valor no nulo y actualiza PBIPerCapitaUSD con SP_ABM_Pais.
-- Si el PBI no cambió no vuelve a modificar (idempotente).
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_IMPORTAR_PBI_JSON
    @nombreArchivo   VARCHAR(255),
    @contenidoJSON   NVARCHAR(MAX),
    @filasProcesadas INT = NULL OUTPUT,
    @filasConError   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @filasProcesadas = 0;
    SET @filasConError   = 0;
    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombreArchivo IS NULL OR LTRIM(RTRIM(@nombreArchivo)) = ''
        SET @errores += N'- El nombre del archivo es obligatorio.' + @salto;
    IF @contenidoJSON IS NULL OR ISJSON(@contenidoJSON) <> 1
        SET @errores += N'- El contenido no es un JSON válido.' + @salto;
    ELSE IF NOT EXISTS (SELECT 1 FROM OPENJSON(@contenidoJSON, '$[1]'))
        SET @errores += N'- El JSON no contiene registros de PBI (respuesta de error o vacía de la API).' + @salto;
    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_IMPORTAR_PBI_JSON - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- Un registro por país: el último año con valor no nulo (si no hay ninguno, queda el más reciente con valor NULL).
    DECLARE @paises TABLE (
        IdOrden INT IDENTITY(1,1) PRIMARY KEY,
        Iso2    VARCHAR(10),
        Anio    VARCHAR(10),
        Valor   VARCHAR(40),
        Cruda   NVARCHAR(MAX)
    );
    ;WITH Registros AS (
        SELECT j.Iso2, j.Anio, j.Valor, j.Cruda,
               ROW_NUMBER() OVER (PARTITION BY j.Iso2
                                  ORDER BY CASE WHEN j.Valor IS NULL THEN 1 ELSE 0 END, j.Anio DESC) AS Rn
        FROM OPENJSON(@contenidoJSON, '$[1]')
             WITH (Iso2  VARCHAR(10)   '$.country.id',
                   Anio  VARCHAR(10)   '$.date',
                   Valor VARCHAR(40)   '$.value',
                   Cruda NVARCHAR(MAX) '$' AS JSON) AS j
    )
    INSERT INTO @paises (Iso2, Anio, Valor, Cruda)
    SELECT Iso2, Anio, Valor, Cruda FROM Registros WHERE Rn = 1 ORDER BY Iso2;

    DECLARE @i INT = 1,
            @total INT = (SELECT COUNT(*) FROM @paises),
            @iso2 VARCHAR(10), @valor VARCHAR(40), @cruda NVARCHAR(MAX),
            @pbi DECIMAL(10,2), @pbiActual DECIMAL(10,2),
            @idPais INT, @nombre VARCHAR(50), @iso2Pais CHAR(2), @iso3 CHAR(3),
            @idConf INT, @huso VARCHAR(50);

    WHILE @i <= @total
    BEGIN
        SELECT @iso2 = Iso2, @valor = Valor, @cruda = Cruda FROM @paises WHERE IdOrden = @i;
        SET @idPais = NULL;
        BEGIN TRY
            SET @errores = N'';
            SET @pbi = TRY_CONVERT(DECIMAL(10,2), @valor);
            SELECT @idPais = IdPais, @nombre = Nombre, @iso2Pais = CodigoISO2, @iso3 = CodigoISO3,
                   @idConf = IdConfederacion, @huso = HusoHorarioComercial, @pbiActual = PBIPerCapitaUSD
            FROM nucleo.Pais
            WHERE CodigoISO2 = @iso2;
            IF @idPais IS NULL
                SET @errores += N'- No existe un país con código ISO2 ' + ISNULL(@iso2, N'(nulo)') + N'.' + @salto;
            IF @pbi IS NULL
                SET @errores += N'- El PBI informado es nulo o no numérico.' + @salto;
            IF LEN(@errores) > 0
            BEGIN
                SET @mensaje = LEFT(@errores, 2048);
                THROW 52000, @mensaje, 1;
            END;

            IF @pbiActual IS NULL OR @pbiActual <> @pbi
                EXEC nucleo.SP_MODIFICACION_Pais
                    @idPais = @idPais, @nombre = @nombre,
                    @codigoISO2 = @iso2Pais, @codigoISO3 = @iso3, @idConfederacion = @idConf,
                    @husoHorarioComercial = @huso, @pbiPerCapitaUSD = @pbi;
            SET @filasProcesadas += 1;
        END TRY
        BEGIN CATCH
            SET @filasConError += 1;
            INSERT INTO eventos.LogImportacion (NombreArchivo, IdFilaStaging, DatosCrudos, MensajeError)
            VALUES (@nombreArchivo, NULL, @cruda, LEFT(ERROR_MESSAGE(), 500));
        END CATCH;
        SET @i += 1;
    END;
END;
GO

-- =========================================================================
-- publicidad.SP_IMPORTAR_COTIZACIONES_JSON
-- Entrada: respuesta cruda de https://api.frankfurter.app/latest?from=USD&to=EUR,BRL,JPY,GBP
--          {"amount":1.0,"base":"USD","date":"AAAA-MM-DD","rates":{"EUR":0.86,...}}
-- Upsert en publicidad.CotizacionMoneda por (MonedaBase, Moneda, Fecha). También guarda base->base = 1.
-- Las monedas que no estén en publicidad.Moneda se informan como error de fila.
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_IMPORTAR_COTIZACIONES_JSON
    @nombreArchivo   VARCHAR(255),
    @contenidoJSON   NVARCHAR(MAX),
    @filasProcesadas INT = NULL OUTPUT,
    @filasConError   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @filasProcesadas = 0;
    SET @filasConError   = 0;
    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @base    CHAR(3),
            @fecha   DATE;

    IF @nombreArchivo IS NULL OR LTRIM(RTRIM(@nombreArchivo)) = ''
        SET @errores += N'- El nombre del archivo es obligatorio.' + @salto;
    IF @contenidoJSON IS NULL OR ISJSON(@contenidoJSON) <> 1
        SET @errores += N'- El contenido no es un JSON válido.' + @salto;
    ELSE
    BEGIN
        SET @base  = UPPER(JSON_VALUE(@contenidoJSON, '$.base'));
        SET @fecha = TRY_CONVERT(DATE, JSON_VALUE(@contenidoJSON, '$.date'));
        IF @base IS NULL OR NOT EXISTS (SELECT 1 FROM publicidad.Moneda WHERE Codigo = @base)
            SET @errores += N'- La moneda base del JSON no existe en publicidad.Moneda.' + @salto;
        IF @fecha IS NULL
            SET @errores += N'- La fecha de cotización del JSON es obligatoria y debe ser válida.' + @salto;
        IF NOT EXISTS (SELECT 1 FROM OPENJSON(@contenidoJSON, '$.rates'))
            SET @errores += N'- El JSON no contiene cotizaciones (rates).' + @salto;
    END;
    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_IMPORTAR_COTIZACIONES_JSON - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    DECLARE @tasas TABLE (
        IdOrden INT IDENTITY(1,1) PRIMARY KEY,
        Moneda  VARCHAR(10),
        Valor   VARCHAR(40)
    );
    INSERT INTO @tasas (Moneda, Valor) VALUES (@base, '1');
    INSERT INTO @tasas (Moneda, Valor)
    SELECT [key], [value] FROM OPENJSON(@contenidoJSON, '$.rates') ORDER BY [key];

    DECLARE @i INT = 1, @total INT = (SELECT COUNT(*) FROM @tasas),
            @moneda VARCHAR(10), @valor VARCHAR(40), @tasa DECIMAL(18,8);

    WHILE @i <= @total
    BEGIN
        SELECT @moneda = UPPER(Moneda), @valor = Valor FROM @tasas WHERE IdOrden = @i;
        BEGIN TRY
            SET @errores = N'';
            SET @tasa = TRY_CONVERT(DECIMAL(18,8), @valor);
            IF NOT EXISTS (SELECT 1 FROM publicidad.Moneda WHERE Codigo = @moneda)
                SET @errores += N'- La moneda ' + @moneda + N' no existe en publicidad.Moneda.' + @salto;
            IF @tasa IS NULL OR @tasa <= 0
                SET @errores += N'- La cotización de ' + @moneda + N' es nula o no es mayor a cero.' + @salto;
            IF LEN(@errores) > 0
            BEGIN
                SET @mensaje = LEFT(@errores, 2048);
                THROW 52000, @mensaje, 1;
            END;

            IF EXISTS (SELECT 1 FROM publicidad.CotizacionMoneda
                       WHERE MonedaBase = @base AND Moneda = @moneda AND Fecha = @fecha)
                UPDATE publicidad.CotizacionMoneda
                SET Tasa = @tasa
                WHERE MonedaBase = @base AND Moneda = @moneda AND Fecha = @fecha;
            ELSE
                INSERT INTO publicidad.CotizacionMoneda (MonedaBase, Moneda, Fecha, Tasa)
                VALUES (@base, @moneda, @fecha, @tasa);
            SET @filasProcesadas += 1;
        END TRY
        BEGIN CATCH
            SET @filasConError += 1;
            INSERT INTO eventos.LogImportacion (NombreArchivo, IdFilaStaging, DatosCrudos, MensajeError)
            VALUES (@nombreArchivo, NULL, @moneda + N'=' + ISNULL(@valor, N'NULL'), LEFT(ERROR_MESSAGE(), 500));
        END CATCH;
        SET @i += 1;
    END;
END;
GO

-- =========================================================================
-- publicidad.SP_IMPORTAR_PAUTA_JSON
-- Entrada: arreglo JSON de pauta [{"numeroPartido":1,"numeroEspacio":1,"anunciante":"...","titulo":"...",
--          "idioma":"...","monto":100000,"moneda":"EUR"}, ...].
-- Convierte cada monto de su moneda a @monedaDestino en T-SQL con la última cotización disponible de
-- publicidad.CotizacionMoneda (monto / tasa(origen) * tasa(destino), ambas contra la misma base y fecha) y
-- registra el espacio con SP_ABM_EspacioPublicitario (ALTA, o MODIFICACION si (partido, espacio) ya existe).
-- Falla por fila si falta partido, pieza, moneda o cotización (por ejemplo ARS, que Frankfurter no publica).
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_IMPORTAR_PAUTA_JSON
    @nombreArchivo   VARCHAR(255),
    @contenidoJSON   NVARCHAR(MAX),
    @monedaDestino   CHAR(3) = 'USD',
    @filasProcesadas INT = NULL OUTPUT,
    @filasConError   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @filasProcesadas = 0;
    SET @filasConError   = 0;
    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idMonedaDestino INT;

    SET @monedaDestino = UPPER(LTRIM(RTRIM(@monedaDestino)));
    SELECT @idMonedaDestino = IdMoneda FROM publicidad.Moneda WHERE Codigo = @monedaDestino;

    IF @nombreArchivo IS NULL OR LTRIM(RTRIM(@nombreArchivo)) = ''
        SET @errores += N'- El nombre del archivo es obligatorio.' + @salto;
    IF @idMonedaDestino IS NULL
        SET @errores += N'- La moneda destino no existe en publicidad.Moneda.' + @salto;
    IF @contenidoJSON IS NULL OR ISJSON(@contenidoJSON) <> 1
        SET @errores += N'- El contenido no es un JSON válido.' + @salto;
    ELSE IF NOT EXISTS (SELECT 1 FROM OPENJSON(@contenidoJSON))
        SET @errores += N'- El JSON no contiene filas de pauta.' + @salto;
    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_IMPORTAR_PAUTA_JSON - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    DECLARE @filas TABLE (
        IdOrden       INT IDENTITY(1,1) PRIMARY KEY,
        NumeroPartido VARCHAR(10),
        NumeroEspacio VARCHAR(10),
        Anunciante    VARCHAR(100),
        Titulo        VARCHAR(100),
        Idioma        VARCHAR(100),
        Monto         VARCHAR(30),
        Moneda        VARCHAR(10),
        Cruda         NVARCHAR(MAX)
    );
    INSERT INTO @filas (NumeroPartido, NumeroEspacio, Anunciante, Titulo, Idioma, Monto, Moneda, Cruda)
    SELECT NumeroPartido, NumeroEspacio, Anunciante, Titulo, Idioma, Monto, Moneda, Cruda
    FROM OPENJSON(@contenidoJSON)
         WITH (NumeroPartido VARCHAR(10)   '$.numeroPartido',
               NumeroEspacio VARCHAR(10)   '$.numeroEspacio',
               Anunciante    VARCHAR(100)  '$.anunciante',
               Titulo        VARCHAR(100)  '$.titulo',
               Idioma        VARCHAR(100)  '$.idioma',
               Monto         VARCHAR(30)   '$.monto',
               Moneda        VARCHAR(10)   '$.moneda',
               Cruda         NVARCHAR(MAX) '$' AS JSON);

    DECLARE @i INT = 1, @total INT = (SELECT COUNT(*) FROM @filas),
            @cruda NVARCHAR(MAX), @numPartido INT, @numEspacio TINYINT, @monto DECIMAL(18,2),
            @monedaOrigen CHAR(3), @idPartido INT, @idPieza INT, @idMonedaOrigen INT,
            @tarifa DECIMAL(12,2), @existe BIT, @operacion VARCHAR(12);

    WHILE @i <= @total
    BEGIN
        BEGIN TRY
            SET @errores = N'';
            SET @idPartido = NULL; SET @idPieza = NULL; SET @idMonedaOrigen = NULL; SET @tarifa = NULL;

            SELECT @cruda = Cruda,
                   @numPartido    = TRY_CONVERT(INT, NumeroPartido),
                   @numEspacio    = TRY_CONVERT(TINYINT, NumeroEspacio),
                   @monto         = TRY_CONVERT(DECIMAL(18,2), Monto),
                   @monedaOrigen  = UPPER(LTRIM(RTRIM(Moneda)))
            FROM @filas WHERE IdOrden = @i;

            SELECT @idPartido = IdPartido FROM nucleo.Partido WHERE NumeroPartido = @numPartido;
            SELECT @idMonedaOrigen = IdMoneda FROM publicidad.Moneda WHERE Codigo = @monedaOrigen;
            SELECT @idPieza = pz.IdPieza
            FROM @filas AS f
            INNER JOIN publicidad.Anunciante AS an ON an.Nombre = LTRIM(RTRIM(f.Anunciante))
            INNER JOIN nucleo.Idioma         AS id ON id.Nombre = LTRIM(RTRIM(f.Idioma))
            INNER JOIN publicidad.Pieza      AS pz ON pz.IdAnunciante = an.IdAnunciante
                                                  AND pz.IdIdioma     = id.IdIdioma
                                                  AND pz.Titulo       = LTRIM(RTRIM(f.Titulo))
            WHERE f.IdOrden = @i;

            IF @idPartido IS NULL        SET @errores += N'- El partido indicado no existe.' + @salto;
            IF @numEspacio IS NULL OR @numEspacio NOT BETWEEN 1 AND 4
                                         SET @errores += N'- El número de espacio debe estar entre 1 y 4.' + @salto;
            IF @idPieza IS NULL          SET @errores += N'- No existe la pieza (anunciante, título e idioma).' + @salto;
            IF @monto IS NULL OR @monto < 0
                                         SET @errores += N'- El monto es obligatorio, numérico y no negativo.' + @salto;
            IF @idMonedaOrigen IS NULL   SET @errores += N'- La moneda de origen no existe en publicidad.Moneda.' + @salto;

            -- Conversión de moneda en T-SQL: monto / tasa(origen) * tasa(destino) sobre la última fecha con ambas.
            IF @monto IS NOT NULL AND @idMonedaOrigen IS NOT NULL
            BEGIN
                IF @monedaOrigen = @monedaDestino
                    SET @tarifa = CAST(@monto AS DECIMAL(12,2));
                ELSE
                    SELECT TOP (1) @tarifa = CAST(@monto / o.Tasa * d.Tasa AS DECIMAL(12,2))
                    FROM publicidad.CotizacionMoneda AS o
                    INNER JOIN publicidad.CotizacionMoneda AS d
                            ON d.MonedaBase = o.MonedaBase AND d.Fecha = o.Fecha
                    WHERE o.Moneda = @monedaOrigen AND d.Moneda = @monedaDestino
                    ORDER BY o.Fecha DESC, o.MonedaBase;
                IF @tarifa IS NULL
                    SET @errores += N'- No hay cotización para convertir ' + @monedaOrigen + N' a ' + @monedaDestino + N'.' + @salto;
            END;

            IF LEN(@errores) > 0
            BEGIN
                SET @mensaje = LEFT(@errores, 2048);
                THROW 52000, @mensaje, 1;
            END;

            SET @existe = IIF(EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario
                                      WHERE IdPartido = @idPartido AND NumeroEspacio = @numEspacio), 1, 0);
            IF @existe = 0
                EXEC publicidad.SP_ALTA_EspacioPublicitario
                    @idPartido = @idPartido, @numeroEspacio = @numEspacio,
                    @idPieza = @idPieza, @tarifaPublicitaria = @tarifa, @idMoneda = @idMonedaDestino;
            ELSE IF NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario
                                WHERE IdPartido = @idPartido AND NumeroEspacio = @numEspacio
                                  AND IdPieza = @idPieza AND TarifaPublicitaria = @tarifa
                                  AND IdMoneda = @idMonedaDestino)
                EXEC publicidad.SP_MODIFICACION_EspacioPublicitario
                    @idPartido = @idPartido, @numeroEspacio = @numEspacio,
                    @idPieza = @idPieza, @tarifaPublicitaria = @tarifa, @idMoneda = @idMonedaDestino;
            SET @filasProcesadas += 1;
        END TRY
        BEGIN CATCH
            SET @filasConError += 1;
            INSERT INTO eventos.LogImportacion (NombreArchivo, IdFilaStaging, DatosCrudos, MensajeError)
            VALUES (@nombreArchivo, NULL, @cruda, LEFT(ERROR_MESSAGE(), 500));
        END CATCH;
        SET @i += 1;
    END;
END;
GO

-- =========================================================================
-- nucleo.SP_IMPORTAR_FIXTURE_CSV
-- Procesa eventos.StagingFixture (filas de @nombreArchivo), cargado por BULK INSERT estático desde
-- fixture_sedes.csv (generado por scraping). Una fila = un partido con los datos de su sede.
--   PaisISO3 -> Pais.CodigoISO3 | SeleccionLocal/Visitante -> Seleccion.CodigoFIFA | Fase -> Fase.Nombre
--   FechaHoraLocal -> hora local de la sede (SP_ALTA_Partido la convierte a UTC)
-- Upsert por clave natural: Ciudad (Nombre, IdPais), Sede (NombreEstadio, IdCiudad), Partido (NumeroPartido).
-- Solo modifica lo que cambió, así re-ejecutar el mismo archivo no falla ni duplica (ni toca partidos ya
-- finalizados cuando el dato es idéntico). En fases eliminatorias las selecciones se dejan vacías.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_IMPORTAR_FIXTURE_CSV
    @nombreArchivo   VARCHAR(255),
    @filasProcesadas INT = NULL OUTPUT,
    @filasConError   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @filasProcesadas = 0;
    SET @filasConError   = 0;
    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombreArchivo IS NULL OR LTRIM(RTRIM(@nombreArchivo)) = ''
        SET @errores += N'- El nombre del archivo es obligatorio.' + @salto;
    ELSE IF NOT EXISTS (SELECT 1 FROM eventos.StagingFixture WHERE NombreArchivo = @nombreArchivo)
        SET @errores += N'- No hay filas en eventos.StagingFixture para el archivo indicado.' + @salto;
    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_IMPORTAR_FIXTURE_CSV - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    DECLARE @filas TABLE (IdOrden INT IDENTITY(1,1) PRIMARY KEY, IdFila INT);
    INSERT INTO @filas (IdFila)
    SELECT IdFila FROM eventos.StagingFixture WHERE NombreArchivo = @nombreArchivo ORDER BY IdFila;

    DECLARE @i INT = 1, @total INT = (SELECT COUNT(*) FROM @filas),
            @idFila INT, @cruda NVARCHAR(MAX),
            @numero INT, @idFase INT, @esElim BIT, @idPais INT, @idCiudad INT, @idSede INT,
            @idSelL INT, @idSelV INT, @fechaLocal DATETIME2(0), @fechaUTC DATETIME2(0),
            @lat DECIMAL(9,6), @lon DECIMAL(9,6), @cap INT, @huso VARCHAR(50),
            @estadio VARCHAR(100), @ciudad VARCHAR(100), @idPartido SMALLINT,
            @tFase VARCHAR(50), @tIso3 VARCHAR(10), @tLocal VARCHAR(10), @tVisit VARCHAR(10);

    WHILE @i <= @total
    BEGIN
        SELECT @idFila = IdFila FROM @filas WHERE IdOrden = @i;
        BEGIN TRY
            SET @errores = N'';
            SET @idFase = NULL; SET @idPais = NULL; SET @idCiudad = NULL; SET @idSede = NULL;
            SET @idSelL = NULL; SET @idSelV = NULL; SET @fechaUTC = NULL; SET @idPartido = NULL;

            SELECT @cruda = CONCAT_WS(';', NumeroPartido, Fase, NombreEstadio, Ciudad, PaisISO3, HusoHorario,
                                      Capacidad, Latitud, Longitud, FechaHoraLocal, SeleccionLocal, SeleccionVisitante),
                   @numero     = TRY_CONVERT(INT, LTRIM(RTRIM(NumeroPartido))),
                   @tFase      = LTRIM(RTRIM(Fase)),
                   @estadio    = LTRIM(RTRIM(NombreEstadio)),
                   @ciudad     = LTRIM(RTRIM(Ciudad)),
                   @tIso3      = UPPER(LTRIM(RTRIM(PaisISO3))),
                   @huso       = LTRIM(RTRIM(HusoHorario)),
                   @cap        = TRY_CONVERT(INT, LTRIM(RTRIM(Capacidad))),
                   @lat        = TRY_CONVERT(DECIMAL(9,6), LTRIM(RTRIM(Latitud))),
                   @lon        = TRY_CONVERT(DECIMAL(9,6), LTRIM(RTRIM(Longitud))),
                   @fechaLocal = TRY_CONVERT(DATETIME2(0), LTRIM(RTRIM(FechaHoraLocal)), 126),
                   @tLocal     = UPPER(NULLIF(LTRIM(RTRIM(SeleccionLocal)), '')),
                   @tVisit     = UPPER(NULLIF(LTRIM(RTRIM(SeleccionVisitante)), ''))
            FROM eventos.StagingFixture WHERE IdFila = @idFila;

            SELECT @idFase = IdFase, @esElim = EsEliminatoria FROM nucleo.Fase WHERE Nombre = @tFase;
            SELECT @idPais = IdPais FROM nucleo.Pais WHERE CodigoISO3 = @tIso3;
            SELECT @idSelL = IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = @tLocal;
            SELECT @idSelV = IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = @tVisit;

            IF @numero IS NULL OR @numero NOT BETWEEN 1 AND 255
                SET @errores += N'- El número de partido es obligatorio y debe estar entre 1 y 255.' + @salto;
            IF @idFase IS NULL            SET @errores += N'- La fase indicada no existe.' + @salto;
            IF @estadio IS NULL OR @estadio = '' OR @ciudad IS NULL OR @ciudad = ''
                                          SET @errores += N'- El estadio y la ciudad son obligatorios.' + @salto;
            IF @idPais IS NULL            SET @errores += N'- El país de la sede no existe (CodigoISO3).' + @salto;
            IF @huso IS NULL OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @huso)
                                          SET @errores += N'- El huso horario no es válido (sys.time_zone_info).' + @salto;
            IF @lat IS NULL OR @lon IS NULL OR @lat NOT BETWEEN -90 AND 90 OR @lon NOT BETWEEN -180 AND 180
                                          SET @errores += N'- La latitud y la longitud son obligatorias y deben ser válidas.' + @salto;
            IF @cap IS NULL OR @cap <= 0  SET @errores += N'- La capacidad es obligatoria y debe ser positiva.' + @salto;
            IF @fechaLocal IS NULL        SET @errores += N'- La fecha y hora local es obligatoria (AAAA-MM-DDTHH:MM:SS).' + @salto;
            IF @tLocal IS NOT NULL AND @idSelL IS NULL
                                          SET @errores += N'- La selección local no existe (CodigoFIFA).' + @salto;
            IF @tVisit IS NOT NULL AND @idSelV IS NULL
                                          SET @errores += N'- La selección visitante no existe (CodigoFIFA).' + @salto;
            IF LEN(@errores) > 0
            BEGIN
                SET @mensaje = LEFT(@errores, 2048);
                THROW 52000, @mensaje, 1;
            END;

            -- Ciudad (Upsert)
            SELECT @idCiudad = IdCiudad FROM nucleo.Ciudad WHERE Nombre = @ciudad AND IdPais = @idPais;
            IF @idCiudad IS NULL
            BEGIN
                EXEC nucleo.SP_ALTA_Ciudad @nombre = @ciudad, @idPais = @idPais, @husoHorario = @huso;
                SELECT @idCiudad = IdCiudad FROM nucleo.Ciudad WHERE Nombre = @ciudad AND IdPais = @idPais;
            END
            ELSE IF EXISTS (SELECT 1 FROM nucleo.Ciudad WHERE IdCiudad = @idCiudad AND HusoHorario <> @huso)
                EXEC nucleo.SP_MODIFICACION_Ciudad @idCiudad = @idCiudad, @nombre = @ciudad,
                                                   @idPais = @idPais, @husoHorario = @huso;

            -- Sede (Upsert)
            SELECT @idSede = IdSede FROM nucleo.Sede WHERE NombreEstadio = @estadio AND IdCiudad = @idCiudad;
            IF @idSede IS NULL
            BEGIN
                EXEC nucleo.SP_ALTA_Sede @nombreEstadio = @estadio, @idCiudad = @idCiudad, @capacidad = @cap,
                                         @latitud = @lat, @longitud = @lon;
                SELECT @idSede = IdSede FROM nucleo.Sede WHERE NombreEstadio = @estadio AND IdCiudad = @idCiudad;
            END
            ELSE IF NOT EXISTS (SELECT 1 FROM nucleo.Sede
                                WHERE IdSede = @idSede AND Capacidad = @cap AND Latitud = @lat AND Longitud = @lon)
                EXEC nucleo.SP_MODIFICACION_Sede @idSede = @idSede, @nombreEstadio = @estadio, @idCiudad = @idCiudad,
                                                 @capacidad = @cap, @latitud = @lat, @longitud = @lon;

            -- Partido (Upsert por NumeroPartido). La hora local se convierte a UTC solo para comparar.
            SET @fechaUTC = CAST((@fechaLocal AT TIME ZONE @huso) AT TIME ZONE 'UTC' AS DATETIME2(0));
            SELECT @idPartido = IdPartido FROM nucleo.Partido WHERE NumeroPartido = @numero;
            IF @idPartido IS NULL
                EXEC nucleo.SP_ALTA_Partido @numeroPartido = @numero, @idFase = @idFase, @idSede = @idSede,
                                            @fechaHoraLocal = @fechaLocal,
                                            @idSeleccionLocal = @idSelL, @idSeleccionVisitante = @idSelV;
            ELSE IF NOT EXISTS (SELECT 1 FROM nucleo.Partido
                                WHERE IdPartido = @idPartido AND IdFase = @idFase AND IdSede = @idSede
                                  AND FechaHoraUTC = @fechaUTC
                                  AND ISNULL(IdSeleccionLocal, 0)     = ISNULL(@idSelL, 0)
                                  AND ISNULL(IdSeleccionVisitante, 0) = ISNULL(@idSelV, 0))
                EXEC nucleo.SP_MODIFICACION_Partido @idPartido = @idPartido, @numeroPartido = @numero,
                                                    @idFase = @idFase, @idSede = @idSede, @fechaHoraLocal = @fechaLocal,
                                                    @idSeleccionLocal = @idSelL, @idSeleccionVisitante = @idSelV;
            SET @filasProcesadas += 1;
        END TRY
        BEGIN CATCH
            SET @filasConError += 1;
            INSERT INTO eventos.LogImportacion (NombreArchivo, IdFilaStaging, DatosCrudos, MensajeError)
            VALUES (@nombreArchivo, @idFila, @cruda, LEFT(ERROR_MESSAGE(), 500));
        END CATCH;
        SET @i += 1;
    END;
END;
GO
