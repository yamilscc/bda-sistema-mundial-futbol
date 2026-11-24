/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner (versión original); con verificaciones automáticas de Torczuk, Elías Alexei
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar los 7 Stored Procedures de reportes de la Entrega 7 (scripts/creacion/30_SP_Reportes.sql).
          Cada caso imprime OK o FALLÓ comparando el resultado del reporte con lo que dicen las tablas:
            - cantidad de filas (o de nodos XML) esperada y coherencia de totales;
            - que los dos reportes XML devuelvan un documento válido con su raíz;
            - que los nombres de árbitros y staff salgan descifrados (sin la máscara '***-CONFIDENCIAL');
            - que un filtro inexistente se rechace con un único mensaje agrupado (THROW 52000).
          Los casos que necesitan datos se informan como OMITIDO si la base no tiene partidos cargados
          (por ejemplo, corriendo la suite justo después de 00_Reset_Total.sql). Con los seeds cargados
          (importacion/00_Cargar_Seeds.sql) los valores esperados son: 24 partidos, 96 espacios, 18 árbitros,
          16 selecciones y 368 convocados.
          Requiere ejecutados los scripts 01 a 33. No modifica datos.
*/

USE MundialFutbol;
GO

SET NOCOUNT ON;

DECLARE @hayDatos BIT = CASE WHEN EXISTS (SELECT 1 FROM nucleo.Partido) THEN 1 ELSE 0 END,
        @esperado INT, @obtenido INT, @aux INT, @mensaje NVARCHAR(2048), @lineas INT, @x XML,
        @raiz BIT, @nodos INT, @hijos INT, @incompletos INT, @enmascarados BIT;

DECLARE @goleadores TABLE (PuestoTorneo BIGINT, PuestoEnSeleccion BIGINT, CodigoFIFA CHAR(3), Seleccion NVARCHAR(100),
        Dorsal INT, Jugador NVARCHAR(200), Posicion NVARCHAR(20), Fase NVARCHAR(50), GolesEnFase INT, GolesJugada INT,
        GolesCabezazo INT, GolesPenal INT, GolesTiroLibre INT, GolesEnContra INT, AsistenciasEnFase INT,
        TotalGolesJugadorTorneo INT, TotalAsistenciasTorneo INT, TotalGolesSeleccionTorneo INT);
DECLARE @tarjetas TABLE (CodigoFIFA CHAR(3), Seleccion NVARCHAR(100), Dorsal INT, Jugador NVARCHAR(200), Amarillas INT,
        AmarillasAcumulables INT, RojasDobleAmarilla INT, RojasDirectas INT, TotalTarjetas INT,
        SuspensionActivaAcumulacion BIT, PartidosPendientesPorAcumulacion INT, DetalleSuspensionesAcumulacion NVARCHAR(MAX));
DECLARE @ocupacion TABLE (IdSede INT, Sede NVARCHAR(100), Ciudad NVARCHAR(100), PaisSede NVARCHAR(100), IdPartido INT,
        NumeroPartido INT, Fase NVARCHAR(50), FechaHoraUTC DATETIME2(0), Encuentro NVARCHAR(20), NumeroEspacio INT,
        EstadoEspacio NVARCHAR(10), Anunciante NVARCHAR(100), PaisAnunciante NVARCHAR(100), Campania NVARCHAR(100),
        PiezaPublicitaria NVARCHAR(100), IdiomaPieza NVARCHAR(100), TarifaPublicitaria DECIMAL(12,2), Moneda NVARCHAR(3),
        TarifaUSD DECIMAL(14,2), CriterioAsignacion NVARCHAR(60), EspaciosOcupadosPartido INT, PorcentajeOcupacionPartido DECIMAL(5,2));
DECLARE @resumen TABLE (IdSede INT, Sede NVARCHAR(100), Ciudad NVARCHAR(100), PaisSede NVARCHAR(100), PartidosEnSede INT,
        CuposTotalesSede INT, TotalEspaciosOcupadosSede INT, PorcentajeOcupacionSede DECIMAL(5,2), Moneda NVARCHAR(20),
        EspaciosEnMoneda INT, IngresosGenerados DECIMAL(14,2), IngresosUSD DECIMAL(14,2), TotalIngresosUSDSede DECIMAL(14,2));
