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
Objetivo: Cierra los partidos programados: toma el resultado calculado por eventos.fn_ResultadoPartido a
          partir de los goles cargados por Mateo y lo registra con nucleo.SP_REGISTRAR_RESULTADO_PARTIDO
          (el partido pasa a 'Finalizado'). Idempotente: solo procesa partidos en estado 'Programado'.
          ORDEN: ejecutar al final, después de 03, 01 y 02 de Mateo (formaciones, convocatorias y eventos).
NOTA: nucleo.SP_REGISTRAR_RESULTADO_PARTIDO figura en el contrato de la entrega pero no está en los scripts
      01 a 24 del repositorio. Si no existe, este script lo informa y no modifica nada.
*/
USE MundialFutbol;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID('nucleo.SP_REGISTRAR_RESULTADO_PARTIDO', 'P') IS NULL
BEGIN
    PRINT 'ATENCIÓN: nucleo.SP_REGISTRAR_RESULTADO_PARTIDO no existe en la base; no se cierran partidos.';
    RETURN;
END;

DECLARE @part TABLE (Id INT IDENTITY(1,1) PRIMARY KEY, IdPartido INT, GolesLocal INT, GolesVisitante INT,
                     PenalesLocal INT, PenalesVisitante INT);
INSERT INTO @part (IdPartido, GolesLocal, GolesVisitante, PenalesLocal, PenalesVisitante)
SELECT p.IdPartido, r.GolesLocal, r.GolesVisitante, r.PenalesLocal, r.PenalesVisitante
FROM nucleo.Partido AS p
CROSS APPLY eventos.fn_ResultadoPartido(p.IdPartido) AS r
WHERE p.Estado = 'Programado'
ORDER BY p.NumeroPartido;

DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @part), @idPartido INT, @gl INT, @gv INT, @pl INT, @pv INT;
WHILE @i <= @n
BEGIN
    SELECT @idPartido = IdPartido, @gl = GolesLocal, @gv = GolesVisitante, @pl = PenalesLocal, @pv = PenalesVisitante
    FROM @part WHERE Id = @i;
    EXEC nucleo.SP_REGISTRAR_RESULTADO_PARTIDO @idPartido = @idPartido, @golesLocal = @gl, @golesVisitante = @gv,
                                               @penalesLocal = @pl, @penalesVisitante = @pv,
                                               @asistencia = NULL, @permitirFechaFutura = 1;
    SET @i += 1;
END;

SELECT p.NumeroPartido, p.Estado, p.GolesLocal, p.GolesVisitante
FROM nucleo.Partido AS p ORDER BY p.NumeroPartido;
GO
