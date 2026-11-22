/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-21
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Validar en un escenario aislado (BEGIN TRANSACTION / ROLLBACK) los volúmenes
          mínimos y los 4 casos obligatorios de los módulos jugadores y eventos:
          - 16 selecciones con 23 convocados activos cada una (368 en total).
          - 24 partidos con formaciones completas (11 titulares con 1 arquero y 7 suplentes).
          - Caso 1: expulsión por doble amarilla.
          - Caso 2: expulsión por roja directa.
          - Caso 3: jugador suspendido por acumulación fuera de la titular del partido
            siguiente (y rechazado si se intenta agregarlo a la formación).
          - Caso 4: cambio por lesión antes del minuto 20.
          Requiere ejecutados los scripts 01 a 24.
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- 1. ESCENARIO DE PRUEBA: 16 SELECCIONES Y 24 PARTIDOS (Nros 9701..9724)
-- =========================================================================
DELETE FROM jugadores.ReglaConvocados;
INSERT INTO jugadores.ReglaConvocados (Minimo, Maximo) VALUES (23, 26);

DELETE FROM jugadores.ReglaCambios;
INSERT INTO jugadores.ReglaCambios (MaxCambiosRegular, MaxVentanasRegular, MaxCambiosSuplementario, MaxVentanasSuplementario)
VALUES (5, 3, 1, 1);

IF NOT EXISTS (SELECT 1 FROM eventos.ReglaSuspension WHERE Criterio = 'Acumulacion Amarillas')
    INSERT INTO eventos.ReglaSuspension (Criterio, CantidadAmarillas, PartidosSuspension) VALUES ('Acumulacion Amarillas', 2, 1);
IF NOT EXISTS (SELECT 1 FROM eventos.ReglaSuspension WHERE Criterio = 'Doble Amarilla')
    INSERT INTO eventos.ReglaSuspension (Criterio, CantidadAmarillas, PartidosSuspension) VALUES ('Doble Amarilla', NULL, 1);
IF NOT EXISTS (SELECT 1 FROM eventos.ReglaSuspension WHERE Criterio = 'Roja Directa')
    INSERT INTO eventos.ReglaSuspension (Criterio, CantidadAmarillas, PartidosSuspension) VALUES ('Roja Directa', NULL, 2);

IF NOT EXISTS (SELECT 1 FROM eventos.TipoGol WHERE Descripcion = 'Jugada')
    INSERT INTO eventos.TipoGol (Descripcion) VALUES ('Jugada');
IF NOT EXISTS (SELECT 1 FROM eventos.Periodo WHERE Descripcion = 'Primer Tiempo')
    INSERT INTO eventos.Periodo (Descripcion) VALUES ('Primer Tiempo');
IF NOT EXISTS (SELECT 1 FROM eventos.Tarjeta WHERE Tipo = 'Amarilla')
    INSERT INTO eventos.Tarjeta (Tipo) VALUES ('Amarilla');
IF NOT EXISTS (SELECT 1 FROM eventos.Tarjeta WHERE Tipo = 'Roja por doble amarilla')
    INSERT INTO eventos.Tarjeta (Tipo) VALUES ('Roja por doble amarilla');
IF NOT EXISTS (SELECT 1 FROM eventos.Tarjeta WHERE Tipo = 'Roja directa')
    INSERT INTO eventos.Tarjeta (Tipo) VALUES ('Roja directa');

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST SEED Conf', 'TSC');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TSC');

INSERT INTO nucleo.Grupo (Nombre) VALUES ('TS-A'), ('TS-B'), ('TS-C'), ('TS-D');
DECLARE @gA INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'TS-A'),
        @gB INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'TS-B'),
        @gC INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'TS-C'),
        @gD INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'TS-D');

-- Crear 16 países y sus 16 selecciones (4 por grupo)
DECLARE @k INT = 1, @idPaisT INT, @idSelT INT, @iso3 CHAR(3), @iso2 CHAR(2), @nomP VARCHAR(80), @grp INT;
DECLARE @sels TABLE (Idx INT IDENTITY(1,1) PRIMARY KEY, IdSeleccion INT, CodigoISO3 CHAR(3), IdGrupo INT);

WHILE @k <= 16
BEGIN
    SET @iso2 = 'S' + CASE WHEN @k < 10 THEN CAST(@k AS CHAR(1)) ELSE CHAR(55 + @k) END;
    SET @iso3 = 'TS' + CASE WHEN @k < 10 THEN CAST(@k AS CHAR(1)) ELSE CHAR(55 + @k) END;
    SET @nomP = 'TEST SEED Pais ' + CAST(@k AS VARCHAR(2));
    SET @grp  = CASE WHEN @k <= 4 THEN @gA WHEN @k <= 8 THEN @gB WHEN @k <= 12 THEN @gC ELSE @gD END;

    INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, ZonaHoraria)
    VALUES (@nomP, @iso2, @iso3, @idConf, 'Argentina Standard Time');
    SET @idPaisT = SCOPE_IDENTITY();

    INSERT INTO nucleo.Seleccion (IdPais, IdGrupo) VALUES (@idPaisT, @grp);
    SET @idSelT = SCOPE_IDENTITY();

    INSERT INTO @sels (IdSeleccion, CodigoISO3, IdGrupo) VALUES (@idSelT, @iso3, @grp);
    SET @k += 1;
END;

INSERT INTO nucleo.Ciudad (Nombre, IdPais)
VALUES ('TEST SEED Ciudad', (SELECT TOP (1) IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TS1'));
DECLARE @idCiudad INT = SCOPE_IDENTITY();

DECLARE @idSede INT;
EXEC nucleo.SP_ABM_Sede @operacion = 'ALTA', @idSede = @idSede OUTPUT, @nombreEstadio = 'TEST SEED Estadio',
     @idCiudad = @idCiudad, @capacidad = 60000, @zonaHoraria = 'Argentina Standard Time';

DECLARE @idFaseGrupos INT = (SELECT IdFase FROM nucleo.Fase WHERE Descripcion = 'Grupos');

-- Generar 24 partidos de grupos (6 por grupo, separados 5 días entre fechas y 4 horas en la sede)
DECLARE @gIdx INT = 1, @baseIdx INT, @s1 INT, @s2 INT, @s3 INT, @s4 INT, @pOut INT, @numP INT = 9701;
WHILE @gIdx <= 4
BEGIN
    SET @baseIdx = (@gIdx - 1) * 4;
    SELECT @s1 = IdSeleccion FROM @sels WHERE Idx = @baseIdx + 1;
    SELECT @s2 = IdSeleccion FROM @sels WHERE Idx = @baseIdx + 2;
    SELECT @s3 = IdSeleccion FROM @sels WHERE Idx = @baseIdx + 3;
    SELECT @s4 = IdSeleccion FROM @sels WHERE Idx = @baseIdx + 4;

    DECLARE @f1 DATETIME2(0) = DATEADD(HOUR, (@gIdx - 1) * 4, '2026-06-11 10:00');
    DECLARE @f2 DATETIME2(0) = DATEADD(DAY, 5, @f1);
    DECLARE @f3 DATETIME2(0) = DATEADD(DAY, 10, @f1);

    EXEC nucleo.SP_ABM_Partido 'ALTA', @pOut OUTPUT, @numP, @idFaseGrupos, @idSede, @f1, @s1, @s2; SET @numP += 1;
    SET @f1 = DATEADD(HOUR, 16, @f1);
    EXEC nucleo.SP_ABM_Partido 'ALTA', @pOut OUTPUT, @numP, @idFaseGrupos, @idSede, @f1, @s3, @s4; SET @numP += 1;

    EXEC nucleo.SP_ABM_Partido 'ALTA', @pOut OUTPUT, @numP, @idFaseGrupos, @idSede, @f2, @s1, @s3; SET @numP += 1;
    SET @f2 = DATEADD(HOUR, 16, @f2);
    EXEC nucleo.SP_ABM_Partido 'ALTA', @pOut OUTPUT, @numP, @idFaseGrupos, @idSede, @f2, @s2, @s4; SET @numP += 1;

    EXEC nucleo.SP_ABM_Partido 'ALTA', @pOut OUTPUT, @numP, @idFaseGrupos, @idSede, @f3, @s1, @s4; SET @numP += 1;
    SET @f3 = DATEADD(HOUR, 16, @f3);
    EXEC nucleo.SP_ABM_Partido 'ALTA', @pOut OUTPUT, @numP, @idFaseGrupos, @idSede, @f3, @s2, @s3; SET @numP += 1;

    SET @gIdx += 1;
END;

-- =========================================================================
-- 2. POBLAR 23 CONVOCADOS PARA LAS 16 SELECCIONES DE PRUEBA (368 EN TOTAL)
-- =========================================================================
DECLARE @sIdx INT = 1, @selCur INT, @isoCur CHAR(3), @d INT, @jId INT, @cId INT, @doc VARCHAR(20), @pos VARCHAR(20);
WHILE @sIdx <= 16
BEGIN
    SELECT @selCur = IdSeleccion, @isoCur = CodigoISO3 FROM @sels WHERE Idx = @sIdx;
    SET @d = 1;
    WHILE @d <= 23
    BEGIN
        SET @doc = RTRIM(@isoCur) + '-T-' + RIGHT('00' + CAST(@d AS VARCHAR(2)), 2);
        SET @pos = CASE
            WHEN @d IN (1, 12, 23) THEN 'Arquero'
            WHEN @d IN (2, 3, 4, 6, 13, 14, 15, 16) THEN 'Defensor'
            WHEN @d IN (5, 7, 8, 10, 17, 18, 20) THEN 'Mediocampista'
            ELSE 'Delantero'
        END;

        EXEC jugadores.SP_ABM_Jugador 'ALTA', @jId OUTPUT, 'Nom', 'Ape', @doc, '1998-01-01', 'M', @pos, NULL;
        EXEC jugadores.SP_CONVOCAR_JUGADOR @selCur, @jId, @d, '2026-05-20', @cId OUTPUT;
        SET @d += 1;
    END;
    SET @sIdx += 1;
END;

-- =========================================================================
-- 3. EJECUTAR CASOS OBLIGATORIOS + 24 FORMACIONES
-- =========================================================================
DECLARE @selTest1 INT = (SELECT IdSeleccion FROM @sels WHERE Idx = 1);
DECLARE @jugAcum  INT = (SELECT c.IdJugador FROM jugadores.Convocatoria c WHERE c.IdSeleccion = @selTest1 AND c.Dorsal = 8);
DECLARE @pSel1_1  INT, @pSel1_2 INT, @pSel1_3 INT;

;WITH P1 AS (
    SELECT IdPartido, ROW_NUMBER() OVER (ORDER BY FechaHoraUTC) AS Rn
    FROM nucleo.Partido
    WHERE NumeroPartido BETWEEN 9701 AND 9724
      AND @selTest1 IN (IdSeleccionLocal, IdSeleccionVisitante)
)
SELECT @pSel1_1 = MAX(CASE WHEN Rn = 1 THEN IdPartido END),
       @pSel1_2 = MAX(CASE WHEN Rn = 2 THEN IdPartido END),
       @pSel1_3 = MAX(CASE WHEN Rn = 3 THEN IdPartido END)
FROM P1;

-- Cargar formaciones de los 24 partidos (filtrando suspendidos) + eventos obligatorios
DECLARE @pCur INT = 9701, @idPartCur INT, @locCur INT, @visCur INT, @fOut INT, @aOut INT, @sOut INT;
WHILE @pCur <= 9724
BEGIN
    SELECT @idPartCur = IdPartido, @locCur = IdSeleccionLocal, @visCur = IdSeleccionVisitante
    FROM nucleo.Partido WHERE NumeroPartido = @pCur;

    EXEC jugadores.SP_REGISTRAR_FORMACION @idPartCur, 'Local',     '4-3-3', 1, @fOut OUTPUT;
    -- 11 titulares + 7 suplentes Local (excluyendo suspendidos)
    DECLARE @tList TABLE (Rn INT IDENTITY(1,1) PRIMARY KEY, IdJugador INT, Posicion VARCHAR(20));
    DELETE FROM @tList;

    ;WITH El AS (
        SELECT c.IdJugador, j.Posicion, c.Dorsal,
               ROW_NUMBER() OVER (PARTITION BY j.Posicion ORDER BY c.Dorsal) AS Rp
        FROM jugadores.Convocatoria c
        INNER JOIN jugadores.Jugador j ON j.IdJugador = c.IdJugador
        WHERE c.IdSeleccion = @locCur
          AND eventos.fn_EstaSuspendido(c.IdJugador, @idPartCur) = 0
    ),
    Tit AS (
        SELECT IdJugador, Posicion, Dorsal, 1 AS T FROM El
        WHERE (Posicion = 'Arquero' AND Rp = 1) OR (Posicion = 'Defensor' AND Rp <= 4)
           OR (Posicion = 'Mediocampista' AND Rp <= 3) OR (Posicion = 'Delantero' AND Rp <= 3)
    ),
    Sup AS (
        SELECT TOP (7) e.IdJugador, e.Posicion, e.Dorsal, 0 AS T FROM El e
        WHERE NOT EXISTS (SELECT 1 FROM Tit WHERE Tit.IdJugador = e.IdJugador) ORDER BY e.Dorsal
    )
    INSERT INTO @tList (IdJugador, Posicion)
    SELECT IdJugador, Posicion FROM (SELECT * FROM Tit UNION ALL SELECT * FROM Sup) x ORDER BY x.T DESC, x.Dorsal;

    DECLARE @r INT = 1, @jIns INT, @pIns VARCHAR(20), @est VARCHAR(8), @posC VARCHAR(20);
    WHILE @r <= 18
    BEGIN
        SELECT @jIns = IdJugador, @pIns = Posicion FROM @tList WHERE Rn = @r;
        SET @est  = CASE WHEN @r <= 11 THEN 'Titular' ELSE 'Suplente' END;
        SET @posC = CASE WHEN @r <= 11 THEN @pIns ELSE NULL END;
        EXEC jugadores.SP_AGREGAR_JUGADOR_FORMACION @fOut, @jIns, @est, @posC, NULL;
        SET @r += 1;
    END;

    EXEC jugadores.SP_REGISTRAR_FORMACION @idPartCur, 'Visitante', '4-3-3', 1, @fOut OUTPUT;
    DELETE FROM @tList;

    ;WITH ElV AS (
        SELECT c.IdJugador, j.Posicion, c.Dorsal,
               ROW_NUMBER() OVER (PARTITION BY j.Posicion ORDER BY c.Dorsal) AS Rp
        FROM jugadores.Convocatoria c
        INNER JOIN jugadores.Jugador j ON j.IdJugador = c.IdJugador
        WHERE c.IdSeleccion = @visCur
          AND eventos.fn_EstaSuspendido(c.IdJugador, @idPartCur) = 0
    ),
    TitV AS (
        SELECT IdJugador, Posicion, Dorsal, 1 AS T FROM ElV
        WHERE (Posicion = 'Arquero' AND Rp = 1) OR (Posicion = 'Defensor' AND Rp <= 4)
           OR (Posicion = 'Mediocampista' AND Rp <= 3) OR (Posicion = 'Delantero' AND Rp <= 3)
    ),
    SupV AS (
        SELECT TOP (7) e.IdJugador, e.Posicion, e.Dorsal, 0 AS T FROM ElV e
        WHERE NOT EXISTS (SELECT 1 FROM TitV WHERE TitV.IdJugador = e.IdJugador) ORDER BY e.Dorsal
    )
    INSERT INTO @tList (IdJugador, Posicion)
    SELECT IdJugador, Posicion FROM (SELECT * FROM TitV UNION ALL SELECT * FROM SupV) x ORDER BY x.T DESC, x.Dorsal;

    SET @r = 1;
    WHILE @r <= 18
    BEGIN
        SELECT @jIns = IdJugador, @pIns = Posicion FROM @tList WHERE Rn = @r;
        SET @est  = CASE WHEN @r <= 11 THEN 'Titular' ELSE 'Suplente' END;
        SET @posC = CASE WHEN @r <= 11 THEN @pIns ELSE NULL END;
        EXEC jugadores.SP_AGREGAR_JUGADOR_FORMACION @fOut, @jIns, @est, @posC, NULL;
        SET @r += 1;
    END;

    -- Eventos de los 4 casos obligatorios en el partido 9701
    IF @pCur = 9701
    BEGIN
        DECLARE @jLesSal INT = (SELECT IdJugador FROM jugadores.Convocatoria WHERE IdSeleccion = @locCur AND Dorsal = 2);
        DECLARE @jLesEnt INT = (SELECT TOP (1) fj.IdJugador FROM jugadores.Formacion f JOIN jugadores.FormacionJugador fj ON fj.IdFormacion = f.IdFormacion WHERE f.IdPartido = @idPartCur AND f.Localia = 'Local' AND fj.EstadoTitularidad = 'Suplente');
        EXEC jugadores.SP_REGISTRAR_SUSTITUCION @idPartCur, @jLesSal, @jLesEnt, 15, 'Regular', 'Lesion', 1, @sOut OUTPUT;

        DECLARE @jDobleAm INT = (SELECT IdJugador FROM jugadores.Convocatoria WHERE IdSeleccion = @locCur AND Dorsal = 3);
        EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartCur, 'Amarilla', 22, 'Falta 1', @jDobleAm, NULL, 1, @aOut OUTPUT;
        EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartCur, 'Amarilla', 58, 'Falta 2', @jDobleAm, NULL, 1, @aOut OUTPUT;

        DECLARE @jRojaDir INT = (SELECT IdJugador FROM jugadores.Convocatoria WHERE IdSeleccion = @visCur AND Dorsal = 2);
        EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartCur, 'Roja directa', 71, 'Juego brusco grave', @jRojaDir, NULL, 1, @aOut OUTPUT;
    END;

    -- Amarillas por acumulación en partidos 1 y 2 de @selTest1
    IF @idPartCur IN (@pSel1_1, @pSel1_2)
        EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartCur, 'Amarilla', 40, 'Acumulacion', @jugAcum, NULL, 1, @aOut OUTPUT;

    SET @pCur += 1;
END;

-- =========================================================================
-- 4. VERIFICACIONES DE VOLÚMENES Y 4 CASOS OBLIGATORIOS
-- =========================================================================
SELECT 'Volumenes' AS Test,
       (SELECT COUNT(*) FROM jugadores.Convocatoria c WHERE c.IdSeleccion IN (SELECT IdSeleccion FROM @sels)) AS Convocados_Esperado_368,
       (SELECT COUNT(*) FROM jugadores.Formacion f INNER JOIN nucleo.Partido p ON p.IdPartido = f.IdPartido WHERE p.NumeroPartido BETWEEN 9701 AND 9724) AS Formaciones_Esperado_48,
       (SELECT COUNT(*) FROM eventos.Amonestacion a INNER JOIN eventos.Tarjeta t ON t.IdTarjeta = a.IdTarjeta INNER JOIN nucleo.Partido p ON p.IdPartido = a.IdPartido WHERE p.NumeroPartido = 9701 AND t.Tipo = 'Roja por doble amarilla') AS DobleAmarilla_Esperado_1,
       (SELECT COUNT(*) FROM eventos.Amonestacion a INNER JOIN eventos.Tarjeta t ON t.IdTarjeta = a.IdTarjeta INNER JOIN nucleo.Partido p ON p.IdPartido = a.IdPartido WHERE p.NumeroPartido = 9701 AND t.Tipo = 'Roja directa') AS RojaDirecta_Esperado_1,
       (SELECT COUNT(*) FROM jugadores.Sustitucion s INNER JOIN nucleo.Partido p ON p.IdPartido = s.IdPartido WHERE p.NumeroPartido = 9701 AND s.Motivo = 'Lesion' AND s.Minuto < 20) AS CambioLesionPre20_Esperado_1,
       eventos.fn_EstaSuspendido(@jugAcum, @pSel1_3) AS SuspendidoEnPartido3_Esperado_1;

-- Verificar que intentar incluir al jugador suspendido por acumulación en la formación del partido 3 falla
DECLARE @idFormP3 INT = (
    SELECT f.IdFormacion
    FROM jugadores.Formacion AS f
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = f.IdPartido
    WHERE f.IdPartido = @pSel1_3
      AND ((f.Localia = 'Local' AND p.IdSeleccionLocal = @selTest1)
        OR (f.Localia = 'Visitante' AND p.IdSeleccionVisitante = @selTest1))
);

BEGIN TRY
    EXEC jugadores.SP_AGREGAR_JUGADOR_FORMACION @idFormP3, @jugAcum, 'Titular', 'Mediocampista', 99;
    PRINT 'TEST SUSPENSIÓN FALLÓ: permitió alinear al jugador suspendido por acumulación.';
END TRY
BEGIN CATCH
    PRINT 'TEST SUSPENSIÓN OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

ROLLBACK TRANSACTION;
GO