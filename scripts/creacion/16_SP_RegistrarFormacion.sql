/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-16
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Stored procedures para registrar la formación y la planilla de titulares y suplentes
          de cada selección en un partido:
          - jugadores.SP_REGISTRAR_FORMACION
          - jugadores.SP_AGREGAR_JUGADOR_FORMACION
          Requiere ejecutados los scripts 01 a 14.
          Test correspondiente: testing/16_Test_SP_RegistrarFormacion.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. SP_REGISTRAR_FORMACION
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_REGISTRAR_FORMACION
    @idPartido               INT,
    @localia                 VARCHAR(9),
    @esquemaTactico          VARCHAR(10),
    @validarMinimoConvocados BIT = 0,
    @idFormacion             INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores           NVARCHAR(MAX) = N'',
            @mensaje           NVARCHAR(2048),
            @salto             NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @existePartido     BIT           = 0,
            @estadoPartido     VARCHAR(10),
            @idLocal           INT,
            @idVisitante       INT,
            @idSelFormacion    INT,
            @minConvocados     INT,
            @convocadosActivos INT;

    SET @localia        = LTRIM(RTRIM(@localia));
    SET @esquemaTactico = LTRIM(RTRIM(@esquemaTactico));

    SELECT @existePartido = 1,
           @estadoPartido = p.Estado,
           @idLocal       = p.IdSeleccionLocal,
           @idVisitante   = p.IdSeleccionVisitante
    FROM nucleo.Partido AS p
    WHERE p.IdPartido = @idPartido;

    -- ---- Validaciones ----------------------------------------------------
    IF @existePartido = 0
        SET @errores += N'- El partido indicado no existe.' + @salto;
    ELSE
    BEGIN
        IF @idLocal IS NULL OR @idVisitante IS NULL
            SET @errores += N'- El partido no tiene definidas ambas selecciones.' + @salto;
        IF @estadoPartido = 'Finalizado'
            SET @errores += N'- El partido ya está finalizado: no se pueden registrar formaciones.' + @salto;
    END;

    IF @localia IS NULL OR @localia NOT IN ('Local', 'Visitante')
        SET @errores += N'- La localía debe ser Local o Visitante.' + @salto;
    ELSE IF @existePartido = 1
    BEGIN
        IF EXISTS (SELECT 1 FROM jugadores.Formacion AS f WHERE f.IdPartido = @idPartido AND f.Localia = @localia)
            SET @errores += N'- Ya existe una formación registrada para esa localía en el partido.' + @salto;

        SET @idSelFormacion = CASE WHEN @localia = 'Local' THEN @idLocal ELSE @idVisitante END;

        IF @validarMinimoConvocados = 1 AND @idSelFormacion IS NOT NULL
        BEGIN
            SELECT TOP (1) @minConvocados = r.Minimo FROM jugadores.ReglaConvocados AS r ORDER BY r.IdRegla;

            SELECT @convocadosActivos = COUNT(*)
            FROM jugadores.Convocatoria AS c
            WHERE c.IdSeleccion = @idSelFormacion
              AND NOT EXISTS (SELECT 1 FROM jugadores.Baja AS b WHERE b.IdConvocatoria = c.IdConvocatoria);

            IF @minConvocados IS NOT NULL AND @convocadosActivos < @minConvocados
                SET @errores += N'- La selección no alcanza el mínimo de convocados activos requerido ('
                                + CAST(@minConvocados AS NVARCHAR(10)) + N').' + @salto;
        END;
    END;

    IF @esquemaTactico IS NULL OR jugadores.fn_EsquemaValido(@esquemaTactico) = 0
        SET @errores += N'- El esquema táctico debe tener formato válido (ej. 4-3-3 o 4-2-3-1) y sus líneas deben sumar 10.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_REGISTRAR_FORMACION - No se pudo registrar la formación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO jugadores.Formacion (IdPartido, Localia, EsquemaTactico)
        VALUES (@idPartido, @localia, @esquemaTactico);

        SET @idFormacion = SCOPE_IDENTITY();

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
-- 2. SP_AGREGAR_JUGADOR_FORMACION
-- Si @dorsal es NULL, toma automáticamente el Dorsal asignado al jugador en
-- jugadores.Convocatoria.
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_AGREGAR_JUGADOR_FORMACION
    @idFormacion       INT,
    @idJugador         INT,
    @estadoTitularidad VARCHAR(8),
    @posicionEnCampo   VARCHAR(20) = NULL,
    @dorsal            INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores        NVARCHAR(MAX),
            @mensaje        NVARCHAR(2048),
            @salto          NVARCHAR(2) = CHAR(13) + CHAR(10),
            @dorsalEfectivo INT         = @dorsal;

    SET @estadoTitularidad = LTRIM(RTRIM(@estadoTitularidad));
    SET @posicionEnCampo   = LTRIM(RTRIM(@posicionEnCampo));

    IF @dorsalEfectivo IS NULL
        SELECT @dorsalEfectivo = c.Dorsal
        FROM jugadores.Convocatoria AS c
        WHERE c.IdJugador = @idJugador;

    SET @errores = jugadores.fn_ValidarFormacionJugador(
        @idFormacion,
        @idJugador,
        @estadoTitularidad,
        @posicionEnCampo,
        @dorsalEfectivo,
        0
    );

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_AGREGAR_JUGADOR_FORMACION - No se pudo agregar al jugador a la formación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO jugadores.FormacionJugador (IdFormacion, IdJugador, EstadoTitularidad, PosicionEnCampo, Dorsal)
        VALUES (@idFormacion, @idJugador, @estadoTitularidad, @posicionEnCampo, @dorsalEfectivo);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO