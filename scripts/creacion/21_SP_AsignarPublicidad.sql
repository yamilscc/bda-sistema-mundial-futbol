/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-19
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Stored procedure de lógica de negocio publicidad.SP_ASIGNAR_PUBLICIDAD: propone y
          registra qué piezas publicitarias ocupan los cuatro espacios de un partido, según
          los criterios de la sección H del enunciado (público de cada encuentro y prime time).
          Requiere ejecutados los scripts 01 a 20 (usa nucleo.fn_MercadosEnPrimeTime y
          jugadores.fn_SeleccionesDelPartido).
          Test correspondiente: testing/21_Test_SP_AsignarPublicidad.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- SP_ASIGNAR_PUBLICIDAD
-- Completa los espacios libres (1 a 4) de un partido con las mejores piezas candidatas y
-- devuelve los cuatro espacios del partido con el motivo de cada asignación.
--
-- CRITERIO DE PRIORIZACIÓN (en este orden; se compara pieza contra pieza):
--   1. Pieza orientada al país de alguna de las selecciones que juegan el partido.
--   2. Mayor PBI per cápita (poder adquisitivo) entre los países de orientación de la pieza.
--      Un país sin PBI importado cuenta como 0.
--   3. Alguno de los países de orientación de la pieza está en prime time (19:00 a 22:59 hora
--      local) al momento del partido, según nucleo.fn_MercadosEnPrimeTime.
--   Desempate final: menor IdPieza (el resultado es siempre el mismo para los mismos datos).
--
-- REGLAS:
--   - Son candidatas las piezas con al menos un país de orientación y que todavía no están
--     asignadas en ese partido (una pieza no puede ocupar dos espacios, UQ_EspacioPublicitario_Partido_Pieza).
--   - Si el partido ya tiene espacios cargados (por ejemplo, a mano con SP_ABM_EspacioPublicitario),
--     solo se completan los números libres; los ya ocupados no se tocan.
--   - La prioridad 1 recibe el número libre más bajo, la 2 el siguiente, y así sucesivamente.
--   - La tarifa y la moneda recibidas se aplican a cada franja asignada en esta corrida
--     (son las vigentes al momento de la asignación, para poder facturar después).
--   - Si hay menos candidatas que espacios libres, se asignan las que haya y se informa
--     una advertencia en @advertencia (no es un error).
--
-- Validaciones (se informan todas juntas en un único mensaje, THROW 52000):
--   - Partido existente.
--   - Tarifa obligatoria y no negativa; moneda existente.
--   - El partido tiene al menos un espacio libre.
--   - Existe al menos una pieza candidata.
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
            @cantidadAsignar INT           = 0;

    -- Espacios (1 a 4) que todavía no tiene el partido, numerados por orden de número.
    DECLARE @libres TABLE (
        Orden         INT     NOT NULL PRIMARY KEY,
        NumeroEspacio TINYINT NOT NULL
    );

    -- Piezas elegidas, numeradas por orden de prioridad, con los datos del criterio aplicado.
    DECLARE @elegidas TABLE (
        Orden                INT           NOT NULL PRIMARY KEY,
        IdPieza              INT           NOT NULL,
        ApuntaAParticipante  BIT           NOT NULL,
        PBIMaximo            DECIMAL(12,2) NOT NULL,
        EnPrimeTime          BIT           NOT NULL
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
            -- Ranking de piezas candidatas: se evalúa cada par (pieza, país de orientación)
            -- y luego se resume por pieza. Todo en una sola consulta basada en conjuntos.
            WITH MercadoPieza AS (
                SELECT op.IdPieza,
                       CASE WHEN sel.IdPais IS NOT NULL THEN 1 ELSE 0 END AS EsParticipante,
                       ISNULL(pa.PBIPerCapita, 0)                         AS PBI,
                       CASE WHEN mp.IdPais  IS NOT NULL THEN 1 ELSE 0 END AS EnPrimeTime
                FROM publicidad.OrientacionPais AS op
                INNER JOIN nucleo.Pais AS pa ON pa.IdPais = op.IdPais
                LEFT JOIN (SELECT s.IdPais
                           FROM jugadores.fn_SeleccionesDelPartido(@idPartido) AS sp
                           INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion) AS sel
                       ON sel.IdPais = op.IdPais
                LEFT JOIN nucleo.fn_MercadosEnPrimeTime(@idPartido) AS mp
                       ON mp.IdPais = op.IdPais
                WHERE NOT EXISTS (SELECT 1
                                  FROM publicidad.EspacioPublicitario AS e
                                  WHERE e.IdPartido = @idPartido
                                    AND e.IdPieza   = op.IdPieza)
            ),
            PorPieza AS (
                SELECT IdPieza,
                       MAX(EsParticipante) AS ApuntaAParticipante,
                       MAX(PBI)            AS PBIMaximo,
                       MAX(EnPrimeTime)    AS EnPrimeTime
                FROM MercadoPieza
                GROUP BY IdPieza
            ),
            Ranking AS (
                SELECT IdPieza, ApuntaAParticipante, PBIMaximo, EnPrimeTime,
                       ROW_NUMBER() OVER (ORDER BY ApuntaAParticipante DESC,
                                                   PBIMaximo           DESC,
                                                   EnPrimeTime         DESC,
                                                   IdPieza             ASC) AS Orden
                FROM PorPieza
            )
            INSERT INTO @elegidas (Orden, IdPieza, ApuntaAParticipante, PBIMaximo, EnPrimeTime)
            SELECT Orden, IdPieza, CAST(ApuntaAParticipante AS BIT), PBIMaximo, CAST(EnPrimeTime AS BIT)
            FROM Ranking
            WHERE Orden <= @cantidadLibres;

            SELECT @cantidadAsignar = COUNT(*) FROM @elegidas;

            IF @cantidadAsignar = 0
                SET @errores += N'- No hay piezas publicitarias candidatas: se necesita al menos una pieza con países de orientación que no esté ya asignada al partido.' + @salto;
        END;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ASIGNAR_PUBLICIDAD - No se pudo asignar la publicidad:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    -- ---- Operación -------------------------------------------------------
    -- La pieza de mayor prioridad toma el número libre más bajo. Si otra sesión ocupó un
    -- espacio entre la validación y el INSERT, la PK (IdPartido, NumeroEspacio) lo rechaza
    -- y se deshace todo (no queda una asignación a medias).
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda)
        SELECT @idPartido, l.NumeroEspacio, el.IdPieza, @tarifaPublicitaria, @idMoneda
        FROM @elegidas AS el
        INNER JOIN @libres AS l ON l.Orden = el.Orden;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    IF @cantidadAsignar < @cantidadLibres
    BEGIN
        SET @advertencia = 'Advertencia: solo hubo ' + CAST(@cantidadAsignar AS VARCHAR(10))
                         + ' piezas candidatas para ' + CAST(@cantidadLibres AS VARCHAR(10))
                         + ' espacios libres; quedaron espacios sin asignar.';
        PRINT @advertencia;
    END;

    -- Los cuatro espacios del partido. Las columnas de criterio solo se informan para los
    -- espacios asignados en esta corrida (NULL en los que ya estaban ocupados).
    SELECT e.NumeroEspacio,
           e.IdPieza,
           pz.Titulo,
           an.Nombre             AS Anunciante,
           e.TarifaPublicitaria,
           mo.Codigo             AS Moneda,
           CAST(CASE WHEN el.IdPieza IS NULL THEN 0 ELSE 1 END AS BIT) AS AsignadoAhora,
           el.ApuntaAParticipante,
           el.PBIMaximo,
           el.EnPrimeTime
    FROM publicidad.EspacioPublicitario AS e
    INNER JOIN publicidad.Pieza       AS pz ON pz.IdPieza       = e.IdPieza
    INNER JOIN publicidad.Anunciante  AS an ON an.IdAnunciante  = pz.IdAnunciante
    INNER JOIN publicidad.Moneda      AS mo ON mo.IdMoneda      = e.IdMoneda
    LEFT JOIN @elegidas               AS el ON el.IdPieza       = e.IdPieza
    WHERE e.IdPartido = @idPartido
    ORDER BY e.NumeroEspacio;
END;
GO