DECLARE @prime TABLE (IdPartido INT, NumeroPartido INT, Fase NVARCHAR(50), FechaHoraUTC DATETIME2(0), Encuentro NVARCHAR(20),
        TotalMercadosPrimeTime INT, MercadosEnPrimeTimeDetalle NVARCHAR(MAX),
        ARG NVARCHAR(20), AUS NVARCHAR(20), BRA NVARCHAR(20), CAN NVARCHAR(20), CHI NVARCHAR(20), COL NVARCHAR(20),
        ENG NVARCHAR(20), ESP NVARCHAR(20), FRA NVARCHAR(20), GER NVARCHAR(20), ITA NVARCHAR(20), JPN NVARCHAR(20),
        KOR NVARCHAR(20), MAR NVARCHAR(20), MEX NVARCHAR(20), NED NVARCHAR(20), NOR NVARCHAR(20), POR NVARCHAR(20),
        SUI NVARCHAR(20), SWE NVARCHAR(20), URU NVARCHAR(20), USA NVARCHAR(20));
DECLARE @resultados TABLE (IdPartido INT, NumeroPartido INT, Fase NVARCHAR(50), Instancia NVARCHAR(50), FechaHoraUTC DATETIME2(0),
        FechaHoraLocalSede DATETIME2(0), HusoHorarioSede NVARCHAR(50), Estadio NVARCHAR(100), CiudadPaisSede NVARCHAR(200),
        Estado NVARCHAR(10), SeleccionLocal NVARCHAR(100), GolesLocal INT, GolesVisitante INT, PenalesLocal INT,
        PenalesVisitante INT, Marcador NVARCHAR(50), SeleccionVisitante NVARCHAR(100), Ganador NVARCHAR(100),
        ConcurrenciaPublico INT, CapacidadEstadio INT, PorcentajeOcupacionEstadio DECIMAL(5,2), ArbitroPrincipal NVARCHAR(200));
DECLARE @xml TABLE (Documento XML);

IF @hayDatos = 0
    PRINT 'AVISO: la base no tiene partidos; los casos con datos se informan como OMITIDO.';

-- =========================================================================
-- TEST 1: eventos.SP_REPORTE_GOLEADORES
-- =========================================================================
PRINT '--- TEST 1: goleadores ---';

-- 1.A Sin filtros. Resultado esperado: una fila por (jugador convocado, fase) con goles válidos (sin tanda de
-- penales ni goles en contra) y la suma de GolesEnFase igual a la cantidad de esos goles.
INSERT INTO @goleadores EXEC eventos.SP_REPORTE_GOLEADORES;
SELECT @esperado = COUNT(*), @aux = ISNULL(SUM(x.Goles), 0)
FROM (SELECT g.IdJugadorAutor, p.IdFase, COUNT(*) AS Goles
      FROM eventos.Gol AS g
      INNER JOIN nucleo.Partido AS p ON p.IdPartido = g.IdPartido
      INNER JOIN eventos.TipoGol AS tg ON tg.IdTipoGol = g.IdTipoGol
      INNER JOIN eventos.Periodo AS pe ON pe.IdPeriodo = g.IdPeriodo
      WHERE pe.Descripcion <> 'Definicion por Penales' AND tg.Descripcion <> 'En contra'
        AND EXISTS (SELECT 1 FROM jugadores.Convocatoria AS c WHERE c.IdJugador = g.IdJugadorAutor)
      GROUP BY g.IdJugadorAutor, p.IdFase) AS x;
SELECT @obtenido = COUNT(*) FROM @goleadores;
IF @hayDatos = 0 PRINT '1.A: OMITIDO - sin datos.';
ELSE IF @obtenido = @esperado AND (SELECT ISNULL(SUM(GolesEnFase), 0) FROM @goleadores) = @aux
    PRINT '1.A: OK - ' + CAST(@obtenido AS VARCHAR(10)) + ' filas y ' + CAST(@aux AS VARCHAR(10)) + ' goles válidos.';
