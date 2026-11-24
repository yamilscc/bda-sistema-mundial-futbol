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
Objetivo: Probar los SP de respaldo (scripts/creacion/33_Procedimientos_Backups.sql):
            1. Modelo de recuperación FULL.
            2. Validaciones agrupadas (tipo inválido, LOG sin FULL previo, directorio inválido, historial fuera de rango).
            3. Backups FULL, DIFF y LOG: archivo con nombre fechado y registro en msdb.
            4. Historial de respaldos.
          Genera archivos de backup reales en la carpeta de backup de la instancia (no se puede hacer dentro de una
          transacción). Requiere ejecutados los scripts 01 a 33.
*/

USE MundialFutbol;
GO

SET NOCOUNT ON;

DECLARE @ruta NVARCHAR(500), @antes INT, @mensaje NVARCHAR(2048), @lineas INT,
        @creada DATETIME = (SELECT create_date FROM sys.databases WHERE name = 'MundialFutbol');
DECLARE @historial TABLE (BaseDeDatos NVARCHAR(128), TipoBackup NVARCHAR(40), FechaInicio DATETIME, FechaFin DATETIME,
                          DuracionSegundos INT, TamanoOriginalMB DECIMAL(10,2), TamanoComprimidoMB DECIMAL(10,2),
                          RutaArchivo NVARCHAR(260));

-- =========================================================================
-- TEST 1: modelo de recuperación
-- =========================================================================
PRINT '--- TEST 1: SP_CONFIGURAR_POLITICA_BACKUP ---';
-- 1.A Resultado esperado: la base queda (o ya estaba) en modelo FULL.
EXEC nucleo.SP_CONFIGURAR_POLITICA_BACKUP;
IF (SELECT recovery_model_desc FROM sys.databases WHERE name = 'MundialFutbol') = 'FULL'
    PRINT '1.A: OK - modelo de recuperación FULL.';
ELSE PRINT '1.A: FALLÓ - la base no quedó en modelo FULL.';

-- =========================================================================
-- TEST 2: validaciones
-- =========================================================================
PRINT '--- TEST 2: validaciones ---';
-- 2.A Tipo inválido y directorio con caracteres no permitidos. Resultado esperado: error 52000 con 2 renglones.
BEGIN TRY
    EXEC nucleo.SP_EJECUTAR_BACKUP @tipo = 'XXX', @directorioSalida = N'/tmp/no*valido';
    PRINT '2.A: FALLÓ - aceptó un tipo y un directorio inválidos.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 2 PRINT '2.A: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '2.A: FALLÓ - ' + @mensaje;
END CATCH;

-- 2.B LOG sin un FULL previo desde que se creó la base. Resultado esperado: error 52000 "No hay un backup completo".
-- Si ya hay un FULL (el test se corre por segunda vez sin recrear la base), el caso se omite.
IF EXISTS (SELECT 1 FROM msdb.dbo.backupset WHERE database_name = 'MundialFutbol' AND type = 'D' AND backup_start_date >= @creada)
    PRINT '2.B: OMITIDO - ya existe un backup FULL de esta base.';
ELSE
BEGIN TRY
    EXEC nucleo.SP_BACKUP_LOG;
    PRINT '2.B: FALLÓ - permitió un backup de log sin FULL previo.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 52000 AND ERROR_MESSAGE() LIKE '%No hay un backup completo%'
        PRINT '2.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '2.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.C Historial fuera de rango. Resultado esperado: error 52000.
BEGIN TRY
    EXEC nucleo.SP_CONSULTAR_HISTORIAL_BACKUPS @ultimosRegistros = 0;
    PRINT '2.C: FALLÓ - aceptó 0 registros.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 52000 PRINT '2.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '2.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: backups FULL, DIFF y LOG
-- =========================================================================
PRINT '--- TEST 3: backups ---';
-- 3.A/B/C Resultado esperado: cada SP devuelve la ruta MundialFutbol_<TIPO>_aaaammdd_hhmmss.(bak|trn) y agrega una
-- fila del tipo correspondiente ('D', 'I', 'L') en msdb.dbo.backupset.
SELECT @antes = COUNT(*) FROM msdb.dbo.backupset WHERE database_name = 'MundialFutbol' AND type = 'D';
BEGIN TRY
    EXEC nucleo.SP_BACKUP_COMPLETO @rutaGenerada = @ruta OUTPUT;
    IF @ruta LIKE '%MundialFutbol_FULL_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9].bak'
       AND (SELECT COUNT(*) FROM msdb.dbo.backupset WHERE database_name = 'MundialFutbol' AND type = 'D') = @antes + 1
        PRINT '3.A: OK - backup FULL en ' + @ruta;
    ELSE PRINT '3.A: FALLÓ - el backup FULL no generó la ruta o el registro esperado.';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

SELECT @antes = COUNT(*) FROM msdb.dbo.backupset WHERE database_name = 'MundialFutbol' AND type = 'I';
BEGIN TRY
    EXEC nucleo.SP_BACKUP_DIFERENCIAL @rutaGenerada = @ruta OUTPUT;
    IF @ruta LIKE '%MundialFutbol_DIFF_%.bak'
       AND (SELECT COUNT(*) FROM msdb.dbo.backupset WHERE database_name = 'MundialFutbol' AND type = 'I') = @antes + 1
        PRINT '3.B: OK - backup DIFF en ' + @ruta;
    ELSE PRINT '3.B: FALLÓ - el backup DIFF no generó la ruta o el registro esperado.';
END TRY
BEGIN CATCH
    PRINT '3.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

SELECT @antes = COUNT(*) FROM msdb.dbo.backupset WHERE database_name = 'MundialFutbol' AND type = 'L';
BEGIN TRY
    EXEC nucleo.SP_BACKUP_LOG @rutaGenerada = @ruta OUTPUT;
    IF @ruta LIKE '%MundialFutbol_LOG_%.trn'
       AND (SELECT COUNT(*) FROM msdb.dbo.backupset WHERE database_name = 'MundialFutbol' AND type = 'L') = @antes + 1
        PRINT '3.C: OK - backup LOG en ' + @ruta;
    ELSE PRINT '3.C: FALLÓ - el backup LOG no generó la ruta o el registro esperado.';
END TRY
BEGIN CATCH
    PRINT '3.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: historial
-- =========================================================================
PRINT '--- TEST 4: SP_CONSULTAR_HISTORIAL_BACKUPS ---';
-- 4.A Resultado esperado: los 3 registros más recientes son el LOG, el DIFF y el FULL recién generados.
INSERT INTO @historial EXEC nucleo.SP_CONSULTAR_HISTORIAL_BACKUPS @ultimosRegistros = 3;
IF (SELECT COUNT(*) FROM @historial) = 3
   AND EXISTS (SELECT 1 FROM @historial WHERE TipoBackup LIKE 'Completo%')
   AND EXISTS (SELECT 1 FROM @historial WHERE TipoBackup LIKE 'Diferencial%')
   AND EXISTS (SELECT 1 FROM @historial WHERE TipoBackup LIKE 'Log%')
    PRINT '4.A: OK - el historial muestra el FULL, el DIFF y el LOG.';
ELSE PRINT '4.A: FALLÓ - el historial no muestra los tres backups recientes.';
GO
