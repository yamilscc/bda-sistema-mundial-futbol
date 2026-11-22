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
Objetivo: Objetos de importación masiva en formato CSV para el módulo eventos (Entrega 6):
          - Default en eventos.StagingEvento.NombreArchivo y vista eventos.vw_CargaStagingEvento
            para permitir BULK INSERT estático sin SQL dinámico.
          - eventos.SP_IMPORTAR_EVENTOS_CSV: procesa filas desde eventos.StagingEvento,
            reutiliza los SP de la Entrega 5 con Upsert idempotente y registra errores
            parciales en eventos.LogImportacion sin abortar el lote válido.
          Requiere ejecutados los scripts 01 a 23.
          Test correspondiente: testing/24_Test_SP_Importacion_Eventos.sql.
*/

USE MundialFutbol;
GO

-- Default temporal para permitir la carga directa vía vista con BULK INSERT estático.
IF NOT EXISTS (
    SELECT 1
    FROM sys.default_constraints
    WHERE name = 'DF_StagingEvento_NombreArchivo'
      AND parent_object_id = OBJECT_ID('eventos.StagingEvento')
)
BEGIN
    ALTER TABLE eventos.StagingEvento
        ADD CONSTRAINT DF_StagingEvento_NombreArchivo DEFAULT ('PENDIENTE') FOR NombreArchivo;
END;
GO

-- Vista de aterrizaje con las 7 columnas del CSV (omite IdFila IDENTITY y NombreArchivo).
CREATE OR ALTER VIEW eventos.vw_CargaStagingEvento
AS
SELECT PartidoRef,
       TipoEvento,
       DocumentoSancionado,
       DocumentoAsistente,
       MinutoTexto,
       DetalleTipo,
       PeriodoOMotivo
FROM eventos.StagingEvento;
GO

