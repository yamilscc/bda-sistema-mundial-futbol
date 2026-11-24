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
Objetivo: Probar qué puede y qué no puede hacer el usuario usr_resultados_test (Rol_OperadorResultados): carga de
          resultados (goles, tarjetas, formaciones, convocatoria y cierre de partidos) sin acceso a publicidad ni a
          datos descifrados.
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
EXECUTE AS USER = 'usr_resultados_test';
PRINT 'Contexto: ' + USER_NAME() + ' (Rol_OperadorResultados)';
DECLARE @t TABLE (x INT);

-- 2.1 Puede leer partidos y jugadores. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    INSERT INTO @t SELECT TOP (1) IdPartido FROM nucleo.Partido; INSERT INTO @t SELECT TOP (1) IdJugador FROM jugadores.Jugador;
    PRINT '2.1: OK - puede leer partidos y jugadores.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '2.1: FALLÓ - no pudo leer partidos y jugadores: ' + ERROR_MESSAGE();
    ELSE
        PRINT '2.1: OK - puede leer partidos y jugadores (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 2.2 Puede registrar goles. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = -1, @idJugadorAutor = -1, @tipoGol = 'Jugada', @periodo = 'Primer Tiempo', @minuto = 10;
    PRINT '2.2: OK - puede registrar goles.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '2.2: FALLÓ - no pudo registrar goles: ' + ERROR_MESSAGE();
    ELSE
        PRINT '2.2: OK - puede registrar goles (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 2.3 Puede registrar amonestaciones. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = -1, @tipoTarjeta = 'Amarilla', @minuto = 10, @motivo = 'Prueba de permisos', @idJugador = -1;
    PRINT '2.3: OK - puede registrar amonestaciones.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '2.3: FALLÓ - no pudo registrar amonestaciones: ' + ERROR_MESSAGE();
    ELSE
        PRINT '2.3: OK - puede registrar amonestaciones (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 2.4 Puede convocar jugadores. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC jugadores.SP_CONVOCAR_JUGADOR @idSeleccion = -1, @idJugador = -1, @dorsal = 1;
    PRINT '2.4: OK - puede convocar jugadores.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '2.4: FALLÓ - no pudo convocar jugadores: ' + ERROR_MESSAGE();
    ELSE
        PRINT '2.4: OK - puede convocar jugadores (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 2.5 Puede finalizar partidos. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = -1;
    PRINT '2.5: OK - puede finalizar partidos.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '2.5: FALLÓ - no pudo finalizar partidos: ' + ERROR_MESSAGE();
    ELSE
        PRINT '2.5: OK - puede finalizar partidos (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 2.6 Puede ver el reporte de goleadores. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC eventos.SP_REPORTE_GOLEADORES @codigoFIFA = 'ZZZ';
    PRINT '2.6: OK - puede ver el reporte de goleadores.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '2.6: FALLÓ - no pudo ver el reporte de goleadores: ' + ERROR_MESSAGE();
    ELSE
        PRINT '2.6: OK - puede ver el reporte de goleadores (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 2.7 No puede asignar publicidad. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = -1, @soloSimular = 1;
    PRINT '2.7: FALLÓ - pudo asignar publicidad.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '2.7: OK (Bloqueado) - no puede asignar publicidad (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '2.7: FALLÓ - asignar publicidad: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 2.8 No puede dar de alta anunciantes. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    EXEC publicidad.SP_ALTA_Anunciante @nombre = 'TEST ROL Anunciante', @idPais = 1;
    PRINT '2.8: FALLÓ - pudo dar de alta anunciantes.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '2.8: OK (Bloqueado) - no puede dar de alta anunciantes (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '2.8: FALLÓ - dar de alta anunciantes: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 2.9 No puede insertar directo en tablas. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion) VALUES ('TEST ROL Pais', 'QR', 'QRA', 'UTC', 1);
    PRINT '2.9: FALLÓ - pudo insertar directo en tablas.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '2.9: OK (Bloqueado) - no puede insertar directo en tablas (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '2.9: FALLÓ - insertar directo en tablas: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 2.10 No puede leer el secreto del hash. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    INSERT INTO @t SELECT COUNT(*) FROM nucleo.ConfiguracionCifrado;
    PRINT '2.10: FALLÓ - pudo leer el secreto del hash.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '2.10: OK (Bloqueado) - no puede leer el secreto del hash (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '2.10: FALLÓ - leer el secreto del hash: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 2.11 No puede consultar documentos descifrados. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    EXEC jugadores.SP_CONSULTAR_JUGADOR_DESCIFRADO @idJugador = -1;
    PRINT '2.11: FALLÓ - pudo consultar documentos descifrados.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '2.11: OK (Bloqueado) - no puede consultar documentos descifrados (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '2.11: FALLÓ - consultar documentos descifrados: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

REVERT;
GO
