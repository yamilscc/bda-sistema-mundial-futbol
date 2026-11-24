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
Objetivo: Implementar la infraestructura de cifrado para datos sensibles (PII)
          correspondiente a la Entrega 8:
          1. Funciones y Stored Procedures de cifrado y descifrado en el esquema nucleo.
          2. Script modificatorio (ALTER TABLE) para incorporar columnas cifradas:
             - jugadores.Jugador (DocumentoCifrado)
             - nucleo.Arbitro (NombreApellidoCifrado)
             - nucleo.StaffTecnico (NombreApellidoCifrado)
          3. Migración y enmascaramiento de los datos preexistentes.
          4. Actualización (ALTER PROCEDURE) de SP_ABM_Jugador, SP_ABM_Arbitro y
             SP_ABM_StaffTecnico para almacenar y validar datos cifrados.
          5. Procedimientos de consulta segura con descifrado en tiempo de ejecución.

NOTA PEDAGÓGICA (Consigna Entrega 8):
"Una vez aplicado el cifrado el testing aplicado en entregas previas puede que ya no sea exitoso."
Al enmascarar las columnas públicas y trasladar los datos sensibles a columnas VARBINARY,
las consultas directas (SELECT Documento FROM ...) dejan de retornar el valor plano,
obligando al consumo a través de los procedimientos autorizados de descifrado.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. INFRAESTRUCTURA Y FUNCIONES CRIPTOGRÁFICAS
-- Se define una clave canónica de cifrado del torneo para proteger datos PII.
-- =========================================================================

-- Clave interna de cifrado para el sistema del torneo
CREATE OR ALTER FUNCTION nucleo.fn_ObtenerClaveCifrado()
RETURNS NVARCHAR(128)
WITH SCHEMABINDING
AS
BEGIN
    RETURN N'Mundial2026!Key_Seguridad_UNLaM_BDA_Grupo05#AES';
END;
GO

-- Función escalar para cifrado de texto plano a VARBINARY
CREATE OR ALTER FUNCTION nucleo.fn_CifrarTexto(@texto NVARCHAR(MAX))
RETURNS VARBINARY(MAX)
AS
BEGIN
    IF @texto IS NULL
        RETURN NULL;
    RETURN ENCRYPTBYPASSPHRASE(nucleo.fn_ObtenerClaveCifrado(), @texto);
END;
GO

