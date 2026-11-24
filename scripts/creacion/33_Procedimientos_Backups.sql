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
Objetivo: Implementar los Stored Procedures para la Política de Respaldo y Recuperación
          correspondiente a la Entrega 8 en el esquema nucleo:
          1. nucleo.SP_CONFIGURAR_POLITICA_BACKUP: Asegura el modelo de recuperación FULL.
          2. nucleo.SP_BACKUP_COMPLETO: Ejecuta un backup completo (FULL) con compresión.
          3. nucleo.SP_BACKUP_DIFERENCIAL: Ejecuta un backup diferencial (DIFF).
          4. nucleo.SP_BACKUP_LOG: Ejecuta un backup del registro de transacciones (LOG)
             diseñado para cumplir con el RPO de 5 minutos en días de partido.
          5. nucleo.SP_CONSULTAR_HISTORIAL_BACKUPS: Consulta el historial de respaldos en msdb.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. SP_CONFIGURAR_POLITICA_BACKUP
-- Configura la base de datos en modo RECOVERY FULL para permitir
-- respaldos de log de transacciones y recuperación Point-In-Time.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_CONFIGURAR_POLITICA_BACKUP
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @recoveryModel NVARCHAR(60);
    SELECT @recoveryModel = recovery_model_desc
    FROM sys.databases
    WHERE name = 'MundialFutbol';

    IF @recoveryModel <> 'FULL'
    BEGIN
        ALTER DATABASE MundialFutbol SET RECOVERY FULL;
        PRINT 'Modelo de recuperación actualizado a FULL para MundialFutbol.';
    END
    ELSE
    BEGIN
        PRINT 'El modelo de recuperación ya se encuentra configurado en FULL.';
    END;
END;
GO

