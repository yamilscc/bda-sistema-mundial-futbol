/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner (versión original); rehecho sobre claves de SQL Server por Torczuk, Elías Alexei
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Script de MODIFICACIÓN que cifra los datos personales sensibles (Entrega 8):
            - jugadores.Jugador.Documento
            - nucleo.Arbitro.NombreApellido
            - nucleo.StaffTecnico.NombreApellido
          sobre los componentes ya creados por los scripts 01 a 30:
          1. Tablas (ALTER TABLE): columnas cifradas (VARBINARY) y de hash para búsquedas; se reemplaza la
             restricción única del documento en texto plano por una única sobre el hash.
          2. Infraestructura de claves con SP (nucleo.SP_CONFIGURAR_CIFRADO): master key de la base,
             certificado y clave simétrica AES_256. Ninguna clave ni contraseña queda escrita en el código.
          3. Funciones y SP de cifrado (nucleo.SP_CIFRAR_DATO, nucleo.fn_DescifrarTexto, nucleo.fn_HashDato).
          4. Consultas: redefine las funciones de búsqueda y de nombre visible creadas en 07 y 14
             (fn_IdJugadorPorDocumento, fn_IdArbitroPorNombre, fn_IdStaffPorNombre, fn_NombreArbitro y
             fn_NombreStaff), que usan las importaciones, los seeds y los reportes.
          5. SP: redefine fn_ValidarJugador y los SP_ALTA_ / SP_MODIFICACION_ de Jugador, Arbitro y StaffTecnico
             para guardar el dato cifrado, su hash y una máscara en la columna pública.
          6. Migración con SP (nucleo.SP_APLICAR_CIFRADO_DATOS_SENSIBLES) de las filas que estén en texto plano.
          7. SP de consulta descifrada para usuarios autorizados.
          Requiere ejecutados los scripts 01 a 30.
          Test correspondiente: testing/31_Test_Seguridad_Cifrado.sql.

DISEÑO:
  - Cifrado: ENCRYPTBYKEY con la clave simétrica ClaveDatosSensibles (AES_256), protegida por el certificado
    CertDatosSensibles, que a su vez protege la master key de la base (y esta, la service master key de la
    instancia). La contraseña de la master key se genera al azar y no se guarda: por eso el respaldo de la
    master key y del certificado forma parte de la política de backup (doc/entrega8).
  - Descifrado: nucleo.fn_DescifrarTexto (DECRYPTBYKEYAUTOCERT) con EXECUTE AS OWNER. No se otorga permiso
    sobre la función a ningún rol: solo descifran los SP y reportes que la usan (cadena de propiedad).
  - Búsquedas: la columna cifrada no se puede comparar (cada cifrado da bytes distintos), así que se guarda
    además un hash SHA2_256 con un secreto aleatorio (nucleo.ConfiguracionCifrado), en mayúsculas y sin
    espacios de los extremos (igual que las comparaciones por collation del resto del modelo).
  - Columna pública: queda enmascarada ('***-' + últimos 4 caracteres del documento; '***-CONFIDENCIAL-<id>***'
    para los nombres). Las filas que se cargan directo en texto plano (por ejemplo en tests de entregas
    anteriores) siguen encontrándose: las funciones de búsqueda prueban primero el hash y después la columna
    pública si la fila no tiene hash.

NOTA (Consigna Entrega 8): "una vez aplicado el cifrado el testing aplicado en entregas previas puede que ya
no sea exitoso". Los tests que dan de alta con los SP y después buscan con SELECT ... WHERE Documento = '...'
o WHERE NombreApellido = '...' dejan de encontrar la fila. La lista está en doc/entrega8.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. TABLAS (script de modificación)
-- =========================================================================

-- Secreto del hash de búsqueda. Una sola fila; la carga nucleo.SP_CONFIGURAR_CIFRADO con un valor aleatorio.
IF OBJECT_ID('nucleo.ConfiguracionCifrado', 'U') IS NULL
CREATE TABLE nucleo.ConfiguracionCifrado (
    IdConfiguracion TINYINT       NOT NULL CONSTRAINT PK_ConfiguracionCifrado PRIMARY KEY
                                  CONSTRAINT CK_ConfiguracionCifrado_UnaFila CHECK (IdConfiguracion = 1),
    SecretoHash     VARBINARY(32) NOT NULL,
    FechaAlta       DATETIME2(0)  NOT NULL CONSTRAINT DF_ConfiguracionCifrado_FechaAlta DEFAULT (SYSDATETIME())
);
GO