-- Función escalar para descifrado de VARBINARY a texto plano
CREATE OR ALTER FUNCTION nucleo.fn_DescifrarTexto(@cifrado VARBINARY(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    IF @cifrado IS NULL
        RETURN NULL;
    RETURN CONVERT(NVARCHAR(MAX), DECRYPTBYPASSPHRASE(nucleo.fn_ObtenerClaveCifrado(), @cifrado));
END;
GO

-- Stored Procedure para cifrar un dato mediante código
CREATE OR ALTER PROCEDURE nucleo.SP_CIFRAR_DATO
    @textoPlano NVARCHAR(MAX),
    @datoCifrado VARBINARY(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @datoCifrado = nucleo.fn_CifrarTexto(@textoPlano);
END;
GO

-- Stored Procedure para descifrar un dato mediante código
CREATE OR ALTER PROCEDURE nucleo.SP_DESCIFRAR_DATO
    @datoCifrado VARBINARY(MAX),
    @textoPlano  NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @textoPlano = nucleo.fn_DescifrarTexto(@datoCifrado);
END;
GO

-- =========================================================================
-- 2. MODIFICACIÓN DE TABLAS (ALTER TABLE) Y MIGRACIÓN DE DATOS SENSIBLES
-- =========================================================================

-- A. Modificación de jugadores.Jugador (Cifrado de Documento)
IF COL_LENGTH('jugadores.Jugador', 'DocumentoCifrado') IS NULL
BEGIN
    ALTER TABLE jugadores.Jugador ADD DocumentoCifrado VARBINARY(256) NULL;
    PRINT 'Columna agregada: jugadores.Jugador.DocumentoCifrado';
END;
GO

-- Migrar datos de Documento existentes a la columna cifrada
UPDATE jugadores.Jugador
SET DocumentoCifrado = nucleo.fn_CifrarTexto(Documento)
WHERE DocumentoCifrado IS NULL
  AND Documento IS NOT NULL
  AND Documento NOT LIKE '***-%';
GO

-- Eliminar la restricción UNIQUE sobre el Documento en texto plano si existe
IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_Jugador_Documento')
BEGIN
    ALTER TABLE jugadores.Jugador DROP CONSTRAINT UQ_Jugador_Documento;
    PRINT 'Restricción eliminada: UQ_Jugador_Documento';
END;
GO

-- Enmascarar los documentos planos preexistentes
UPDATE jugadores.Jugador
SET Documento = '***-' + RIGHT(Documento, 4)
WHERE Documento NOT LIKE '***-%' AND DocumentoCifrado IS NOT NULL;
GO

-- B. Modificación de nucleo.Arbitro (Cifrado de NombreApellido)
IF COL_LENGTH('nucleo.Arbitro', 'NombreApellidoCifrado') IS NULL
BEGIN
    ALTER TABLE nucleo.Arbitro ADD NombreApellidoCifrado VARBINARY(512) NULL;
    PRINT 'Columna agregada: nucleo.Arbitro.NombreApellidoCifrado';
END;
GO

UPDATE nucleo.Arbitro
SET NombreApellidoCifrado = nucleo.fn_CifrarTexto(NombreApellido)
WHERE NombreApellidoCifrado IS NULL
  AND NombreApellido IS NOT NULL
  AND NombreApellido NOT LIKE '***-CONFIDENCIAL-%';
GO

-- Enmascarar NombreApellido en nucleo.Arbitro
UPDATE nucleo.Arbitro
SET NombreApellido = '***-CONFIDENCIAL-' + CAST(IdArbitro AS VARCHAR(10)) + '***'
WHERE NombreApellido NOT LIKE '***-CONFIDENCIAL-%' AND NombreApellidoCifrado IS NOT NULL;
GO

-- C. Modificación de nucleo.StaffTecnico (Cifrado de NombreApellido)
IF COL_LENGTH('nucleo.StaffTecnico', 'NombreApellidoCifrado') IS NULL
BEGIN
    ALTER TABLE nucleo.StaffTecnico ADD NombreApellidoCifrado VARBINARY(512) NULL;
    PRINT 'Columna agregada: nucleo.StaffTecnico.NombreApellidoCifrado';
END;
GO

UPDATE nucleo.StaffTecnico
SET NombreApellidoCifrado = nucleo.fn_CifrarTexto(NombreApellido)
WHERE NombreApellidoCifrado IS NULL
  AND NombreApellido IS NOT NULL
  AND NombreApellido NOT LIKE '***-CONFIDENCIAL-%';
GO

-- Enmascarar NombreApellido en nucleo.StaffTecnico
UPDATE nucleo.StaffTecnico
SET NombreApellido = '***-CONFIDENCIAL-' + CAST(IdStaffTecnico AS VARCHAR(10)) + '***'
WHERE NombreApellido NOT LIKE '***-CONFIDENCIAL-%' AND NombreApellidoCifrado IS NOT NULL;
GO


-- =========================================================================
-- 3. ACTUALIZACIÓN DE STORED PROCEDURES ABM PARA OPERAR CON CIFRADO
-- =========================================================================

-- A. Modificación de jugadores.SP_ABM_Jugador
CREATE OR ALTER PROCEDURE jugadores.SP_ABM_Jugador
    @operacion       VARCHAR(12),
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

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombre    = LTRIM(RTRIM(@nombre));
    SET @apellido  = LTRIM(RTRIM(@apellido));
    SET @documento = LTRIM(RTRIM(@documento));
    SET @sexo      = UPPER(LTRIM(RTRIM(@sexo)));
    SET @posicion  = LTRIM(RTRIM(@posicion));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idJugador IS NULL OR NOT EXISTS (SELECT 1 FROM jugadores.Jugador WHERE IdJugador = @idJugador)
            SET @errores += N'- El jugador indicado no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombre IS NULL OR @nombre = ''
            SET @errores += N'- El nombre del jugador es obligatorio.' + @salto;
        IF @apellido IS NULL OR @apellido = ''
            SET @errores += N'- El apellido del jugador es obligatorio.' + @salto;

        IF @documento IS NULL OR @documento = ''
            SET @errores += N'- El documento del jugador es obligatorio.' + @salto;
        ELSE
        BEGIN
            -- Se valida unicidad del documento descifrando las filas existentes
            IF EXISTS (SELECT 1
                       FROM jugadores.Jugador
                       WHERE nucleo.fn_DescifrarTexto(DocumentoCifrado) = @documento
                         AND (@operacion = 'ALTA' OR IdJugador <> @idJugador))
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
    END;

    IF @operacion = 'BAJA'
    BEGIN
        IF EXISTS (SELECT 1 FROM jugadores.Convocatoria WHERE IdJugador = @idJugador)
            SET @errores += N'- El jugador tiene una convocatoria asociada y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM jugadores.FormacionJugador WHERE IdJugador = @idJugador)
            SET @errores += N'- El jugador figura en formaciones de partidos y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM jugadores.Sustitucion WHERE IdJugadorSaliente = @idJugador OR IdJugadorEntrante = @idJugador)
            SET @errores += N'- El jugador registra sustituciones y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM eventos.Gol WHERE IdJugadorAutor = @idJugador OR IdJugadorAsistencia = @idJugador)
            SET @errores += N'- El jugador registra goles o asistencias y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdJugador = @idJugador)
            SET @errores += N'- El jugador registra amonestaciones y no puede eliminarse.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Jugador (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @docMascara VARCHAR(20) = '***-' + RIGHT(@documento, 4);
        DECLARE @docCifrado VARBINARY(256) = nucleo.fn_CifrarTexto(@documento);

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, DocumentoCifrado, FechaNacimiento, Sexo, Posicion, IdClub)
            VALUES (@nombre, @apellido, @docMascara, @docCifrado, @fechaNacimiento, @sexo, @posicion, @idClub);

            SET @idJugador = SCOPE_IDENTITY();
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE jugadores.Jugador
            SET Nombre           = @nombre,
                Apellido         = @apellido,
                Documento        = @docMascara,
                DocumentoCifrado = @docCifrado,
                FechaNacimiento  = @fechaNacimiento,
                Sexo             = @sexo,
                Posicion         = @posicion,
                IdClub           = @idClub
            WHERE IdJugador = @idJugador;
        END
        ELSE
        BEGIN
            DELETE FROM jugadores.Jugador WHERE IdJugador = @idJugador;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- B. Modificación de nucleo.SP_ABM_Arbitro
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_Arbitro
    @operacion       VARCHAR(12),
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

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion      = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombreApellido = LTRIM(RTRIM(@nombreApellido));
    SET @sexo           = UPPER(LTRIM(RTRIM(@sexo)));
    SET @estaHabilitado = UPPER(LTRIM(RTRIM(@estaHabilitado)));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idArbitro IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdArbitro = @idArbitro)
            SET @errores += N'- El árbitro indicado no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombreApellido IS NULL OR @nombreApellido = ''
            SET @errores += N'- El nombre y apellido del árbitro es obligatorio.' + @salto;

        IF @sexo IS NOT NULL AND @sexo NOT IN ('M', 'F')
            SET @errores += N'- El sexo debe ser M, F o NULL.' + @salto;

        IF @estaHabilitado IS NULL OR @estaHabilitado NOT IN ('Y', 'N')
            SET @errores += N'- El estado de habilitación debe ser Y o N.' + @salto;

        IF @fechaNacimiento IS NULL
            SET @errores += N'- La fecha de nacimiento es obligatoria.' + @salto;
        ELSE IF @fechaNacimiento < '1930-01-01' OR @fechaNacimiento >= CAST(GETDATE() AS DATE)
            SET @errores += N'- La fecha de nacimiento no es válida (debe ser posterior a 1930 y anterior a hoy).' + @salto;

        IF @idPais IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
            SET @errores += N'- El país indicado no existe.' + @salto;

        IF @idCategoria IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Categoria WHERE IdCategoria = @idCategoria)
            SET @errores += N'- La categoría indicada no existe.' + @salto;
    END;

    IF @operacion = 'BAJA'
    BEGIN
        IF EXISTS (SELECT 1 FROM nucleo.DesignacionArbitral WHERE IdArbitro = @idArbitro)
            SET @errores += N'- El árbitro tiene designaciones arbitrales asociadas y no puede eliminarse.' + @salto;
        IF EXISTS (SELECT 1 FROM nucleo.ArbitroIdioma WHERE IdArbitro = @idArbitro)
            SET @errores += N'- El árbitro tiene idiomas asociados; elimine primero sus registros en ArbitroIdioma.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_Arbitro (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @nomCifrado VARBINARY(512) = nucleo.fn_CifrarTexto(@nombreApellido);

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.Arbitro (NombreApellido, NombreApellidoCifrado, Sexo, EstaHabilitado, FechaNacimiento, IdPais, IdCategoria)
            VALUES ('***-CONFIDENCIAL-TMP***', @nomCifrado, @sexo, @estaHabilitado, @fechaNacimiento, @idPais, @idCategoria);

            SET @idArbitro = SCOPE_IDENTITY();

            UPDATE nucleo.Arbitro
            SET NombreApellido = '***-CONFIDENCIAL-' + CAST(@idArbitro AS VARCHAR(10)) + '***'
            WHERE IdArbitro = @idArbitro;
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.Arbitro
            SET NombreApellido        = '***-CONFIDENCIAL-' + CAST(@idArbitro AS VARCHAR(10)) + '***',
                NombreApellidoCifrado = @nomCifrado,
                Sexo                  = @sexo,
                EstaHabilitado        = @estaHabilitado,
                FechaNacimiento       = @fechaNacimiento,
                IdPais                = @idPais,
                IdCategoria           = @idCategoria
            WHERE IdArbitro = @idArbitro;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.Arbitro WHERE IdArbitro = @idArbitro;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- C. Modificación de nucleo.SP_ABM_StaffTecnico
