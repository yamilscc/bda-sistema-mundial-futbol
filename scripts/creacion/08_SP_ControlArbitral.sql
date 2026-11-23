/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-15
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Designar árbitros a un partido validando el impedimento por país
          (árbitro del mismo país que alguna de las selecciones del partido)
          y emitiendo una advertencia desde dieciseisavos si el árbitro es de
          un país con selección que podría cruzarse con las del partido.
          Todas las validaciones se acumulan y se informan en UN solo mensaje
          (THROW 52000, igual que los SP del script 09). Reemplaza a los THROW
          51000 a 51005 de la versión anterior, que cortaban en el primer error.
          Test correspondiente: testing/08_Test_SP_ControlArbitral.sql.
*/

USE MundialFutbol;
GO

/*
Roles válidos: 'Principal', 'Asistente 1', 'Asistente 2', 'Cuarto', 'VAR' (uno de cada uno).
Fases eliminatorias: 'Dieciseisavos de final', 'Octavos de final', 'Cuartos de final', 'Semifinal',
'Tercer puesto', 'Final'.
Solo se designan árbitros habilitados (Arbitro.EstaHabilitado = 'Y').

CRITERIO DE ADVERTENCIA ("puede cruzarse"):
  Desde dieciseisavos se advierte si el país del árbitro tiene una selección que
  disputa otro partido de la misma fase, es decir, que sigue en competencia y
  podría enfrentarse a alguna de las selecciones de este partido.
  La advertencia no impide la designación: se devuelve en @advertencia y se imprime.
*/

CREATE OR ALTER PROCEDURE nucleo.SP_CONTROL_ARBITRAL
    @idPartido   INT,
    @idArbitro   INT,
    @rol         VARCHAR(15),
    @advertencia VARCHAR(200) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @advertencia = NULL;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idFase          INT,
            @descripcionFase VARCHAR(50),
            @idPaisArbitro   INT,
            @estaHabilitado  CHAR(1),
            @rolValido       BIT = 0,
            @maxPorRol       INT;

    -- Las validaciones y la inserción van en una sola transacción: el conteo de cupo por rol
    -- toma UPDLOCK/HOLDLOCK para evitar designaciones simultáneas que lo superen.
    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @idFase = p.IdFase,
               @descripcionFase = f.Nombre
        FROM nucleo.Partido AS p
        INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
        WHERE p.IdPartido = @idPartido;

        SELECT @idPaisArbitro  = a.IdPais,
               @estaHabilitado = a.EstaHabilitado
        FROM nucleo.Arbitro AS a
        WHERE a.IdArbitro = @idArbitro;

        -- ---- Validaciones (se acumulan todas) --------------------------------
        IF @rol IS NULL OR @rol NOT IN ('Principal', 'Asistente 1', 'Asistente 2', 'Cuarto', 'VAR')
            SET @errores += N'- Rol inválido. Valores permitidos: Principal, Asistente 1, Asistente 2, Cuarto, VAR.' + @salto;
        ELSE
            SET @rolValido = 1;

        IF @idFase IS NULL
            SET @errores += N'- El partido indicado no existe.' + @salto;

        IF @idPaisArbitro IS NULL
            SET @errores += N'- El árbitro indicado no existe.' + @salto;
        ELSE IF @estaHabilitado <> 'Y'
            SET @errores += N'- El árbitro no está habilitado para ser designado.' + @salto;

        -- Estas dos dependen de que existan el partido y el árbitro.
        IF @idFase IS NOT NULL AND @idPaisArbitro IS NOT NULL
        BEGIN
            -- Impedimento: el árbitro no puede ser del país de ninguna de las selecciones del partido.
            IF EXISTS (
                SELECT 1
                FROM nucleo.fn_SeleccionesDelPartido(@idPartido) AS sp
                INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion
                WHERE s.IdPais = @idPaisArbitro
            )
                SET @errores += N'- Designación rechazada: el país del árbitro coincide con el de una de las selecciones del partido.' + @salto;

            -- El árbitro no puede estar designado dos veces en el mismo partido.
            IF EXISTS (
                SELECT 1
                FROM nucleo.DesignacionArbitral AS d
                WHERE d.IdPartido = @idPartido
                  AND d.IdArbitro = @idArbitro
            )
                SET @errores += N'- El árbitro ya está designado en este partido.' + @salto;
        END;

        -- Cupo por rol: depende de que exista el partido y de que el rol sea válido.
        IF @idFase IS NOT NULL AND @rolValido = 1
        BEGIN
            SET @maxPorRol = 1;

            IF (
                SELECT COUNT(*)
                FROM nucleo.DesignacionArbitral AS d WITH (UPDLOCK, HOLDLOCK)
                WHERE d.IdPartido = @idPartido
                  AND d.Rol = @rol
            ) >= @maxPorRol
                SET @errores += N'- El partido ya tiene cubiertos los lugares para ese rol.' + @salto;
        END;

        IF LEN(@errores) > 0
        BEGIN
            SET @mensaje = LEFT(N'SP_CONTROL_ARBITRAL - No se pudo designar al árbitro:'
                                + @salto + @errores, 2048);
            THROW 52000, @mensaje, 1;   -- el CATCH hace ROLLBACK y relanza este mismo error
        END;

        INSERT INTO nucleo.DesignacionArbitral (IdPartido, IdArbitro, Rol)
        VALUES (@idPartido, @idArbitro, @rol);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    -- Advertencia desde dieciseisavos: el país del árbitro tiene una selección
    -- que disputa otra llave de la misma fase y podría cruzarse con las de este partido.
    IF @descripcionFase IN ('Dieciseisavos de final', 'Octavos de final', 'Cuartos de final', 'Semifinal', 'Tercer puesto', 'Final')
       AND EXISTS (
            SELECT 1
            FROM nucleo.Partido AS p
            CROSS APPLY nucleo.fn_SeleccionesDelPartido(p.IdPartido) AS sp
            INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion
            WHERE p.IdFase = @idFase
              AND p.IdPartido <> @idPartido
              AND s.IdPais = @idPaisArbitro
       )
    BEGIN
        SET @advertencia = 'Advertencia: el país del árbitro tiene una selección que podría cruzarse con las de este partido.';
        PRINT @advertencia;
    END;
END;
GO
