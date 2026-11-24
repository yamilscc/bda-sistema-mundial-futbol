/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner (versión original); separado por usuario por Torczuk, Elías Alexei
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar qué puede y qué no puede hacer el usuario usr_consulta_test (Rol_Consulta): ejecución de los siete
          reportes y lectura de vistas, sin escritura, sin SP transaccionales ni datos descifrados.
          Cada caso imprime OK o FALLÓ. "Puede" = el permiso alcanza: la instrucción corre o el SP responde con su
          propia validación (por ejemplo error 52000 por un id inexistente), nunca con permiso denegado.
          "No puede" = el motor la rechaza por permisos (error 229, o 262 para crear objetos).
          Los casos no modifican datos: los SP se llaman con ids inexistentes (responden con su validación)
          y la única escritura (alta directa del administrador) se deshace en el mismo caso.
          Requiere ejecutados los scripts 01 a 33 (usa los usuarios de nucleo.SP_CREAR_USUARIOS_PRUEBA).
*/

USE MundialFutbol;
GO

SET NOCOUNT ON;
EXECUTE AS USER = 'usr_consulta_test';
PRINT 'Contexto: ' + USER_NAME() + ' (Rol_Consulta)';
DECLARE @t TABLE (x INT);

-- 4.1 Puede ver el reporte de resultados. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    DECLARE @r TABLE (a INT, b INT, c NVARCHAR(50), d NVARCHAR(50), e DATETIME2(0), f DATETIME2(0), g NVARCHAR(50), h NVARCHAR(100), i NVARCHAR(200), j NVARCHAR(10), k NVARCHAR(100), l INT, m INT, n INT, o INT, p NVARCHAR(50), q NVARCHAR(100), r NVARCHAR(100), s INT, t INT, u DECIMAL(5,2), v NVARCHAR(200)); INSERT INTO @r EXEC nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS;
    PRINT '4.1: OK - puede ver el reporte de resultados.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '4.1: FALLÓ - no pudo ver el reporte de resultados: ' + ERROR_MESSAGE();
    ELSE
        PRINT '4.1: OK - puede ver el reporte de resultados (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 4.2 Puede ver los reportes XML. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    DECLARE @x TABLE (d XML); INSERT INTO @x EXEC jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS; INSERT INTO @x EXEC nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES;
    PRINT '4.2: OK - puede ver los reportes XML.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '4.2: FALLÓ - no pudo ver los reportes XML: ' + ERROR_MESSAGE();
    ELSE
        PRINT '4.2: OK - puede ver los reportes XML (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 4.3 Puede ver el reporte de goleadores. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC eventos.SP_REPORTE_GOLEADORES @codigoFIFA = 'ZZZ';
    PRINT '4.3: OK - puede ver el reporte de goleadores.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '4.3: FALLÓ - no pudo ver el reporte de goleadores: ' + ERROR_MESSAGE();
    ELSE
        PRINT '4.3: OK - puede ver el reporte de goleadores (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 4.3.b Puede ver el reporte de tarjetas. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC eventos.SP_REPORTE_TARJETAS_SUSPENSIONES @codigoFIFA = 'ZZZ';
    PRINT '4.3.b: OK - puede ver el reporte de tarjetas.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300) PRINT '4.3.b: FALLÓ - no pudo ver el reporte de tarjetas: ' + ERROR_MESSAGE();
    ELSE PRINT '4.3.b: OK - puede ver el reporte de tarjetas (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 4.3.c Puede ver el reporte de ocupación. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA @idSede = 250;
    PRINT '4.3.c: OK - puede ver el reporte de ocupación.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300) PRINT '4.3.c: FALLÓ - no pudo ver el reporte de ocupación: ' + ERROR_MESSAGE();
    ELSE PRINT '4.3.c: OK - puede ver el reporte de ocupación (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 4.4 Puede ver la matriz de prime time. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC publicidad.SP_REPORTE_MATRIZ_PRIME_TIME @idPartido = -1;
    PRINT '4.4: OK - puede ver la matriz de prime time.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '4.4: FALLÓ - no pudo ver la matriz de prime time: ' + ERROR_MESSAGE();
    ELSE
        PRINT '4.4: OK - puede ver la matriz de prime time (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 4.5 Puede leer la vista de resultados. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    INSERT INTO @t SELECT COUNT(*) FROM nucleo.vw_PartidoResultado;
    PRINT '4.5: OK - puede leer la vista de resultados.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '4.5: FALLÓ - no pudo leer la vista de resultados: ' + ERROR_MESSAGE();
    ELSE
        PRINT '4.5: OK - puede leer la vista de resultados (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 4.6 No puede insertar directo en tablas. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion) VALUES ('TEST ROL Pais', 'QR', 'QRA', 'UTC', 1);
    PRINT '4.6: FALLÓ - pudo insertar directo en tablas.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '4.6: OK (Bloqueado) - no puede insertar directo en tablas (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '4.6: FALLÓ - insertar directo en tablas: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 4.7 No puede registrar amonestaciones. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = -1, @tipoTarjeta = 'Amarilla', @minuto = 10, @motivo = 'Prueba de permisos', @idJugador = -1;
    PRINT '4.7: FALLÓ - pudo registrar amonestaciones.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '4.7: OK (Bloqueado) - no puede registrar amonestaciones (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '4.7: FALLÓ - registrar amonestaciones: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 4.8 No puede asignar publicidad. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = -1, @soloSimular = 1;
    PRINT '4.8: FALLÓ - pudo asignar publicidad.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '4.8: OK (Bloqueado) - no puede asignar publicidad (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '4.8: FALLÓ - asignar publicidad: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 4.9 No puede leer la tabla de jugadores. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    INSERT INTO @t SELECT TOP (1) IdJugador FROM jugadores.Jugador;
    PRINT '4.9: FALLÓ - pudo leer la tabla de jugadores.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '4.9: OK (Bloqueado) - no puede leer la tabla de jugadores (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '4.9: FALLÓ - leer la tabla de jugadores: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 4.10 No puede usar la función de descifrado. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    INSERT INTO @t SELECT CASE WHEN nucleo.fn_DescifrarTexto(NULL) IS NULL THEN 1 END;
    PRINT '4.10: FALLÓ - pudo usar la función de descifrado.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '4.10: OK (Bloqueado) - no puede usar la función de descifrado (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '4.10: FALLÓ - usar la función de descifrado: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 4.11 No puede ejecutar backups. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    EXEC nucleo.SP_BACKUP_COMPLETO;
    PRINT '4.11: FALLÓ - pudo ejecutar backups.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '4.11: OK (Bloqueado) - no puede ejecutar backups (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '4.11: FALLÓ - ejecutar backups: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

REVERT;
GO