CREATE OR ALTER PROCEDURE nucleo.SP_ABM_StaffTecnico
    @operacion       VARCHAR(12),
    @idStaffTecnico  INT          = NULL OUTPUT,
    @idSeleccion     INT          = NULL,
    @nombreApellido  VARCHAR(200) = NULL,
    @rol             VARCHAR(25)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @operacion      = UPPER(LTRIM(RTRIM(@operacion)));
    SET @nombreApellido = LTRIM(RTRIM(@nombreApellido));
    SET @rol            = LTRIM(RTRIM(@rol));

    IF @operacion IS NULL OR @operacion NOT IN ('ALTA', 'MODIFICACION', 'BAJA')
        THROW 52001, 'Operación inválida. Valores permitidos: ALTA, MODIFICACION, BAJA.', 1;

    IF @operacion IN ('MODIFICACION', 'BAJA')
    BEGIN
        IF @idStaffTecnico IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.StaffTecnico WHERE IdStaffTecnico = @idStaffTecnico)
            SET @errores += N'- El integrante del staff técnico indicado no existe.' + @salto;
    END;

    IF @operacion IN ('ALTA', 'MODIFICACION')
    BEGIN
        IF @nombreApellido IS NULL OR @nombreApellido = ''
            SET @errores += N'- El nombre y apellido es obligatorio.' + @salto;

        IF @idSeleccion IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccion)
            SET @errores += N'- La selección indicada no existe.' + @salto;

        IF @rol IS NULL OR @rol NOT IN ('Director Técnico', 'Ayudante de campo 1', 'Ayudante de campo 2')
            SET @errores += N'- El rol debe ser: Director Técnico, Ayudante de campo 1 o Ayudante de campo 2.' + @salto;

        IF @idSeleccion IS NOT NULL AND @rol IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1
                       FROM nucleo.StaffTecnico
                       WHERE IdSeleccion = @idSeleccion
                         AND Rol = @rol
                         AND (@operacion = 'ALTA' OR IdStaffTecnico <> @idStaffTecnico))
                SET @errores += N'- La selección ya tiene asignado un integrante con ese rol.' + @salto;
        END;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ABM_StaffTecnico (' + @operacion + N') - No se pudo completar la operación:'
                            + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @staffCifrado VARBINARY(512) = nucleo.fn_CifrarTexto(@nombreApellido);

        IF @operacion = 'ALTA'
        BEGIN
            INSERT INTO nucleo.StaffTecnico (NombreApellido, NombreApellidoCifrado, Rol, IdSeleccion)
            VALUES ('***-CONFIDENCIAL-TMP***', @staffCifrado, @rol, @idSeleccion);

            SET @idStaffTecnico = SCOPE_IDENTITY();

            UPDATE nucleo.StaffTecnico
            SET NombreApellido = '***-CONFIDENCIAL-' + CAST(@idStaffTecnico AS VARCHAR(10)) + '***'
            WHERE IdStaffTecnico = @idStaffTecnico;
        END
        ELSE IF @operacion = 'MODIFICACION'
        BEGIN
            UPDATE nucleo.StaffTecnico
            SET NombreApellido        = '***-CONFIDENCIAL-' + CAST(@idStaffTecnico AS VARCHAR(10)) + '***',
                NombreApellidoCifrado = @staffCifrado,
                Rol                   = @rol,
                IdSeleccion           = @idSeleccion
            WHERE IdStaffTecnico = @idStaffTecnico;
        END
        ELSE
        BEGIN
            DELETE FROM nucleo.StaffTecnico WHERE IdStaffTecnico = @idStaffTecnico;
        END;

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
-- D. Modificación de SP_ALTA_Jugador y SP_MODIFICACION_Jugador (Refactor ABM)
-- =========================================================================

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
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombre IS NULL OR @nombre = ''
        SET @errores += N'- El nombre del jugador es obligatorio.' + @salto;
    IF @apellido IS NULL OR @apellido = ''
        SET @errores += N'- El apellido del jugador es obligatorio.' + @salto;

    IF @documento IS NULL OR @documento = ''
        SET @errores += N'- El documento del jugador es obligatorio.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM jugadores.Jugador
                    WHERE (Documento = @documento OR nucleo.fn_DescifrarTexto(DocumentoCifrado) = @documento)
                      AND (@idExcluido IS NULL OR IdJugador <> @idExcluido))
        SET @errores += N'- Ya existe otro jugador con ese documento.' + @salto;

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

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

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

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @docMascara VARCHAR(20) = '***-' + RIGHT(@documento, 4);
        DECLARE @docCifrado VARBINARY(256) = nucleo.fn_CifrarTexto(@documento);

        INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, DocumentoCifrado, FechaNacimiento, Sexo, Posicion, IdClub)
        VALUES (@nombre, @apellido, @docMascara, @docCifrado, @fechaNacimiento, @sexo, @posicion, @idClub);

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

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

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

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @docMascara VARCHAR(20) = '***-' + RIGHT(@documento, 4);
        DECLARE @docCifrado VARBINARY(256) = nucleo.fn_CifrarTexto(@documento);

        UPDATE jugadores.Jugador
        SET Nombre           = @nombre,
            Apellido         = @apellido,
            Documento        = @docMascara,
            DocumentoCifrado = @docCifrado,
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