ELSE PRINT '1.A: FALLÓ - filas ' + CAST(@obtenido AS VARCHAR(10)) + ' (esperado ' + CAST(@esperado AS VARCHAR(10)) + ').';

-- 1.B Filtro por selección 'ARG'. Resultado esperado: todas las filas son de ARG.
DELETE FROM @goleadores;
IF EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE CodigoFIFA = 'ARG')
BEGIN
    INSERT INTO @goleadores EXEC eventos.SP_REPORTE_GOLEADORES @codigoFIFA = 'arg', @incluirEnContra = 1;
    IF NOT EXISTS (SELECT 1 FROM @goleadores WHERE CodigoFIFA <> 'ARG')
        BEGIN SET @mensaje = '1.B: OK - ' + CAST((SELECT COUNT(*) FROM @goleadores) AS VARCHAR(10)) + ' filas, todas de ARG.'; PRINT @mensaje; END
    ELSE PRINT '1.B: FALLÓ - el filtro por selección devolvió filas de otra selección.';
END
ELSE PRINT '1.B: OMITIDO - no existe la selección ARG.';

-- 1.C Filtros inexistentes (selección 'ZZZ' y fase 250). Resultado esperado: error 52000 con 2 renglones.
BEGIN TRY
    EXEC eventos.SP_REPORTE_GOLEADORES @codigoFIFA = 'ZZZ', @idFase = 250;
    PRINT '1.C: FALLÓ - aceptó filtros inexistentes.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 2 PRINT '1.C: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '1.C: FALLÓ - ' + @mensaje;
END CATCH;

-- =========================================================================
-- TEST 2: eventos.SP_REPORTE_TARJETAS_SUSPENSIONES
-- =========================================================================
PRINT '--- TEST 2: tarjetas y suspensiones ---';

-- 2.A Sin filtros. Resultado esperado: una fila por jugador convocado con al menos una tarjeta, y el total de
-- tarjetas igual a las amonestaciones de jugadores convocados.
INSERT INTO @tarjetas EXEC eventos.SP_REPORTE_TARJETAS_SUSPENSIONES;
SELECT @esperado = COUNT(DISTINCT a.IdJugador), @aux = COUNT(*)
FROM eventos.Amonestacion AS a
WHERE a.IdJugador IS NOT NULL
  AND EXISTS (SELECT 1 FROM jugadores.Convocatoria AS c WHERE c.IdJugador = a.IdJugador);
IF @hayDatos = 0 PRINT '2.A: OMITIDO - sin datos.';
ELSE IF (SELECT COUNT(*) FROM @tarjetas) = @esperado AND (SELECT ISNULL(SUM(TotalTarjetas), 0) FROM @tarjetas) = @aux
    PRINT '2.A: OK - ' + CAST(@esperado AS VARCHAR(10)) + ' jugadores con ' + CAST(@aux AS VARCHAR(10)) + ' tarjetas.';
ELSE BEGIN SET @mensaje = '2.A: FALLÓ - jugadores ' + CAST((SELECT COUNT(*) FROM @tarjetas) AS VARCHAR(10)) + ' (esperado ' + CAST(@esperado AS VARCHAR(10)) + ').'; PRINT @mensaje; END

-- 2.B Solo suspensiones activas. Resultado esperado: todas las filas con SuspensionActivaAcumulacion = 1.
DELETE FROM @tarjetas;
INSERT INTO @tarjetas EXEC eventos.SP_REPORTE_TARJETAS_SUSPENSIONES @soloConSuspensionActiva = 1;
IF NOT EXISTS (SELECT 1 FROM @tarjetas WHERE SuspensionActivaAcumulacion = 0)
    BEGIN SET @mensaje = '2.B: OK - ' + CAST((SELECT COUNT(*) FROM @tarjetas) AS VARCHAR(10)) + ' jugadores con suspensión activa, todos marcados.'; PRINT @mensaje; END
ELSE PRINT '2.B: FALLÓ - devolvió jugadores sin suspensión activa.';

