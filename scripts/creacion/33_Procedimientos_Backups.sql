/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner (versión original); sin SQL dinámico y con validaciones por Torczuk, Elías Alexei
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Stored Procedures de la política de respaldo (Entrega 8; la política y el RPO están en
          doc/entrega8/entrega8_seguridad_y_respaldo.md):
          1. nucleo.SP_CONFIGURAR_POLITICA_BACKUP: deja la base en modelo de recuperación FULL.
          2. nucleo.fn_ObtenerRutaBackupPredeterminada: carpeta de backup de la instancia (Windows o Linux).
          3. nucleo.SP_BACKUP_COMPLETO, nucleo.SP_BACKUP_DIFERENCIAL y nucleo.SP_BACKUP_LOG: backups FULL, DIFF y LOG
             con nombre fechado (comparten nucleo.SP_EJECUTAR_BACKUP).
          4. nucleo.SP_CONSULTAR_HISTORIAL_BACKUPS: historial de respaldos en msdb.
          Sin SQL dinámico: BACKUP DATABASE / BACKUP LOG aceptan la ruta como variable; la compresión (no disponible
          en Express) se resuelve con dos sentencias estáticas.
          Validaciones agrupadas (THROW 52000): el DIFF y el LOG necesitan un FULL previo, y el LOG el modelo FULL.
          Requiere ejecutados los scripts 01 a 32 (al final vuelve a aplicar los permisos de 32 sobre estos SP).
          Test correspondiente: testing/33_Test_Backups.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. SP_CONFIGURAR_POLITICA_BACKUP
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_CONFIGURAR_POLITICA_BACKUP
AS
BEGIN
    SET NOCOUNT ON;

    IF (SELECT recovery_model_desc FROM sys.databases WHERE name = 'MundialFutbol') <> 'FULL'
    BEGIN
        ALTER DATABASE MundialFutbol SET RECOVERY FULL;
        PRINT 'Modelo de recuperación actualizado a FULL para MundialFutbol.';
    END
    ELSE
        PRINT 'El modelo de recuperación ya se encuentra configurado en FULL.';
END;
GO

