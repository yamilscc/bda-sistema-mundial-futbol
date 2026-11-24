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
Objetivo: Stored procedure de lógica de negocio publicidad.SP_ASIGNAR_PUBLICIDAD: propone (y, si no
          es una simulación, registra) qué piezas publicitarias ocupan los espacios libres de un partido,
          con un ranking determinista según la sección H del enunciado: (1) piezas dirigidas a los países
          de las selecciones del partido, (2) piezas dirigidas a mercados de mayor PBI per cápita y
          (3) piezas cuya franja cae en prime time del mercado destino. La tarifa se toma de
          publicidad.Tarifa según la fase y la fecha del partido.
          Requiere ejecutados los scripts 01 a 20 (usa nucleo.fn_MercadosEnPrimeTime y
          nucleo.fn_SeleccionesDelPartido).
          Test correspondiente: testing/21_Test_SP_AsignarPublicidad.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- SP_ASIGNAR_PUBLICIDAD
-- Completa los espacios libres (1 a 4) de un partido con las piezas mejor rankeadas.
--
-- CANDIDATAS: toda pieza con al menos un país en publicidad.OrientacionPais que no esté ya en un
-- espacio del partido y cuyo anunciante no tenga ya un espacio en el partido.
--
-- RANKING (por pieza, sobre SUS países de orientación):
--   1. EsParticipante DESC: alguno de sus países es el de la selección local o visitante
--      (nucleo.fn_SeleccionesDelPartido). Un partido con cruce sin definir no tiene participantes.
--   2. PBIMax DESC: mayor PBIPerCapitaUSD entre sus países (los países sin PBI no cuentan; una
--      pieza sin ningún país con PBI queda última en este criterio).
--   3. EnPrimeTime DESC: alguno de sus países está en prime time local (19:00 a 22:59) a la hora
--      del partido (nucleo.fn_MercadosEnPrimeTime).
--   4. IdPieza ASC: desempate final, para que el resultado sea DETERMINISTA (misma base, mismo
--      resultado en cada corrida).
--
-- REGLAS:
--   - Una pieza por anunciante en cada partido: de cada anunciante se queda la mejor pieza según el
--     mismo orden (ROW_NUMBER por anunciante). Los anunciantes que ya ocupan un espacio del partido
--     (por ejemplo, cargado a mano o por la pauta importada) no vuelven a entrar.
--   - Se toman las N mejores, con N = cantidad de espacios libres, y se asignan a los números libres
--     de menor a mayor (la mejor al número libre más bajo). Los espacios ocupados no se tocan.
--   - Si hay menos candidatas que espacios libres, se asignan las que hay y se avisa por
--     @advertencia (no es un error).
--   - CriterioAsignacion guarda por qué salió elegida, por ejemplo
--     'Participante | PBI 22800 (URU) | Prime time'.
--   - Tarifa: la de publicidad.Tarifa para la fase del partido con mayor VigenciaDesde <= fecha del
--     partido (FechaHoraUTC). Si en esa fecha hay varias monedas, se prefiere USD y después el menor
--     IdTarifa. El monto y la moneda se copian a cada espacio (histórico para facturar).
--   - @soloSimular = 1 devuelve la propuesta sin insertar nada.
--
-- RESULTADO: un result set con los cuatro números de espacio que quedan ocupados en el partido
-- (ya ocupados y asignados/propuestos en esta corrida): NumeroEspacio, IdPieza, Titulo, Anunciante,
-- TarifaPublicitaria, Moneda, Estado ('Ya ocupado', 'Asignado' o 'Propuesto') y Criterio.
--
-- Validaciones (se informan todas juntas en un único mensaje, THROW 52000):
--   - Partido existente.
--   - Partido no finalizado (sus espacios son histórico de facturación).
--   - El partido tiene al menos un espacio libre.
--   - Hay tarifa vigente para la fase del partido a la fecha del partido.
--   - Hay al menos una pieza candidata para los espacios libres.
-- Las validaciones se hacen antes de abrir la transacción (igual que los SP ABM), por lo que un
-- error de validación nunca deshace una transacción externa del llamador.
-- =========================================================================
CREATE OR ALTER PROCEDURE publicidad.SP_ASIGNAR_PUBLICIDAD
    @idPartido   INT,
    @soloSimular BIT          = 0,
    @advertencia VARCHAR(200) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @advertencia = NULL;
    SET @soloSimular = ISNULL(@soloSimular, 0);

    DECLARE @errores         NVARCHAR(MAX) = N'',
            @mensaje         NVARCHAR(2048),
            @salto           NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @existePartido   BIT           = 0,
            @estado          VARCHAR(10),
            @idFase          TINYINT,
            @fechaPartido    DATE,
            @montoTarifa     DECIMAL(12,2),
            @idMonedaTarifa  INT,
            @cantidadLibres  INT           = 0,
            @cantidadAsignar INT           = 0;

    -- Espacios (1 a 4) que todavía no tiene el partido, numerados de menor a mayor.
    DECLARE @libres TABLE (
        Orden         INT     NOT NULL PRIMARY KEY,
        NumeroEspacio TINYINT NOT NULL
    );

    -- Países de las selecciones del partido y países en prime time a la hora del partido.
    DECLARE @paisesParticipantes TABLE (IdPais SMALLINT NOT NULL PRIMARY KEY);
    DECLARE @paisesPrimeTime     TABLE (IdPais SMALLINT NOT NULL PRIMARY KEY);

    -- Propuesta: las mejores piezas (una por anunciante), en orden de ranking.
    DECLARE @propuesta TABLE (
        Orden         INT         NOT NULL PRIMARY KEY,
        NumeroEspacio TINYINT     NULL,
        IdPieza       INT         NOT NULL UNIQUE,
        Criterio      VARCHAR(60) NOT NULL
    );

    -- ---- Validaciones (se acumulan todas) --------------------------------
    SELECT @existePartido = 1,
           @estado        = p.Estado,
           @idFase        = p.IdFase,
           @fechaPartido  = CAST(p.FechaHoraUTC AS DATE)
    FROM nucleo.Partido AS p
    WHERE p.IdPartido = @idPartido;

    IF @existePartido = 0
        SET @errores += N'- El partido indicado no existe.' + @salto;
    ELSE
    BEGIN
        IF @estado = 'Finalizado'
            SET @errores += N'- El partido ya está finalizado: sus espacios publicitarios son histórico de facturación y no se asignan.' + @salto;

        -- Tarifa vigente para la fase a la fecha del partido (USD primero, después menor IdTarifa).
        SELECT TOP (1) @montoTarifa    = t.Monto,
                       @idMonedaTarifa = t.IdMoneda
        FROM publicidad.Tarifa AS t
        INNER JOIN publicidad.Moneda AS m ON m.IdMoneda = t.IdMoneda
        WHERE t.IdFase = @idFase
          AND t.VigenciaDesde <= @fechaPartido
        ORDER BY t.VigenciaDesde DESC,
                 CASE WHEN m.Codigo = 'USD' THEN 0 ELSE 1 END,
                 t.IdTarifa ASC;

        IF @montoTarifa IS NULL
            SET @errores += N'- No hay tarifa vigente para la fase del partido a la fecha del partido (publicidad.Tarifa).' + @salto;

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
            INSERT INTO @paisesParticipantes (IdPais)
            SELECT DISTINCT s.IdPais
            FROM nucleo.fn_SeleccionesDelPartido(@idPartido) AS sp
            INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion;

            INSERT INTO @paisesPrimeTime (IdPais)
            SELECT DISTINCT mp.IdPais
            FROM nucleo.fn_MercadosEnPrimeTime(@idPartido) AS mp;

            WITH Candidatas AS (
                SELECT pz.IdPieza,
                       cp.IdAnunciante,
                       CAST(CASE WHEN EXISTS (SELECT 1
                                              FROM publicidad.OrientacionPais AS op
                                              INNER JOIN @paisesParticipantes AS pp ON pp.IdPais = op.IdPais
                                              WHERE op.IdPieza = pz.IdPieza)
                                 THEN 1 ELSE 0 END AS BIT) AS EsParticipante,
                       mx.PBIPerCapitaUSD AS PBIMax,
                       mx.CodigoISO3      AS PaisPBIMax,
                       CAST(CASE WHEN EXISTS (SELECT 1
                                              FROM publicidad.OrientacionPais AS op
                                              INNER JOIN @paisesPrimeTime AS pt ON pt.IdPais = op.IdPais
                                              WHERE op.IdPieza = pz.IdPieza)
                                 THEN 1 ELSE 0 END AS BIT) AS EnPrimeTime
                FROM publicidad.Pieza AS pz
                INNER JOIN publicidad.Campania AS cp ON cp.IdCampania = pz.IdCampania
                -- País de orientación con mayor PBI per cápita (desempate por IdPais).
                OUTER APPLY (SELECT TOP (1) pa.PBIPerCapitaUSD, pa.CodigoISO3
                             FROM publicidad.OrientacionPais AS op
                             INNER JOIN nucleo.Pais AS pa ON pa.IdPais = op.IdPais
                             WHERE op.IdPieza = pz.IdPieza
                               AND pa.PBIPerCapitaUSD IS NOT NULL
                             ORDER BY pa.PBIPerCapitaUSD DESC, pa.IdPais ASC) AS mx
                WHERE EXISTS (SELECT 1 FROM publicidad.OrientacionPais AS op WHERE op.IdPieza = pz.IdPieza)
                  -- La pieza no está ya en el partido.
                  AND NOT EXISTS (SELECT 1
                                  FROM publicidad.EspacioPublicitario AS e
                                  WHERE e.IdPartido = @idPartido
                                    AND e.IdPieza   = pz.IdPieza)
                  -- El anunciante no tiene ya un espacio en el partido.
                  AND NOT EXISTS (SELECT 1
                                  FROM publicidad.EspacioPublicitario AS e
                                  INNER JOIN publicidad.Pieza    AS pe ON pe.IdPieza    = e.IdPieza
                                  INNER JOIN publicidad.Campania AS ce ON ce.IdCampania = pe.IdCampania
                                  WHERE e.IdPartido     = @idPartido
                                    AND ce.IdAnunciante = cp.IdAnunciante)
            ),
            Rankeadas AS (
                SELECT c.*,
                       ROW_NUMBER() OVER (PARTITION BY c.IdAnunciante
                                          ORDER BY c.EsParticipante DESC,
                                                   CASE WHEN c.PBIMax IS NULL THEN 1 ELSE 0 END,
                                                   c.PBIMax DESC,
                                                   c.EnPrimeTime DESC,
                                                   c.IdPieza ASC) AS PosicionAnunciante
                FROM Candidatas AS c
            )
            INSERT INTO @propuesta (Orden, IdPieza, Criterio)
            SELECT TOP (@cantidadLibres)
                   ROW_NUMBER() OVER (ORDER BY r.EsParticipante DESC,
                                               CASE WHEN r.PBIMax IS NULL THEN 1 ELSE 0 END,
                                               r.PBIMax DESC,
                                               r.EnPrimeTime DESC,
                                               r.IdPieza ASC),
                   r.IdPieza,
                   LEFT(CASE WHEN r.EsParticipante = 1 THEN 'Participante' ELSE 'No participante' END
                        + ' | '
                        + CASE WHEN r.PBIMax IS NULL THEN 'PBI s/d'
                               ELSE 'PBI ' + CAST(CAST(r.PBIMax AS DECIMAL(10,0)) AS VARCHAR(12))
                                    + ' (' + r.PaisPBIMax + ')' END
                        + ' | '
                        + CASE WHEN r.EnPrimeTime = 1 THEN 'Prime time' ELSE 'Sin prime time' END, 60)
            FROM Rankeadas AS r
            WHERE r.PosicionAnunciante = 1
            ORDER BY r.EsParticipante DESC,
                     CASE WHEN r.PBIMax IS NULL THEN 1 ELSE 0 END,
                     r.PBIMax DESC,
                     r.EnPrimeTime DESC,
                     r.IdPieza ASC;

            -- La mejor pieza va al número libre más bajo, y así sucesivamente.
            UPDATE pr
            SET NumeroEspacio = l.NumeroEspacio
            FROM @propuesta AS pr
            INNER JOIN @libres AS l ON l.Orden = pr.Orden;

            SELECT @cantidadAsignar = COUNT(*) FROM @propuesta;

            IF @cantidadAsignar = 0
                SET @errores += N'- No hay piezas publicitarias candidatas: se necesita al menos una pieza con país de orientación que no esté ya en el partido y cuyo anunciante no tenga ya un espacio en el partido.' + @salto;
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
    IF @soloSimular = 0
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            INSERT INTO publicidad.EspacioPublicitario (IdPartido, NumeroEspacio, IdPieza, TarifaPublicitaria, IdMoneda, CriterioAsignacion)
            SELECT @idPartido, pr.NumeroEspacio, pr.IdPieza, @montoTarifa, @idMonedaTarifa, pr.Criterio
            FROM @propuesta AS pr;

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
    END;

    IF @cantidadAsignar < @cantidadLibres
    BEGIN
        SELECT @advertencia = 'Advertencia: solo hubo ' + CAST(@cantidadAsignar AS VARCHAR(1))
                            + ' pieza(s) candidata(s) para ' + CAST(@cantidadLibres AS VARCHAR(1))
                            + ' espacio(s) libre(s); quedan sin asignar los espacios '
                            + STRING_AGG(CAST(l.NumeroEspacio AS VARCHAR(1)), ', ') WITHIN GROUP (ORDER BY l.NumeroEspacio)
                            + '.'
        FROM @libres AS l
        WHERE l.Orden > @cantidadAsignar;
        PRINT @advertencia;
    END;

    -- Espacios ocupados del partido tras la corrida: los que ya estaban y los de la propuesta.
    -- Al simular, la propuesta no está en la tabla y se informa desde @propuesta.
    SELECT x.NumeroEspacio,
           x.IdPieza,
           pz.Titulo,
           an.Nombre AS Anunciante,
           x.TarifaPublicitaria,
           mo.Codigo AS Moneda,
           x.Estado,
           x.Criterio
    FROM (SELECT e.NumeroEspacio, e.IdPieza, e.TarifaPublicitaria, e.IdMoneda,
                 CAST('Ya ocupado' AS VARCHAR(10)) AS Estado, e.CriterioAsignacion AS Criterio
          FROM publicidad.EspacioPublicitario AS e
          WHERE e.IdPartido = @idPartido
            AND NOT EXISTS (SELECT 1 FROM @propuesta AS pr WHERE pr.NumeroEspacio = e.NumeroEspacio)
          UNION ALL
          SELECT pr.NumeroEspacio, pr.IdPieza, @montoTarifa, @idMonedaTarifa,
                 CASE WHEN @soloSimular = 1 THEN 'Propuesto' ELSE 'Asignado' END, pr.Criterio
          FROM @propuesta AS pr) AS x
    INNER JOIN publicidad.Pieza      AS pz ON pz.IdPieza      = x.IdPieza
    INNER JOIN publicidad.Campania   AS cp ON cp.IdCampania   = pz.IdCampania
    INNER JOIN publicidad.Anunciante AS an ON an.IdAnunciante = cp.IdAnunciante
    INNER JOIN publicidad.Moneda     AS mo ON mo.IdMoneda     = x.IdMoneda
    ORDER BY x.NumeroEspacio;
END;
GO
