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
Objetivo: Validar los permisos del usuario [usr_consulta_test] perteneciente al rol [Rol_Consulta]:
          1. Casos Exitosos: Ejecución de reportes oficiales (Entrega 7) y consultas de lectura.
          2. Casos Denegados: Intentar realizar operaciones de modificación (INSERT directo)
             o ejecutar Stored Procedures de ABM / transaccionales (captura de Error 229).
*/

USE MundialFutbol;
GO

PRINT '=========================================================================';
PRINT 'TEST DE PERMISOS: Usuario [usr_consulta_test] (Rol_Consulta)';
PRINT '=========================================================================';
GO

EXECUTE AS USER = 'usr_consulta_test';
PRINT 'Contexto actual: ' + USER_NAME();
GO

-- 1. CASO EXITOSO: Ejecución autorizada de reportes
-- Resultado esperado: Ejecución de los SP de reportes sin impedimento.
EXEC eventos.SP_REPORTE_GOLEADORES;
EXEC publicidad.SP_REPORTE_MATRIZ_PRIME_TIME;
GO

-- 2. CASO DENEGADO CONTROLADO: Intentar realizar un INSERT directo en tablas
-- Resultado esperado: Error 229 capturado (The INSERT permission was denied).
BEGIN TRY
    PRINT 'Intentando insertar directamente en nucleo.Pais...';
    INSERT INTO nucleo.Pais (Nombre, CodigoISO3, IdConfederacion)
    VALUES ('PaisInfiltrado', 'XXX', 1);
    PRINT 'FALLÓ LA SEGURIDAD: El usuario de consulta no debe poder insertar datos.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
    BEGIN
        PRINT 'SEGURIDAD CONFIRMADA (Éxito del Test): INSERT denegado correctamente.';
        PRINT 'Error capturado: [' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + N'] ' + ERROR_MESSAGE();
    END
    ELSE
    BEGIN
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
    END;
END CATCH;
GO

-- 3. CASO DENEGADO CONTROLADO: Intentar ejecutar SP transaccional de registro
BEGIN TRY
    PRINT 'Intentando ejecutar eventos.SP_REGISTRAR_AMONESTACION...';
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = 1, @idJugador = 1, @minuto = 10, @idTipoTarjeta = 1;
    PRINT 'FALLÓ LA SEGURIDAD: El usuario de consulta no debe poder registrar amonestaciones.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
    BEGIN
        PRINT 'SEGURIDAD CONFIRMADA (Éxito del Test): Permiso denegado a SP_REGISTRAR_AMONESTACION.';
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
PRINT 'Test Rol_Consulta FINALIZADO CON ÉXITO.';
GO