-- 2.C Selección inexistente. Resultado esperado: error 52000 con 1 renglón.
BEGIN TRY
    EXEC eventos.SP_REPORTE_TARJETAS_SUSPENSIONES @codigoFIFA = 'ZZZ';
    PRINT '2.C: FALLÓ - aceptó una selección inexistente.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 1 PRINT '2.C: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '2.C: FALLÓ - ' + @mensaje;
END CATCH;

-- =========================================================================
-- TEST 3: nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES (XML #1)
-- =========================================================================
PRINT '--- TEST 3: designaciones arbitrales (XML) ---';

-- 3.A Resultado esperado: XML válido con raíz <DesignacionesArbitrales>, un nodo <Arbitro> por árbitro, tantos
-- <Partido> como designaciones y ningún nombre enmascarado.
INSERT INTO @xml EXEC nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES;
SELECT @x = Documento FROM @xml;
SELECT @raiz         = @x.exist('/DesignacionesArbitrales'),
       @nodos        = @x.value('count(/DesignacionesArbitrales/Arbitro)', 'INT'),
       @hijos        = @x.value('count(/DesignacionesArbitrales/Arbitro/PartidosDesignados/Partido)', 'INT'),
       @enmascarados = @x.exist('//NombreApellido[contains(., "***")]');
IF NOT EXISTS (SELECT 1 FROM nucleo.Arbitro) PRINT '3.A: OMITIDO - sin árbitros.';
ELSE IF @raiz = 1 AND @enmascarados = 0
     AND @nodos = (SELECT COUNT(*) FROM nucleo.Arbitro)
     AND @hijos = (SELECT COUNT(*) FROM nucleo.DesignacionArbitral)
    PRINT '3.A: OK - XML válido con ' + CAST(@nodos AS VARCHAR(10)) + ' árbitros y ' + CAST(@hijos AS VARCHAR(10))
          + ' designaciones, nombres descifrados.';
ELSE PRINT '3.A: FALLÓ - el XML no tiene la estructura o las cantidades esperadas.';

-- 3.B Árbitro inexistente y fase inexistente. Resultado esperado: error 52000 con 2 renglones.
BEGIN TRY
    EXEC nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES @idArbitro = -1, @idFase = 250;
    PRINT '3.B: FALLÓ - aceptó filtros inexistentes.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 2 PRINT '3.B: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '3.B: FALLÓ - ' + @mensaje;
END CATCH;

-- =========================================================================
-- TEST 4: publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA
-- =========================================================================
PRINT '--- TEST 4: ocupación publicitaria ---';

-- 4.A Detalle (@resultado = 1). Resultado esperado: 4 filas por partido; tantas 'Ocupado' como espacios
-- asignados, todas con anunciante y campaña; y la tarifa en USD informada en los espacios en USD.
INSERT INTO @ocupacion EXEC publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA @resultado = 1;
IF @hayDatos = 0 PRINT '4.A: OMITIDO - sin datos.';
ELSE IF (SELECT COUNT(*) FROM @ocupacion) = 4 * (SELECT COUNT(*) FROM nucleo.Partido)
     AND (SELECT COUNT(*) FROM @ocupacion WHERE EstadoEspacio = 'Ocupado') = (SELECT COUNT(*) FROM publicidad.EspacioPublicitario)
     AND NOT EXISTS (SELECT 1 FROM @ocupacion WHERE EstadoEspacio = 'Ocupado' AND (Anunciante = '-' OR Campania = '-'))
     AND NOT EXISTS (SELECT 1 FROM @ocupacion WHERE Moneda = 'USD' AND ISNULL(TarifaUSD, -1) <> TarifaPublicitaria)
    BEGIN SET @mensaje = '4.A: OK - ' + CAST((SELECT COUNT(*) FROM @ocupacion) AS VARCHAR(10)) + ' filas, '
          + CAST((SELECT COUNT(*) FROM @ocupacion WHERE EstadoEspacio = 'Ocupado') AS VARCHAR(10)) + ' ocupadas con anunciante y campaña.'; PRINT @mensaje; END
ELSE PRINT '4.A: FALLÓ - el detalle no coincide con los espacios cargados.';

-- 4.B Resumen (@resultado = 2). Resultado esperado: la suma de IngresosGenerados es la suma de las tarifas de
-- todos los espacios, y la de espacios ocupados es la cantidad de espacios.
INSERT INTO @resumen EXEC publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA @resultado = 2;
IF @hayDatos = 0 PRINT '4.B: OMITIDO - sin datos.';
ELSE IF (SELECT ISNULL(SUM(IngresosGenerados), 0) FROM @resumen) = (SELECT ISNULL(SUM(TarifaPublicitaria), 0) FROM publicidad.EspacioPublicitario)
     AND (SELECT ISNULL(SUM(EspaciosEnMoneda), 0) FROM @resumen) = (SELECT COUNT(*) FROM publicidad.EspacioPublicitario)
    BEGIN SET @mensaje = '4.B: OK - ingresos por sede y moneda coherentes con los espacios (total USD: '
          + ISNULL(CAST((SELECT SUM(IngresosUSD) FROM @resumen) AS VARCHAR(20)), 'NULL') + ').'; PRINT @mensaje; END
ELSE PRINT '4.B: FALLÓ - el resumen no suma lo mismo que los espacios.';

-- 4.C Sede inexistente y @resultado fuera de rango. Resultado esperado: error 52000 con 2 renglones.
BEGIN TRY
    EXEC publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA @idSede = 250, @resultado = 5;
    PRINT '4.C: FALLÓ - aceptó parámetros inválidos.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 2 PRINT '4.C: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '4.C: FALLÓ - ' + @mensaje;
END CATCH;

-- =========================================================================
-- TEST 5: publicidad.SP_REPORTE_MATRIZ_PRIME_TIME (PIVOT)
-- =========================================================================
PRINT '--- TEST 5: matriz de prime time ---';

-- 5.A Resultado esperado: una fila por partido; TotalMercadosPrimeTime igual a nucleo.fn_MercadosEnPrimeTime, y
-- la columna ARG con 'SI (...)' exactamente en los partidos en que ARG está en prime time. Con el seed, el
-- partido 1 (ARG vs BRA, 23:00 UTC) tiene 6 mercados en prime time.
INSERT INTO @prime EXEC publicidad.SP_REPORTE_MATRIZ_PRIME_TIME;
SELECT @esperado = COUNT(*) FROM nucleo.Partido AS p
WHERE EXISTS (SELECT 1 FROM nucleo.fn_MercadosEnPrimeTime(p.IdPartido) AS m WHERE m.CodigoISO3 = 'ARG');
IF @hayDatos = 0 PRINT '5.A: OMITIDO - sin datos.';
ELSE IF (SELECT COUNT(*) FROM @prime) = (SELECT COUNT(*) FROM nucleo.Partido)
     AND NOT EXISTS (SELECT 1 FROM @prime AS pr
                     WHERE pr.TotalMercadosPrimeTime <> (SELECT COUNT(*) FROM nucleo.fn_MercadosEnPrimeTime(pr.IdPartido)))
     AND (SELECT COUNT(*) FROM @prime WHERE ARG LIKE 'SI%') = @esperado
    BEGIN SET @mensaje = '5.A: OK - ' + CAST((SELECT COUNT(*) FROM @prime) AS VARCHAR(10)) + ' partidos; partido 1 en prime time en '
          + ISNULL(CAST((SELECT TotalMercadosPrimeTime FROM @prime WHERE NumeroPartido = 1) AS VARCHAR(10)), '-') + ' mercados.'; PRINT @mensaje; END
ELSE PRINT '5.A: FALLÓ - la matriz no coincide con nucleo.fn_MercadosEnPrimeTime.';

-- 5.B Partido inexistente. Resultado esperado: error 52000 con 1 renglón.
BEGIN TRY
    EXEC publicidad.SP_REPORTE_MATRIZ_PRIME_TIME @idPartido = -1;
    PRINT '5.B: FALLÓ - aceptó un partido inexistente.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 1 PRINT '5.B: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '5.B: FALLÓ - ' + @mensaje;
END CATCH;

-- =========================================================================
-- TEST 6: jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS (XML #2)
-- =========================================================================
PRINT '--- TEST 6: selecciones y plantillas (XML) ---';

-- 6.A Resultado esperado: XML válido con raíz <SeleccionesYPlantillas>, un nodo <Seleccion> por selección, un
-- <Jugador> por convocado activo (nombre, posición, club y dorsal) y el cuerpo técnico sin nombres enmascarados.
DELETE FROM @xml;
INSERT INTO @xml EXEC jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS;
SELECT @x = Documento FROM @xml;
SELECT @esperado = COUNT(*) FROM jugadores.Convocatoria AS c
WHERE NOT EXISTS (SELECT 1 FROM jugadores.Baja AS b WHERE b.IdConvocatoria = c.IdConvocatoria);
SELECT @raiz         = @x.exist('/SeleccionesYPlantillas'),
       @nodos        = @x.value('count(/SeleccionesYPlantillas/Seleccion)', 'INT'),
       @hijos        = @x.value('count(/SeleccionesYPlantillas/Seleccion/Convocados/Jugador)', 'INT'),
       @incompletos  = @x.value('count(//Jugador[not(Nombre) or not(Posicion) or not(Club) or not(Dorsal)])', 'INT'),
       @enmascarados = @x.exist('//Integrante/NombreApellido[contains(., "***")]');
IF NOT EXISTS (SELECT 1 FROM nucleo.Seleccion) PRINT '6.A: OMITIDO - sin selecciones.';
ELSE IF @raiz = 1 AND @enmascarados = 0 AND @incompletos = 0
     AND @nodos = (SELECT COUNT(*) FROM nucleo.Seleccion)
     AND @hijos = @esperado
    PRINT '6.A: OK - XML válido con ' + CAST(@nodos AS VARCHAR(10)) + ' selecciones y ' + CAST(@hijos AS VARCHAR(10)) + ' convocados.';
ELSE PRINT '6.A: FALLÓ - el XML no tiene la estructura o las cantidades esperadas.';

-- 6.B Selección y grupo inexistentes. Resultado esperado: error 52000 con 2 renglones.
BEGIN TRY
    EXEC jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS @codigoFIFA = 'ZZZ', @grupo = 'X';
    PRINT '6.B: FALLÓ - aceptó filtros inexistentes.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 2 PRINT '6.B: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '6.B: FALLÓ - ' + @mensaje;
END CATCH;

-- =========================================================================
-- TEST 7: nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS
-- =========================================================================
PRINT '--- TEST 7: resultados de los encuentros ---';

-- 7.A Resultado esperado: una fila por partido; los finalizados con marcador ('n - m') y los programados con
-- 'vs'; ningún árbitro con nombre enmascarado.
INSERT INTO @resultados EXEC nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS;
IF @hayDatos = 0 PRINT '7.A: OMITIDO - sin datos.';
ELSE IF (SELECT COUNT(*) FROM @resultados) = (SELECT COUNT(*) FROM nucleo.Partido)
     AND NOT EXISTS (SELECT 1 FROM @resultados WHERE Estado = 'Finalizado' AND Marcador NOT LIKE '%-%')
     AND NOT EXISTS (SELECT 1 FROM @resultados WHERE Estado = 'Programado' AND Marcador <> 'vs')
     AND NOT EXISTS (SELECT 1 FROM @resultados WHERE ArbitroPrincipal LIKE '%***%')
    BEGIN SET @mensaje = '7.A: OK - ' + CAST((SELECT COUNT(*) FROM @resultados) AS VARCHAR(10)) + ' partidos ('
          + CAST((SELECT COUNT(*) FROM @resultados WHERE Estado = 'Finalizado') AS VARCHAR(10)) + ' finalizados).'; PRINT @mensaje; END
ELSE PRINT '7.A: FALLÓ - el reporte no coincide con los partidos.';

-- 7.B Estado inválido. Resultado esperado: error 52000 con 1 renglón.
BEGIN TRY
    EXEC nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS @estado = 'Jugando';
    PRINT '7.B: FALLÓ - aceptó un estado inválido.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 1 PRINT '7.B: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '7.B: FALLÓ - ' + @mensaje;
END CATCH;
GO
