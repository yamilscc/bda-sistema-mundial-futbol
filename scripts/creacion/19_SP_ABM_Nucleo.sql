/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner
Fecha: 2026-11-19
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Stored procedures ABM restantes del módulo núcleo, uno por operación y tabla
          (SP_ALTA_<Tabla>, SP_MODIFICACION_<Tabla> y SP_BAJA_<Tabla>) para:
          1.  Confederacion      2.  Pais              3.  Ciudad          4.  Fase
          5.  Grupo              6.  Seleccion         7.  StaffTecnico    8.  Idioma
          9.  Categoria          10. Arbitro           11. ArbitroIdioma   12. DesignacionArbitral
          13. Sancion            14. ReglaClasificacion
          ArbitroIdioma es una tabla asociativa (PK compuesta): solo tiene alta y baja, no modificación.
          ReglaClasificacion tiene una sola fila (IdRegla = 1): su alta solo funciona si no existe.
          Las validaciones que comparten el alta y la modificación (o la modificación y la baja)
          están en funciones nucleo.fn_Validar*: no hay código repetido entre los SP.
          Requiere ejecutados los scripts 01 a 18.
          Test correspondiente: testing/19_Test_SP_ABM_Nucleo.sql.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- FUNCIONES DE VALIDACIÓN COMPARTIDAS
-- Cada una devuelve el texto de las condiciones incumplidas (cada línea empieza con "- " y
-- termina con CHAR(13) + CHAR(10)); cadena vacía si todo está bien. @idExcluido es el registro
-- que se está modificando (NULL en el alta), para no compararlo consigo mismo.
-- =========================================================================

-- Confederacion (alta y modificación).
CREATE OR ALTER FUNCTION nucleo.fn_ValidarConfederacion (@idExcluido INT, @nombre VARCHAR(100), @sigla VARCHAR(8))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombre IS NULL OR @nombre = ''
        SET @errores += N'- El nombre de la confederación es obligatorio.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM nucleo.Confederacion
                    WHERE Nombre = @nombre
                      AND (@idExcluido IS NULL OR IdConfederacion <> @idExcluido))
        SET @errores += N'- Ya existe otra confederación con ese nombre.' + @salto;

    IF @sigla IS NULL OR @sigla = ''
        SET @errores += N'- La sigla de la confederación es obligatoria.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM nucleo.Confederacion
                    WHERE Sigla = @sigla
                      AND (@idExcluido IS NULL OR IdConfederacion <> @idExcluido))
        SET @errores += N'- Ya existe otra confederación con esa sigla.' + @salto;

    RETURN @errores;
END;
GO

-- Pais (alta y modificación).
CREATE OR ALTER FUNCTION nucleo.fn_ValidarPais
(
    @idExcluido           INT,
    @nombre               VARCHAR(50),
    @codigoISO2           CHAR(2),
    @codigoISO3           CHAR(3),
    @idConfederacion      INT,
    @husoHorarioComercial VARCHAR(50),
    @pbiPerCapitaUSD      DECIMAL(10,2)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombre IS NULL OR @nombre = ''
        SET @errores += N'- El nombre del país es obligatorio.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM nucleo.Pais
                    WHERE Nombre = @nombre
                      AND (@idExcluido IS NULL OR IdPais <> @idExcluido))
        SET @errores += N'- Ya existe otro país con ese nombre.' + @salto;

    IF @codigoISO2 IS NULL OR @codigoISO2 NOT LIKE '[A-Z][A-Z]'
        SET @errores += N'- El código ISO2 es obligatorio y debe tener exactamente 2 letras (A-Z).' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM nucleo.Pais
                    WHERE CodigoISO2 = @codigoISO2
                      AND (@idExcluido IS NULL OR IdPais <> @idExcluido))
        SET @errores += N'- Ya existe otro país con ese código ISO2.' + @salto;

    IF @codigoISO3 IS NULL OR @codigoISO3 NOT LIKE '[A-Z][A-Z][A-Z]'
        SET @errores += N'- El código ISO3 es obligatorio y debe tener exactamente 3 letras (A-Z).' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM nucleo.Pais
                    WHERE CodigoISO3 = @codigoISO3
                      AND (@idExcluido IS NULL OR IdPais <> @idExcluido))
        SET @errores += N'- Ya existe otro país con ese código ISO3.' + @salto;

    IF @idConfederacion IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Confederacion WHERE IdConfederacion = @idConfederacion)
        SET @errores += N'- La confederación indicada no existe.' + @salto;

    IF @husoHorarioComercial IS NULL OR @husoHorarioComercial = ''
       OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @husoHorarioComercial)
        SET @errores += N'- El huso horario comercial no es válido (debe existir en sys.time_zone_info).' + @salto;

    IF @pbiPerCapitaUSD IS NOT NULL AND @pbiPerCapitaUSD < 0
        SET @errores += N'- El PBI per cápita no puede ser negativo.' + @salto;

    RETURN @errores;
END;
GO

-- Huso horario que se guarda para una ciudad: el informado o, si no se informó, el comercial de su país.
-- NULL si el país no existe.
CREATE OR ALTER FUNCTION nucleo.fn_HusoHorarioEfectivoCiudad (@husoHorario VARCHAR(50), @idPais INT)
RETURNS VARCHAR(50)
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
                THEN COALESCE(@husoHorario, (SELECT HusoHorarioComercial FROM nucleo.Pais WHERE IdPais = @idPais))
           END;
END;
GO

-- Ciudad (alta y modificación).
CREATE OR ALTER FUNCTION nucleo.fn_ValidarCiudad (@idExcluido INT, @nombre VARCHAR(100), @idPais INT, @husoHorario VARCHAR(50))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores             NVARCHAR(MAX) = N'',
            @salto               NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @husoHorarioEfectivo VARCHAR(50)   = nucleo.fn_HusoHorarioEfectivoCiudad(@husoHorario, @idPais);

    IF @nombre IS NULL OR @nombre = ''
        SET @errores += N'- El nombre de la ciudad es obligatorio.' + @salto;

    IF @idPais IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
        SET @errores += N'- El país indicado no existe.' + @salto;

    IF @husoHorario IS NOT NULL AND (@husoHorario = '' OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @husoHorario))
        SET @errores += N'- El huso horario de la ciudad no es válido (debe existir en sys.time_zone_info).' + @salto;
    ELSE IF @idPais IS NOT NULL AND (@husoHorarioEfectivo IS NULL OR @husoHorarioEfectivo = '')
        SET @errores += N'- El huso horario de la ciudad es obligatorio.' + @salto;

    IF @nombre IS NOT NULL AND @nombre <> '' AND @idPais IS NOT NULL
       AND EXISTS (SELECT 1
                   FROM nucleo.Ciudad
                   WHERE IdPais = @idPais
                     AND Nombre = @nombre
                     AND (@idExcluido IS NULL OR IdCiudad <> @idExcluido))
        SET @errores += N'- Ya existe otra ciudad con ese nombre en el mismo país.' + @salto;

    RETURN @errores;
