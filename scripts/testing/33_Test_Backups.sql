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
Objetivo: Validar la ejecución de los procedimientos de la Política de Respaldo (Entrega 8):
          1. Verificación de configuración en modo RECOVERY FULL.
          2. Generación exitosa de Backup Completo (FULL).
          3. Generación exitosa de Backup Diferencial (DIFF).
          4. Generación exitosa de Backup de Registro de Transacciones (LOG).
          5. Consulta y evidencia del historial de backups en msdb.
*/

USE MundialFutbol;
GO

PRINT '=========================================================================';
PRINT 'TEST 1: Verificación y aseguramiento del modo RECOVERY FULL';
PRINT '=========================================================================';
EXEC nucleo.SP_CONFIGURAR_POLITICA_BACKUP;

SELECT name AS BaseDeDatos, recovery_model_desc AS ModoRecuperacion
FROM sys.databases
WHERE name = 'MundialFutbol';
GO

PRINT '=========================================================================';
PRINT 'TEST 2: Ejecución de Backup Completo (FULL)';
PRINT '=========================================================================';
-- Resultado esperado:
-- Retorna la ruta física generada del archivo .bak y emite mensaje de confirmación.
DECLARE @rutaFull NVARCHAR(500);
EXEC nucleo.SP_BACKUP_COMPLETO @rutaGenerada = @rutaFull OUTPUT;
SELECT @rutaFull AS RutaArchivoBackupFullGenerado;
GO

PRINT '=========================================================================';
PRINT 'TEST 3: Ejecución de Backup Diferencial (DIFF)';
PRINT '=========================================================================';
-- Resultado esperado:
-- Genera el archivo .bak diferencial conteniendo solo los cambios desde el último Full.
DECLARE @rutaDiff NVARCHAR(500);
EXEC nucleo.SP_BACKUP_DIFERENCIAL @rutaGenerada = @rutaDiff OUTPUT;
SELECT @rutaDiff AS RutaArchivoBackupDiffGenerado;
GO

PRINT '=========================================================================';
PRINT 'TEST 4: Ejecución de Backup de Log de Transacciones (LOG)';
PRINT '=========================================================================';
-- Resultado esperado:
-- Genera el archivo .trn del registro de transacciones que garantiza el RPO de 5 minutos.
DECLARE @rutaLog NVARCHAR(500);
EXEC nucleo.SP_BACKUP_LOG @rutaGenerada = @rutaLog OUTPUT;
SELECT @rutaLog AS RutaArchivoBackupLogGenerado;
GO

PRINT '=========================================================================';
PRINT 'TEST 5: Consulta de Historial de Backups en msdb';
PRINT '=========================================================================';
-- Resultado esperado:
-- Muestra el registro tabular de los respaldos FULL, DIFF y LOG generados con sus
-- tamaños originales y comprimidos, tiempos y rutas físicas.
EXEC nucleo.SP_CONSULTAR_HISTORIAL_BACKUPS @ultimosRegistros = 5;
GO

PRINT 'Test de Procedimientos de Backup FINALIZADO CON ÉXITO.';
GO
