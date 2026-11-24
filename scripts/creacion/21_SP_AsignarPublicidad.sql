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
Objetivo: Stored procedure de lógica de negocio publicidad.SP_ASIGNAR_PUBLICIDAD: propone y
          registra qué piezas publicitarias ocupan los cuatro espacios de un partido, según
          los criterios de la sección H del enunciado (países de las selecciones, poder
          adquisitivo y prime time). Cada número de espacio tiene su propio criterio.
          Requiere ejecutados los scripts 01 a 20 (usa nucleo.fn_MercadosEnPrimeTime y
          nucleo.fn_SeleccionesDelPartido).
          Test correspondiente: testing/21_Test_SP_AsignarPublicidad.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- SP_ASIGNAR_PUBLICIDAD
-- Completa los espacios libres (1 a 4) de un partido y devuelve los cuatro espacios del
-- partido con el criterio aplicado a cada asignación.
--
-- CRITERIO POR ESPACIO PUBLICITARIO (en cada caso se elige UNA pieza al azar entre las
-- candidatas, buscadas en publicidad.OrientacionPais):
--   Espacio 1: pieza orientada al país de la selección LOCAL del partido.
--   Espacio 2: pieza orientada al país de la selección VISITANTE del partido.
--   Espacio 3: pieza orientada a alguno de los 3 países con mayor PBI per cápita
--              (nucleo.Pais ordenado por PBIPerCapitaUSD descendente; desempate por IdPais;
--              los países sin PBI importado no participan del ranking).
--   Espacio 4: pieza orientada a alguno de los países donde el partido cae en prime time local
--              (19:00 a 22:59), según nucleo.fn_MercadosEnPrimeTime.
--
-- REGLAS:
--   - Los espacios se completan en orden (1, 2, 3, 4), por lo que una pieza elegida para un
--     espacio queda fuera de las candidatas de los siguientes (una pieza no puede ocupar dos
--     espacios del mismo partido, UQ_EspacioPublicitario_Partido_Pieza).
--   - La elección es uniforme entre piezas distintas: una pieza orientada a varios países del
--     conjunto no tiene más probabilidad que una orientada a uno solo.
--   - Si el partido ya tiene espacios cargados (por ejemplo, a mano con SP_ABM_EspacioPublicitario),
--     solo se completan los números libres con el criterio de cada número; los ocupados no se
--     tocan y sus piezas no se repiten.
--   - No hay criterio de reemplazo: si un espacio no tiene pieza candidata (por ejemplo, el cruce
--     todavía no está definido y no hay selección local/visitante, o ninguna pieza apunta a
--     esos países) queda libre y se informa en @advertencia (no es un error).
--   - La tarifa y la moneda recibidas se aplican a cada franja asignada en esta corrida
--     (son las vigentes al momento de la asignación, para poder facturar después).
--   - El resultado NO es determinista (usa NEWID()): dos corridas sobre el mismo partido pueden
--     elegir piezas distintas.
--
-- Validaciones (se informan todas juntas en un único mensaje, THROW 52000):
--   - Partido existente.
--   - Tarifa obligatoria y no negativa; moneda existente.
--   - El partido tiene al menos un espacio libre.
--   - Se pudo elegir al menos una pieza para los espacios libres.
-- Las validaciones se hacen antes de abrir la transacción (igual que los SP ABM), por lo que un
-- error de validación nunca deshace una transacción externa del llamador.
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_ASIGNAR_PUBLICIDAD
    @idPartido          INT,
    @tarifaPublicitaria DECIMAL(12,2),
    @idMoneda           INT,
    @advertencia        VARCHAR(200) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @advertencia = NULL;

    DECLARE @errores         NVARCHAR(MAX) = N'',
            @mensaje         NVARCHAR(2048),
            @salto           NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @existePartido   BIT           = 0,
            @cantidadLibres  INT           = 0,
            @cantidadAsignar INT           = 0,
            @orden           INT,
            @numeroEspacio   TINYINT,
            @idPieza         INT,
            @criterio        VARCHAR(60);

    -- Espacios (1 a 4) que todavía no tiene el partido, numerados por orden de número.
    DECLARE @libres TABLE (
        Orden         INT     NOT NULL PRIMARY KEY,
        NumeroEspacio TINYINT NOT NULL
    );

    -- Países que aplican al espacio que se está resolviendo (se recarga en cada vuelta).
    DECLARE @paisesEspacio TABLE (
        IdPais SMALLINT NOT NULL PRIMARY KEY
    );

    -- Piezas elegidas, una por espacio, con el criterio que se aplicó.
    DECLARE @elegidas TABLE (
        NumeroEspacio TINYINT     NOT NULL PRIMARY KEY,
        IdPieza       INT         NOT NULL,
        Criterio      VARCHAR(60) NOT NULL
    );

    -- Espacios libres para los que no hubo ninguna pieza candidata.
    DECLARE @sinPieza TABLE (
        NumeroEspacio TINYINT NOT NULL PRIMARY KEY
    );

    -- ---- Validaciones (se acumulan todas) --------------------------------
    IF @idPartido IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdPartido = @idPartido)
        SET @errores += N'- El partido indicado no existe.' + @salto;
    ELSE
        SET @existePartido = 1;

    IF @tarifaPublicitaria IS NULL OR @tarifaPublicitaria < 0
        SET @errores += N'- La tarifa publicitaria es obligatoria y no puede ser negativa.' + @salto;

    IF @idMoneda IS NULL
       OR NOT EXISTS (SELECT 1 FROM publicidad.Moneda WHERE IdMoneda = @idMoneda)
        SET @errores += N'- La moneda indicada no existe.' + @salto;

    -- Estas dos dependen de que el partido exista.
    IF @existePartido = 1
    BEGIN
        INSERT INTO @libres (Orden, NumeroEspacio)
        SELECT ROW_NUMBER() OVER (ORDER BY n.Numero), n.Numero
        FROM (VALUES (1), (2), (3), (4)) AS n (Numero)
        WHERE NOT EXISTS (SELECT 1
                          FROM publicidad.EspacioPublicitario AS e
                          WHERE e.IdPartido     = @idPartido
                            AND e.NumeroEspacio = n.Numero);

        SELECT @cantidadLibres = COUNT(*) FROM @libres;

        IF @cantidadLibres = 0
            SET @errores += N'- El partido ya tiene sus cuatro espacios publicitarios asignados.' + @salto;
        ELSE
        BEGIN
            -- Se resuelve un espacio por vez, de menor a mayor número: cada uno tiene su conjunto
            -- de países y se elige una pieza al azar entre las que apuntan a ese conjunto.
            SET @orden = 1;
            WHILE @orden <= @cantidadLibres
            BEGIN
                SELECT @numeroEspacio = NumeroEspacio FROM @libres WHERE Orden = @orden;
                DELETE FROM @paisesEspacio;
                SET @idPieza = NULL;

                IF @numeroEspacio = 1
                BEGIN
                    SET @criterio = 'Pais de la seleccion local';
                    INSERT INTO @paisesEspacio (IdPais)
                    SELECT s.IdPais
                    FROM nucleo.fn_SeleccionesDelPartido(@idPartido) AS sp
                    INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion
                    WHERE sp.Localia = 'Local';
                END
                ELSE IF @numeroEspacio = 2
                BEGIN
                    SET @criterio = 'Pais de la seleccion visitante';
                    INSERT INTO @paisesEspacio (IdPais)
                    SELECT s.IdPais
                    FROM nucleo.fn_SeleccionesDelPartido(@idPartido) AS sp
                    INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion
                    WHERE sp.Localia = 'Visitante';
                END
                ELSE IF @numeroEspacio = 3
                BEGIN
                    SET @criterio = 'Top 3 paises por PBI per capita';
                    INSERT INTO @paisesEspacio (IdPais)
                    SELECT TOP (3) pa.IdPais
                    FROM nucleo.Pais AS pa
                    WHERE pa.PBIPerCapitaUSD IS NOT NULL
                    ORDER BY pa.PBIPerCapitaUSD DESC, pa.IdPais ASC;
                END
                ELSE
                BEGIN
                    SET @criterio = 'Pais en prime time local';
                    INSERT INTO @paisesEspacio (IdPais)
                    SELECT mp.IdPais
                    FROM nucleo.fn_MercadosEnPrimeTime(@idPartido) AS mp;
                END;

                -- Una pieza al azar entre las distintas candidatas. Se descartan las piezas que
                -- ya están en el partido (cargadas a mano) o que se eligieron para un espacio anterior.
                SELECT TOP (1) @idPieza = c.IdPieza
                FROM (SELECT DISTINCT op.IdPieza
                      FROM publicidad.OrientacionPais AS op
                      INNER JOIN @paisesEspacio AS pe ON pe.IdPais = op.IdPais
                      WHERE NOT EXISTS (SELECT 1
                                        FROM publicidad.EspacioPublicitario AS e
                                        WHERE e.IdPartido = @idPartido
                                          AND e.IdPieza   = op.IdPieza)
                        AND NOT EXISTS (SELECT 1
                                        FROM @elegidas AS el
                                        WHERE el.IdPieza = op.IdPieza)) AS c
                ORDER BY NEWID();

                IF @idPieza IS NULL
                    INSERT INTO @sinPieza (NumeroEspacio) VALUES (@numeroEspacio);
                ELSE
                    INSERT INTO @elegidas (NumeroEspacio, IdPieza, Criterio)
                    VALUES (@numeroEspacio, @idPieza, @criterio);

                SET @orden += 1;
            END;

            SELECT @cantidadAsignar = COUNT(*) FROM @elegidas;

            IF @cantidadAsignar = 0
                SET @errores += N'- No hay piezas publicitarias candidatas para los espacios libres: se necesita al menos una pieza orientada a los países que indica el criterio de cada espacio y que no esté ya asignada al partido.' + @salto;
        END;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ASIGNAR_PUBLICIDAD - No se pudo asignar la publicidad:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    -- Si otra sesión ocupó un espacio o una pieza entre la validación y el INSERT, la PK
    -- (IdPartido, NumeroEspacio) o la UQ (IdPartido, IdPieza) lo rechazan y se deshace todo
    -- (no queda una asignación a medias).
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
        SELECT @idPartido, el.NumeroEspacio, el.IdPieza, @tarifaPublicitaria, @idMoneda
        FROM @elegidas AS el;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    IF @cantidadAsignar < @cantidadLibres
    BEGIN
        SELECT @advertencia = 'Advertencia: sin pieza candidata para los espacios '
                            + STRING_AGG(CAST(NumeroEspacio AS VARCHAR(1)), ', ') WITHIN GROUP (ORDER BY NumeroEspacio)
                            + '; quedaron sin asignar.'
        FROM @sinPieza;
        PRINT @advertencia;
    END;

    -- Los cuatro espacios del partido. El criterio solo se informa para los espacios asignados
    -- en esta corrida (NULL en los que ya estaban ocupados).
    SELECT e.NumeroEspacio,
           e.IdPieza,
           pz.Titulo,
           an.Nombre             AS Anunciante,
           e.TarifaPublicitaria,
           mo.Codigo             AS Moneda,
           CAST(CASE WHEN el.IdPieza IS NULL THEN 0 ELSE 1 END AS BIT) AS AsignadoAhora,
           el.Criterio
    FROM publicidad.EspacioPublicitario AS e
    INNER JOIN publicidad.Pieza       AS pz ON pz.IdPieza       = e.IdPieza
    INNER JOIN publicidad.Anunciante  AS an ON an.IdAnunciante  = pz.IdAnunciante
    INNER JOIN publicidad.Moneda      AS mo ON mo.IdMoneda      = e.IdMoneda
    LEFT JOIN @elegidas               AS el ON el.NumeroEspacio = e.NumeroEspacio
                                           AND el.IdPieza       = e.IdPieza
    WHERE e.IdPartido = @idPartido
    ORDER BY e.NumeroEspacio;
END;
GO