-- =========================================================================
-- E. Modificación de SP_ALTA_Arbitro y SP_MODIFICACION_Arbitro (Refactor ABM)
-- =========================================================================

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

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombreApellido = LTRIM(RTRIM(@nombreApellido));
    SET @sexo           = NULLIF(UPPER(LTRIM(RTRIM(@sexo))), '');
    SET @estaHabilitado = UPPER(LTRIM(RTRIM(ISNULL(@estaHabilitado, 'Y'))));

    SET @errores = nucleo.fn_ValidarArbitro(@nombreApellido, @sexo, @estaHabilitado, @fechaNacimiento, @idPais, @idCategoria);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Arbitro - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @nomCifrado VARBINARY(512) = nucleo.fn_CifrarTexto(@nombreApellido);

        INSERT INTO nucleo.Arbitro (NombreApellido, NombreApellidoCifrado, Sexo, EstaHabilitado, FechaNacimiento, IdPais, IdCategoria)
        VALUES ('***-CONFIDENCIAL-TMP***', @nomCifrado, @sexo, @estaHabilitado, @fechaNacimiento, @idPais, @idCategoria);
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

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombreApellido = LTRIM(RTRIM(@nombreApellido));
    SET @sexo           = NULLIF(UPPER(LTRIM(RTRIM(@sexo))), '');
    SET @estaHabilitado = UPPER(LTRIM(RTRIM(ISNULL(@estaHabilitado, 'Y'))));

    IF @idArbitro IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdArbitro = @idArbitro)
        SET @errores += N'- El árbitro indicado no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarArbitro(@nombreApellido, @sexo, @estaHabilitado, @fechaNacimiento, @idPais, @idCategoria);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Arbitro - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @nomCifrado VARBINARY(512) = nucleo.fn_CifrarTexto(@nombreApellido);

        UPDATE nucleo.Arbitro
        SET NombreApellido        = '***-CONFIDENCIAL-' + CAST(@idArbitro AS VARCHAR(10)) + '***',
            NombreApellidoCifrado = @nomCifrado,
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

