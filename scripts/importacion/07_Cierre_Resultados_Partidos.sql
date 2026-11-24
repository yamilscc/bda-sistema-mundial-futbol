/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-23
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Cierra los partidos programados con nucleo.SP_FINALIZAR_PARTIDO (el partido pasa a 'Finalizado').
          El resultado no se registra: sale de los goles cargados por Mateo (eventos.Gol), que el SP valida
          con eventos.fn_ResultadoPartido antes de cerrar el partido (3FN: nucleo.Partido no guarda goles).
          - Recorre los partidos 'Programado' con ambas selecciones definidas, en orden de NumeroPartido.
          - Si el cierre de un partido es rechazado (por ejemplo, un partido eliminatorio empatado sin tanda
            de penales, un gol de un jugador no convocado o un partido con fecha futura), informa el motivo
            con PRINT y sigue con el siguiente.
          - La concurrencia se deja en NULL: ninguna fuente de datos del proyecto la trae (el fixture solo
            informa la capacidad de la sede) y SP_FINALIZAR_PARTIDO la acepta vacía; no se inventa un público.
          - Al final muestra un resumen desde nucleo.vw_PartidoResultado.
          Idempotente: solo procesa partidos en estado 'Programado'; una segunda ejecución no cambia nada.
          Requiere ejecutados los scripts de creación 01 a 28 y, de esta carpeta, 04, 05 y 06 (partidos y
          designaciones) y 01, 03 y 02 (jugadores, formaciones y goles).
          ORDEN: ejecutar al final de la carpeta importacion, después de 01, 03 y 02 de Mateo.
*/
USE MundialFutbol;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID('nucleo.SP_FINALIZAR_PARTIDO', 'P') IS NULL
    PRINT 'ATENCIÓN: nucleo.SP_FINALIZAR_PARTIDO no existe en la base (script 26); no se cierran partidos.';
ELSE
BEGIN
    DECLARE @part TABLE (Id INT IDENTITY(1,1) PRIMARY KEY, IdPartido INT, NumeroPartido INT);
    INSERT INTO @part (IdPartido, NumeroPartido)
    SELECT p.IdPartido, p.NumeroPartido
    FROM nucleo.Partido AS p
    WHERE p.Estado = 'Programado'
      AND p.IdSeleccionLocal IS NOT NULL
      AND p.IdSeleccionVisitante IS NOT NULL
    ORDER BY p.NumeroPartido;

    DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @part), @idPartido INT, @numero INT,
            @cerrados INT = 0, @rechazados INT = 0;

    WHILE @i <= @n
    BEGIN
        SELECT @idPartido = IdPartido, @numero = NumeroPartido FROM @part WHERE Id = @i;
        BEGIN TRY
            EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = @idPartido, @concurrencia = NULL;
            SET @cerrados += 1;
        END TRY
        BEGIN CATCH
            SET @rechazados += 1;
            PRINT 'Partido ' + CAST(@numero AS VARCHAR(10)) + ' no se pudo finalizar: '
                + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
        END CATCH;
        SET @i += 1;
    END;

    PRINT 'Cierre de partidos: ' + CAST(@n AS VARCHAR(10)) + ' a procesar, '
        + CAST(@cerrados AS VARCHAR(10)) + ' finalizados y ' + CAST(@rechazados AS VARCHAR(10)) + ' rechazados.';

    SELECT p.NumeroPartido, p.Estado,
           sl.CodigoFIFA AS Local, sv.CodigoFIFA AS Visitante,
           p.GolesLocal, p.GolesVisitante, p.PenalesLocal, p.PenalesVisitante,
           sg.CodigoFIFA AS Ganador
    FROM nucleo.vw_PartidoResultado AS p
    LEFT JOIN nucleo.Seleccion AS sl ON sl.IdSeleccion = p.IdSeleccionLocal
    LEFT JOIN nucleo.Seleccion AS sv ON sv.IdSeleccion = p.IdSeleccionVisitante
    LEFT JOIN nucleo.Seleccion AS sg ON sg.IdSeleccion = p.IdGanador
    ORDER BY p.NumeroPartido;
END;
GO
