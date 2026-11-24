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
Objetivo: Probar qué puede y qué no puede hacer el usuario usr_publicidad_test (Rol_GestorPublicidad): gestión de la
          pauta publicitaria con lectura de partidos y sedes, sin acceso a eventos, jugadores ni datos descifrados.
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
EXECUTE AS USER = 'usr_publicidad_test';
PRINT 'Contexto: ' + USER_NAME() + ' (Rol_GestorPublicidad)';
DECLARE @t TABLE (x INT);

-- 3.1 Puede leer partidos, sedes y anunciantes. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    INSERT INTO @t SELECT TOP (1) IdSede FROM nucleo.Sede; INSERT INTO @t SELECT TOP (1) IdPartido FROM nucleo.Partido; INSERT INTO @t SELECT TOP (1) IdAnunciante FROM publicidad.Anunciante;
    PRINT '3.1: OK - puede leer partidos, sedes y anunciantes.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '3.1: FALLÓ - no pudo leer partidos, sedes y anunciantes: ' + ERROR_MESSAGE();
    ELSE
        PRINT '3.1: OK - puede leer partidos, sedes y anunciantes (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 3.2 Puede simular la asignación de publicidad. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = -1, @soloSimular = 1;
    PRINT '3.2: OK - puede simular la asignación de publicidad.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '3.2: FALLÓ - no pudo simular la asignación de publicidad: ' + ERROR_MESSAGE();
    ELSE
        PRINT '3.2: OK - puede simular la asignación de publicidad (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 3.3 Puede dar de alta anunciantes. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC publicidad.SP_ALTA_Anunciante @nombre = NULL, @idPais = -1;
    PRINT '3.3: OK - puede dar de alta anunciantes.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '3.3: FALLÓ - no pudo dar de alta anunciantes: ' + ERROR_MESSAGE();
    ELSE
        PRINT '3.3: OK - puede dar de alta anunciantes (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 3.4 Puede importar campañas. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC publicidad.SP_IMPORTAR_CAMPANIAS_CSV @nombreArchivo = NULL;
    PRINT '3.4: OK - puede importar campañas.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '3.4: FALLÓ - no pudo importar campañas: ' + ERROR_MESSAGE();
    ELSE
        PRINT '3.4: OK - puede importar campañas (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 3.5 Puede ver el reporte de ocupación. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA @idSede = 250;
    PRINT '3.5: OK - puede ver el reporte de ocupación.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '3.5: FALLÓ - no pudo ver el reporte de ocupación: ' + ERROR_MESSAGE();
    ELSE
        PRINT '3.5: OK - puede ver el reporte de ocupación (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 3.6 No puede registrar goles. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = -1, @idJugadorAutor = -1, @tipoGol = 'Jugada', @periodo = 'Primer Tiempo', @minuto = 10;
    PRINT '3.6: FALLÓ - pudo registrar goles.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '3.6: OK (Bloqueado) - no puede registrar goles (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '3.6: FALLÓ - registrar goles: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 3.7 No puede dar de alta jugadores. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    EXEC jugadores.SP_ALTA_Jugador @nombre = 'TEST ROL', @apellido = 'Permisos', @documento = NULL, @sexo = 'X', @posicion = 'Nada';
    PRINT '3.7: FALLÓ - pudo dar de alta jugadores.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '3.7: OK (Bloqueado) - no puede dar de alta jugadores (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '3.7: FALLÓ - dar de alta jugadores: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 3.8 No puede leer jugadores. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    INSERT INTO @t SELECT TOP (1) IdJugador FROM jugadores.Jugador;
    PRINT '3.8: FALLÓ - pudo leer jugadores.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '3.8: OK (Bloqueado) - no puede leer jugadores (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '3.8: FALLÓ - leer jugadores: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 3.9 No puede finalizar partidos. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    EXEC nucleo.SP_FINALIZAR_PARTIDO @idPartido = -1;
    PRINT '3.9: FALLÓ - pudo finalizar partidos.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '3.9: OK (Bloqueado) - no puede finalizar partidos (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '3.9: FALLÓ - finalizar partidos: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

-- 3.10 No puede consultar árbitros descifrados. Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    EXEC nucleo.SP_CONSULTAR_ARBITRO_DESCIFRADO;
    PRINT '3.10: FALLÓ - pudo consultar árbitros descifrados.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '3.10: OK (Bloqueado) - no puede consultar árbitros descifrados (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '3.10: FALLÓ - consultar árbitros descifrados: error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

REVERT;
GO