END;
GO

-- Fase (alta y modificación).
CREATE OR ALTER FUNCTION nucleo.fn_ValidarFase (@idExcluido INT, @nombre VARCHAR(28), @orden INT, @esEliminatoria BIT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombre IS NULL
       OR @nombre NOT IN (
           'Fase de grupos',
           'Dieciseisavos de final',
           'Octavos de final',
           'Cuartos de final',
           'Semifinal',
           'Tercer puesto',
           'Final'
       )
        SET @errores += N'- El nombre es obligatorio y debe ser: Fase de grupos, Dieciseisavos de final, Octavos de final, Cuartos de final, Semifinal, Tercer puesto o Final.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM nucleo.Fase
                    WHERE Nombre = @nombre
                      AND (@idExcluido IS NULL OR IdFase <> @idExcluido))
        SET @errores += N'- Ya existe otra fase con ese nombre.' + @salto;

    IF @orden IS NULL OR @orden NOT BETWEEN 1 AND 7
        SET @errores += N'- El orden es obligatorio y debe estar entre 1 y 7.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM nucleo.Fase
                    WHERE Orden = @orden
                      AND (@idExcluido IS NULL OR IdFase <> @idExcluido))
        SET @errores += N'- Ya existe otra fase con ese número de orden.' + @salto;

    IF @esEliminatoria IS NULL
        SET @errores += N'- Debe indicar si la fase es eliminatoria (0 o 1).' + @salto;

    RETURN @errores;
END;
GO

-- Grupo (alta y modificación).
CREATE OR ALTER FUNCTION nucleo.fn_ValidarGrupo (@idExcluido INT, @nombre VARCHAR(10))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombre IS NULL OR @nombre NOT LIKE '[A-Z]'
        SET @errores += N'- El nombre del grupo es obligatorio y debe ser una única letra (A-Z).' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM nucleo.Grupo
                    WHERE Nombre = @nombre
                      AND (@idExcluido IS NULL OR IdGrupo <> @idExcluido))
        SET @errores += N'- Ya existe otro grupo con ese nombre.' + @salto;

    RETURN @errores;
END;
GO

-- Seleccion (alta y modificación).
CREATE OR ALTER FUNCTION nucleo.fn_ValidarSeleccion
(
    @idExcluido  INT,
    @codigoFIFA  CHAR(3),
    @rankingFIFA SMALLINT,
    @idPais      INT,
    @idGrupo     INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @codigoFIFA IS NULL OR @codigoFIFA NOT LIKE '[A-Z][A-Z][A-Z]'
        SET @errores += N'- El código FIFA es obligatorio y debe tener exactamente 3 letras (A-Z).' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM nucleo.Seleccion
                    WHERE CodigoFIFA = @codigoFIFA
                      AND (@idExcluido IS NULL OR IdSeleccion <> @idExcluido))
        SET @errores += N'- Ya existe otra selección con ese código FIFA.' + @salto;

    IF @rankingFIFA IS NULL OR @rankingFIFA <= 0
        SET @errores += N'- El ranking FIFA es obligatorio y debe ser mayor a cero.' + @salto;

    IF @idPais IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
        SET @errores += N'- El país indicado no existe.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM nucleo.Seleccion
                    WHERE IdPais = @idPais
                      AND (@idExcluido IS NULL OR IdSeleccion <> @idExcluido))
        SET @errores += N'- Ya existe otra selección registrada para ese país.' + @salto;

    IF @idGrupo IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE IdGrupo = @idGrupo)
        SET @errores += N'- El grupo es obligatorio y debe existir.' + @salto;

    RETURN @errores;
END;
GO

-- StaffTecnico (alta y modificación). Respeta UQ_StaffTecnico_IdSeleccion_Rol (un integrante por rol y selección).
CREATE OR ALTER FUNCTION nucleo.fn_ValidarStaffTecnico (@idExcluido INT, @idSeleccion INT, @nombreApellido VARCHAR(200), @rol VARCHAR(25))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idSeleccion IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccion)
        SET @errores += N'- La selección indicada no existe.' + @salto;

    IF @nombreApellido IS NULL OR @nombreApellido = ''
        SET @errores += N'- El nombre y apellido es obligatorio.' + @salto;

    IF @rol IS NULL OR @rol NOT IN ('Director Técnico', 'Ayudante de campo 1', 'Ayudante de campo 2')
        SET @errores += N'- El rol es obligatorio y debe ser: Director Técnico, Ayudante de campo 1 o Ayudante de campo 2.' + @salto;
    ELSE IF @idSeleccion IS NOT NULL
            AND EXISTS (SELECT 1
                        FROM nucleo.StaffTecnico
                        WHERE IdSeleccion = @idSeleccion
                          AND Rol = @rol
                          AND (@idExcluido IS NULL OR IdStaffTecnico <> @idExcluido))
        SET @errores += N'- La selección ya tiene asignado un integrante para ese rol.' + @salto;

    RETURN @errores;
END;
GO

-- Idioma (alta y modificación).
CREATE OR ALTER FUNCTION nucleo.fn_ValidarIdioma (@idExcluido INT, @nombre VARCHAR(100))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombre IS NULL OR @nombre = ''
        SET @errores += N'- El nombre del idioma es obligatorio.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM nucleo.Idioma
                    WHERE Nombre = @nombre
                      AND (@idExcluido IS NULL OR IdIdioma <> @idExcluido))
        SET @errores += N'- Ya existe otro idioma con ese nombre.' + @salto;

    RETURN @errores;
END;
GO

