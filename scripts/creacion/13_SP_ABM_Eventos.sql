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
Objetivo: Stored procedures ABM del módulo de eventos:
          - eventos.SP_ABM_ReglaSuspension
          - eventos.SP_ABM_TipoGol
          - eventos.SP_ABM_Periodo
          - eventos.SP_ABM_Tarjeta
          - eventos.SP_ABM_Gol
          - eventos.SP_ABM_Amonestacion
          Requiere ejecutados los scripts 01 a 12.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. SP_ABM_ReglaSuspension
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_ABM_ReglaSuspension
    @operacion          VARCHAR(12),
    @idReglaSuspension  INT         = NULL OUTPUT,
    @criterio           VARCHAR(40) = NULL,
    @cantidadAmarillas  INT         = NULL,
    @partidosSuspension INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @criterio  = LTRIM(RTRIM(@criterio));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idReglaSuspension IS NULL
           OR NOT EXISTS (SELECT 1 FROM eventos.ReglaSuspension WHERE IdReglaSuspension = @idReglaSuspension)
            SET @errores += N'- La regla de suspensión indicada no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @criterio IS NULL OR @criterio NOT IN ('Acumulacion Amarillas', 'Doble Amarilla', 'Roja Directa')
            SET @errores += N'- El criterio es obligatorio y debe ser: Acumulacion Amarillas, Doble Amarilla o Roja Directa.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM eventos.ReglaSuspension
                        WHERE Criterio = @criterio
                          AND (@operacion = 'ALTA' OR IdReglaSuspension <> @idReglaSuspension))
            SET @errores += N'- Ya existe otra regla de suspensión para ese criterio.' + @salto;

        IF @partidosSuspension IS NULL OR @partidosSuspension <= 0
            SET @errores += N'- La cantidad de partidos de suspensión es obligatoria y debe ser mayor a cero.' + @salto;

        IF @criterio = 'Acumulacion Amarillas' AND (@cantidadAmarillas IS NULL OR @cantidadAmarillas < 2)
            SET @errores += N'- Para Acumulacion Amarillas la cantidad de amarillas debe ser al menos 2.' + @salto;

        IF @criterio IS NOT NULL AND @criterio <> 'Acumulacion Amarillas' AND @cantidadAmarillas IS NOT NULL
            SET @errores += N'- CantidadAmarillas debe ser NULL cuando el criterio no es Acumulacion Amarillas.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_ReglaSuspension (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO eventos.ReglaSuspension (Criterio, CantidadAmarillas, PartidosSuspension)
            VALUES (@criterio, @cantidadAmarillas, @partidosSuspension);

            SET @idReglaSuspension = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE eventos.ReglaSuspension
            SET Criterio           = @criterio,
                CantidadAmarillas  = @cantidadAmarillas,
                PartidosSuspension = @partidosSuspension
            WHERE IdReglaSuspension = @idReglaSuspension;
        END
        ELSE
        BEGIN
            DELETE FROM eventos.ReglaSuspension
            WHERE IdReglaSuspension = @idReglaSuspension;
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
-- 2. SP_ABM_TipoGol
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_ABM_TipoGol
    @operacion   VARCHAR(12),
    @idTipoGol   INT         = NULL OUTPUT,
    @descripcion VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion   = UPPER(LTRIM(RTRIM(@operacion)));
    SET @descripcion = LTRIM(RTRIM(@descripcion));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idTipoGol IS NULL
           OR NOT EXISTS (SELECT 1 FROM eventos.TipoGol WHERE IdTipoGol = @idTipoGol)
            SET @errores += N'- El tipo de gol indicado no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @descripcion IS NULL
           OR @descripcion NOT IN ('Jugada', 'Penal', 'Tiro Libre', 'Cabezazo', 'En contra')
            SET @errores += N'- La descripción es obligatoria y debe ser: Jugada, Penal, Tiro Libre, Cabezazo o En contra.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM eventos.TipoGol
                        WHERE Descripcion = @descripcion
                          AND (@operacion = 'ALTA' OR IdTipoGol <> @idTipoGol))
            SET @errores += N'- Ya existe otro tipo de gol con esa descripción.' + @salto;
    END;

    IF @operacion = 'BAJA'
       AND EXISTS (SELECT 1 FROM eventos.Gol WHERE IdTipoGol = @idTipoGol)
        SET @errores += N'- El tipo de gol tiene goles asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_TipoGol (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO eventos.TipoGol (Descripcion)
            VALUES (@descripcion);

            SET @idTipoGol = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE eventos.TipoGol
            SET Descripcion = @descripcion
            WHERE IdTipoGol = @idTipoGol;
        END
        ELSE
        BEGIN
            DELETE FROM eventos.TipoGol
            WHERE IdTipoGol = @idTipoGol;
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
-- 3. SP_ABM_Periodo
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_ABM_Periodo
    @operacion   VARCHAR(12),
    @idPeriodo   INT         = NULL OUTPUT,
    @descripcion VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion   = UPPER(LTRIM(RTRIM(@operacion)));
    SET @descripcion = LTRIM(RTRIM(@descripcion));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idPeriodo IS NULL
           OR NOT EXISTS (SELECT 1 FROM eventos.Periodo WHERE IdPeriodo = @idPeriodo)
            SET @errores += N'- El período indicado no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @descripcion IS NULL
           OR @descripcion NOT IN ('Primer Tiempo', 'Segundo Tiempo', 'Adicional PT', 'Adicional ST',
                                   'Alargue PT', 'Alargue ST', 'Definicion por Penales')
            SET @errores += N'- La descripción del período no es válida.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM eventos.Periodo
                        WHERE Descripcion = @descripcion
                          AND (@operacion = 'ALTA' OR IdPeriodo <> @idPeriodo))
            SET @errores += N'- Ya existe otro período con esa descripción.' + @salto;
    END;

    IF @operacion = 'BAJA'
       AND EXISTS (SELECT 1 FROM eventos.Gol WHERE IdPeriodo = @idPeriodo)
        SET @errores += N'- El período tiene goles asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Periodo (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO eventos.Periodo (Descripcion)
            VALUES (@descripcion);

            SET @idPeriodo = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE eventos.Periodo
            SET Descripcion = @descripcion
            WHERE IdPeriodo = @idPeriodo;
        END
        ELSE
        BEGIN
            DELETE FROM eventos.Periodo
            WHERE IdPeriodo = @idPeriodo;
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
-- 4. SP_ABM_Tarjeta
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_ABM_Tarjeta
    @operacion VARCHAR(12),
    @idTarjeta INT         = NULL OUTPUT,
    @tipo      VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @tipo      = LTRIM(RTRIM(@tipo));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- ---- Validaciones ----------------------------------------------------
    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idTarjeta IS NULL
           OR NOT EXISTS (SELECT 1 FROM eventos.Tarjeta WHERE IdTarjeta = @idTarjeta)
            SET @errores += N'- La tarjeta indicada no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @tipo IS NULL
           OR @tipo NOT IN ('Amarilla', 'Roja por doble amarilla', 'Roja directa')
            SET @errores += N'- El tipo de tarjeta debe ser: Amarilla, Roja por doble amarilla o Roja directa.' + @salto;
        ELSE IF EXISTS (SELECT 1
                        FROM eventos.Tarjeta
                        WHERE Tipo = @tipo
                          AND (@operacion = 'ALTA' OR IdTarjeta <> @idTarjeta))
            SET @errores += N'- Ya existe otra tarjeta con ese tipo.' + @salto;
    END;

    IF @operacion = 'BAJA'
       AND EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdTarjeta = @idTarjeta)
        SET @errores += N'- La tarjeta tiene amonestaciones asociadas y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Tarjeta (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO eventos.Tarjeta (Tipo)
            VALUES (@tipo);

            SET @idTarjeta = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE eventos.Tarjeta
            SET Tipo = @tipo
            WHERE IdTarjeta = @idTarjeta;
        END
        ELSE
        BEGIN
            DELETE FROM eventos.Tarjeta
            WHERE IdTarjeta = @idTarjeta;
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
-- 5. SP_ABM_Gol
-- En ALTA delega en eventos.SP_REGISTRAR_GOL.
-- En MODIFICACION y BAJA valida que el partido no esté finalizado y aplica
-- las mismas reglas de integridad sobre jugadores, minuto, tipo y período.
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_ABM_Gol
    @operacion           VARCHAR(12),
    @idGol               INT         = NULL OUTPUT,
    @idPartido           INT         = NULL,
    @idJugadorAutor      INT         = NULL,
    @tipoGol             VARCHAR(30) = NULL,
    @periodo             VARCHAR(30) = NULL,
    @minuto              INT         = NULL,
    @idJugadorAsistencia INT         = NULL,
    @permitirFechaFutura BIT         = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    -- En ALTA se reutiliza íntegramente SP_REGISTRAR_GOL.
    IF @operacion = 'ALTA'
    BEGIN
        EXEC eventos.SP_REGISTRAR_GOL
            @idPartido           = @idPartido,
            @idJugadorAutor      = @idJugadorAutor,
            @tipoGol             = @tipoGol,
            @periodo             = @periodo,
            @minuto              = @minuto,
            @idJugadorAsistencia = @idJugadorAsistencia,
            @permitirFechaFutura = @permitirFechaFutura,
            @idGol               = @idGol OUTPUT;
        RETURN;
    END;

    DECLARE @errores         NVARCHAR(MAX) = N'',
            @mensaje         NVARCHAR(2048),
            @salto           NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartidoActual INT,
            @estadoActual    VARCHAR(10),
            @existePartido   BIT = 0,
            @estadoDestino   VARCHAR(10),
            @esEliminatoria  BIT,
            @idLocal         INT,
            @idVisitante     INT,
            @fechaHoraUTC    DATETIME2(0),
            @fechaLocal      DATE,
            @idTipoGol       INT,
            @idPeriodo       INT,
            @idSelAutor      INT,
            @idSelAsistente  INT;

    SELECT @idPartidoActual = g.IdPartido,
           @estadoActual    = p.Estado
    FROM eventos.Gol AS g
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = g.IdPartido
    WHERE g.IdGol = @idGol;

    IF @idPartidoActual IS NULL
        SET @errores += N'- El gol indicado no existe.' + @salto;
    ELSE IF @estadoActual = 'Finalizado'
        SET @errores += N'- El partido del gol ya está finalizado: no se puede modificar ni eliminar.' + @salto;

    IF @operacion = 'MODIFICACION'
    BEGIN
        SELECT @existePartido  = 1,
               @estadoDestino  = p.Estado,
               @esEliminatoria = f.EsEliminatoria,
               @idLocal        = p.IdSeleccionLocal,
               @idVisitante    = p.IdSeleccionVisitante,
               @fechaHoraUTC   = p.FechaHoraUTC,
               @fechaLocal     = CAST(p.FechaHoraLocal AS DATE)
        FROM nucleo.Partido AS p
        INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
        WHERE p.IdPartido = @idPartido;

        SELECT @idTipoGol      = t.IdTipoGol   FROM eventos.TipoGol AS t WHERE t.Descripcion = @tipoGol;
        SELECT @idPeriodo      = pe.IdPeriodo  FROM eventos.Periodo AS pe WHERE pe.Descripcion = @periodo;
        SELECT @idSelAutor     = c.IdSeleccion FROM jugadores.Convocatoria AS c WHERE c.IdJugador = @idJugadorAutor;
        SELECT @idSelAsistente = c.IdSeleccion FROM jugadores.Convocatoria AS c WHERE c.IdJugador = @idJugadorAsistencia;

        IF @existePartido = 0
            SET @errores += N'- El partido indicado no existe.' + @salto;
        ELSE
        BEGIN
            IF @idLocal IS NULL OR @idVisitante IS NULL
                SET @errores += N'- El partido no tiene definidas ambas selecciones.' + @salto;
            IF @estadoDestino = 'Finalizado' AND (@idPartidoActual IS NULL OR @idPartido <> @idPartidoActual)
                SET @errores += N'- El partido destino ya está finalizado.' + @salto;
            IF @permitirFechaFutura = 0 AND @fechaHoraUTC > SYSUTCDATETIME()
                SET @errores += N'- No se pueden registrar goles en un partido que todavía no se jugó.' + @salto;
        END;

        IF @idTipoGol IS NULL
            SET @errores += N'- El tipo de gol indicado no existe.' + @salto;
        IF @idPeriodo IS NULL
            SET @errores += N'- El período indicado no existe.' + @salto;
        IF @minuto IS NULL OR @minuto NOT BETWEEN 1 AND 135
            SET @errores += N'- El minuto debe estar entre 1 y 135.' + @salto;

        IF @periodo = 'Definicion por Penales'
        BEGIN
            IF @tipoGol <> 'Penal'
                SET @errores += N'- En la definición por penales solo se pueden registrar goles de tipo Penal.' + @salto;
            IF @existePartido = 1 AND @esEliminatoria = 0
                SET @errores += N'- En fase de grupos no hay definición por penales.' + @salto;
        END;

        IF @idJugadorAsistencia IS NOT NULL
           AND (@tipoGol IN ('En contra', 'Penal') OR @periodo = 'Definicion por Penales')
            SET @errores += N'- Este tipo de gol no admite asistencia.' + @salto;

        -- Validaciones del autor
        IF @idJugadorAutor IS NULL
           OR NOT EXISTS (SELECT 1 FROM jugadores.Jugador AS j WHERE j.IdJugador = @idJugadorAutor)
            SET @errores += N'- El jugador autor del gol no existe.' + @salto;
        ELSE IF @idSelAutor IS NULL
            SET @errores += N'- El jugador autor del gol no está convocado.' + @salto;
        ELSE IF @existePartido = 1 AND @idSelAutor NOT IN (ISNULL(@idLocal, -1), ISNULL(@idVisitante, -1))
            SET @errores += N'- El jugador autor del gol no pertenece a ninguna de las selecciones del partido.' + @salto;
        ELSE IF @existePartido = 1
        BEGIN
            IF EXISTS (SELECT 1
                       FROM jugadores.Convocatoria AS c
                       INNER JOIN jugadores.Baja AS b ON b.IdConvocatoria = c.IdConvocatoria
                       WHERE c.IdJugador = @idJugadorAutor AND b.FechaBaja <= @fechaLocal)
                SET @errores += N'- El jugador autor del gol está dado de baja de la convocatoria.' + @salto;

            IF eventos.fn_EstaSuspendido(@idJugadorAutor, @idPartido) = 1
                SET @errores += N'- El jugador autor del gol está suspendido para este partido.' + @salto;

            IF @minuto IS NOT NULL
               AND EXISTS (SELECT 1
                           FROM eventos.Amonestacion AS a
                           INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                           WHERE a.IdPartido = @idPartido AND a.IdJugador = @idJugadorAutor
                             AND t.Tipo IN ('Roja por doble amarilla', 'Roja directa')
                             AND a.Minuto <= @minuto)
                SET @errores += N'- El jugador autor del gol ya estaba expulsado en ese minuto.' + @salto;
        END;

        -- Validaciones del asistente (opcional)
        IF @idJugadorAsistencia IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM jugadores.Jugador AS j WHERE j.IdJugador = @idJugadorAsistencia)
                SET @errores += N'- El jugador que asiste no existe.' + @salto;
            ELSE IF @idJugadorAsistencia = @idJugadorAutor
                SET @errores += N'- El autor del gol no puede ser también quien asiste.' + @salto;
            ELSE IF @idSelAsistente IS NULL
                SET @errores += N'- El jugador que asiste no está convocado.' + @salto;
            ELSE IF @idSelAutor IS NOT NULL AND @idSelAsistente <> @idSelAutor
                SET @errores += N'- El jugador que asiste debe ser de la misma selección que el autor.' + @salto;
            ELSE IF @existePartido = 1 AND @idSelAsistente NOT IN (ISNULL(@idLocal, -1), ISNULL(@idVisitante, -1))
                SET @errores += N'- El jugador que asiste no pertenece a ninguna de las selecciones del partido.' + @salto;
            ELSE IF @existePartido = 1
            BEGIN
                IF EXISTS (SELECT 1
                           FROM jugadores.Convocatoria AS c
                           INNER JOIN jugadores.Baja AS b ON b.IdConvocatoria = c.IdConvocatoria
                           WHERE c.IdJugador = @idJugadorAsistencia AND b.FechaBaja <= @fechaLocal)
                    SET @errores += N'- El jugador que asiste está dado de baja de la convocatoria.' + @salto;

                IF eventos.fn_EstaSuspendido(@idJugadorAsistencia, @idPartido) = 1
                    SET @errores += N'- El jugador que asiste está suspendido para este partido.' + @salto;

                IF @minuto IS NOT NULL
                   AND EXISTS (SELECT 1
                               FROM eventos.Amonestacion AS a
                               INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                               WHERE a.IdPartido = @idPartido AND a.IdJugador = @idJugadorAsistencia
                                 AND t.Tipo IN ('Roja por doble amarilla', 'Roja directa')
                                 AND a.Minuto <= @minuto)
                    SET @errores += N'- El jugador que asiste ya estaba expulsado en ese minuto.' + @salto;
            END;
        END;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Gol (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE eventos.Gol
            SET IdPartido           = @idPartido,
                IdJugadorAutor      = @idJugadorAutor,
                IdJugadorAsistencia = @idJugadorAsistencia,
                IdTipoGol           = @idTipoGol,
                IdPeriodo           = @idPeriodo,
                Minuto              = @minuto
            WHERE IdGol = @idGol;
        END
        ELSE
        BEGIN
            DELETE FROM eventos.Gol
            WHERE IdGol = @idGol;
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
-- 6. SP_ABM_Amonestacion
-- =========================================================================
CREATE OR ALTER PROCEDURE eventos.SP_ABM_Amonestacion
    @operacion           VARCHAR(12),
    @idAmonestacion      INT          = NULL OUTPUT,
    @idPartido           INT          = NULL,
    @tipoTarjeta         VARCHAR(30)  = NULL,
    @minuto              INT          = NULL,
    @motivo              VARCHAR(200) = NULL,
    @idJugador           INT          = NULL,
    @idStaffTecnico      INT          = NULL,
    @permitirFechaFutura BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    IF @operacion = 'ALTA'
    BEGIN
        EXEC eventos.SP_REGISTRAR_AMONESTACION
            @idPartido           = @idPartido,
            @tipoTarjeta         = @tipoTarjeta,
            @minuto              = @minuto,
            @motivo              = @motivo,
            @idJugador           = @idJugador,
            @idStaffTecnico      = @idStaffTecnico,
            @permitirFechaFutura = @permitirFechaFutura,
            @idAmonestacion      = @idAmonestacion OUTPUT;
        RETURN;
    END;

    DECLARE @errores             NVARCHAR(MAX) = N'',
            @mensaje             NVARCHAR(2048),
            @salto               NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartidoActual     INT,
            @idJugadorActual     INT,
            @tipoActual          VARCHAR(30),
            @estadoActual        VARCHAR(10),
            @existePartido       BIT = 0,
            @estadoDestino       VARCHAR(10),
            @idLocal             INT,
            @idVisitante         INT,
            @fechaHoraUTC        DATETIME2(0),
            @fechaLocal          DATE,
            @idSelSancionado     INT,
            @susRoja             INT,
            @susDoble            INT,
            @susAcum             INT,
            @cantAcum            INT,
            @tipoFinal           VARCHAR(30) = @tipoTarjeta,
            @idTarjetaFinal      INT,
            @partidosSuspension  INT = 0,
            @amarillasPrevias    INT;

    SELECT @idPartidoActual = a.IdPartido,
           @idJugadorActual = a.IdJugador,
           @tipoActual      = t.Tipo,
           @estadoActual    = p.Estado
    FROM eventos.Amonestacion AS a
    INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = a.IdPartido
    WHERE a.IdAmonestacion = @idAmonestacion;

    IF @idPartidoActual IS NULL
        SET @errores += N'- La amonestación indicada no existe.' + @salto;
    ELSE IF @estadoActual = 'Finalizado'
        SET @errores += N'- El partido de la amonestación ya está finalizado: no se puede modificar ni eliminar.' + @salto;

    IF @operacion = 'BAJA'
       AND @idPartidoActual IS NOT NULL
       AND @tipoActual = 'Amarilla'
       AND @idJugadorActual IS NOT NULL
       AND EXISTS (SELECT 1
                   FROM eventos.Amonestacion AS r
                   INNER JOIN eventos.Tarjeta AS tr ON tr.IdTarjeta = r.IdTarjeta
                   WHERE r.IdPartido = @idPartidoActual
                     AND r.IdJugador = @idJugadorActual
                     AND tr.Tipo = 'Roja por doble amarilla')
        SET @errores += N'- No se puede eliminar la primera amarilla mientras exista una roja por doble amarilla del jugador en ese partido.' + @salto;

    IF @operacion = 'MODIFICACION'
    BEGIN
        SELECT @existePartido = 1,
               @estadoDestino = p.Estado,
               @idLocal       = p.IdSeleccionLocal,
               @idVisitante   = p.IdSeleccionVisitante,
               @fechaHoraUTC  = p.FechaHoraUTC,
               @fechaLocal    = CAST(p.FechaHoraLocal AS DATE)
        FROM nucleo.Partido AS p
        WHERE p.IdPartido = @idPartido;

        SELECT @susRoja  = r.PartidosSuspension FROM eventos.ReglaSuspension AS r WHERE r.Criterio = 'Roja Directa';
        SELECT @susDoble = r.PartidosSuspension FROM eventos.ReglaSuspension AS r WHERE r.Criterio = 'Doble Amarilla';
        SELECT @susAcum  = r.PartidosSuspension, @cantAcum = r.CantidadAmarillas
        FROM eventos.ReglaSuspension AS r WHERE r.Criterio = 'Acumulacion Amarillas';

        IF @existePartido = 0
            SET @errores += N'- El partido indicado no existe.' + @salto;
        ELSE
        BEGIN
            IF @idLocal IS NULL OR @idVisitante IS NULL
                SET @errores += N'- El partido no tiene definidas ambas selecciones.' + @salto;
            IF @estadoDestino = 'Finalizado' AND (@idPartidoActual IS NULL OR @idPartido <> @idPartidoActual)
                SET @errores += N'- El partido destino ya está finalizado.' + @salto;
            IF @permitirFechaFutura = 0 AND @fechaHoraUTC > SYSUTCDATETIME()
                SET @errores += N'- No se pueden registrar tarjetas en un partido que todavía no se jugó.' + @salto;
        END;

        IF @tipoTarjeta IS NULL OR @tipoTarjeta NOT IN ('Amarilla', 'Roja directa')
            SET @errores += N'- El tipo de tarjeta debe ser Amarilla o Roja directa (la roja por doble amarilla se genera automáticamente).' + @salto;

        IF (SELECT COUNT(*) FROM eventos.Tarjeta AS t
            WHERE t.Tipo IN ('Amarilla', 'Roja por doble amarilla', 'Roja directa')) < 3
            SET @errores += N'- El catálogo de tarjetas está incompleto (Amarilla, Roja por doble amarilla, Roja directa).' + @salto;

        IF @minuto IS NULL OR @minuto NOT BETWEEN 1 AND 135
            SET @errores += N'- El minuto debe estar entre 1 y 135.' + @salto;

        IF @motivo IS NULL OR LEN(LTRIM(RTRIM(@motivo))) = 0
            SET @errores += N'- El motivo es obligatorio.' + @salto;

        IF (@idJugador IS NULL AND @idStaffTecnico IS NULL)
           OR (@idJugador IS NOT NULL AND @idStaffTecnico IS NOT NULL)
            SET @errores += N'- Debe indicarse un jugador o un miembro del staff técnico (uno solo de los dos).' + @salto;
        ELSE IF @idJugador IS NOT NULL
        BEGIN
            SELECT @idSelSancionado = c.IdSeleccion FROM jugadores.Convocatoria AS c WHERE c.IdJugador = @idJugador;

            IF NOT EXISTS (SELECT 1 FROM jugadores.Jugador AS j WHERE j.IdJugador = @idJugador)
                SET @errores += N'- El jugador indicado no existe.' + @salto;
            ELSE IF @idSelSancionado IS NULL
                SET @errores += N'- El jugador indicado no está convocado.' + @salto;
            ELSE IF @existePartido = 1 AND @idSelSancionado NOT IN (ISNULL(@idLocal, -1), ISNULL(@idVisitante, -1))
                SET @errores += N'- El jugador no pertenece a ninguna de las selecciones del partido.' + @salto;
            ELSE IF @existePartido = 1
            BEGIN
                IF EXISTS (SELECT 1
                           FROM jugadores.Convocatoria AS c
                           INNER JOIN jugadores.Baja AS b ON b.IdConvocatoria = c.IdConvocatoria
                           WHERE c.IdJugador = @idJugador AND b.FechaBaja <= @fechaLocal)
                    SET @errores += N'- El jugador está dado de baja de la convocatoria.' + @salto;

                IF eventos.fn_EstaSuspendido(@idJugador, @idPartido) = 1
                    SET @errores += N'- El jugador está suspendido para este partido.' + @salto;

                IF @minuto IS NOT NULL
                   AND EXISTS (SELECT 1
                               FROM eventos.Amonestacion AS a
                               INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                               WHERE a.IdPartido = @idPartido
                                 AND a.IdJugador = @idJugador
                                 AND a.IdAmonestacion <> @idAmonestacion
                                 AND t.Tipo IN ('Roja por doble amarilla', 'Roja directa')
                                 AND a.Minuto <= @minuto)
                    SET @errores += N'- El jugador ya estaba expulsado en ese minuto.' + @salto;

                IF @susRoja IS NULL OR @susDoble IS NULL OR @susAcum IS NULL OR @cantAcum IS NULL
                    SET @errores += N'- Faltan cargar reglas en eventos.ReglaSuspension (Roja Directa, Doble Amarilla y Acumulacion Amarillas).' + @salto;
            END;
        END
        ELSE
        BEGIN
            SELECT @idSelSancionado = s.IdSeleccion FROM nucleo.StaffTecnico AS s WHERE s.IdStaffTecnico = @idStaffTecnico;

            IF @idSelSancionado IS NULL
                SET @errores += N'- El miembro del staff técnico indicado no existe.' + @salto;
            ELSE IF @existePartido = 1 AND @idSelSancionado NOT IN (ISNULL(@idLocal, -1), ISNULL(@idVisitante, -1))
                SET @errores += N'- El miembro del staff técnico no pertenece a ninguna de las selecciones del partido.' + @salto;
            ELSE IF @existePartido = 1 AND @minuto IS NOT NULL
                    AND EXISTS (SELECT 1
                                FROM eventos.Amonestacion AS a
                                INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                                WHERE a.IdPartido = @idPartido
                                  AND a.IdStaffTecnico = @idStaffTecnico
                                  AND a.IdAmonestacion <> @idAmonestacion
                                  AND t.Tipo IN ('Roja por doble amarilla', 'Roja directa')
                                  AND a.Minuto <= @minuto)
                SET @errores += N'- El miembro del staff técnico ya estaba expulsado en ese minuto.' + @salto;
        END;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Amonestacion (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @operacion = 'MODIFICACION'
        BEGIN
            IF @idJugador IS NOT NULL
            BEGIN
                IF @tipoTarjeta = 'Roja directa'
                    SET @partidosSuspension = @susRoja;
                ELSE IF EXISTS (SELECT 1
                                FROM eventos.Amonestacion AS a
                                INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                                WHERE a.IdPartido = @idPartido
                                  AND a.IdJugador = @idJugador
                                  AND a.IdAmonestacion <> @idAmonestacion
                                  AND t.Tipo = 'Amarilla')
                BEGIN
                    SET @tipoFinal = 'Roja por doble amarilla';
                    SET @partidosSuspension = @susDoble;
                END
                ELSE
                BEGIN
                    SELECT @amarillasPrevias = COUNT(*)
                    FROM eventos.Amonestacion AS a
                    INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                    INNER JOIN nucleo.Partido AS po ON po.IdPartido = a.IdPartido
                    WHERE a.IdJugador = @idJugador
                      AND a.IdAmonestacion <> @idAmonestacion
                      AND t.Tipo = 'Amarilla'
                      AND po.FechaHoraUTC < @fechaHoraUTC
                      AND NOT EXISTS (SELECT 1
                                      FROM eventos.Amonestacion AS r
                                      INNER JOIN eventos.Tarjeta AS tr ON tr.IdTarjeta = r.IdTarjeta
                                      WHERE r.IdPartido = a.IdPartido
                                        AND r.IdJugador = a.IdJugador
                                        AND r.IdAmonestacion <> @idAmonestacion
                                        AND tr.Tipo = 'Roja por doble amarilla');

                    IF (@amarillasPrevias + 1) % @cantAcum = 0
                        SET @partidosSuspension = @susAcum;
                END;
            END
            ELSE IF @idStaffTecnico IS NOT NULL
                    AND @tipoTarjeta = 'Amarilla'
                    AND EXISTS (SELECT 1
                                FROM eventos.Amonestacion AS a
                                INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                                WHERE a.IdPartido = @idPartido
                                  AND a.IdStaffTecnico = @idStaffTecnico
                                  AND a.IdAmonestacion <> @idAmonestacion
                                  AND t.Tipo = 'Amarilla')
            BEGIN
                SET @tipoFinal = 'Roja por doble amarilla';
            END;

            SELECT @idTarjetaFinal = t.IdTarjeta FROM eventos.Tarjeta AS t WHERE t.Tipo = @tipoFinal;

            UPDATE eventos.Amonestacion
            SET IdPartido          = @idPartido,
                IdTarjeta          = @idTarjetaFinal,
                IdJugador          = @idJugador,
                IdStaffTecnico     = @idStaffTecnico,
                Minuto             = @minuto,
                Motivo             = LTRIM(RTRIM(@motivo)),
                PartidosSuspension = @partidosSuspension
            WHERE IdAmonestacion = @idAmonestacion;
        END
        ELSE
        BEGIN
            DELETE FROM eventos.Amonestacion
            WHERE IdAmonestacion = @idAmonestacion;
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