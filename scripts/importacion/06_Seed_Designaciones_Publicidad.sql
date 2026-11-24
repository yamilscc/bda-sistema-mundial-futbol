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
Objetivo: Completa el seed de nucleo y publicidad una vez cargados los 24 partidos:
          1. Designa 5 árbitros por partido (Principal, Asistente 1, Asistente 2, Cuarto, VAR) con
             nucleo.SP_CONTROL_ARBITRAL, rotando entre los árbitros habilitados que no sean del país de
             ninguna de las selecciones del partido.
          2. CASO OBLIGATORIO: designación descartada por conflicto de nacionalidad (árbitro argentino en
             ARG vs BRA); queda registrada en eventos.LogImportacion.
          3. Completa con publicidad.SP_ASIGNAR_PUBLICIDAD los espacios libres de cada partido programado
             (los espacios ya cargados por la pauta importada no se tocan; la tarifa sale de
             publicidad.Tarifa según la fase del partido).
          4. CASO OBLIGATORIO: verifica que el partido 1 tenga más de 4 mercados en prime time.
          Idempotente. ORDEN: después de 04 y 05, y antes de los scripts de Mateo.
*/
USE MundialFutbol;
GO
SET NOCOUNT ON;
GO

-- ===== 1. Designaciones arbitrales =====
DECLARE @pend TABLE (Id INT IDENTITY(1,1) PRIMARY KEY, IdPartido INT, NumeroPartido INT, Rol VARCHAR(15));
INSERT INTO @pend (IdPartido, NumeroPartido, Rol)
SELECT p.IdPartido, p.NumeroPartido, r.Rol
FROM nucleo.Partido AS p
CROSS JOIN (VALUES ('Principal'), ('Asistente 1'), ('Asistente 2'), ('Cuarto'), ('VAR')) AS r (Rol)
WHERE p.Estado = 'Programado'
  AND NOT EXISTS (SELECT 1 FROM nucleo.DesignacionArbitral AS d WHERE d.IdPartido = p.IdPartido AND d.Rol = r.Rol)
ORDER BY p.NumeroPartido, r.Rol;

DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @pend), @idPartido INT, @num INT, @rol VARCHAR(15),
        @idArbitro INT, @adv VARCHAR(200), @total INT = (SELECT COUNT(*) FROM nucleo.Arbitro WHERE EstaHabilitado = 'Y');
WHILE @i <= @n
BEGIN
    SELECT @idPartido = IdPartido, @num = NumeroPartido, @rol = Rol FROM @pend WHERE Id = @i;
    SET @idArbitro = NULL;
    -- Primer árbitro elegible según una rotación que depende del partido y del rol (reparte la carga).
    SELECT TOP (1) @idArbitro = a.IdArbitro
    FROM nucleo.Arbitro AS a
    WHERE a.EstaHabilitado = 'Y'
      AND NOT EXISTS (SELECT 1 FROM nucleo.DesignacionArbitral AS d WHERE d.IdPartido = @idPartido AND d.IdArbitro = a.IdArbitro)
      AND NOT EXISTS (SELECT 1 FROM nucleo.fn_SeleccionesDelPartido(@idPartido) AS sp
                      INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion
                      WHERE s.IdPais = a.IdPais)
    ORDER BY (a.IdArbitro + @num * 5 + @i) % @total, a.IdArbitro;
    IF @idArbitro IS NOT NULL
        EXEC nucleo.SP_CONTROL_ARBITRAL @idPartido = @idPartido, @idArbitro = @idArbitro, @rol = @rol, @advertencia = @adv OUTPUT;
    SET @i += 1;
END;
GO

-- ===== 2. Caso obligatorio: designación rechazada por nacionalidad =====
DECLARE @idPartido INT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 1),
        @idArbitro INT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'Néstor Ferrante'), -- argentino
        @adv VARCHAR(200), @mensaje NVARCHAR(500);
IF @idPartido IS NOT NULL AND @idArbitro IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM eventos.LogImportacion WHERE NombreArchivo = 'seed_designaciones' AND MensajeError LIKE '%país del árbitro%')
BEGIN
    BEGIN TRY
        EXEC nucleo.SP_CONTROL_ARBITRAL @idPartido = @idPartido, @idArbitro = @idArbitro, @rol = 'VAR', @advertencia = @adv OUTPUT;
        PRINT 'ERROR: se aceptó un árbitro argentino en ARG vs BRA.';
    END TRY
    BEGIN CATCH
        SET @mensaje = LEFT(ERROR_MESSAGE(), 500);
        INSERT INTO eventos.LogImportacion (NombreArchivo, IdFilaStaging, DatosCrudos, MensajeError)
        VALUES ('seed_designaciones', NULL, 'Partido 1 (ARG vs BRA), árbitro Néstor Ferrante (ARG), rol VAR', @mensaje);
        PRINT 'Designación descartada (esperado): ' + @mensaje;
    END CATCH;
END;
GO

-- ===== 3. Publicidad: completa los espacios libres de cada partido programado (tarifa de su fase) =====
DECLARE @res TABLE (NumeroEspacio TINYINT, IdPieza INT, Titulo VARCHAR(100), Anunciante VARCHAR(100),
                    TarifaPublicitaria DECIMAL(12,2), Moneda CHAR(3), Estado VARCHAR(10),
                    Criterio VARCHAR(60));
DECLARE @part TABLE (Id INT IDENTITY(1,1) PRIMARY KEY, IdPartido INT);
INSERT INTO @part (IdPartido)
SELECT p.IdPartido FROM nucleo.Partido AS p
WHERE p.Estado = 'Programado'   -- los finalizados son histórico de facturación (el SP los rechaza)
  AND (SELECT COUNT(*) FROM publicidad.EspacioPublicitario AS e WHERE e.IdPartido = p.IdPartido) < 4
ORDER BY p.NumeroPartido;
DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @part), @idPartido INT, @adv VARCHAR(200);
WHILE @i <= @n
BEGIN
    SELECT @idPartido = IdPartido FROM @part WHERE Id = @i;
    INSERT INTO @res EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = @idPartido, @advertencia = @adv OUTPUT;
    DELETE FROM @res;
    SET @i += 1;
END;
GO

-- ===== 4. Caso obligatorio: prime time en más de 4 mercados =====
DECLARE @idPartido INT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 1),
        @mercados INT;
SELECT @mercados = COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(@idPartido);
IF @mercados > 4
    PRINT 'Partido 1 en prime time en ' + CAST(@mercados AS VARCHAR(10)) + ' mercados (OK, más de 4).';
ELSE
    PRINT 'ATENCIÓN: el partido 1 solo está en prime time en ' + CAST(@mercados AS VARCHAR(10)) + ' mercados.';

SELECT 'Resumen' AS Control,
       (SELECT COUNT(*) FROM nucleo.Partido) AS Partidos_24,
       (SELECT COUNT(*) FROM nucleo.DesignacionArbitral) AS Designaciones_120,
       (SELECT COUNT(*) FROM publicidad.EspacioPublicitario) AS Espacios_96,
       (SELECT COUNT(DISTINCT s.IdCiudad) FROM nucleo.Sede AS s) AS Ciudades_Sede,
       (SELECT COUNT(DISTINCT c.HusoHorario) FROM nucleo.Sede AS s INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = s.IdCiudad) AS HusosSedes_4;
GO