-- Categoria (alta y modificación).
CREATE OR ALTER FUNCTION nucleo.fn_ValidarCategoria (@idExcluido INT, @nombre VARCHAR(100))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombre IS NULL OR @nombre = ''
        SET @errores += N'- El nombre de la categoría es obligatorio.' + @salto;
    ELSE IF EXISTS (SELECT 1
                    FROM nucleo.Categoria
                    WHERE Nombre = @nombre
                      AND (@idExcluido IS NULL OR IdCategoria <> @idExcluido))
        SET @errores += N'- Ya existe otra categoría con ese nombre.' + @salto;

    RETURN @errores;
END;
GO

-- Arbitro (alta y modificación).
CREATE OR ALTER FUNCTION nucleo.fn_ValidarArbitro
(
    @nombreApellido  VARCHAR(200),
    @sexo            CHAR(1),
    @estaHabilitado  CHAR(1),
    @fechaNacimiento DATE,
    @idPais          INT,
    @idCategoria     INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @nombreApellido IS NULL OR @nombreApellido = ''
        SET @errores += N'- El nombre y apellido del árbitro es obligatorio.' + @salto;

    IF @sexo IS NOT NULL AND @sexo NOT IN ('M', 'F')
        SET @errores += N'- El sexo debe ser M o F.' + @salto;

    IF @estaHabilitado NOT IN ('Y', 'N')
        SET @errores += N'- El estado de habilitación debe ser Y o N.' + @salto;

    IF @fechaNacimiento IS NULL
        SET @errores += N'- La fecha de nacimiento es obligatoria.' + @salto;
    ELSE IF @fechaNacimiento < '1930-01-01' OR @fechaNacimiento >= CAST(GETDATE() AS DATE)
        SET @errores += N'- La fecha de nacimiento debe ser mayor o igual a 1930-01-01 y anterior a hoy.' + @salto;

    IF @idPais IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
        SET @errores += N'- El país indicado no existe.' + @salto;

    IF @idCategoria IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Categoria WHERE IdCategoria = @idCategoria)
        SET @errores += N'- La categoría indicada no existe.' + @salto;

    RETURN @errores;
END;
GO

-- ArbitroIdioma (alta y baja): el árbitro y el idioma existen.
CREATE OR ALTER FUNCTION nucleo.fn_ValidarArbitroIdioma (@idArbitro INT, @idIdioma INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idArbitro IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdArbitro = @idArbitro)
        SET @errores += N'- El árbitro indicado no existe.' + @salto;

    IF @idIdioma IS NULL OR NOT EXISTS (SELECT 1 FROM nucleo.Idioma WHERE IdIdioma = @idIdioma)
        SET @errores += N'- El idioma indicado no existe.' + @salto;

    RETURN @errores;
END;
GO

