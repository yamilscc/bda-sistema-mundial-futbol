/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Importación de las campañas del dossier de publicidad del Mundial (web scraping, ver
          importacion/scraping/scraping_dossier.py), sin SQL dinámico ni cursores:
          publicidad.SP_IMPORTAR_CAMPANIAS_CSV procesa publicidad.StagingCampania (cargada por BULK INSERT estático
          a través de publicidad.vw_CargaStagingCampania) y hace Upsert de Anunciante, Campania, Pieza y
          OrientacionPais con los SP ABM del script 20. Es idempotente y registra los errores por fila en
          eventos.LogImportacion sin abortar el lote válido.
          Requiere ejecutados los scripts 01 a 28 (usa los ABM de publicidad del script 20).
          Test correspondiente: testing/29_Test_SP_Importacion_Campanias.sql.
*/
USE MundialFutbol;
GO

-- =========================================================================
-- Objeto auxiliar: vista de aterrizaje para el BULK INSERT estático (NombreArchivo toma el default 'PENDIENTE').
-- =========================================================================
CREATE OR ALTER VIEW publicidad.vw_CargaStagingCampania
AS
SELECT Anunciante, Marca, Titulo, Agencia, Productora, Periodo, Categorias
FROM publicidad.StagingCampania;
GO

-- =========================================================================
-- publicidad.SP_IMPORTAR_CAMPANIAS_CSV
-- Procesa publicidad.StagingCampania (filas de @nombreArchivo). Una fila = una campaña del dossier.
--   Anunciante -> Anunciante.Nombre | Titulo -> Campania.Titulo | Marca y Agencia -> Campania.Marca y Agencia
--   Productora, Periodo y Categorias llegan a staging pero no se guardan (el modelo no tiene dónde).
-- El dossier son campañas argentinas y no informa país: @codigoISO3Pais (por defecto 'ARG') es el país de origen
-- de los anunciantes y, con @crearPiezas = 1, el país de orientación de la pieza.
-- Upsert por clave natural: Anunciante (Nombre), Campania (IdAnunciante, Titulo), Pieza (IdCampania, Titulo,
-- IdIdioma) y OrientacionPais (IdPieza, IdPais). Solo se modifica lo que cambió (la comparación distingue
-- mayúsculas y acentos), así re-ejecutar el mismo archivo no falla ni duplica.
-- Con @crearPiezas = 1 cada campaña tiene una pieza en idioma Español con el mismo título que la campaña,
-- orientada al país indicado, para que participe de publicidad.SP_ASIGNAR_PUBLICIDAD.
-- Fila inválida (anunciante o título vacío, texto más largo que la columna destino, país inexistente): se
-- registra en eventos.LogImportacion con el IdFila de staging y los datos crudos, y sigue con la siguiente.
-- Validaciones generales (un único mensaje agrupado, THROW 52000): nombre de archivo, filas en staging e
-- idioma Español (solo si @crearPiezas = 1).
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_IMPORTAR_CAMPANIAS_CSV
    @nombreArchivo   VARCHAR(255),
    @filasProcesadas INT     = NULL OUTPUT,
    @filasConError   INT     = NULL OUTPUT,
    @codigoISO3Pais  CHAR(3) = 'ARG',
    @crearPiezas     BIT     = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET @filasProcesadas = 0;
    SET @filasConError   = 0;
    SET @crearPiezas     = ISNULL(@crearPiezas, 0);
    SET @codigoISO3Pais  = UPPER(LTRIM(RTRIM(@codigoISO3Pais)));

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idIdioma INT = (SELECT IdIdioma FROM nucleo.Idioma WHERE Nombre = 'Español'),
            @idPais   INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = @codigoISO3Pais);

    IF @nombreArchivo IS NULL OR LTRIM(RTRIM(@nombreArchivo)) = ''
        SET @errores += N'- El nombre del archivo es obligatorio.' + @salto;
    ELSE IF NOT EXISTS (SELECT 1 FROM publicidad.StagingCampania WHERE NombreArchivo = @nombreArchivo)
        SET @errores += N'- No hay filas en publicidad.StagingCampania para el archivo indicado.' + @salto;
    IF @crearPiezas = 1 AND @idIdioma IS NULL
        SET @errores += N'- No existe el idioma Español en nucleo.Idioma: no se pueden crear las piezas.' + @salto;
    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_IMPORTAR_CAMPANIAS_CSV - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    DECLARE @filas TABLE (IdOrden INT IDENTITY(1,1) PRIMARY KEY, IdFila INT);
    INSERT INTO @filas (IdFila)
    SELECT IdFila FROM publicidad.StagingCampania WHERE NombreArchivo = @nombreArchivo ORDER BY IdFila;

    DECLARE @i INT = 1, @total INT = (SELECT COUNT(*) FROM @filas),
            @idFila INT, @cruda NVARCHAR(MAX),
            @anunciante VARCHAR(300), @titulo VARCHAR(300), @marca VARCHAR(300), @agencia VARCHAR(300),
            @idAnunciante INT, @idPaisActual INT, @idCampania INT, @idPieza INT,
            @marcaActual VARCHAR(100), @agenciaActual VARCHAR(100), @tituloActual VARCHAR(100),
            @fechaDesde DATE, @fechaHasta DATE;

    WHILE @i <= @total
    BEGIN
        SELECT @idFila = IdFila FROM @filas WHERE IdOrden = @i;
        BEGIN TRY
            SET @errores = N'';
            SET @idAnunciante = NULL; SET @idCampania = NULL; SET @idPieza = NULL;

            SELECT @cruda      = CONCAT_WS(';', Anunciante, Marca, Titulo, Agencia, Productora, Periodo, Categorias),
                   @anunciante = LTRIM(RTRIM(Anunciante)),
                   @marca      = NULLIF(LTRIM(RTRIM(Marca)), ''),
                   @titulo     = LTRIM(RTRIM(Titulo)),
                   @agencia    = NULLIF(LTRIM(RTRIM(Agencia)), '')
            FROM publicidad.StagingCampania WHERE IdFila = @idFila;

            IF @anunciante IS NULL OR @anunciante = ''
                SET @errores += N'- El nombre del anunciante es obligatorio.' + @salto;
            ELSE IF LEN(@anunciante) > 100
                SET @errores += N'- El nombre del anunciante supera los 100 caracteres.' + @salto;
            IF @titulo IS NULL OR @titulo = ''
                SET @errores += N'- El título de la campaña es obligatorio.' + @salto;
            ELSE IF LEN(@titulo) > 100
                SET @errores += N'- El título de la campaña supera los 100 caracteres.' + @salto;
            IF LEN(@marca) > 100
                SET @errores += N'- La marca supera los 100 caracteres.' + @salto;
            IF LEN(@agencia) > 100
                SET @errores += N'- La agencia supera los 100 caracteres.' + @salto;
            IF @idPais IS NULL
                SET @errores += N'- El país de origen indicado no existe (CodigoISO3).' + @salto;
            IF LEN(@errores) > 0
            BEGIN
                SET @mensaje = LEFT(@errores, 2048);
                THROW 52000, @mensaje, 1;
            END;

            -- Anunciante (Upsert por Nombre)
            SELECT @idAnunciante = IdAnunciante, @idPaisActual = IdPais
            FROM publicidad.Anunciante WHERE Nombre = @anunciante;
            IF @idAnunciante IS NULL
            BEGIN
                EXEC publicidad.SP_ALTA_Anunciante @idAnunciante = @idAnunciante OUTPUT,
                                                   @nombre = @anunciante, @idPais = @idPais;
            END
            ELSE IF @idPaisActual <> @idPais
                EXEC publicidad.SP_MODIFICACION_Anunciante @idAnunciante = @idAnunciante,
                                                           @nombre = @anunciante, @idPais = @idPais;

            -- Campania (Upsert por IdAnunciante y Titulo; las fechas existentes se conservan)
            SELECT @idCampania = IdCampania, @tituloActual = Titulo, @marcaActual = Marca, @agenciaActual = Agencia,
                   @fechaDesde = FechaDesde, @fechaHasta = FechaHasta
            FROM publicidad.Campania WHERE IdAnunciante = @idAnunciante AND Titulo = @titulo;
            IF @idCampania IS NULL
            BEGIN
                EXEC publicidad.SP_ALTA_Campania @idCampania = @idCampania OUTPUT, @idAnunciante = @idAnunciante,
                                                 @titulo = @titulo, @marca = @marca, @agencia = @agencia;
            END
            ELSE IF ISNULL(@tituloActual, '')  COLLATE Latin1_General_BIN2 <> ISNULL(@titulo, '')  COLLATE Latin1_General_BIN2
                 OR ISNULL(@marcaActual, '')   COLLATE Latin1_General_BIN2 <> ISNULL(@marca, '')   COLLATE Latin1_General_BIN2
                 OR ISNULL(@agenciaActual, '') COLLATE Latin1_General_BIN2 <> ISNULL(@agencia, '') COLLATE Latin1_General_BIN2
                EXEC publicidad.SP_MODIFICACION_Campania @idCampania = @idCampania, @idAnunciante = @idAnunciante,
                                                         @titulo = @titulo, @marca = @marca, @agencia = @agencia,
                                                         @fechaDesde = @fechaDesde, @fechaHasta = @fechaHasta;

            -- Pieza en español con el título de la campaña y su país de orientación
            IF @crearPiezas = 1
            BEGIN
                SELECT @idPieza = IdPieza
                FROM publicidad.Pieza
                WHERE IdCampania = @idCampania AND Titulo = @titulo AND IdIdioma = @idIdioma;
                IF @idPieza IS NULL
                    EXEC publicidad.SP_ALTA_Pieza @idPieza = @idPieza OUTPUT, @idCampania = @idCampania,
                                                  @idIdioma = @idIdioma, @titulo = @titulo;
                IF NOT EXISTS (SELECT 1 FROM publicidad.OrientacionPais WHERE IdPieza = @idPieza AND IdPais = @idPais)
                    EXEC publicidad.SP_ALTA_OrientacionPais @idPieza = @idPieza, @idPais = @idPais;
            END;
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
