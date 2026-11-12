/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Designar árbitros a un partido validando el impedimento por país
          (árbitro del mismo país que alguna de las selecciones del partido)
          y emitiendo una advertencia desde dieciseisavos si el árbitro es de
          un país con selección que podría cruzarse con las del partido.
*/

/*
SUPUESTOS (nombres tomados del DER; ajustar a lo que implemente cada módulo):
  nucleo.Partido(IdPartido, IdFase)
  nucleo.Fase(IdFase, Descripcion)
  nucleo.Arbitro(IdArbitro, IdPais)                 -- "Árbitro pertenece a País"
  nucleo.Seleccion(IdSeleccion, IdPais)             -- "Selección es representada por País"
  nucleo.DesignacionArbitral(IdPartido, IdArbitro, Rol)   -- relación "Partido Tiene Árbitro" con Rol
  jugadores.fn_SeleccionesDelPartido(@idPartido)    -- devuelve una tabla con IdSeleccion
Roles válidos: 'Principal', 'Asistente' (hasta 2), 'Cuarto', 'VAR'.
Descripciones de fase eliminatoria: 'Dieciseisavos', 'Octavos', 'Cuartos',
                                    'Semifinal', 'Tercer puesto', 'Final'.

CRITERIO DE ADVERTENCIA ("puede cruzarse"):
  Desde dieciseisavos se advierte si el país del árbitro tiene una selección que
  disputa otro partido de la misma fase, es decir, que sigue en competencia y
  podría enfrentarse a alguna de las selecciones de este partido.
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

    DECLARE @idFase INT,
            @descripcionFase VARCHAR(50),
            @idPaisArbitro INT,
            @maxPorRol INT;

    -- Validaciones de datos de entrada.
    IF @rol NOT IN ('Principal', 'Asistente', 'Cuarto', 'VAR')
        THROW 51000, 'Rol inválido. Valores permitidos: Principal, Asistente, Cuarto, VAR.', 1;

    SELECT @idFase = p.IdFase,
           @descripcionFase = f.Descripcion
    FROM nucleo.Partido AS p
    INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
    WHERE p.IdPartido = @idPartido;

    IF @idFase IS NULL
        THROW 51001, 'El partido indicado no existe.', 1;

    SELECT @idPaisArbitro = a.IdPais
    FROM nucleo.Arbitro AS a
    WHERE a.IdArbitro = @idArbitro;

    IF @idPaisArbitro IS NULL
        THROW 51002, 'El árbitro indicado no existe.', 1;

    -- Impedimento: el árbitro no puede ser del país de ninguna de las selecciones del partido.
    IF EXISTS (
        SELECT 1
        FROM jugadores.fn_SeleccionesDelPartido(@idPartido) AS sp
        INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion
        WHERE s.IdPais = @idPaisArbitro
    )
        THROW 51003, 'Designación rechazada: el país del árbitro coincide con el de una de las selecciones del partido.', 1;

    -- El árbitro no puede estar designado dos veces en el mismo partido.
    IF EXISTS (
        SELECT 1
        FROM nucleo.DesignacionArbitral AS d
        WHERE d.IdPartido = @idPartido
          AND d.IdArbitro = @idArbitro
    )
        THROW 51004, 'El árbitro ya está designado en este partido.', 1;

    SET @maxPorRol = CASE @rol WHEN 'Asistente' THEN 2 ELSE 1 END;

    -- Cupo por rol e inserción, en una sola transacción para evitar designaciones simultáneas.
    BEGIN TRY
        BEGIN TRANSACTION;

        IF (
            SELECT COUNT(*)
            FROM nucleo.DesignacionArbitral AS d WITH (UPDLOCK, HOLDLOCK)
            WHERE d.IdPartido = @idPartido
              AND d.Rol = @rol
        ) >= @maxPorRol
            THROW 51005, 'El partido ya tiene cubiertos los lugares para ese rol.', 1;

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
    IF @descripcionFase IN ('Dieciseisavos', 'Octavos', 'Cuartos', 'Semifinal', 'Tercer puesto', 'Final')
       AND EXISTS (
            SELECT 1
            FROM nucleo.Partido AS p
            CROSS APPLY jugadores.fn_SeleccionesDelPartido(p.IdPartido) AS sp
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