-- DesignacionArbitral (modificación y baja): la designación existe y su partido no está finalizado.
CREATE OR ALTER FUNCTION nucleo.fn_ValidarDesignacionEditable (@idDesignacionArbitral INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartidoActual INT,
            @estadoActual    VARCHAR(10);

    SELECT @idPartidoActual = d.IdPartido,
           @estadoActual    = p.Estado
    FROM nucleo.DesignacionArbitral AS d
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido
    WHERE d.IdDesignacionArbitral = @idDesignacionArbitral;

    IF @idPartidoActual IS NULL
        SET @errores += N'- La designación arbitral indicada no existe.' + @salto;
    ELSE IF @estadoActual = 'Finalizado'
        SET @errores += N'- El partido de la designación ya está finalizado: no se puede modificar ni eliminar.' + @salto;

    RETURN @errores;
END;
GO

-- Sancion (alta y modificación). @fechaEfectiva ya viene resuelta (la informada o la de hoy).
CREATE OR ALTER FUNCTION nucleo.fn_ValidarSancion
(
    @idDesignacionArbitral INT,
    @tipo                  VARCHAR(20),
    @descripcion           VARCHAR(300),
    @fechaEfectiva         DATE
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores      NVARCHAR(MAX) = N'',
            @salto        NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @fechaPartido DATE;

    SELECT @fechaPartido = CAST(p.FechaHoraUTC AS DATE)
    FROM nucleo.DesignacionArbitral AS d
    INNER JOIN nucleo.Partido AS p ON p.IdPartido = d.IdPartido
    WHERE d.IdDesignacionArbitral = @idDesignacionArbitral;

    IF @fechaPartido IS NULL
        SET @errores += N'- La designación arbitral indicada no existe.' + @salto;
    ELSE IF @fechaEfectiva < @fechaPartido
        SET @errores += N'- La fecha de la sanción/informe no puede ser anterior a la fecha del partido.' + @salto;

    IF @tipo IS NULL OR @tipo NOT IN ('Suspension Temporal', 'Inhabilitacion', 'Multa', 'Advertencia', 'Informe')
        SET @errores += N'- El tipo es obligatorio y debe ser: Suspension Temporal, Inhabilitacion, Multa, Advertencia o Informe.' + @salto;

    IF @descripcion IS NULL OR @descripcion = ''
        SET @errores += N'- La descripción de la sanción o informe es obligatoria.' + @salto;

    RETURN @errores;
END;
GO

-- ReglaClasificacion (alta y modificación). El total de clasificados depende de los grupos que tienen
-- selecciones: grupos x ClasificadosPorGrupo + MejoresTerceros debe ser 8, 16 o 32 (ver nucleo.fn_FaseEliminatoriaInicial).
CREATE OR ALTER FUNCTION nucleo.fn_ValidarReglaClasificacion (@clasificadosPorGrupo INT, @mejoresTerceros INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores        NVARCHAR(MAX) = N'',
            @salto          NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @grupos         INT,
            @minSelecciones INT,
            @candidatos     INT,
            @total          INT;

    IF @clasificadosPorGrupo IS NULL OR @clasificadosPorGrupo NOT BETWEEN 1 AND 255
        SET @errores += N'- ClasificadosPorGrupo es obligatorio y debe estar entre 1 y 255.' + @salto;

    IF @mejoresTerceros IS NULL OR @mejoresTerceros NOT BETWEEN 0 AND 255
        SET @errores += N'- MejoresTerceros es obligatorio y debe estar entre 0 y 255.' + @salto;

    IF LEN(@errores) = 0
    BEGIN
        SELECT @grupos = COUNT(*), @minSelecciones = MIN(g.Cantidad)
        FROM (SELECT IdGrupo, COUNT(*) AS Cantidad FROM nucleo.Seleccion GROUP BY IdGrupo) AS g;

        IF @grupos = 0
            SET @errores += N'- No hay selecciones asignadas a grupos: no se puede validar el cupo de clasificados.' + @salto;
        ELSE
        BEGIN
            IF @clasificadosPorGrupo > @minSelecciones
                SET @errores += N'- ClasificadosPorGrupo (' + CAST(@clasificadosPorGrupo AS NVARCHAR(10))
                              + N') supera las selecciones del grupo más chico (' + CAST(@minSelecciones AS NVARCHAR(10)) + N').' + @salto;

            -- Candidatos al cupo adicional: grupos con selecciones en el puesto ClasificadosPorGrupo + 1.
            SELECT @candidatos = COUNT(*)
            FROM (SELECT IdGrupo FROM nucleo.Seleccion GROUP BY IdGrupo HAVING COUNT(*) > @clasificadosPorGrupo) AS c;

            IF @mejoresTerceros > @candidatos
                SET @errores += N'- MejoresTerceros (' + CAST(@mejoresTerceros AS NVARCHAR(10))
                              + N') supera los grupos que tienen selecciones en el puesto siguiente a los directos (' + CAST(@candidatos AS NVARCHAR(10)) + N').' + @salto;

            SET @total = @grupos * @clasificadosPorGrupo + @mejoresTerceros;
            IF @total NOT IN (8, 16, 32)
                SET @errores += N'- El total de clasificados (' + CAST(@grupos AS NVARCHAR(10)) + N' grupos x '
                              + CAST(@clasificadosPorGrupo AS NVARCHAR(10)) + N' + ' + CAST(@mejoresTerceros AS NVARCHAR(10))
                              + N' = ' + CAST(@total AS NVARCHAR(10)) + N') debe ser 8, 16 o 32.' + @salto;
        END;
    END;

    RETURN @errores;
END;
GO

-- =========================================================================
-- 1. Confederacion
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_Confederacion
    @idConfederacion INT          = NULL OUTPUT,
    @nombre          VARCHAR(100) = NULL,
    @sigla           VARCHAR(8)   = NULL,
    @region          VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = LTRIM(RTRIM(@nombre));
    SET @sigla  = UPPER(LTRIM(RTRIM(@sigla)));
    SET @region = NULLIF(LTRIM(RTRIM(@region)), '');

    SET @errores = nucleo.fn_ValidarConfederacion(NULL, @nombre, @sigla);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Confederacion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.Confederacion (Nombre, Sigla, Region) VALUES (@nombre, @sigla, @region);
        SET @idConfederacion = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_Confederacion
    @idConfederacion INT          = NULL,
    @nombre          VARCHAR(100) = NULL,
    @sigla           VARCHAR(8)   = NULL,
    @region          VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = LTRIM(RTRIM(@nombre));
    SET @sigla  = UPPER(LTRIM(RTRIM(@sigla)));
    SET @region = NULLIF(LTRIM(RTRIM(@region)), '');

    IF @idConfederacion IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Confederacion WHERE IdConfederacion = @idConfederacion)
        SET @errores += N'- La confederación indicada no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarConfederacion(@idConfederacion, @nombre, @sigla);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Confederacion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.Confederacion
        SET Nombre = @nombre,
            Sigla  = @sigla,
            Region = @region
        WHERE IdConfederacion = @idConfederacion;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_Confederacion
    @idConfederacion INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idConfederacion IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Confederacion WHERE IdConfederacion = @idConfederacion)
        SET @errores += N'- La confederación indicada no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdConfederacion = @idConfederacion)
        SET @errores += N'- La confederación tiene países asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Confederacion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.Confederacion WHERE IdConfederacion = @idConfederacion;
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
-- 2. Pais
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_Pais
    @idPais               INT           = NULL OUTPUT,
    @nombre               VARCHAR(50)   = NULL,
    @codigoISO2           CHAR(2)       = NULL,
    @codigoISO3           CHAR(3)       = NULL,
    @idConfederacion      INT           = NULL,
    @husoHorarioComercial VARCHAR(50)   = NULL,
    @pbiPerCapitaUSD      DECIMAL(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre               = LTRIM(RTRIM(@nombre));
    SET @codigoISO2           = UPPER(LTRIM(RTRIM(@codigoISO2)));
    SET @codigoISO3           = UPPER(LTRIM(RTRIM(@codigoISO3)));
    SET @husoHorarioComercial = LTRIM(RTRIM(@husoHorarioComercial));

    SET @errores = nucleo.fn_ValidarPais(NULL, @nombre, @codigoISO2, @codigoISO3, @idConfederacion,
                                         @husoHorarioComercial, @pbiPerCapitaUSD);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Pais - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, HusoHorarioComercial, PBIPerCapitaUSD)
        VALUES (@nombre, @codigoISO2, @codigoISO3, @idConfederacion, @husoHorarioComercial, @pbiPerCapitaUSD);
        SET @idPais = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_Pais
    @idPais               INT           = NULL,
    @nombre               VARCHAR(50)   = NULL,
    @codigoISO2           CHAR(2)       = NULL,
    @codigoISO3           CHAR(3)       = NULL,
    @idConfederacion      INT           = NULL,
    @husoHorarioComercial VARCHAR(50)   = NULL,
    @pbiPerCapitaUSD      DECIMAL(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre               = LTRIM(RTRIM(@nombre));
    SET @codigoISO2           = UPPER(LTRIM(RTRIM(@codigoISO2)));
    SET @codigoISO3           = UPPER(LTRIM(RTRIM(@codigoISO3)));
    SET @husoHorarioComercial = LTRIM(RTRIM(@husoHorarioComercial));

    IF @idPais IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
        SET @errores += N'- El país indicado no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarPais(@idPais, @nombre, @codigoISO2, @codigoISO3, @idConfederacion,
                                          @husoHorarioComercial, @pbiPerCapitaUSD);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Pais - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.Pais
        SET Nombre               = @nombre,
            CodigoISO2           = @codigoISO2,
            CodigoISO3           = @codigoISO3,
            IdConfederacion      = @idConfederacion,
            HusoHorarioComercial = @husoHorarioComercial,
            PBIPerCapitaUSD      = @pbiPerCapitaUSD
        WHERE IdPais = @idPais;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_Pais
    @idPais INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idPais IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE IdPais = @idPais)
        SET @errores += N'- El país indicado no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM nucleo.Ciudad WHERE IdPais = @idPais)
        SET @errores += N'- El país tiene ciudades asociadas y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdPais = @idPais)
        SET @errores += N'- El país tiene una selección registrada y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdPais = @idPais)
        SET @errores += N'- El país tiene árbitros asociados y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE IdPais = @idPais)
        SET @errores += N'- El país tiene anunciantes asociados y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM publicidad.OrientacionPais WHERE IdPais = @idPais)
        SET @errores += N'- El país está asociado a orientaciones de piezas publicitarias y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Pais - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.Pais WHERE IdPais = @idPais;
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
-- 3. Ciudad
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_Ciudad
    @idCiudad    INT          = NULL OUTPUT,
    @nombre      VARCHAR(100) = NULL,
    @idPais      INT          = NULL,
    @husoHorario VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre      = LTRIM(RTRIM(@nombre));
    SET @husoHorario = LTRIM(RTRIM(@husoHorario));

    SET @errores = nucleo.fn_ValidarCiudad(NULL, @nombre, @idPais, @husoHorario);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Ciudad - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
        VALUES (@nombre, nucleo.fn_HusoHorarioEfectivoCiudad(@husoHorario, @idPais), @idPais);
        SET @idCiudad = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_Ciudad
    @idCiudad    INT          = NULL,
    @nombre      VARCHAR(100) = NULL,
    @idPais      INT          = NULL,
    @husoHorario VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre      = LTRIM(RTRIM(@nombre));
    SET @husoHorario = LTRIM(RTRIM(@husoHorario));

    IF @idCiudad IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Ciudad WHERE IdCiudad = @idCiudad)
        SET @errores += N'- La ciudad indicada no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarCiudad(@idCiudad, @nombre, @idPais, @husoHorario);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Ciudad - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.Ciudad
        SET Nombre      = @nombre,
            HusoHorario = nucleo.fn_HusoHorarioEfectivoCiudad(@husoHorario, @idPais),
            IdPais      = @idPais
        WHERE IdCiudad = @idCiudad;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_Ciudad
    @idCiudad INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idCiudad IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Ciudad WHERE IdCiudad = @idCiudad)
        SET @errores += N'- La ciudad indicada no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM nucleo.Sede WHERE IdCiudad = @idCiudad)
        SET @errores += N'- La ciudad tiene sedes asociadas y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Ciudad - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.Ciudad WHERE IdCiudad = @idCiudad;
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
-- 4. Fase
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_Fase
    @idFase         INT         = NULL OUTPUT,
    @nombre         VARCHAR(28) = NULL,
    @orden          INT         = NULL,
    @esEliminatoria BIT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = LTRIM(RTRIM(@nombre));

    SET @errores = nucleo.fn_ValidarFase(NULL, @nombre, @orden, @esEliminatoria);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Fase - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.Fase (Nombre, Orden, EsEliminatoria) VALUES (@nombre, @orden, @esEliminatoria);
        SET @idFase = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_Fase
    @idFase         INT         = NULL,
    @nombre         VARCHAR(28) = NULL,
    @orden          INT         = NULL,
    @esEliminatoria BIT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = LTRIM(RTRIM(@nombre));

    IF @idFase IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE IdFase = @idFase)
        SET @errores += N'- La fase indicada no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarFase(@idFase, @nombre, @orden, @esEliminatoria);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Fase - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.Fase
        SET Nombre         = @nombre,
            Orden          = @orden,
            EsEliminatoria = @esEliminatoria
        WHERE IdFase = @idFase;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_Fase
    @idFase INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idFase IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE IdFase = @idFase)
        SET @errores += N'- La fase indicada no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdFase = @idFase)
        SET @errores += N'- La fase tiene partidos asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Fase - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.Fase WHERE IdFase = @idFase;
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
-- 5. Grupo
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_Grupo
    @idGrupo INT         = NULL OUTPUT,
    @nombre  VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = UPPER(LTRIM(RTRIM(@nombre)));

    SET @errores = nucleo.fn_ValidarGrupo(NULL, @nombre);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Grupo - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.Grupo (Nombre) VALUES (@nombre);
        SET @idGrupo = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_Grupo
    @idGrupo INT         = NULL,
    @nombre  VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = UPPER(LTRIM(RTRIM(@nombre)));

    IF @idGrupo IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE IdGrupo = @idGrupo)
        SET @errores += N'- El grupo indicado no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarGrupo(@idGrupo, @nombre);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Grupo - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.Grupo SET Nombre = @nombre WHERE IdGrupo = @idGrupo;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_Grupo
    @idGrupo INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idGrupo IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE IdGrupo = @idGrupo)
        SET @errores += N'- El grupo indicado no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdGrupo = @idGrupo)
        SET @errores += N'- El grupo tiene selecciones asignadas y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Grupo - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.Grupo WHERE IdGrupo = @idGrupo;
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
-- 6. Seleccion
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_Seleccion
    @idSeleccion INT      = NULL OUTPUT,
    @codigoFIFA  CHAR(3)  = NULL,
    @rankingFIFA SMALLINT = NULL,
    @esAnfitrion BIT      = 0,
    @idPais      INT      = NULL,
    @idGrupo     INT      = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @codigoFIFA  = UPPER(LTRIM(RTRIM(@codigoFIFA)));
    SET @esAnfitrion = ISNULL(@esAnfitrion, 0);

    SET @errores = nucleo.fn_ValidarSeleccion(NULL, @codigoFIFA, @rankingFIFA, @idPais, @idGrupo);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Seleccion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
        VALUES (@codigoFIFA, @rankingFIFA, @esAnfitrion, @idPais, @idGrupo);
        SET @idSeleccion = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_Seleccion
    @idSeleccion INT      = NULL,
    @codigoFIFA  CHAR(3)  = NULL,
    @rankingFIFA SMALLINT = NULL,
    @esAnfitrion BIT      = 0,
    @idPais      INT      = NULL,
    @idGrupo     INT      = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @codigoFIFA  = UPPER(LTRIM(RTRIM(@codigoFIFA)));
    SET @esAnfitrion = ISNULL(@esAnfitrion, 0);

    IF @idSeleccion IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccion)
        SET @errores += N'- La selección indicada no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarSeleccion(@idSeleccion, @codigoFIFA, @rankingFIFA, @idPais, @idGrupo);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Seleccion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.Seleccion
        SET CodigoFIFA  = @codigoFIFA,
            RankingFIFA = @rankingFIFA,
            EsAnfitrion = @esAnfitrion,
            IdPais      = @idPais,
            IdGrupo     = @idGrupo
        WHERE IdSeleccion = @idSeleccion;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_Seleccion
    @idSeleccion INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idSeleccion IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccion)
        SET @errores += N'- La selección indicada no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM nucleo.StaffTecnico WHERE IdSeleccion = @idSeleccion)
        SET @errores += N'- La selección tiene cuerpo técnico registrado y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE IdSeleccionLocal = @idSeleccion OR IdSeleccionVisitante = @idSeleccion)
        SET @errores += N'- La selección tiene partidos asociados y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM jugadores.Convocatoria WHERE IdSeleccion = @idSeleccion)
        SET @errores += N'- La selección tiene jugadores convocados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Seleccion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.Seleccion WHERE IdSeleccion = @idSeleccion;
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
-- 7. StaffTecnico
-- Respeta la restricción única UQ_StaffTecnico_IdSeleccion_Rol (un integrante por rol y selección).
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
        INSERT INTO nucleo.StaffTecnico (IdSeleccion, NombreApellido, Rol) VALUES (@idSeleccion, @nombreApellido, @rol);
        SET @idStaffTecnico = SCOPE_IDENTITY();
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
        SET @errores += N'- El integrante del cuerpo técnico indicado no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarStaffTecnico(@idStaffTecnico, @idSeleccion, @nombreApellido, @rol);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_StaffTecnico - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.StaffTecnico
        SET IdSeleccion    = @idSeleccion,
            NombreApellido = @nombreApellido,
            Rol            = @rol
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

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_StaffTecnico
    @idStaffTecnico INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idStaffTecnico IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.StaffTecnico WHERE IdStaffTecnico = @idStaffTecnico)
        SET @errores += N'- El integrante del cuerpo técnico indicado no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdStaffTecnico = @idStaffTecnico)
        SET @errores += N'- El integrante del staff técnico registra amonestaciones y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_StaffTecnico - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.StaffTecnico WHERE IdStaffTecnico = @idStaffTecnico;
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
-- 8. Idioma
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_Idioma
    @idIdioma INT          = NULL OUTPUT,
    @nombre   VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = LTRIM(RTRIM(@nombre));

    SET @errores = nucleo.fn_ValidarIdioma(NULL, @nombre);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Idioma - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.Idioma (Nombre) VALUES (@nombre);
        SET @idIdioma = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_Idioma
    @idIdioma INT          = NULL,
    @nombre   VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = LTRIM(RTRIM(@nombre));

    IF @idIdioma IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Idioma WHERE IdIdioma = @idIdioma)
        SET @errores += N'- El idioma indicado no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarIdioma(@idIdioma, @nombre);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Idioma - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.Idioma SET Nombre = @nombre WHERE IdIdioma = @idIdioma;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_Idioma
    @idIdioma INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idIdioma IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Idioma WHERE IdIdioma = @idIdioma)
        SET @errores += N'- El idioma indicado no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM nucleo.ArbitroIdioma WHERE IdIdioma = @idIdioma)
        SET @errores += N'- El idioma está asociado a árbitros y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM publicidad.Pieza WHERE IdIdioma = @idIdioma)
        SET @errores += N'- El idioma está asociado a piezas publicitarias y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Idioma - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.Idioma WHERE IdIdioma = @idIdioma;
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
-- 9. Categoria
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_Categoria
    @idCategoria INT          = NULL OUTPUT,
    @nombre      VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = LTRIM(RTRIM(@nombre));

    SET @errores = nucleo.fn_ValidarCategoria(NULL, @nombre);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Categoria - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.Categoria (Nombre) VALUES (@nombre);
        SET @idCategoria = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_Categoria
    @idCategoria INT          = NULL,
    @nombre      VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @nombre = LTRIM(RTRIM(@nombre));

    IF @idCategoria IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Categoria WHERE IdCategoria = @idCategoria)
        SET @errores += N'- La categoría indicada no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarCategoria(@idCategoria, @nombre);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Categoria - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.Categoria SET Nombre = @nombre WHERE IdCategoria = @idCategoria;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_Categoria
    @idCategoria INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idCategoria IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Categoria WHERE IdCategoria = @idCategoria)
        SET @errores += N'- La categoría indicada no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdCategoria = @idCategoria)
        SET @errores += N'- La categoría tiene árbitros asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Categoria - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.Categoria WHERE IdCategoria = @idCategoria;
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
-- 10. Arbitro
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
        INSERT INTO nucleo.Arbitro (NombreApellido, Sexo, EstaHabilitado, FechaNacimiento, IdPais, IdCategoria)
        VALUES (@nombreApellido, @sexo, @estaHabilitado, @fechaNacimiento, @idPais, @idCategoria);
        SET @idArbitro = SCOPE_IDENTITY();
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
        UPDATE nucleo.Arbitro
        SET NombreApellido  = @nombreApellido,
            Sexo            = @sexo,
            EstaHabilitado  = @estaHabilitado,
            FechaNacimiento = @fechaNacimiento,
            IdPais          = @idPais,
            IdCategoria     = @idCategoria
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

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_Arbitro
    @idArbitro INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idArbitro IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdArbitro = @idArbitro)
        SET @errores += N'- El árbitro indicado no existe.' + @salto;

    IF EXISTS (SELECT 1 FROM nucleo.DesignacionArbitral WHERE IdArbitro = @idArbitro)
        SET @errores += N'- El árbitro tiene designaciones arbitrales registradas y no puede eliminarse.' + @salto;
    IF EXISTS (SELECT 1 FROM nucleo.ArbitroIdioma WHERE IdArbitro = @idArbitro)
        SET @errores += N'- El árbitro tiene idiomas asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Arbitro - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.Arbitro WHERE IdArbitro = @idArbitro;
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
-- 11. ArbitroIdioma
-- Tabla asociativa (PK compuesta IdArbitro, IdIdioma): solo tiene alta y baja (no hay nada que modificar:
-- para cambiar un idioma se da de baja y de alta).
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_ArbitroIdioma
    @idArbitro INT,
    @idIdioma  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @errores = nucleo.fn_ValidarArbitroIdioma(@idArbitro, @idIdioma);

    IF @idArbitro IS NOT NULL AND @idIdioma IS NOT NULL
       AND EXISTS (SELECT 1 FROM nucleo.ArbitroIdioma WHERE IdArbitro = @idArbitro AND IdIdioma = @idIdioma)
        SET @errores += N'- El árbitro ya tiene registrado ese idioma.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_ArbitroIdioma - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.ArbitroIdioma (IdArbitro, IdIdioma) VALUES (@idArbitro, @idIdioma);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_ArbitroIdioma
    @idArbitro INT,
    @idIdioma  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @errores = nucleo.fn_ValidarArbitroIdioma(@idArbitro, @idIdioma);

    IF @idArbitro IS NOT NULL AND @idIdioma IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM nucleo.ArbitroIdioma WHERE IdArbitro = @idArbitro AND IdIdioma = @idIdioma)
        SET @errores += N'- El árbitro no tiene asociado ese idioma.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_ArbitroIdioma - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.ArbitroIdioma
        WHERE IdArbitro = @idArbitro
          AND IdIdioma  = @idIdioma;
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
-- 12. DesignacionArbitral
-- El alta delega en nucleo.SP_CONTROL_ARBITRAL (mismo patrón que eventos.SP_ALTA_Gol). La modificación y la
-- baja exigen que el partido no esté finalizado (nucleo.fn_ValidarDesignacionEditable).
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_DesignacionArbitral
    @idDesignacionArbitral INT          = NULL OUTPUT,
    @idPartido             INT          = NULL,
    @idArbitro             INT          = NULL,
    @rol                   VARCHAR(15)  = NULL,
    @advertencia           VARCHAR(200) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @advertencia = NULL;

    SET @rol = LTRIM(RTRIM(@rol));

    EXEC nucleo.SP_CONTROL_ARBITRAL
        @idPartido   = @idPartido,
        @idArbitro   = @idArbitro,
        @rol         = @rol,
        @advertencia = @advertencia OUTPUT;

    SELECT @idDesignacionArbitral = d.IdDesignacionArbitral
    FROM nucleo.DesignacionArbitral AS d
    WHERE d.IdPartido = @idPartido
      AND d.IdArbitro = @idArbitro;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_DesignacionArbitral
    @idDesignacionArbitral INT          = NULL,
    @idPartido             INT          = NULL,
    @idArbitro             INT          = NULL,
    @rol                   VARCHAR(15)  = NULL,
    @advertencia           VARCHAR(200) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @advertencia = NULL;

    SET @rol = LTRIM(RTRIM(@rol));

    DECLARE @errores           NVARCHAR(MAX),
            @mensaje           NVARCHAR(2048),
            @salto             NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idPartidoActual   INT,
            @idFaseDestino     INT,
            @nombreFaseDestino VARCHAR(50),
            @estadoDestino     VARCHAR(10),
            @idPaisArbitro     INT,
            @estaHabilitado    CHAR(1),
            @rolValido         BIT = 0,
            @maxPorRol         INT;

    SET @errores = nucleo.fn_ValidarDesignacionEditable(@idDesignacionArbitral);

    SELECT @idPartidoActual = d.IdPartido
    FROM nucleo.DesignacionArbitral AS d
    WHERE d.IdDesignacionArbitral = @idDesignacionArbitral;

    SELECT @idFaseDestino     = p.IdFase,
           @nombreFaseDestino = f.Nombre,
           @estadoDestino     = p.Estado
    FROM nucleo.Partido AS p
    INNER JOIN nucleo.Fase AS f ON f.IdFase = p.IdFase
    WHERE p.IdPartido = @idPartido;

    SELECT @idPaisArbitro  = a.IdPais,
           @estaHabilitado = a.EstaHabilitado
    FROM nucleo.Arbitro AS a
    WHERE a.IdArbitro = @idArbitro;

    IF @rol IS NULL OR @rol NOT IN ('Principal', 'Asistente 1', 'Asistente 2', 'Cuarto', 'VAR')
        SET @errores += N'- Rol inválido. Valores permitidos: Principal, Asistente 1, Asistente 2, Cuarto, VAR.' + @salto;
    ELSE
        SET @rolValido = 1;

    IF @idFaseDestino IS NULL
        SET @errores += N'- El partido indicado no existe.' + @salto;
    ELSE IF @estadoDestino = 'Finalizado' AND (@idPartidoActual IS NULL OR @idPartido <> @idPartidoActual)
        SET @errores += N'- El partido destino ya está finalizado.' + @salto;

    IF @idPaisArbitro IS NULL
        SET @errores += N'- El árbitro indicado no existe.' + @salto;
    ELSE IF @estaHabilitado <> 'Y'
        SET @errores += N'- El árbitro no está habilitado para ser designado.' + @salto;

    IF @idFaseDestino IS NOT NULL AND @idPaisArbitro IS NOT NULL
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM nucleo.fn_SeleccionesDelPartido(@idPartido) AS sp
            INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion
            WHERE s.IdPais = @idPaisArbitro
        )
            SET @errores += N'- Designación rechazada: el país del árbitro coincide con el de una de las selecciones del partido.' + @salto;

        IF EXISTS (
            SELECT 1
            FROM nucleo.DesignacionArbitral AS d
            WHERE d.IdPartido = @idPartido
              AND d.IdArbitro = @idArbitro
              AND d.IdDesignacionArbitral <> @idDesignacionArbitral
        )
            SET @errores += N'- El árbitro ya está designado en ese partido.' + @salto;
    END;

    IF @idFaseDestino IS NOT NULL AND @rolValido = 1
    BEGIN
        SET @maxPorRol = 1;

        IF (
            SELECT COUNT(*)
            FROM nucleo.DesignacionArbitral AS d
            WHERE d.IdPartido = @idPartido
              AND d.Rol = @rol
              AND d.IdDesignacionArbitral <> @idDesignacionArbitral
        ) >= @maxPorRol
            SET @errores += N'- El partido ya tiene cubiertos los lugares para ese rol.' + @salto;
    END;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_DesignacionArbitral - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.DesignacionArbitral
        SET IdPartido = @idPartido,
            IdArbitro = @idArbitro,
            Rol       = @rol
        WHERE IdDesignacionArbitral = @idDesignacionArbitral;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    IF @nombreFaseDestino IN ('Dieciseisavos de final', 'Octavos de final', 'Cuartos de final', 'Semifinal', 'Tercer puesto', 'Final')
       AND EXISTS (
            SELECT 1
            FROM nucleo.Partido AS p
            CROSS APPLY nucleo.fn_SeleccionesDelPartido(p.IdPartido) AS sp
            INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion
            WHERE p.IdFase = @idFaseDestino
              AND p.IdPartido <> @idPartido
              AND s.IdPais = @idPaisArbitro
       )
    BEGIN
        SET @advertencia = 'Advertencia: el país del árbitro tiene una selección que podría cruzarse con las de este partido.';
        PRINT @advertencia;
    END;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_DesignacionArbitral
    @idDesignacionArbitral INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX),
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    SET @errores = nucleo.fn_ValidarDesignacionEditable(@idDesignacionArbitral);

    IF EXISTS (SELECT 1 FROM nucleo.DesignacionArbitral WHERE IdDesignacionArbitral = @idDesignacionArbitral)
       AND EXISTS (SELECT 1 FROM nucleo.Sancion WHERE IdDesignacionArbitral = @idDesignacionArbitral)
        SET @errores += N'- La designación tiene sanciones o informes asociados y no puede eliminarse.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_DesignacionArbitral - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.DesignacionArbitral WHERE IdDesignacionArbitral = @idDesignacionArbitral;
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
-- 13. Sancion
-- Sanciones e informes post-partido recibidos por un árbitro.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_Sancion
    @idSancion             INT          = NULL OUTPUT,
    @idDesignacionArbitral INT          = NULL,
    @tipo                  VARCHAR(20)  = NULL,
    @descripcion           VARCHAR(300) = NULL,
    @fecha                 DATE         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores       NVARCHAR(MAX),
            @mensaje       NVARCHAR(2048),
            @salto         NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @fechaEfectiva DATE          = ISNULL(@fecha, CAST(GETDATE() AS DATE));

    SET @tipo        = LTRIM(RTRIM(@tipo));
    SET @descripcion = LTRIM(RTRIM(@descripcion));

    SET @errores = nucleo.fn_ValidarSancion(@idDesignacionArbitral, @tipo, @descripcion, @fechaEfectiva);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_Sancion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.Sancion (IdDesignacionArbitral, Tipo, Descripcion, Fecha)
        VALUES (@idDesignacionArbitral, @tipo, @descripcion, @fechaEfectiva);
        SET @idSancion = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_Sancion
    @idSancion             INT          = NULL,
    @idDesignacionArbitral INT          = NULL,
    @tipo                  VARCHAR(20)  = NULL,
    @descripcion           VARCHAR(300) = NULL,
    @fecha                 DATE         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores       NVARCHAR(MAX) = N'',
            @mensaje       NVARCHAR(2048),
            @salto         NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @fechaEfectiva DATE          = ISNULL(@fecha, CAST(GETDATE() AS DATE));

    SET @tipo        = LTRIM(RTRIM(@tipo));
    SET @descripcion = LTRIM(RTRIM(@descripcion));

    IF @idSancion IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Sancion WHERE IdSancion = @idSancion)
        SET @errores += N'- La sanción indicada no existe.' + @salto;

    SET @errores += nucleo.fn_ValidarSancion(@idDesignacionArbitral, @tipo, @descripcion, @fechaEfectiva);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_Sancion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.Sancion
        SET IdDesignacionArbitral = @idDesignacionArbitral,
            Tipo                  = @tipo,
            Descripcion           = @descripcion,
            Fecha                 = @fechaEfectiva
        WHERE IdSancion = @idSancion;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_Sancion
    @idSancion INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF @idSancion IS NULL
       OR NOT EXISTS (SELECT 1 FROM nucleo.Sancion WHERE IdSancion = @idSancion)
        SET @errores += N'- La sanción indicada no existe.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_Sancion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.Sancion WHERE IdSancion = @idSancion;
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
-- 14. ReglaClasificacion
-- Tabla de reglas de una sola fila (IdRegla = 1): sin identificador en los parámetros.
-- El alta solo funciona si no hay regla; la modificación valida que el total de clasificados que resulta
-- con los grupos y selecciones actuales sea 8, 16 o 32 (nucleo.fn_ValidarReglaClasificacion).
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ALTA_ReglaClasificacion
    @clasificadosPorGrupo INT = NULL,
    @mejoresTerceros      INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF EXISTS (SELECT 1 FROM nucleo.ReglaClasificacion)
        SET @errores += N'- Ya existe la regla de clasificación (es una sola): modifíquela con SP_MODIFICACION_ReglaClasificacion.' + @salto;

    SET @errores += nucleo.fn_ValidarReglaClasificacion(@clasificadosPorGrupo, @mejoresTerceros);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ALTA_ReglaClasificacion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO nucleo.ReglaClasificacion (IdRegla, ClasificadosPorGrupo, MejoresTerceros)
        VALUES (1, @clasificadosPorGrupo, @mejoresTerceros);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_MODIFICACION_ReglaClasificacion
    @clasificadosPorGrupo INT = NULL,
    @mejoresTerceros      INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF NOT EXISTS (SELECT 1 FROM nucleo.ReglaClasificacion)
        SET @errores += N'- No hay regla de clasificación cargada: cárguela con SP_ALTA_ReglaClasificacion.' + @salto;

    SET @errores += nucleo.fn_ValidarReglaClasificacion(@clasificadosPorGrupo, @mejoresTerceros);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_MODIFICACION_ReglaClasificacion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE nucleo.ReglaClasificacion
        SET ClasificadosPorGrupo = @clasificadosPorGrupo,
            MejoresTerceros      = @mejoresTerceros
        WHERE IdRegla = 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE nucleo.SP_BAJA_ReglaClasificacion
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'',
            @mensaje NVARCHAR(2048),
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10);

    IF NOT EXISTS (SELECT 1 FROM nucleo.ReglaClasificacion)
        SET @errores += N'- No hay regla de clasificación cargada.' + @salto;

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_BAJA_ReglaClasificacion - No se pudo completar la operación:' + @salto + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM nucleo.ReglaClasificacion WHERE IdRegla = 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