-- =========================================================================
-- 2. fn_ObtenerRutaBackupPredeterminada
-- Carpeta de backup de la instancia, terminada en el separador de la plataforma ('\' en Windows, '/' en Linux).
-- Si la instancia no la informa (Express), se deduce de la carpeta del archivo de datos de master.
-- =========================================================================
CREATE OR ALTER FUNCTION nucleo.fn_ObtenerRutaBackupPredeterminada()
RETURNS NVARCHAR(500)
AS
BEGIN
    DECLARE @ruta NVARCHAR(500) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(500)),
            @master NVARCHAR(500),
            @separador NCHAR(1);

    IF @ruta IS NULL OR @ruta = N''
    BEGIN
        SELECT @master = physical_name FROM sys.master_files WHERE database_id = 1 AND file_id = 1;
        IF CHARINDEX(N'\DATA\', UPPER(@master)) > 0
            SET @ruta = LEFT(@master, CHARINDEX(N'\DATA\', UPPER(@master))) + N'Backup\';
        ELSE
            SET @ruta = LEFT(@master, LEN(@master) - CHARINDEX(N'/', REVERSE(@master)) + 1);
    END;

    SET @separador = CASE WHEN CHARINDEX(N'/', @ruta) > 0 THEN N'/' ELSE N'\' END;
    IF RIGHT(@ruta, 1) NOT IN (N'\', N'/')
        SET @ruta += @separador;

    RETURN @ruta;
END;
GO

-- =========================================================================
-- 3. SP_EJECUTAR_BACKUP (compartido) y los tres SP públicos
-- @tipo: 'FULL', 'DIFF' o 'LOG'. @directorioSalida NULL = carpeta de la instancia.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_EJECUTAR_BACKUP
    @tipo             VARCHAR(4),
    @directorioSalida NVARCHAR(500) = NULL,
    @rutaGenerada     NVARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores   NVARCHAR(MAX) = N'',
            @mensaje   NVARCHAR(2048),
            @salto     NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @separador NCHAR(1),
            @marca     VARCHAR(15)   = FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss'),
            @comprimir BIT           = CASE WHEN CAST(SERVERPROPERTY('EngineEdition') AS INT) = 4 THEN 0 ELSE 1 END,
            @nombre    NVARCHAR(128);

    SET @tipo = UPPER(LTRIM(RTRIM(@tipo)));
    SET @directorioSalida = NULLIF(LTRIM(RTRIM(@directorioSalida)), N'');

    IF @tipo IS NULL OR @tipo NOT IN ('FULL', 'DIFF', 'LOG')
        SET @errores += N'- El tipo de backup debe ser FULL, DIFF o LOG.' + @salto;
    IF @tipo IN ('DIFF', 'LOG')
       AND NOT EXISTS (SELECT 1 FROM msdb.dbo.backupset WHERE database_name = 'MundialFutbol' AND type = 'D'
                       AND backup_start_date >= (SELECT create_date FROM sys.databases WHERE name = 'MundialFutbol'))
        SET @errores += N'- No hay un backup completo (FULL) previo de la base: el diferencial y el de log parten de él.' + @salto;
    IF @tipo = 'LOG' AND (SELECT recovery_model_desc FROM sys.databases WHERE name = 'MundialFutbol') <> 'FULL'
        SET @errores += N'- El backup de log requiere el modelo de recuperación FULL (nucleo.SP_CONFIGURAR_POLITICA_BACKUP).' + @salto;
    IF @directorioSalida IS NOT NULL AND (LEN(@directorioSalida) > 400 OR @directorioSalida LIKE N'%[*?"<>|]%')
        SET @errores += N'- El directorio de salida no es válido (más de 400 caracteres o caracteres no permitidos).' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_EJECUTAR_BACKUP - No se pudo generar el backup:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    SET @directorioSalida = ISNULL(@directorioSalida, nucleo.fn_ObtenerRutaBackupPredeterminada());
    SET @separador = CASE WHEN CHARINDEX(N'/', @directorioSalida) > 0 THEN N'/' ELSE N'\' END;
    IF RIGHT(@directorioSalida, 1) NOT IN (N'\', N'/')
        SET @directorioSalida += @separador;

    SET @rutaGenerada = @directorioSalida + N'MundialFutbol_' + @tipo + N'_' + @marca
                        + CASE WHEN @tipo = 'LOG' THEN N'.trn' ELSE N'.bak' END;
    SET @nombre = N'MundialFutbol - backup ' + @tipo + N' ' + @marca;

    IF @tipo = 'FULL' AND @comprimir = 1
        BACKUP DATABASE MundialFutbol TO DISK = @rutaGenerada WITH INIT, NAME = @nombre, COMPRESSION, CHECKSUM;
    ELSE IF @tipo = 'FULL'
        BACKUP DATABASE MundialFutbol TO DISK = @rutaGenerada WITH INIT, NAME = @nombre, CHECKSUM;
    ELSE IF @tipo = 'DIFF' AND @comprimir = 1
        BACKUP DATABASE MundialFutbol TO DISK = @rutaGenerada WITH DIFFERENTIAL, INIT, NAME = @nombre, COMPRESSION, CHECKSUM;
    ELSE IF @tipo = 'DIFF'
        BACKUP DATABASE MundialFutbol TO DISK = @rutaGenerada WITH DIFFERENTIAL, INIT, NAME = @nombre, CHECKSUM;
    ELSE IF @comprimir = 1
        BACKUP LOG MundialFutbol TO DISK = @rutaGenerada WITH INIT, NAME = @nombre, COMPRESSION, CHECKSUM;
    ELSE
        BACKUP LOG MundialFutbol TO DISK = @rutaGenerada WITH INIT, NAME = @nombre, CHECKSUM;

    PRINT 'Backup ' + @tipo + ' generado en: ' + @rutaGenerada;
END;
GO

-- FULL: semanal y diario nocturno fuera de la franja de partidos (ver la política).
CREATE OR ALTER PROCEDURE nucleo.SP_BACKUP_COMPLETO
    @directorioSalida NVARCHAR(500) = NULL,
    @rutaGenerada     NVARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC nucleo.SP_EJECUTAR_BACKUP @tipo = 'FULL', @directorioSalida = @directorioSalida, @rutaGenerada = @rutaGenerada OUTPUT;
END;
GO

-- DIFF: antes de la primera tanda de partidos del día y al terminar la jornada.
CREATE OR ALTER PROCEDURE nucleo.SP_BACKUP_DIFERENCIAL
    @directorioSalida NVARCHAR(500) = NULL,
    @rutaGenerada     NVARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC nucleo.SP_EJECUTAR_BACKUP @tipo = 'DIFF', @directorioSalida = @directorioSalida, @rutaGenerada = @rutaGenerada OUTPUT;
END;
GO

-- LOG: cada 5 minutos en días de partido (RPO de 5 minutos) y cada 30 minutos el resto.
CREATE OR ALTER PROCEDURE nucleo.SP_BACKUP_LOG
    @directorioSalida NVARCHAR(500) = NULL,
    @rutaGenerada     NVARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC nucleo.SP_EJECUTAR_BACKUP @tipo = 'LOG', @directorioSalida = @directorioSalida, @rutaGenerada = @rutaGenerada OUTPUT;
END;
GO

-- =========================================================================
-- 4. SP_CONSULTAR_HISTORIAL_BACKUPS
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_CONSULTAR_HISTORIAL_BACKUPS
    @ultimosRegistros INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @ultimosRegistros IS NULL OR @ultimosRegistros NOT BETWEEN 1 AND 1000
        THROW 52000, N'SP_CONSULTAR_HISTORIAL_BACKUPS - No se pudo completar la consulta:
- La cantidad de registros debe estar entre 1 y 1000.', 1;

    SELECT TOP (@ultimosRegistros)
        bs.database_name                                                      AS BaseDeDatos,
        CASE bs.type WHEN 'D' THEN 'Completo (Full)' WHEN 'I' THEN 'Diferencial (Diff)'
                     WHEN 'L' THEN 'Log de Transacciones (Log)' ELSE bs.type END AS TipoBackup,
        bs.backup_start_date                                                  AS FechaInicio,
        bs.backup_finish_date                                                 AS FechaFin,
        DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date)         AS DuracionSegundos,
        CAST(bs.backup_size / (1024.0 * 1024.0) AS DECIMAL(10,2))             AS TamanoOriginalMB,
        CAST(bs.compressed_backup_size / (1024.0 * 1024.0) AS DECIMAL(10,2))  AS TamanoComprimidoMB,
        bmf.physical_device_name                                              AS RutaArchivo
    FROM msdb.dbo.backupset AS bs
    INNER JOIN msdb.dbo.backupmediafamily AS bmf ON bmf.media_set_id = bs.media_set_id
    WHERE bs.database_name = 'MundialFutbol'
    ORDER BY bs.backup_finish_date DESC;
END;
GO

-- Modelo FULL desde la creación y permisos de 32 aplicados también a estos SP.
EXEC nucleo.SP_CONFIGURAR_POLITICA_BACKUP;
EXEC nucleo.SP_CREAR_ROLES_SISTEMA;
GO

PRINT 'Script 33_Procedimientos_Backups ejecutado correctamente.';
GO