-- =========================================================================
-- 2. FUNCIÓN AUXILIAR: Obtener ruta predeterminada de backup
-- =========================================================================
CREATE OR ALTER FUNCTION nucleo.fn_ObtenerRutaBackupPredeterminada()
RETURNS NVARCHAR(500)
AS
BEGIN
    DECLARE @ruta NVARCHAR(500);
    SET @ruta = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(500));
    
    -- En SQL Server Express, InstanceDefaultBackupPath suele ser NULL por defecto.
    -- Se deduce dinámicamente la carpeta oficial de Backup de la instancia activa.
    IF @ruta IS NULL OR @ruta = ''
    BEGIN
        DECLARE @masterFile NVARCHAR(500);
        SELECT @masterFile = physical_name 
        FROM sys.master_files 
        WHERE database_id = 1 AND file_id = 1;

        IF CHARINDEX('\DATA\', UPPER(@masterFile)) > 0
        BEGIN
            DECLARE @posData INT = CHARINDEX('\DATA\', UPPER(@masterFile));
            SET @ruta = SUBSTRING(@masterFile, 1, @posData) + 'Backup\';
        END
        ELSE
        BEGIN
            SET @ruta = N'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\Backup\';
        END;
    END;

    IF RIGHT(@ruta, 1) <> '\'
        SET @ruta = @ruta + '\';

    RETURN @ruta;
END;
GO

-- =========================================================================
-- 3. SP_BACKUP_COMPLETO
-- Ejecuta una copia de seguridad completa (FULL).
-- Base semanal o diaria nocturna recomendada.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_BACKUP_COMPLETO
    @directorioSalida NVARCHAR(500) = NULL,
    @rutaGenerada     NVARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @directorioSalida IS NULL OR TRIM(@directorioSalida) = ''
            SET @directorioSalida = nucleo.fn_ObtenerRutaBackupPredeterminada();

        IF RIGHT(@directorioSalida, 1) <> '\'
            SET @directorioSalida = @directorioSalida + '\';

        DECLARE @timestamp VARCHAR(20) = REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(19), GETDATE(), 120), '-', ''), ' ', '_'), ':', '');
        DECLARE @nombreArchivo NVARCHAR(200) = N'MundialFutbol_FULL_' + @timestamp + N'.bak';
        SET @rutaGenerada = @directorioSalida + @nombreArchivo;

        DECLARE @opcionCompresion NVARCHAR(20) = N'';
        IF CAST(SERVERPROPERTY('EngineEdition') AS INT) <> 4
            SET @opcionCompresion = N', COMPRESSION';

        DECLARE @sql NVARCHAR(1000);
        SET @sql = N'BACKUP DATABASE MundialFutbol TO DISK = N''' + @rutaGenerada + N''' '
                 + N'WITH FORMAT, INIT, NAME = N''MundialFutbol-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD, STATS = 10'
                 + @opcionCompresion + N';';

        EXEC sys.sp_executesql @sql;

        PRINT 'Backup COMPLETO generado con éxito en: ' + @rutaGenerada;
    END TRY
    BEGIN CATCH
        DECLARE @errorMsg NVARCHAR(2048) = N'Error ejecutando Backup Completo: ' + ERROR_MESSAGE();
        THROW 54001, @errorMsg, 1;
    END CATCH;
END;
GO

-- =========================================================================
-- 4. SP_BACKUP_DIFERENCIAL
-- Ejecuta una copia de seguridad diferencial (DIFF).
-- Recomendado cada 12 horas o previo al inicio de la jornada de partidos.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_BACKUP_DIFERENCIAL
    @directorioSalida NVARCHAR(500) = NULL,
    @rutaGenerada     NVARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @directorioSalida IS NULL OR TRIM(@directorioSalida) = ''
            SET @directorioSalida = nucleo.fn_ObtenerRutaBackupPredeterminada();

        IF RIGHT(@directorioSalida, 1) <> '\'
            SET @directorioSalida = @directorioSalida + '\';

        DECLARE @timestamp VARCHAR(20) = REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(19), GETDATE(), 120), '-', ''), ' ', '_'), ':', '');
        DECLARE @nombreArchivo NVARCHAR(200) = N'MundialFutbol_DIFF_' + @timestamp + N'.bak';
        SET @rutaGenerada = @directorioSalida + @nombreArchivo;

        DECLARE @opcionCompresion NVARCHAR(20) = N'';
        IF CAST(SERVERPROPERTY('EngineEdition') AS INT) <> 4
            SET @opcionCompresion = N', COMPRESSION';

        DECLARE @sql NVARCHAR(1000);
        SET @sql = N'BACKUP DATABASE MundialFutbol TO DISK = N''' + @rutaGenerada + N''' '
                 + N'WITH DIFFERENTIAL, NOINIT, NAME = N''MundialFutbol-Differential Database Backup'', SKIP, NOREWIND, NOUNLOAD, STATS = 10'
                 + @opcionCompresion + N';';

        EXEC sys.sp_executesql @sql;

        PRINT 'Backup DIFERENCIAL generado con éxito en: ' + @rutaGenerada;
    END TRY
    BEGIN CATCH
        DECLARE @errorMsg NVARCHAR(2048) = N'Error ejecutando Backup Diferencial: ' + ERROR_MESSAGE();
        THROW 54002, @errorMsg, 1;
    END CATCH;
END;
GO

-- =========================================================================
-- 5. SP_BACKUP_LOG
-- Ejecuta una copia de seguridad del registro de transacciones (LOG).
-- Clave para cumplir el RPO en días de partido (frecuencia cada 5 minutos).
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_BACKUP_LOG
    @directorioSalida NVARCHAR(500) = NULL,
    @rutaGenerada     NVARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @directorioSalida IS NULL OR TRIM(@directorioSalida) = ''
            SET @directorioSalida = nucleo.fn_ObtenerRutaBackupPredeterminada();

        IF RIGHT(@directorioSalida, 1) <> '\'
            SET @directorioSalida = @directorioSalida + '\';

        DECLARE @timestamp VARCHAR(20) = REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(19), GETDATE(), 120), '-', ''), ' ', '_'), ':', '');
        DECLARE @nombreArchivo NVARCHAR(200) = N'MundialFutbol_LOG_' + @timestamp + N'.trn';
        SET @rutaGenerada = @directorioSalida + @nombreArchivo;

        DECLARE @opcionCompresion NVARCHAR(20) = N'';
        IF CAST(SERVERPROPERTY('EngineEdition') AS INT) <> 4
            SET @opcionCompresion = N', COMPRESSION';

        DECLARE @sql NVARCHAR(1000);
        SET @sql = N'BACKUP LOG MundialFutbol TO DISK = N''' + @rutaGenerada + N''' '
                 + N'WITH NOINIT, NAME = N''MundialFutbol-Transaction Log Backup'', SKIP, NOREWIND, NOUNLOAD, STATS = 10'
                 + @opcionCompresion + N';';

        EXEC sys.sp_executesql @sql;

        PRINT 'Backup de TRANSACTION LOG generado con éxito en: ' + @rutaGenerada;
    END TRY
    BEGIN CATCH
        DECLARE @errorMsg NVARCHAR(2048) = N'Error ejecutando Backup de Log: ' + ERROR_MESSAGE();
        THROW 54003, @errorMsg, 1;
    END CATCH;
END;
GO

-- =========================================================================
-- 6. SP_CONSULTAR_HISTORIAL_BACKUPS
-- Permite verificar el registro histórico de respaldos realizados en msdb.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_CONSULTAR_HISTORIAL_BACKUPS
    @ultimosRegistros INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@ultimosRegistros)
        bs.database_name                                            AS BaseDeDatos,
        CASE bs.type
            WHEN 'D' THEN 'Completo (Full)'
            WHEN 'I' THEN 'Diferencial (Diff)'
            WHEN 'L' THEN 'Log de Transacciones (Log)'
            ELSE bs.type
        END                                                         AS TipoBackup,
        bs.backup_start_date                                        AS FechaInicio,
        bs.backup_finish_date                                       AS FechaFin,
        DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) AS DuracionSegundos,
        CAST(bs.backup_size / (1024.0 * 1024.0) AS DECIMAL(10,2))   AS TamanoOriginalMB,
        CAST(bs.compressed_backup_size / (1024.0 * 1024.0) AS DECIMAL(10,2)) AS TamanoComprimidoMB,
        bmf.physical_device_name                                    AS RutaArchivo
    FROM msdb.dbo.backupset bs
    INNER JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = 'MundialFutbol'
    ORDER BY bs.backup_finish_date DESC;
END;
GO

-- Configurar modo FULL al compilar el script
EXEC nucleo.SP_CONFIGURAR_POLITICA_BACKUP;
GO

PRINT 'Script 33_Procedimientos_Backups ejecutado correctamente.';
GO
