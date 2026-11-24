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
Objetivo: Stored procedure de importación masiva en formato XML para el módulo jugadores
          (Entrega 6), con lógica Upsert idempotente, reutilización de SP de la Entrega 5
          y manejo de errores parciales registrando fallos en eventos.LogImportacion:
          - jugadores.SP_IMPORTAR_CONVOCATORIA_XML
          Requiere ejecutados los scripts 01 a 21.
          Test correspondiente: testing/23_Test_SP_Importacion_Jugadores.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- jugadores.SP_IMPORTAR_CONVOCATORIA_XML
-- Recibe el nombre del archivo y el contenido XML con la estructura:
--   <Convocatorias>
--     <Seleccion CodigoISO3="ARG">
--       <Jugador>
--         <Nombre>...</Nombre>
--         <Apellido>...</Apellido>
--         <Documento>...</Documento>
--         <FechaNacimiento>YYYY-MM-DD</FechaNacimiento> <!-- opcional -->
--         <Sexo>M</Sexo>
--         <Posicion>Arquero|Defensor|Mediocampista|Delantero</Posicion>
--         <Club>...</Club> <!-- opcional -->
--         <Dorsal>23</Dorsal>
--         <FechaAlta>YYYY-MM-DD</FechaAlta> <!-- opcional -->
--       </Jugador>
--     </Seleccion>
--   </Convocatorias>
-- Realiza Upsert de Club, Jugador y Convocatoria sin duplicar ante re-ejecuciones.
-- Las filas con errores se registran en eventos.LogImportacion sin abortar el lote.
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_IMPORTAR_CONVOCATORIA_XML
    @nombreArchivo   VARCHAR(255),
    @contenidoXML    XML,
    @filasProcesadas INT = NULL OUTPUT,
    @filasConError   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombreArchivo = LTRIM(RTRIM(@nombreArchivo));

    IF @nombreArchivo IS NULL OR @nombreArchivo = ''
        SET @errores += N'- El nombre del archivo es obligatorio.' + @salto;

    IF @contenidoXML IS NULL
        SET @errores += N'- El contenido XML es obligatorio.' + @salto;
    ELSE IF @contenidoXML.exist('/Convocatorias/Seleccion/Jugador') = 0
        SET @errores += N'- El XML no contiene nodos /Convocatorias/Seleccion/Jugador.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_IMPORTAR_CONVOCATORIA_XML - No se pudo iniciar la importación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- Variable de tabla con clave secuencial para iterar con WHILE (sin cursores).
    DECLARE @filas TABLE (
        IdOrden              INT IDENTITY(1,1) PRIMARY KEY,
        CodigoISO3           VARCHAR(10)   NULL,
        Nombre               VARCHAR(60)   NULL,
        Apellido             VARCHAR(60)   NULL,
        Documento            VARCHAR(20)   NULL,
        FechaNacimientoTexto VARCHAR(30)   NULL,
        Sexo                 VARCHAR(10)   NULL,
        Posicion             VARCHAR(30)   NULL,
        Club                 VARCHAR(100)  NULL,
        DorsalTexto          VARCHAR(20)   NULL,
        FechaAltaTexto       VARCHAR(30)   NULL,
        DatosCrudos          NVARCHAR(MAX) NULL
    );

    INSERT INTO @filas (
        CodigoISO3, Nombre, Apellido, Documento, FechaNacimientoTexto,
        Sexo, Posicion, Club, DorsalTexto, FechaAltaTexto, DatosCrudos
    )
    SELECT
        UPPER(LTRIM(RTRIM(n.value('(../@CodigoISO3)[1]', 'VARCHAR(10)')))),
        LTRIM(RTRIM(n.value('(Nombre/text())[1]', 'VARCHAR(60)'))),
        LTRIM(RTRIM(n.value('(Apellido/text())[1]', 'VARCHAR(60)'))),
        LTRIM(RTRIM(n.value('(Documento/text())[1]', 'VARCHAR(20)'))),
        LTRIM(RTRIM(n.value('(FechaNacimiento/text())[1]', 'VARCHAR(30)'))),
        UPPER(LTRIM(RTRIM(n.value('(Sexo/text())[1]', 'VARCHAR(10)')))),
        LTRIM(RTRIM(n.value('(Posicion/text())[1]', 'VARCHAR(30)'))),
        LTRIM(RTRIM(n.value('(Club/text())[1]', 'VARCHAR(100)'))),
        LTRIM(RTRIM(n.value('(Dorsal/text())[1]', 'VARCHAR(20)'))),
        LTRIM(RTRIM(n.value('(FechaAlta/text())[1]', 'VARCHAR(30)'))),
        CAST(n.query('.') AS NVARCHAR(MAX))
    FROM @contenidoXML.nodes('/Convocatorias/Seleccion/Jugador') AS t(n);

    DECLARE @idx             INT = 1,
            @total           INT = (SELECT COUNT(*) FROM @filas),
            @ok              INT = 0,
            @err             INT = 0,
            @codigoISO3      VARCHAR(10),
            @nombre          VARCHAR(60),
            @apellido        VARCHAR(60),
            @documento       VARCHAR(20),
            @fechaNacTexto   VARCHAR(30),
            @fechaNacimiento DATE,
            @sexo            VARCHAR(10),
            @posicion        VARCHAR(30),
            @club            VARCHAR(100),
            @dorsalTexto     VARCHAR(20),
            @dorsal          INT,
            @fechaAltaTexto  VARCHAR(30),
            @fechaAlta       DATE,
            @datosCrudos     NVARCHAR(MAX),
            @idSeleccion     INT,
            @idClub          INT,
            @idJugador       INT,
            @idConvocatoria  INT,
            @sexoChar        CHAR(1),
            @msgErrorFila    NVARCHAR(500);

    WHILE @idx <= @total
    BEGIN
        SELECT @codigoISO3     = CodigoISO3,
               @nombre         = Nombre,
               @apellido       = Apellido,
               @documento      = Documento,
               @fechaNacTexto  = FechaNacimientoTexto,
               @sexo           = Sexo,
               @posicion       = Posicion,
               @club           = Club,
               @dorsalTexto    = DorsalTexto,
               @fechaAltaTexto = FechaAltaTexto,
               @datosCrudos    = DatosCrudos
        FROM @filas
        WHERE IdOrden = @idx;

        SET @idSeleccion     = NULL;
        SET @idClub          = NULL;
        SET @idJugador       = NULL;
        SET @idConvocatoria  = NULL;
        SET @fechaNacimiento = NULL;
        SET @fechaAlta       = NULL;
        SET @dorsal          = NULL;

        BEGIN TRY
            -- 1. Resolución de Selección por clave natural CodigoISO3
            IF @codigoISO3 IS NULL OR @codigoISO3 = ''
                THROW 52000, N'El atributo CodigoISO3 de la selección es obligatorio.', 1;

            SELECT @idSeleccion = s.IdSeleccion
            FROM nucleo.Seleccion AS s
            INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais
            WHERE p.CodigoISO3 = @codigoISO3;

            IF @idSeleccion IS NULL
                THROW 52000, N'No existe una selección registrada para el CodigoISO3 informado.', 1;

            -- 2. Conversión tipada de Dorsal, Sexo y fechas opcionales
            SET @dorsal = TRY_CAST(@dorsalTexto AS INT);
            IF @dorsal IS NULL
                THROW 52000, N'El dorsal informado no es un número entero válido.', 1;

            IF @fechaNacTexto IS NOT NULL AND @fechaNacTexto <> ''
            BEGIN
                SET @fechaNacimiento = TRY_CONVERT(DATE, @fechaNacTexto, 23);
                IF @fechaNacimiento IS NULL
                    THROW 52000, N'FechaNacimiento inválida (formato esperado YYYY-MM-DD).', 1;
            END;

            IF @fechaAltaTexto IS NOT NULL AND @fechaAltaTexto <> ''
            BEGIN
                SET @fechaAlta = TRY_CONVERT(DATE, @fechaAltaTexto, 23);
                IF @fechaAlta IS NULL
                    THROW 52000, N'FechaAlta inválida (formato esperado YYYY-MM-DD).', 1;
            END
            ELSE
                SET @fechaAlta = CAST(GETDATE() AS DATE);

            IF @sexo IS NULL OR LEN(@sexo) <> 1
                THROW 52000, N'El sexo debe ser un único carácter (M o F).', 1;
            SET @sexoChar = CAST(@sexo AS CHAR(1));

            -- 3. Upsert de Club (si se informó)
            IF @club IS NOT NULL AND @club <> ''
            BEGIN
                SELECT @idClub = IdClub FROM jugadores.Club WHERE Nombre = @club;

                IF @idClub IS NULL
                    EXEC jugadores.SP_ALTA_Club
                        @idClub    = @idClub OUTPUT,
                        @nombre    = @club;
            END;

            -- 4. Upsert de Jugador por clave natural Documento
            IF @documento IS NULL OR @documento = ''
                THROW 52000, N'El documento del jugador es obligatorio.', 1;

            SET @idJugador = jugadores.fn_IdJugadorPorDocumento(@documento);

            IF @idJugador IS NULL
                EXEC jugadores.SP_ALTA_Jugador
                    @idJugador       = @idJugador OUTPUT,
                    @nombre          = @nombre,
                    @apellido        = @apellido,
                    @documento       = @documento,
                    @fechaNacimiento = @fechaNacimiento,
                    @sexo            = @sexoChar,
                    @posicion        = @posicion,
                    @idClub          = @idClub;
            ELSE
                EXEC jugadores.SP_MODIFICACION_Jugador
                    @idJugador       = @idJugador,
                    @nombre          = @nombre,
                    @apellido        = @apellido,
                    @documento       = @documento,
                    @fechaNacimiento = @fechaNacimiento,
                    @sexo            = @sexoChar,
                    @posicion        = @posicion,
                    @idClub          = @idClub;

            -- 5. Upsert de Convocatoria
            SELECT @idConvocatoria = IdConvocatoria
            FROM jugadores.Convocatoria
            WHERE IdJugador = @idJugador;

            IF @idConvocatoria IS NULL
                EXEC jugadores.SP_CONVOCAR_JUGADOR
                    @idSeleccion    = @idSeleccion,
                    @idJugador      = @idJugador,
                    @dorsal         = @dorsal,
                    @fechaAlta      = @fechaAlta,
                    @idConvocatoria = @idConvocatoria OUTPUT;
            ELSE
                EXEC jugadores.SP_MODIFICACION_Convocatoria
                    @idConvocatoria = @idConvocatoria,
                    @idSeleccion    = @idSeleccion,
                    @idJugador      = @idJugador,
                    @dorsal         = @dorsal,
                    @fechaAlta      = @fechaAlta;

            SET @ok += 1;
        END TRY
        BEGIN CATCH
            SET @msgErrorFila = LEFT(ERROR_MESSAGE(), 500);

            INSERT INTO eventos.LogImportacion (NombreArchivo, IdFilaStaging, DatosCrudos, MensajeError)
            VALUES (@nombreArchivo, NULL, @datosCrudos, @msgErrorFila);

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