-- =========================================================================
-- F. Modificación de SP_ALTA_StaffTecnico y SP_MODIFICACION_StaffTecnico (Refactor ABM)
-- =========================================================================

CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_StaffTecnico
    @idStaffTecnico INT          = NULL OUTPUT,
    @idSeleccion    INT          = NULL,
    @nombreApellido VARCHAR(200) = NULL,
    @rol            VARCHAR(25)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombreApellido = LTRIM(RTRIM(@nombreApellido));
    SET @rol            = LTRIM(RTRIM(@rol));

    SET @errores = nucleo.fn_ValidarStaffTecnico(NULL, @idSeleccion, @nombreApellido, @rol);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_StaffTecnico - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @nomCifrado VARBINARY(512) = nucleo.fn_CifrarTexto(@nombreApellido);

        INSERT INTO nucleo.StaffTecnico (IdSeleccion, NombreApellido, NombreApellidoCifrado, Rol)
        VALUES (@idSeleccion, '***-CONFIDENCIAL-TMP***', @nomCifrado, @rol);
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

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

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

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @nomCifrado VARBINARY(512) = nucleo.fn_CifrarTexto(@nombreApellido);

        UPDATE nucleo.StaffTecnico
        SET IdSeleccion           = @idSeleccion,
            NombreApellido        = '***-CONFIDENCIAL-' + CAST(@idStaffTecnico AS VARCHAR(10)) + '***',
            NombreApellidoCifrado = @nomCifrado,
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
-- 4. PROCEDIMIENTOS DE CONSULTA SEGURA CON DESCIFRADO
-- =========================================================================

