/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner
Fecha: 2026-11-23
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Validar los permisos del usuario [usr_resultados_test] perteneciente al rol [Rol_OperadorResultados]:
          1. Casos Exitosos: Operaciones sobre eventos y partidos (SELECT en núcleo/jugadores,
             ejecución de reportes/procedimientos de eventos).
          2. Casos Denegados: Intentar ejecutar procedimientos del módulo de publicidad
             (captura controlada del Error 229 - EXECUTE permission denied).
*/

USE MundialFutbol;
GO

PRINT '=========================================================================';
PRINT 'TEST DE PERMISOS: Usuario [usr_resultados_test] (Rol_OperadorResultados)';
PRINT '=========================================================================';
GO

EXECUTE AS USER = 'usr_resultados_test';
PRINT 'Contexto actual: ' + USER_NAME();
GO

-- 1. CASO EXITOSO: Consulta de partidos y selecciones autorizada
-- Resultado esperado: Retorna registros sin error.
SELECT TOP 3 IdPartido, FechaHoraUTC, IdSede FROM nucleo.Partido;
GO

-- 2. CASO EXITOSO: Ejecución de procedimiento de reportes de eventos
-- Resultado esperado: Ejecución satisfactoria.
EXEC eventos.SP_REPORTE_GOLEADORES;
GO

-- 3. CASO DENEGADO CONTROLADO: Intentar ejecutar SP de publicidad
-- Resultado esperado: Error 229 (Permiso denegado), capturado en CATCH confirmando la seguridad.
BEGIN TRY
    PRINT 'Intentando ejecutar publicidad.SP_ASIGNAR_PUBLICIDAD...';
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = 1;
    PRINT 'FALLÓ LA SEGURIDAD: El usuario no debía poder ejecutar el SP de publicidad.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
    BEGIN
        PRINT 'SEGURIDAD CONFIRMADA (Éxito del Test): Permiso denegado correctamente.';
        PRINT 'Error capturado: [' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + N'] ' + ERROR_MESSAGE();
    END
    ELSE
    BEGIN
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
    END;
END CATCH;
GO

-- 4. CASO DENEGADO CONTROLADO: Intentar ejecutar ABM de Anunciante
BEGIN TRY
    PRINT 'Intentando ejecutar publicidad.SP_ABM_Anunciante...';
    EXEC publicidad.SP_ABM_Anunciante @operacion = 'ALTA', @nombre = 'TestDenegado';
    PRINT 'FALLÓ LA SEGURIDAD: El operador no debía poder gestionar anunciantes.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
    BEGIN
        PRINT 'SEGURIDAD CONFIRMADA (Éxito del Test): Permiso denegado a SP_ABM_Anunciante.';
    END
    ELSE
    BEGIN
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
    END;
END CATCH;
GO

-- Restaurar contexto
REVERT;
PRINT 'Contexto restaurado: ' + USER_NAME();
PRINT 'Test Rol_OperadorResultados FINALIZADO CON ÉXITO.';
GO
