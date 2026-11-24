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
Objetivo: Validar los permisos del usuario [usr_publicidad_test] perteneciente al rol [Rol_GestorPublicidad]:
          1. Casos Exitosos: Gestión y consulta del módulo de publicidad y pautas comerciales.
          2. Casos Denegados: Intentar registrar eventos deportivos (goles, tarjetas)
             o modificar planteles de jugadores (captura de Error 229).
*/

USE MundialFutbol;
GO

PRINT '=========================================================================';
PRINT 'TEST DE PERMISOS: Usuario [usr_publicidad_test] (Rol_GestorPublicidad)';
PRINT '=========================================================================';
GO

EXECUTE AS USER = 'usr_publicidad_test';
PRINT 'Contexto actual: ' + USER_NAME();
GO

-- 1. CASO EXITOSO: Consulta de partidos y sedes autorizada para análisis de pauta
-- Resultado esperado: Retorna sedes y partidos sin error.
SELECT TOP 3 IdSede, NombreEstadio, Capacidad FROM nucleo.Sede;
SELECT TOP 3 IdPartido, FechaHoraUTC FROM nucleo.Partido;
GO

-- 2. CASO EXITOSO: Ejecución de reporte de ocupación publicitaria
-- Resultado esperado: Ejecución satisfactoria.
EXEC publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA;
GO

-- 3. CASO DENEGADO CONTROLADO: Intentar registrar un gol deportivo
-- Resultado esperado: Error 229 capturado en CATCH.
BEGIN TRY
    PRINT 'Intentando ejecutar eventos.SP_REGISTRAR_GOL...';
    EXEC eventos.SP_REGISTRAR_GOL
        @idPartido       = 1,
        @idJugadorAutor  = 10,
        @minuto          = 45,
        @idTipoGol       = 1,
        @idPeriodo       = 1;
    PRINT 'FALLÓ LA SEGURIDAD: El gestor publicitario no debía poder registrar goles.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
    BEGIN
        PRINT 'SEGURIDAD CONFIRMADA (Éxito del Test): Permiso denegado a SP_REGISTRAR_GOL.';
        PRINT 'Error capturado: [' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + N'] ' + ERROR_MESSAGE();
    END
    ELSE
    BEGIN
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
    END;
END CATCH;
GO

-- 4. CASO DENEGADO CONTROLADO: Intentar modificar jugadores
BEGIN TRY
    PRINT 'Intentando ejecutar jugadores.SP_ABM_Jugador...';
    EXEC jugadores.SP_ABM_Jugador @operacion = 'ALTA', @nombre = 'Infiltrado';
    PRINT 'FALLÓ LA SEGURIDAD: El gestor publicitario no debía tener acceso al ABM de jugadores.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
    BEGIN
        PRINT 'SEGURIDAD CONFIRMADA (Éxito del Test): Permiso denegado a SP_ABM_Jugador.';
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
PRINT 'Test Rol_GestorPublicidad FINALIZADO CON ÉXITO.';
GO