-- Consulta descifrada de Jugador por Id
CREATE OR ALTER PROCEDURE jugadores.SP_CONSULTAR_JUGADOR_DESCIFRADO
    @idJugador INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT j.IdJugador,
           j.Nombre,
           j.Apellido,
           j.Documento AS DocumentoEnmascarado,
           nucleo.fn_DescifrarTexto(j.DocumentoCifrado) AS DocumentoOriginal,
           j.FechaNacimiento,
           j.Sexo,
           j.Posicion,
           c.Nombre AS Club
    FROM jugadores.Jugador j
    LEFT JOIN jugadores.Club c ON j.IdClub = c.IdClub
    WHERE j.IdJugador = @idJugador;
END;
GO

-- Consulta descifrada de Árbitros
CREATE OR ALTER PROCEDURE nucleo.SP_CONSULTAR_ARBITRO_DESCIFRADO
    @idArbitro INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT a.IdArbitro,
           a.NombreApellido AS NombreEnmascarado,
           nucleo.fn_DescifrarTexto(a.NombreApellidoCifrado) AS NombreApellidoOriginal,
           a.Sexo,
           a.EstaHabilitado,
           a.FechaNacimiento,
           p.Nombre AS Pais,
           c.Nombre AS Categoria
    FROM nucleo.Arbitro a
    INNER JOIN nucleo.Pais p ON a.IdPais = p.IdPais
    INNER JOIN nucleo.Categoria c ON a.IdCategoria = c.IdCategoria
    WHERE (@idArbitro IS NULL OR a.IdArbitro = @idArbitro);
END;
GO

-- Consulta descifrada de Staff Técnico por Selección
CREATE OR ALTER PROCEDURE nucleo.SP_CONSULTAR_STAFF_DESCIFRADO
    @idSeleccion INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT st.IdStaffTecnico,
           st.IdSeleccion,
           st.Rol,
           st.NombreApellido AS NombreEnmascarado,
           nucleo.fn_DescifrarTexto(st.NombreApellidoCifrado) AS NombreApellidoOriginal
    FROM nucleo.StaffTecnico st
    WHERE st.IdSeleccion = @idSeleccion;
END;
GO

PRINT 'Script 30_Seguridad_Cifrado ejecutado correctamente.';
GO