-- =========================================================================
-- eventos.SP_IMPORTAR_EVENTOS_CSV
-- Procesa las filas de eventos.StagingEvento asociadas a @nombreArchivo:
--   - PartidoRef          -> NumeroPartido (clave natural en nucleo.Partido)
--   - TipoEvento          -> 'Gol' | 'Amonestacion'
--   - DocumentoSancionado -> Documento del autor del gol o sancionado (jugador/staff) o nombre y apellido
--   - DocumentoAsistente  -> Documento del asistente (solo Gol, opcional)
--   - MinutoTexto         -> Minuto entero (1..135)
--   - DetalleTipo         -> TipoGol ('Jugada', 'Penal', ...) o TipoTarjeta ('Amarilla', 'Roja directa')
--   - PeriodoOMotivo      -> Periodo del gol o Motivo de la amonestación
-- Es idempotente (actualiza si el evento ya existe) y registra fallos por fila
-- en eventos.LogImportacion sin abortar el resto del lote.
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_IMPORTAR_EVENTOS_CSV
    @nombreArchivo       VARCHAR(255),
    @permitirFechaFutura BIT = 0,
    @filasProcesadas     INT = NULL OUTPUT,
    @filasConError       INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombreArchivo = LTRIM(RTRIM(@nombreArchivo));

    IF @nombreArchivo IS NULL OR @nombreArchivo = ''
        SET @errores += N'- El nombre del archivo es obligatorio.' + @salto;
    ELSE IF NOT EXISTS (SELECT 1 FROM eventos.StagingEvento WHERE NombreArchivo = @nombreArchivo)
        SET @errores += N'- No hay filas cargadas en eventos.StagingEvento para el archivo indicado.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_IMPORTAR_EVENTOS_CSV - No se pudo iniciar la importación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- Variable de tabla con clave secuencial para iterar con WHILE (sin cursores).
    DECLARE @filas TABLE (
        IdOrden             INT IDENTITY(1,1) PRIMARY KEY,
        IdFilaStaging       INT          NOT NULL,
        PartidoRef          VARCHAR(100) NULL,
        TipoEvento          VARCHAR(50)  NULL,
        DocumentoSancionado VARCHAR(200)  NULL,
        DocumentoAsistente  VARCHAR(50)  NULL,
        MinutoTexto         VARCHAR(20)  NULL,
        DetalleTipo         VARCHAR(100) NULL,
        PeriodoOMotivo      VARCHAR(200) NULL
    );

    INSERT INTO @filas (
        IdFilaStaging, PartidoRef, TipoEvento, DocumentoSancionado,
        DocumentoAsistente, MinutoTexto, DetalleTipo, PeriodoOMotivo
    )
    SELECT IdFila,
           LTRIM(RTRIM(REPLACE(PartidoRef, CHAR(13), ''))),
           UPPER(LTRIM(RTRIM(REPLACE(TipoEvento, CHAR(13), '')))),
           LTRIM(RTRIM(REPLACE(DocumentoSancionado, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(DocumentoAsistente, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(MinutoTexto, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(DetalleTipo, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(PeriodoOMotivo, CHAR(13), '')))
    FROM eventos.StagingEvento
    WHERE NombreArchivo = @nombreArchivo
    ORDER BY IdFila;

    DECLARE @idx             INT = 1,
            @total           INT = (SELECT COUNT(*) FROM @filas),
            @ok              INT = 0,
            @err             INT = 0,
            @idFilaStaging   INT,
            @partidoRef      VARCHAR(100),
            @tipoEvento      VARCHAR(50),
            @docSancionado   VARCHAR(200),
            @docAsistente    VARCHAR(50),
            @minutoTexto     VARCHAR(20),
            @detalleTipo     VARCHAR(100),
            @periodoOMotivo  VARCHAR(200),
            @numeroPartido   INT,
            @idPartido       INT,
            @minuto          INT,
            @idJugadorAutor  INT,
            @idJugadorAsist  INT,
            @idStaffTecnico  INT,
            @idTipoGol       INT,
            @idPeriodo       INT,
            @idGolExistente  INT,
            @idAmonExistente INT,
            @datosCrudos     NVARCHAR(MAX),
            @msgErrorFila    NVARCHAR(500);

    WHILE @idx <= @total
    BEGIN
        SELECT @idFilaStaging  = IdFilaStaging,
               @partidoRef     = PartidoRef,
               @tipoEvento     = TipoEvento,
               @docSancionado  = DocumentoSancionado,
               @docAsistente   = DocumentoAsistente,
               @minutoTexto    = MinutoTexto,
               @detalleTipo    = DetalleTipo,
               @periodoOMotivo = PeriodoOMotivo
        FROM @filas
        WHERE IdOrden = @idx;

        SET @datosCrudos = N'PartidoRef=' + ISNULL(@partidoRef, N'NULL')
                         + N' | TipoEvento=' + ISNULL(@tipoEvento, N'NULL')
                         + N' | DocSancionado=' + ISNULL(@docSancionado, N'NULL')
                         + N' | DocAsistente=' + ISNULL(@docAsistente, N'NULL')
                         + N' | Minuto=' + ISNULL(@minutoTexto, N'NULL')
                         + N' | DetalleTipo=' + ISNULL(@detalleTipo, N'NULL')
                         + N' | PeriodoOMotivo=' + ISNULL(@periodoOMotivo, N'NULL');

        SET @numeroPartido   = NULL;
        SET @idPartido       = NULL;
        SET @minuto          = NULL;
        SET @idJugadorAutor  = NULL;
        SET @idJugadorAsist  = NULL;
        SET @idStaffTecnico  = NULL;
        SET @idTipoGol       = NULL;
        SET @idPeriodo       = NULL;
        SET @idGolExistente  = NULL;
        SET @idAmonExistente = NULL;

        BEGIN TRY
            -- 1. Resolución de Partido por clave natural NumeroPartido
            SET @numeroPartido = TRY_CAST(@partidoRef AS INT);
            IF @numeroPartido IS NULL OR @numeroPartido <= 0
                THROW 52000, N'PartidoRef debe contener un NumeroPartido entero positivo.', 1;

            SELECT @idPartido = IdPartido
            FROM nucleo.Partido
            WHERE NumeroPartido = @numeroPartido;

            IF @idPartido IS NULL
                THROW 52000, N'No existe un partido con el NumeroPartido informado.', 1;

            -- 2. Conversión tipada de Minuto
            SET @minuto = TRY_CAST(@minutoTexto AS INT);
            IF @minuto IS NULL
                THROW 52000, N'El minuto informado no es un número entero válido.', 1;

            -- 3. Bifurcación por TipoEvento
            IF @tipoEvento = 'GOL'
            BEGIN
                IF @docSancionado IS NULL OR @docSancionado = ''
                    THROW 52000, N'El documento del jugador autor del gol es obligatorio.', 1;

                SELECT @idJugadorAutor = IdJugador
                FROM jugadores.Jugador
                WHERE Documento = @docSancionado;

                IF @idJugadorAutor IS NULL
                    THROW 52000, N'No existe un jugador con el DocumentoSancionado informado.', 1;

                IF @docAsistente IS NOT NULL AND @docAsistente <> ''
                BEGIN
                    SELECT @idJugadorAsist = IdJugador
                    FROM jugadores.Jugador
                    WHERE Documento = @docAsistente;

                    IF @idJugadorAsist IS NULL
                        THROW 52000, N'No existe un jugador con el DocumentoAsistente informado.', 1;
                END;

                SELECT @idTipoGol = IdTipoGol FROM eventos.TipoGol WHERE Descripcion = @detalleTipo;
                SELECT @idPeriodo = IdPeriodo FROM eventos.Periodo WHERE Descripcion = @periodoOMotivo;

                SELECT @idGolExistente = g.IdGol
                FROM eventos.Gol AS g
                WHERE g.IdPartido      = @idPartido
                  AND g.IdJugadorAutor = @idJugadorAutor
                  AND g.Minuto         = @minuto
                  AND g.IdTipoGol      = @idTipoGol
                  AND g.IdPeriodo      = @idPeriodo;

                IF @idGolExistente IS NULL
                    EXEC eventos.SP_REGISTRAR_GOL
                        @idPartido           = @idPartido,
                        @idJugadorAutor      = @idJugadorAutor,
                        @tipoGol             = @detalleTipo,
                        @periodo             = @periodoOMotivo,
                        @minuto              = @minuto,
                        @idJugadorAsistencia = @idJugadorAsist,
                        @permitirFechaFutura = @permitirFechaFutura,
                        @idGol               = @idGolExistente OUTPUT;
                ELSE
                    EXEC eventos.SP_ABM_Gol
                        @operacion           = 'MODIFICACION',
                        @idGol               = @idGolExistente,
                        @idPartido           = @idPartido,
                        @idJugadorAutor      = @idJugadorAutor,
                        @tipoGol             = @detalleTipo,
                        @periodo             = @periodoOMotivo,
                        @minuto              = @minuto,
                        @idJugadorAsistencia = @idJugadorAsist,
                        @permitirFechaFutura = @permitirFechaFutura;
            END
            ELSE IF @tipoEvento IN ('AMONESTACION', 'TARJETA')
            BEGIN
                IF @docSancionado IS NULL OR @docSancionado = ''
                    THROW 52000, N'El documento del jugador o miembro del staff sancionado es obligatorio.', 1;

                SELECT @idJugadorAutor = IdJugador
                FROM jugadores.Jugador
                WHERE Documento = @docSancionado;

                IF @idJugadorAutor IS NULL
                    SELECT @idStaffTecnico = IdStaffTecnico
                    FROM nucleo.StaffTecnico
                    WHERE NombreApellido = @docSancionado;

                IF @idJugadorAutor IS NULL AND @idStaffTecnico IS NULL
                    THROW 52000, N'No existe jugador ni integrante del staff técnico con el DocumentoSancionado informado.', 1;

                SELECT @idAmonExistente = a.IdAmonestacion
                FROM eventos.Amonestacion AS a
                WHERE a.IdPartido = @idPartido
                  AND a.Minuto    = @minuto
                  AND ((@idJugadorAutor IS NOT NULL AND a.IdJugador = @idJugadorAutor)
                    OR (@idStaffTecnico IS NOT NULL AND a.IdStaffTecnico = @idStaffTecnico));

                IF @idAmonExistente IS NULL
                    EXEC eventos.SP_REGISTRAR_AMONESTACION
                        @idPartido           = @idPartido,
                        @tipoTarjeta         = @detalleTipo,
                        @minuto              = @minuto,
                        @motivo              = @periodoOMotivo,
                        @idJugador           = @idJugadorAutor,
                        @idStaffTecnico      = @idStaffTecnico,
                        @permitirFechaFutura = @permitirFechaFutura,
                        @idAmonestacion      = @idAmonExistente OUTPUT;
                ELSE
                    EXEC eventos.SP_ABM_Amonestacion
                        @operacion           = 'MODIFICACION',
                        @idAmonestacion      = @idAmonExistente,
                        @idPartido           = @idPartido,
                        @tipoTarjeta         = @detalleTipo,
                        @minuto              = @minuto,
                        @motivo              = @periodoOMotivo,
                        @idJugador           = @idJugadorAutor,
                        @idStaffTecnico      = @idStaffTecnico,
                        @permitirFechaFutura = @permitirFechaFutura;
            END
            ELSE
            BEGIN
                THROW 52000, N'TipoEvento inválido. Valores permitidos: Gol, Amonestacion.', 1;
            END;

            SET @ok += 1;
        END TRY
        BEGIN CATCH
            SET @msgErrorFila = LEFT(ERROR_MESSAGE(), 500);

            INSERT INTO eventos.LogImportacion (NombreArchivo, IdFilaStaging, DatosCrudos, MensajeError)
            VALUES (@nombreArchivo, @idFilaStaging, @datosCrudos, @msgErrorFila);

            SET @err += 1;
        END CATCH;

        SET @idx += 1;
    END;

    SET @filasProcesadas = @ok;
    SET @filasConError   = @err;

    SELECT @nombreArchivo AS Archivo,
           @total         AS TotalLeidos,
           @ok            AS ProcesadosOK,
           @err           AS ConError;
END;
GO