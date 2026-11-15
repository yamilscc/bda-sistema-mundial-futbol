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
Objetivo: Stored procedure eventos.SP_REGISTRAR_AMONESTACION: registra una tarjeta a un jugador o a un
          miembro del staff técnico y calcula la suspensión (acumulación de amarillas, doble
          amarilla y roja directa) según eventos.ReglaSuspension. Requiere ejecutados los
          scripts 01 a 10. Test correspondiente: 12_Test_SP_RegistrarAmonestacion.sql.
*/

USE MundialFutbol;
GO

CREATE OR ALTER PROCEDURE eventos.SP_REGISTRAR_AMONESTACION
    @idPartido           INT,
    @tipoTarjeta         VARCHAR(30),
    @minuto              INT,
    @motivo              VARCHAR(200),
    @idJugador           INT = NULL,
    @idStaffTecnico      INT = NULL,
    @permitirFechaFutura BIT = 0,
    @idAmonestacion      INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores            NVARCHAR(MAX) = N'',
            @mensaje            NVARCHAR(2048),
            @salto              NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @existe             BIT = 0,
            @estado             VARCHAR(10),
            @idLocal            INT,
            @idVisitante        INT,
            @fechaHoraUTC       DATETIME2(0),
            @fechaLocal         DATE,
            @idSelSancionado    INT,
            @susRoja            INT,
            @susDoble           INT,
            @susAcum            INT,
            @cantAcum           INT,
            @tipoFinal          VARCHAR(30) = @tipoTarjeta,
            @idTarjetaFinal     INT,
            @partidosSuspension INT = 0,
            @amarillasPrevias   INT;

    SELECT @existe       = 1,
           @estado       = p.Estado,
           @idLocal      = p.IdSeleccionLocal,
           @idVisitante  = p.IdSeleccionVisitante,
           @fechaHoraUTC = p.FechaHoraUTC,
           @fechaLocal   = CAST(p.FechaHoraLocal AS DATE)
    FROM nucleo.Partido AS p
    WHERE p.IdPartido = @idPartido;

    SELECT @susRoja  = r.PartidosSuspension FROM eventos.ReglaSuspension AS r WHERE r.Criterio = 'Roja Directa';
    SELECT @susDoble = r.PartidosSuspension FROM eventos.ReglaSuspension AS r WHERE r.Criterio = 'Doble Amarilla';
    SELECT @susAcum  = r.PartidosSuspension, @cantAcum = r.CantidadAmarillas
    FROM eventos.ReglaSuspension AS r WHERE r.Criterio = 'Acumulacion Amarillas';

    -- ---- Validaciones ----------------------------------------------------
    IF @existe = 0
        SET @errores += N'- El partido indicado no existe.' + @salto;
    ELSE
    BEGIN
        IF @idLocal IS NULL OR @idVisitante IS NULL
            SET @errores += N'- El partido no tiene definidas ambas selecciones.' + @salto;
        IF @estado = 'Finalizado'
            SET @errores += N'- El partido ya está finalizado: no se pueden registrar más tarjetas.' + @salto;
        IF @permitirFechaFutura = 0 AND @fechaHoraUTC > SYSUTCDATETIME()
            SET @errores += N'- No se pueden registrar tarjetas de un partido que todavía no se jugó.' + @salto;
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
        ELSE IF @existe = 1 AND @idSelSancionado NOT IN (ISNULL(@idLocal, -1), ISNULL(@idVisitante, -1))
            SET @errores += N'- El jugador no pertenece a ninguna de las selecciones del partido.' + @salto;
        ELSE IF @existe = 1
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
                           WHERE a.IdPartido = @idPartido AND a.IdJugador = @idJugador
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
        ELSE IF @existe = 1 AND @idSelSancionado NOT IN (ISNULL(@idLocal, -1), ISNULL(@idVisitante, -1))
            SET @errores += N'- El miembro del staff técnico no pertenece a ninguna de las selecciones del partido.' + @salto;
        ELSE IF @existe = 1 AND @minuto IS NOT NULL
                AND EXISTS (SELECT 1
                            FROM eventos.Amonestacion AS a
                            INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                            WHERE a.IdPartido = @idPartido AND a.IdStaffTecnico = @idStaffTecnico
                              AND t.Tipo IN ('Roja por doble amarilla', 'Roja directa')
                              AND a.Minuto <= @minuto)
            SET @errores += N'- El miembro del staff técnico ya estaba expulsado en ese minuto.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_REGISTRAR_AMONESTACION - No se pudo registrar la tarjeta:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @idJugador IS NOT NULL
        BEGIN
            IF @tipoTarjeta = 'Roja directa'
                SET @partidosSuspension = @susRoja;
            ELSE IF EXISTS (SELECT 1
                            FROM eventos.Amonestacion AS a
                            INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
                            WHERE a.IdPartido = @idPartido AND a.IdJugador = @idJugador
                              AND t.Tipo = 'Amarilla')
            BEGIN
                -- Segunda amarilla en el mismo partido: se registra como roja por doble amarilla.
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
                  AND t.Tipo = 'Amarilla'
                  AND po.FechaHoraUTC < @fechaHoraUTC
                  AND NOT EXISTS (SELECT 1
                                  FROM eventos.Amonestacion AS r
                                  INNER JOIN eventos.Tarjeta AS tr ON tr.IdTarjeta = r.IdTarjeta
                                  WHERE r.IdPartido = a.IdPartido AND r.IdJugador = a.IdJugador
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
                            WHERE a.IdPartido = @idPartido AND a.IdStaffTecnico = @idStaffTecnico
                              AND t.Tipo = 'Amarilla')
        BEGIN
            -- Segunda amarilla al staff en el mismo partido: se registra como roja por doble amarilla (sin suspensión).
            SET @tipoFinal = 'Roja por doble amarilla';
        END;

        SELECT @idTarjetaFinal = t.IdTarjeta FROM eventos.Tarjeta AS t WHERE t.Tipo = @tipoFinal;

        INSERT INTO eventos.Amonestacion (IdPartido, IdTarjeta, IdJugador, IdStaffTecnico, Minuto, Motivo, PartidosSuspension)
        VALUES (@idPartido, @idTarjetaFinal, @idJugador, @idStaffTecnico, @minuto, LTRIM(RTRIM(@motivo)), @partidosSuspension);

        SET @idAmonestacion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT a.IdAmonestacion, a.IdPartido, t.Tipo AS Tarjeta, a.IdJugador, a.IdStaffTecnico,
           a.Minuto, a.Motivo, a.PartidosSuspension
    FROM eventos.Amonestacion AS a
    INNER JOIN eventos.Tarjeta AS t ON t.IdTarjeta = a.IdTarjeta
    WHERE a.IdAmonestacion = @idAmonestacion;
END;
GO