IF COL_LENGTH('jugadores.Jugador', 'DocumentoCifrado') IS NULL
    ALTER TABLE jugadores.Jugador ADD DocumentoCifrado VARBINARY(256) NULL, DocumentoHash VARBINARY(32) NULL;
GO
-- El documento público pasa a ser una máscara (no única): la unicidad se controla sobre el hash.
IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_Jugador_Documento')
    ALTER TABLE jugadores.Jugador DROP CONSTRAINT UQ_Jugador_Documento;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Jugador_DocumentoHash')
    CREATE UNIQUE INDEX IX_Jugador_DocumentoHash ON jugadores.Jugador (DocumentoHash) WHERE DocumentoHash IS NOT NULL;
GO

IF COL_LENGTH('nucleo.Arbitro', 'NombreApellidoCifrado') IS NULL
    ALTER TABLE nucleo.Arbitro ADD NombreApellidoCifrado VARBINARY(512) NULL, NombreApellidoHash VARBINARY(32) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Arbitro_NombreApellidoHash')
    CREATE INDEX IX_Arbitro_NombreApellidoHash ON nucleo.Arbitro (NombreApellidoHash);
GO

IF COL_LENGTH('nucleo.StaffTecnico', 'NombreApellidoCifrado') IS NULL
    ALTER TABLE nucleo.StaffTecnico ADD NombreApellidoCifrado VARBINARY(512) NULL, NombreApellidoHash VARBINARY(32) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StaffTecnico_NombreApellidoHash')
    CREATE INDEX IX_StaffTecnico_NombreApellidoHash ON nucleo.StaffTecnico (NombreApellidoHash);
GO

-- =========================================================================
-- 2. INFRAESTRUCTURA DE CLAVES
-- nucleo.SP_CONFIGURAR_CIFRADO: crea (si faltan) la master key, el certificado, la clave simétrica y el
-- secreto del hash. Idempotente.
-- Único SQL dinámico del script, estrictamente necesario: CREATE MASTER KEY no acepta una variable como
-- contraseña, y la contraseña debe generarse al azar para no quedar escrita en un repositorio público.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_CONFIGURAR_CIFRADO
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @clave NVARCHAR(128), @sql NVARCHAR(400);

    IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    BEGIN
        SET @clave = CONVERT(NVARCHAR(128), CRYPT_GEN_RANDOM(32), 2) + N'aA1!';
        SET @sql   = N'CREATE MASTER KEY ENCRYPTION BY PASSWORD = ' + QUOTENAME(@clave, '''') + N';';
        EXEC sys.sp_executesql @sql;
        PRINT 'Master key de la base creada (contraseña aleatoria, protegida por la service master key).';
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'CertDatosSensibles')
    BEGIN
        CREATE CERTIFICATE CertDatosSensibles
            WITH SUBJECT = 'MundialFutbol - datos personales sensibles', EXPIRY_DATE = '2036-12-31';
        PRINT 'Certificado creado: CertDatosSensibles';
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'ClaveDatosSensibles')
    BEGIN
        CREATE SYMMETRIC KEY ClaveDatosSensibles
            WITH ALGORITHM = AES_256
            ENCRYPTION BY CERTIFICATE CertDatosSensibles;
        PRINT 'Clave simétrica creada: ClaveDatosSensibles (AES_256)';
    END;

    IF NOT EXISTS (SELECT 1 FROM nucleo.ConfiguracionCifrado WHERE IdConfiguracion = 1)
        INSERT INTO nucleo.ConfiguracionCifrado (IdConfiguracion, SecretoHash) VALUES (1, CRYPT_GEN_RANDOM(32));
END;
GO

EXEC nucleo.SP_CONFIGURAR_CIFRADO;
GO

-- =========================================================================
-- 3. FUNCIONES Y SP DE CIFRADO
-- =========================================================================

-- Hash de búsqueda (no reversible) de un dato sensible.
CREATE OR ALTER FUNCTION nucleo.fn_HashDato (@texto NVARCHAR(400))
RETURNS VARBINARY(32)
WITH EXECUTE AS OWNER
AS
BEGIN
    IF @texto IS NULL
        RETURN NULL;
    RETURN (SELECT HASHBYTES('SHA2_256', SecretoHash + CONVERT(VARBINARY(800), UPPER(LTRIM(RTRIM(@texto)))))
            FROM nucleo.ConfiguracionCifrado
            WHERE IdConfiguracion = 1);
END;
GO

-- Descifrado. Se ejecuta como el dueño (dbo), que tiene acceso al certificado.
CREATE OR ALTER FUNCTION nucleo.fn_DescifrarTexto (@cifrado VARBINARY(512))
RETURNS NVARCHAR(200)
WITH EXECUTE AS OWNER
AS
BEGIN
    IF @cifrado IS NULL
        RETURN NULL;
    RETURN CONVERT(NVARCHAR(200), DECRYPTBYKEYAUTOCERT(CERT_ID('CertDatosSensibles'), NULL, @cifrado));
END;
GO

-- Cifrado. ENCRYPTBYKEY necesita la clave abierta, y eso no se puede hacer dentro de una función:
-- por eso el cifrado es un SP (abre, cifra y cierra la clave).
CREATE OR ALTER PROCEDURE nucleo.SP_CIFRAR_DATO
    @textoPlano  NVARCHAR(200),
    @datoCifrado VARBINARY(512) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF @textoPlano IS NULL
    BEGIN
        SET @datoCifrado = NULL;
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'ClaveDatosSensibles')
        THROW 52000, N'SP_CIFRAR_DATO - No se pudo cifrar:
- Falta la clave ClaveDatosSensibles: ejecutar nucleo.SP_CONFIGURAR_CIFRADO.', 1;

    OPEN SYMMETRIC KEY ClaveDatosSensibles DECRYPTION BY CERTIFICATE CertDatosSensibles;
    SET @datoCifrado = ENCRYPTBYKEY(KEY_GUID('ClaveDatosSensibles'), @textoPlano);
    CLOSE SYMMETRIC KEY ClaveDatosSensibles;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_DESCIFRAR_DATO
    @datoCifrado VARBINARY(512),
    @textoPlano  NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @textoPlano = nucleo.fn_DescifrarTexto(@datoCifrado);
END;
GO

-- =========================================================================
-- 4. CONSULTAS: funciones de búsqueda y de nombre visible (creadas en 07 y 14)
-- Primero buscan por hash; si la fila no tiene hash (cargada en texto plano), por la columna pública.
-- =========================================================================
CREATE OR ALTER FUNCTION jugadores.fn_IdJugadorPorDocumento (@documento VARCHAR(20))
RETURNS INT
AS
BEGIN
    DECLARE @hash VARBINARY(32) = nucleo.fn_HashDato(@documento);
    RETURN (SELECT TOP (1) IdJugador FROM jugadores.Jugador
            WHERE DocumentoHash = @hash
               OR (DocumentoHash IS NULL AND Documento = LTRIM(RTRIM(@documento)))
            ORDER BY CASE WHEN DocumentoHash = @hash THEN 0 ELSE 1 END, IdJugador);
END;
GO

CREATE OR ALTER FUNCTION nucleo.fn_IdArbitroPorNombre (@nombreApellido VARCHAR(200))
RETURNS INT
AS
BEGIN
    DECLARE @hash VARBINARY(32) = nucleo.fn_HashDato(@nombreApellido);
    RETURN (SELECT TOP (1) IdArbitro FROM nucleo.Arbitro
            WHERE NombreApellidoHash = @hash
               OR (NombreApellidoHash IS NULL AND NombreApellido = LTRIM(RTRIM(@nombreApellido)))
            ORDER BY CASE WHEN NombreApellidoHash = @hash THEN 0 ELSE 1 END, IdArbitro);
END;
GO

CREATE OR ALTER FUNCTION nucleo.fn_IdStaffPorNombre (@nombreApellido VARCHAR(200))
RETURNS INT
AS
BEGIN
    DECLARE @hash VARBINARY(32) = nucleo.fn_HashDato(@nombreApellido);
    RETURN (SELECT TOP (1) IdStaffTecnico FROM nucleo.StaffTecnico
            WHERE NombreApellidoHash = @hash
               OR (NombreApellidoHash IS NULL AND NombreApellido = LTRIM(RTRIM(@nombreApellido)))
            ORDER BY CASE WHEN NombreApellidoHash = @hash THEN 0 ELSE 1 END, IdStaffTecnico);
END;
GO

CREATE OR ALTER FUNCTION nucleo.fn_NombreArbitro (@idArbitro INT)
RETURNS VARCHAR(200)
AS
BEGIN
    RETURN (SELECT COALESCE(CONVERT(VARCHAR(200), nucleo.fn_DescifrarTexto(NombreApellidoCifrado)), NombreApellido)
            FROM nucleo.Arbitro WHERE IdArbitro = @idArbitro);
END;
GO

CREATE OR ALTER FUNCTION nucleo.fn_NombreStaff (@idStaffTecnico INT)
RETURNS VARCHAR(200)
AS
BEGIN
    RETURN (SELECT COALESCE(CONVERT(VARCHAR(200), nucleo.fn_DescifrarTexto(NombreApellidoCifrado)), NombreApellido)
            FROM nucleo.StaffTecnico WHERE IdStaffTecnico = @idStaffTecnico);
END;
GO

-- =========================================================================
-- 5. SP: validación y ABM de Jugador, Arbitro y StaffTecnico con el dato cifrado
-- Mismas firmas y validaciones que en 18 y 19; cambia cómo se guarda el dato sensible.
-- =========================================================================

-- Unicidad del documento por hash (y contra filas en texto plano).
CREATE OR ALTER FUNCTION jugadores.fn_ValidarJugador
(
    @idExcluido      INT,
    @nombre          VARCHAR(60),
    @apellido        VARCHAR(60),
    @documento       VARCHAR(20),
    @fechaNacimiento DATE,
    @sexo            CHAR(1),
    @posicion        VARCHAR(20),
    @idClub          INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idOtro  INT;

    IF @nombre IS NULL OR @nombre = ''
        SET @errores += N'- El nombre del jugador es obligatorio.' + @salto;
    IF @apellido IS NULL OR @apellido = ''
        SET @errores += N'- El apellido del jugador es obligatorio.' + @salto;

    IF @documento IS NULL OR @documento = ''
        SET @errores += N'- El documento del jugador es obligatorio.' + @salto;
    ELSE
    BEGIN
        SET @idOtro = jugadores.fn_IdJugadorPorDocumento(@documento);
        IF @idOtro IS NOT NULL AND (@idExcluido IS NULL OR @idOtro <> @idExcluido)
            SET @errores += N'- Ya existe otro jugador con ese documento.' + @salto;
    END;

    IF @fechaNacimiento IS NOT NULL AND @fechaNacimiento > CAST(GETDATE() AS DATE)
        SET @errores += N'- La fecha de nacimiento no puede ser futura.' + @salto;

    IF @sexo IS NULL OR @sexo NOT IN ('M', 'F')
        SET @errores += N'- El sexo debe ser M o F.' + @salto;

    IF @posicion IS NULL OR @posicion NOT IN ('Arquero', 'Defensor', 'Mediocampista', 'Delantero')
        SET @errores += N'- La posición debe ser: Arquero, Defensor, Mediocampista o Delantero.' + @salto;

    IF @idClub IS NOT NULL AND NOT EXISTS (SELECT 1 FROM jugadores.Club WHERE IdClub = @idClub)
        SET @errores += N'- El club indicado no existe.' + @salto;

    RETURN @errores;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_ALTA_Jugador
    @idJugador       INT         = NULL OUTPUT,
    @nombre          VARCHAR(60) = NULL,
    @apellido        VARCHAR(60) = NULL,
    @documento       VARCHAR(20) = NULL,
    @fechaNacimiento DATE        = NULL,
    @sexo            CHAR(1)     = NULL,
    @posicion        VARCHAR(20) = NULL,
    @idClub          INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores    NVARCHAR(MAX),
            @mensaje    NVARCHAR(2048),
            @salto      NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @docCifrado VARBINARY(512);

    SET @nombre    = LTRIM(RTRIM(@nombre));
    SET @apellido  = LTRIM(RTRIM(@apellido));
    SET @documento = LTRIM(RTRIM(@documento));
    SET @sexo      = UPPER(LTRIM(RTRIM(@sexo)));
    SET @posicion  = LTRIM(RTRIM(@posicion));

    SET @errores = jugadores.fn_ValidarJugador(NULL, @nombre, @apellido, @documento, @fechaNacimiento,
                                               @sexo, @posicion, @idClub);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Jugador - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    EXEC nucleo.SP_CIFRAR_DATO @textoPlano = @documento, @datoCifrado = @docCifrado OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, DocumentoCifrado, DocumentoHash,
                                       FechaNacimiento, Sexo, Posicion, IdClub)
        VALUES (@nombre, @apellido, '***-' + RIGHT(@documento, 4), @docCifrado, nucleo.fn_HashDato(@documento),
                @fechaNacimiento, @sexo, @posicion, @idClub);
        SET @idJugador = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE jugadores.SP_MODIFICACION_Jugador
    @idJugador       INT         = NULL,
    @nombre          VARCHAR(60) = NULL,
    @apellido        VARCHAR(60) = NULL,
    @documento       VARCHAR(20) = NULL,
    @fechaNacimiento DATE        = NULL,
    @sexo            CHAR(1)     = NULL,
    @posicion        VARCHAR(20) = NULL,
    @idClub          INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores    NVARCHAR(MAX) = N'',
            @mensaje    NVARCHAR(2048),
            @salto      NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @docCifrado VARBINARY(512);

    SET @nombre    = LTRIM(RTRIM(@nombre));
    SET @apellido  = LTRIM(RTRIM(@apellido));
    SET @documento = LTRIM(RTRIM(@documento));
    SET @sexo      = UPPER(LTRIM(RTRIM(@sexo)));
    SET @posicion  = LTRIM(RTRIM(@posicion));

    IF @idJugador IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.Jugador WHERE IdJugador = @idJugador)
        SET @errores += N'- El jugador indicado no existe.' + @salto;

    SET @errores += jugadores.fn_ValidarJugador(@idJugador, @nombre, @apellido, @documento, @fechaNacimiento,
                                                @sexo, @posicion, @idClub);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Jugador - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    EXEC nucleo.SP_CIFRAR_DATO @textoPlano = @documento, @datoCifrado = @docCifrado OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE jugadores.Jugador
        SET Nombre           = @nombre,
            Apellido         = @apellido,
            Documento        = '***-' + RIGHT(@documento, 4),
            DocumentoCifrado = @docCifrado,
            DocumentoHash    = nucleo.fn_HashDato(@documento),
            FechaNacimiento  = @fechaNacimiento,
            Sexo             = @sexo,
            Posicion         = @posicion,
            IdClub           = @idClub
        WHERE IdJugador = @idJugador;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_Arbitro
    @idArbitro       INT          = NULL OUTPUT,
    @nombreApellido  VARCHAR(200) = NULL,
    @sexo            CHAR(1)      = NULL,
    @estaHabilitado  CHAR(1)      = 'Y',
    @fechaNacimiento DATE         = NULL,
    @idPais          INT          = NULL,
    @idCategoria     INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores    NVARCHAR(MAX),
            @mensaje    NVARCHAR(2048),
            @salto      NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @nomCifrado VARBINARY(512);

    SET @nombreApellido = LTRIM(RTRIM(@nombreApellido));
    SET @sexo           = NULLIF(UPPER(LTRIM(RTRIM(@sexo))), '');
    SET @estaHabilitado = UPPER(LTRIM(RTRIM(ISNULL(@estaHabilitado, 'Y'))));

    SET @errores = nucleo.fn_ValidarArbitro(@nombreApellido, @sexo, @estaHabilitado, @fechaNacimiento, @idPais, @idCategoria);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Arbitro - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    EXEC nucleo.SP_CIFRAR_DATO @textoPlano = @nombreApellido, @datoCifrado = @nomCifrado OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.Arbitro (NombreApellido, NombreApellidoCifrado, NombreApellidoHash, Sexo, EstaHabilitado,
                                    FechaNacimiento, IdPais, IdCategoria)
        VALUES ('***-CONFIDENCIAL***', @nomCifrado, nucleo.fn_HashDato(@nombreApellido), @sexo, @estaHabilitado,
                @fechaNacimiento, @idPais, @idCategoria);
        SET @idArbitro = SCOPE_IDENTITY();

        UPDATE nucleo.Arbitro
        SET NombreApellido = '***-CONFIDENCIAL-' + CAST(@idArbitro AS VARCHAR(10)) + '***'
        WHERE IdArbitro = @idArbitro;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_Arbitro
    @idArbitro       INT          = NULL,
    @nombreApellido  VARCHAR(200) = NULL,
    @sexo            CHAR(1)      = NULL,
    @estaHabilitado  CHAR(1)      = 'Y',
    @fechaNacimiento DATE         = NULL,
    @idPais          INT          = NULL,
    @idCategoria     INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores    NVARCHAR(MAX) = N'',
            @mensaje    NVARCHAR(2048),
            @salto      NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @nomCifrado VARBINARY(512);

    SET @nombreApellido = LTRIM(RTRIM(@nombreApellido));
    SET @sexo           = NULLIF(UPPER(LTRIM(RTRIM(@sexo))), '');
    SET @estaHabilitado = UPPER(LTRIM(RTRIM(ISNULL(@estaHabilitado, 'Y'))));

    IF @idArbitro IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdArbitro = @idArbitro)
        SET @errores += N'- El árbitro indicado no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarArbitro(@nombreApellido, @sexo, @estaHabilitado, @fechaNacimiento, @idPais, @idCategoria);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Arbitro - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    EXEC nucleo.SP_CIFRAR_DATO @textoPlano = @nombreApellido, @datoCifrado = @nomCifrado OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.Arbitro
        SET NombreApellido        = '***-CONFIDENCIAL-' + CAST(@idArbitro AS VARCHAR(10)) + '***',
            NombreApellidoCifrado = @nomCifrado,
            NombreApellidoHash    = nucleo.fn_HashDato(@nombreApellido),
            Sexo                  = @sexo,
            EstaHabilitado        = @estaHabilitado,
            FechaNacimiento       = @fechaNacimiento,
            IdPais                = @idPais,
            IdCategoria           = @idCategoria
        WHERE IdArbitro = @idArbitro;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_StaffTecnico
    @idStaffTecnico INT          = NULL OUTPUT,
    @idSeleccion    INT          = NULL,
    @nombreApellido VARCHAR(200) = NULL,
    @rol            VARCHAR(25)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores    NVARCHAR(MAX),
            @mensaje    NVARCHAR(2048),
            @salto      NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @nomCifrado VARBINARY(512);

    SET @nombreApellido = LTRIM(RTRIM(@nombreApellido));
    SET @rol            = LTRIM(RTRIM(@rol));

    SET @errores = nucleo.fn_ValidarStaffTecnico(NULL, @idSeleccion, @nombreApellido, @rol);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_StaffTecnico - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    EXEC nucleo.SP_CIFRAR_DATO @textoPlano = @nombreApellido, @datoCifrado = @nomCifrado OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.StaffTecnico (IdSeleccion, NombreApellido, NombreApellidoCifrado, NombreApellidoHash, Rol)
        VALUES (@idSeleccion, '***-CONFIDENCIAL***', @nomCifrado, nucleo.fn_HashDato(@nombreApellido), @rol);
        SET @idStaffTecnico = SCOPE_IDENTITY();

        UPDATE nucleo.StaffTecnico
        SET NombreApellido = '***-CONFIDENCIAL-' + CAST(@idStaffTecnico AS VARCHAR(10)) + '***'
        WHERE IdStaffTecnico = @idStaffTecnico;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_StaffTecnico
    @idStaffTecnico INT          = NULL,
    @idSeleccion    INT          = NULL,
    @nombreApellido VARCHAR(200) = NULL,
    @rol            VARCHAR(25)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores    NVARCHAR(MAX) = N'',
            @mensaje    NVARCHAR(2048),
            @salto      NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @nomCifrado VARBINARY(512);

    SET @nombreApellido = LTRIM(RTRIM(@nombreApellido));
    SET @rol            = LTRIM(RTRIM(@rol));

    IF @idStaffTecnico IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.StaffTecnico WHERE IdStaffTecnico = @idStaffTecnico)
        SET @errores += N'- El integrante del staff técnico indicado no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarStaffTecnico(@idStaffTecnico, @idSeleccion, @nombreApellido, @rol);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_StaffTecnico - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    EXEC nucleo.SP_CIFRAR_DATO @textoPlano = @nombreApellido, @datoCifrado = @nomCifrado OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.StaffTecnico
        SET IdSeleccion           = @idSeleccion,
            NombreApellido        = '***-CONFIDENCIAL-' + CAST(@idStaffTecnico AS VARCHAR(10)) + '***',
            NombreApellidoCifrado = @nomCifrado,
            NombreApellidoHash    = nucleo.fn_HashDato(@nombreApellido),
            Rol                   = @rol
        WHERE IdStaffTecnico = @idStaffTecnico;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================================
-- 6. MIGRACIÓN: nucleo.SP_APLICAR_CIFRADO_DATOS_SENSIBLES
-- Cifra, calcula el hash y enmascara las filas que todavía están en texto plano (sin dato cifrado).
-- Set-based (sin cursores) y en una sola transacción. Idempotente: una segunda corrida no encuentra filas.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_APLICAR_CIFRADO_DATOS_SENSIBLES
    @jugadoresCifrados INT = NULL OUTPUT,
    @arbitrosCifrados  INT = NULL OUTPUT,
    @staffCifrado      INT = NULL OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SELECT @jugadoresCifrados = 0, @arbitrosCifrados = 0, @staffCifrado = 0;

    IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'CertDatosSensibles')
        SET @errores += N'- Falta el certificado CertDatosSensibles.' + @salto;
    IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'ClaveDatosSensibles')
        SET @errores += N'- Falta la clave simétrica ClaveDatosSensibles.' + @salto;
    IF NOT EXISTS (SELECT 1 FROM nucleo.ConfiguracionCifrado WHERE IdConfiguracion = 1)
        SET @errores += N'- Falta el secreto del hash en nucleo.ConfiguracionCifrado.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_APLICAR_CIFRADO_DATOS_SENSIBLES - No se pudo aplicar el cifrado (ejecutar nucleo.SP_CONFIGURAR_CIFRADO):'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        OPEN SYMMETRIC KEY ClaveDatosSensibles DECRYPTION BY CERTIFICATE CertDatosSensibles;

        UPDATE jugadores.Jugador
        SET DocumentoCifrado = ENCRYPTBYKEY(KEY_GUID('ClaveDatosSensibles'), CONVERT(NVARCHAR(200), Documento)),
            DocumentoHash    = nucleo.fn_HashDato(Documento),
            Documento        = '***-' + RIGHT(Documento, 4)
        WHERE DocumentoCifrado IS NULL;
        SET @jugadoresCifrados = @@ROWCOUNT;

        UPDATE nucleo.Arbitro
        SET NombreApellidoCifrado = ENCRYPTBYKEY(KEY_GUID('ClaveDatosSensibles'), CONVERT(NVARCHAR(200), NombreApellido)),
            NombreApellidoHash    = nucleo.fn_HashDato(NombreApellido),
            NombreApellido        = '***-CONFIDENCIAL-' + CAST(IdArbitro AS VARCHAR(10)) + '***'
        WHERE NombreApellidoCifrado IS NULL;
        SET @arbitrosCifrados = @@ROWCOUNT;

        UPDATE nucleo.StaffTecnico
        SET NombreApellidoCifrado = ENCRYPTBYKEY(KEY_GUID('ClaveDatosSensibles'), CONVERT(NVARCHAR(200), NombreApellido)),
            NombreApellidoHash    = nucleo.fn_HashDato(NombreApellido),
            NombreApellido        = '***-CONFIDENCIAL-' + CAST(IdStaffTecnico AS VARCHAR(10)) + '***'
        WHERE NombreApellidoCifrado IS NULL;
        SET @staffCifrado = @@ROWCOUNT;

        CLOSE SYMMETRIC KEY ClaveDatosSensibles;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveDatosSensibles')
            CLOSE SYMMETRIC KEY ClaveDatosSensibles;
        THROW;
    END CATCH;
END;
GO

DECLARE @j INT, @a INT, @s INT;
EXEC nucleo.SP_APLICAR_CIFRADO_DATOS_SENSIBLES @jugadoresCifrados = @j OUTPUT, @arbitrosCifrados = @a OUTPUT, @staffCifrado = @s OUTPUT;
PRINT 'Migración de datos existentes: ' + CAST(@j AS VARCHAR(10)) + ' jugadores, ' + CAST(@a AS VARCHAR(10))
      + ' árbitros y ' + CAST(@s AS VARCHAR(10)) + ' integrantes del staff cifrados.';
GO

-- =========================================================================
-- 7. CONSULTA DESCIFRADA (para usuarios autorizados; ver 32_Seguridad_Roles_Permisos.sql)
-- =========================================================================
CREATE OR ALTER PROCEDURE jugadores.SP_CONSULTAR_JUGADOR_DESCIFRADO
    @idJugador INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @idJugador IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.Jugador WHERE IdJugador = @idJugador)
        THROW 52000, N'SP_CONSULTAR_JUGADOR_DESCIFRADO - No se pudo completar la consulta:
- El jugador indicado no existe.', 1;

    SELECT j.IdJugador,
           j.Nombre,
           j.Apellido,
           j.Documento                                                        AS DocumentoEnmascarado,
           COALESCE(CONVERT(VARCHAR(20), nucleo.fn_DescifrarTexto(j.DocumentoCifrado)), j.Documento) AS Documento,
           j.FechaNacimiento,
           j.Sexo,
           j.Posicion,
           c.Nombre                                                           AS Club
    FROM jugadores.Jugador AS j
    LEFT JOIN jugadores.Club AS c ON c.IdClub = j.IdClub
    WHERE j.IdJugador = @idJugador;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_CONSULTAR_ARBITRO_DESCIFRADO
    @idArbitro INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @idArbitro IS NOT NULL AND NOT EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdArbitro = @idArbitro)
        THROW 52000, N'SP_CONSULTAR_ARBITRO_DESCIFRADO - No se pudo completar la consulta:
- El árbitro indicado no existe.', 1;

    SELECT a.IdArbitro,
           a.NombreApellido                    AS NombreEnmascarado,
           nucleo.fn_NombreArbitro(a.IdArbitro) AS NombreApellido,
           a.Sexo,
           a.EstaHabilitado,
           a.FechaNacimiento,
           p.Nombre                            AS Pais,
           c.Nombre                            AS Categoria
    FROM nucleo.Arbitro AS a
    INNER JOIN nucleo.Pais AS p ON p.IdPais = a.IdPais
    INNER JOIN nucleo.Categoria AS c ON c.IdCategoria = a.IdCategoria
    WHERE @idArbitro IS NULL OR a.IdArbitro = @idArbitro
    ORDER BY a.IdArbitro;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_CONSULTAR_STAFF_DESCIFRADO
    @idSeleccion INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @idSeleccion IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccion)
        THROW 52000, N'SP_CONSULTAR_STAFF_DESCIFRADO - No se pudo completar la consulta:
- La selección indicada no existe.', 1;

    SELECT st.IdStaffTecnico,
           st.IdSeleccion,
           st.Rol,
           st.NombreApellido                         AS NombreEnmascarado,
           nucleo.fn_NombreStaff(st.IdStaffTecnico) AS NombreApellido
    FROM nucleo.StaffTecnico AS st
    WHERE st.IdSeleccion = @idSeleccion
    ORDER BY st.IdStaffTecnico;
END;
GO

PRINT 'Script 31_Seguridad_Cifrado ejecutado correctamente.';
GO
