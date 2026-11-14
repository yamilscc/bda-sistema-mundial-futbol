/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-14
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Crear las tablas del núcleo del sistema (requiere 00_Reset_Total.sql ya ejecutado):
          Confederacion, Pais, Ciudad, Sede, Fase, Grupo, Seleccion, StaffTecnico,
          Idioma, Categoria, Arbitro, ArbitroIdioma, Partido, DesignacionArbitral y Sancion.
          Las FK que cruzan módulos (Convocatoria, Formacion, Gol, etc.) están en 06_FK_Cruzadas.sql.
*/

-- La base y los schemas los crea 00_Reset_Total.sql (ejecutar siempre primero).
USE MundialFutbol;
GO

-- =========================================================================
-- CATÁLOGOS GEOGRÁFICOS
-- =========================================================================

IF OBJECT_ID('nucleo.Confederacion', 'U') IS NULL
CREATE TABLE nucleo.Confederacion (
    IdConfederacion INT IDENTITY(1,1) CONSTRAINT PK_Confederacion PRIMARY KEY,
    Nombre          VARCHAR(60) NOT NULL CONSTRAINT UQ_Confederacion_Nombre UNIQUE,
    Sigla           VARCHAR(10) NOT NULL CONSTRAINT UQ_Confederacion_Sigla UNIQUE
);
GO

-- ZonaHoraria guarda el nombre de zona de Windows (ej: 'Argentina Standard Time'),
-- válido contra sys.time_zone_info. Se usa con AT TIME ZONE, que contempla horario de verano.
IF OBJECT_ID('nucleo.Pais', 'U') IS NULL
CREATE TABLE nucleo.Pais (
    IdPais          INT IDENTITY(1,1) CONSTRAINT PK_Pais PRIMARY KEY,
    Nombre          VARCHAR(80) NOT NULL CONSTRAINT UQ_Pais_Nombre UNIQUE,
    CodigoISO2      CHAR(2)     NOT NULL CONSTRAINT UQ_Pais_CodigoISO2 UNIQUE,
    CodigoISO3      CHAR(3)     NOT NULL CONSTRAINT UQ_Pais_CodigoISO3 UNIQUE,
    IdConfederacion INT         NOT NULL,
    ZonaHoraria     VARCHAR(60) NOT NULL,

    CONSTRAINT FK_Pais_Confederacion FOREIGN KEY (IdConfederacion) REFERENCES nucleo.Confederacion (IdConfederacion)
);
GO

IF OBJECT_ID('nucleo.Ciudad', 'U') IS NULL
CREATE TABLE nucleo.Ciudad (
    IdCiudad INT IDENTITY(1,1) CONSTRAINT PK_Ciudad PRIMARY KEY,
    Nombre   VARCHAR(80) NOT NULL,
    IdPais   INT         NOT NULL,

    CONSTRAINT UQ_Ciudad_Pais_Nombre UNIQUE (IdPais, Nombre),
    CONSTRAINT FK_Ciudad_Pais FOREIGN KEY (IdPais) REFERENCES nucleo.Pais (IdPais)
);
GO

-- El huso horario va en la sede (no en la ciudad) porque lo que importa es el del estadio.
IF OBJECT_ID('nucleo.Sede', 'U') IS NULL
CREATE TABLE nucleo.Sede (
    IdSede         INT IDENTITY(1,1) CONSTRAINT PK_Sede PRIMARY KEY,
    NombreEstadio  VARCHAR(100) NOT NULL CONSTRAINT UQ_Sede_NombreEstadio UNIQUE,
    IdCiudad       INT          NOT NULL,
    Capacidad      INT          NOT NULL CONSTRAINT CK_Sede_Capacidad CHECK (Capacidad > 0),
    ZonaHoraria    VARCHAR(60)  NOT NULL,
    Latitud        DECIMAL(9,6) NULL CONSTRAINT CK_Sede_Latitud  CHECK (Latitud  BETWEEN -90  AND 90),
    Longitud       DECIMAL(9,6) NULL CONSTRAINT CK_Sede_Longitud CHECK (Longitud BETWEEN -180 AND 180),

    -- Latitud y longitud se informan juntas o ninguna (se usan para el mapa de BI).
    CONSTRAINT CK_Sede_Coordenadas CHECK ((Latitud IS NULL AND Longitud IS NULL)
                                       OR (Latitud IS NOT NULL AND Longitud IS NOT NULL)),

    CONSTRAINT FK_Sede_Ciudad FOREIGN KEY (IdCiudad) REFERENCES nucleo.Ciudad (IdCiudad)
);
GO

-- =========================================================================
-- FASES, GRUPOS, SELECCIONES Y CUERPO TÉCNICO
-- =========================================================================

IF OBJECT_ID('nucleo.Fase', 'U') IS NULL
CREATE TABLE nucleo.Fase (
    IdFase          INT IDENTITY(1,1) CONSTRAINT PK_Fase PRIMARY KEY,
    Descripcion     VARCHAR(30) NOT NULL CONSTRAINT UQ_Fase_Descripcion UNIQUE
        CONSTRAINT CK_Fase_Descripcion CHECK (Descripcion IN (
            'Grupos', 'Dieciseisavos', 'Octavos', 'Cuartos', 'Semifinal', 'Tercer puesto', 'Final')),
    Orden           INT NOT NULL CONSTRAINT UQ_Fase_Orden UNIQUE,
    EsEliminatoria  BIT NOT NULL
);
GO

IF OBJECT_ID('nucleo.Grupo', 'U') IS NULL
CREATE TABLE nucleo.Grupo (
    IdGrupo INT IDENTITY(1,1) CONSTRAINT PK_Grupo PRIMARY KEY,
    Nombre  VARCHAR(10) NOT NULL CONSTRAINT UQ_Grupo_Nombre UNIQUE
);
GO

-- La confederación de la selección se obtiene por su país (3FN: no se repite acá).
IF OBJECT_ID('nucleo.Seleccion', 'U') IS NULL
CREATE TABLE nucleo.Seleccion (
    IdSeleccion INT IDENTITY(1,1) CONSTRAINT PK_Seleccion PRIMARY KEY,
    IdPais      INT NOT NULL CONSTRAINT UQ_Seleccion_Pais UNIQUE,
    IdGrupo     INT NULL,

    CONSTRAINT FK_Seleccion_Pais  FOREIGN KEY (IdPais)  REFERENCES nucleo.Pais (IdPais),
    CONSTRAINT FK_Seleccion_Grupo FOREIGN KEY (IdGrupo) REFERENCES nucleo.Grupo (IdGrupo)
);
GO

IF OBJECT_ID('nucleo.StaffTecnico', 'U') IS NULL
CREATE TABLE nucleo.StaffTecnico (
    IdStaffTecnico INT IDENTITY(1,1) CONSTRAINT PK_StaffTecnico PRIMARY KEY,
    IdSeleccion    INT         NOT NULL,
    Nombre         VARCHAR(60) NOT NULL,
    Apellido       VARCHAR(60) NOT NULL,
    Documento      VARCHAR(20) NOT NULL CONSTRAINT UQ_StaffTecnico_Documento UNIQUE,
    Rol            VARCHAR(20) NOT NULL
        CONSTRAINT CK_StaffTecnico_Rol CHECK (Rol IN ('Director Tecnico', 'Ayudante')),

    CONSTRAINT FK_StaffTecnico_Seleccion FOREIGN KEY (IdSeleccion) REFERENCES nucleo.Seleccion (IdSeleccion)
);
GO

-- Un solo director técnico por selección.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_StaffTecnico_DirectorTecnico'
                                           AND object_id = OBJECT_ID('nucleo.StaffTecnico'))
CREATE UNIQUE INDEX UQ_StaffTecnico_DirectorTecnico
    ON nucleo.StaffTecnico (IdSeleccion)
    WHERE Rol = 'Director Tecnico';
GO

-- =========================================================================
-- ÁRBITROS
-- =========================================================================

IF OBJECT_ID('nucleo.Idioma', 'U') IS NULL
CREATE TABLE nucleo.Idioma (
    IdIdioma INT IDENTITY(1,1) CONSTRAINT PK_Idioma PRIMARY KEY,
    Nombre   VARCHAR(40) NOT NULL CONSTRAINT UQ_Idioma_Nombre UNIQUE
);
GO

-- Categoría del árbitro: 'FIFA' o la de su confederación (UEFA, CONMEBOL, etc.).
IF OBJECT_ID('nucleo.Categoria', 'U') IS NULL
CREATE TABLE nucleo.Categoria (
    IdCategoria INT IDENTITY(1,1) CONSTRAINT PK_Categoria PRIMARY KEY,
    Descripcion VARCHAR(40) NOT NULL CONSTRAINT UQ_Categoria_Descripcion UNIQUE
);
GO

IF OBJECT_ID('nucleo.Arbitro', 'U') IS NULL
CREATE TABLE nucleo.Arbitro (
    IdArbitro       INT IDENTITY(1,1) CONSTRAINT PK_Arbitro PRIMARY KEY,
    Nombre          VARCHAR(60) NOT NULL,
    Apellido        VARCHAR(60) NOT NULL,
    Documento       VARCHAR(20) NOT NULL CONSTRAINT UQ_Arbitro_Documento UNIQUE,
    FechaNacimiento DATE        NULL,
    IdPais          INT         NOT NULL,
    IdCategoria     INT         NOT NULL,

    CONSTRAINT FK_Arbitro_Pais      FOREIGN KEY (IdPais)      REFERENCES nucleo.Pais (IdPais),
    CONSTRAINT FK_Arbitro_Categoria FOREIGN KEY (IdCategoria) REFERENCES nucleo.Categoria (IdCategoria)
);
GO

-- Relación N:M árbitro-idioma (un árbitro habla varios idiomas).
IF OBJECT_ID('nucleo.ArbitroIdioma', 'U') IS NULL
CREATE TABLE nucleo.ArbitroIdioma (
    IdArbitro INT NOT NULL,
    IdIdioma  INT NOT NULL,

    CONSTRAINT PK_ArbitroIdioma PRIMARY KEY (IdArbitro, IdIdioma),
    CONSTRAINT FK_ArbitroIdioma_Arbitro FOREIGN KEY (IdArbitro) REFERENCES nucleo.Arbitro (IdArbitro),
    CONSTRAINT FK_ArbitroIdioma_Idioma  FOREIGN KEY (IdIdioma)  REFERENCES nucleo.Idioma (IdIdioma)
);
GO

-- =========================================================================
-- PARTIDOS
-- =========================================================================

-- IdSeleccionLocal / IdSeleccionVisitante son NULL cuando el cruce de eliminación directa
-- todavía no está definido. FechaHoraLocal es la de la sede; FechaHoraUTC la calcula el SP.
-- NumeroPartido es el número oficial del fixture (clave natural para el upsert de importación).
-- El resultado (goles, penales, asistencia) solo existe con Estado = 'Finalizado'.
IF OBJECT_ID('nucleo.Partido', 'U') IS NULL
CREATE TABLE nucleo.Partido (
    IdPartido            INT IDENTITY(1,1) CONSTRAINT PK_Partido PRIMARY KEY,
    NumeroPartido        INT          NOT NULL CONSTRAINT UQ_Partido_NumeroPartido UNIQUE
        CONSTRAINT CK_Partido_NumeroPartido CHECK (NumeroPartido > 0),
    IdFase               INT          NOT NULL,
    IdSede               INT          NOT NULL,
    FechaHoraLocal       DATETIME2(0) NOT NULL,
    FechaHoraUTC         DATETIME2(0) NOT NULL,
    IdSeleccionLocal     INT          NULL,
    IdSeleccionVisitante INT          NULL,
    Estado               VARCHAR(10)  NOT NULL CONSTRAINT DF_Partido_Estado DEFAULT ('Programado')
        CONSTRAINT CK_Partido_Estado CHECK (Estado IN ('Programado', 'Finalizado')),
    GolesLocal           INT          NULL CONSTRAINT CK_Partido_GolesLocal      CHECK (GolesLocal >= 0),
    GolesVisitante       INT          NULL CONSTRAINT CK_Partido_GolesVisitante  CHECK (GolesVisitante >= 0),
    PenalesLocal         INT          NULL CONSTRAINT CK_Partido_PenalesLocal    CHECK (PenalesLocal >= 0),
    PenalesVisitante     INT          NULL CONSTRAINT CK_Partido_PenalesVisitante CHECK (PenalesVisitante >= 0),
    Asistencia           INT          NULL CONSTRAINT CK_Partido_Asistencia      CHECK (Asistencia >= 0),

    -- Una sede no puede tener dos partidos en el mismo instante (el solapamiento fino lo valida el SP).
    CONSTRAINT UQ_Partido_Sede_FechaUTC UNIQUE (IdSede, FechaHoraUTC),

    CONSTRAINT CK_Partido_Equipos CHECK (IdSeleccionLocal IS NULL OR IdSeleccionVisitante IS NULL
                                         OR IdSeleccionLocal <> IdSeleccionVisitante),

    -- Programado: sin resultado. Finalizado: ambas selecciones y goles informados.
    CONSTRAINT CK_Partido_Resultado CHECK (
           (Estado = 'Programado' AND GolesLocal IS NULL AND GolesVisitante IS NULL
                                  AND PenalesLocal IS NULL AND PenalesVisitante IS NULL AND Asistencia IS NULL)
        OR (Estado = 'Finalizado' AND GolesLocal IS NOT NULL AND GolesVisitante IS NOT NULL
                                  AND IdSeleccionLocal IS NOT NULL AND IdSeleccionVisitante IS NOT NULL)),

    -- Penales: ambos o ninguno, solo si el partido terminó empatado, y sin empate en la tanda.
    CONSTRAINT CK_Partido_Penales CHECK (
           (PenalesLocal IS NULL AND PenalesVisitante IS NULL)
        OR (PenalesLocal IS NOT NULL AND PenalesVisitante IS NOT NULL
            AND GolesLocal = GolesVisitante AND PenalesLocal <> PenalesVisitante)),

    CONSTRAINT FK_Partido_Fase      FOREIGN KEY (IdFase)               REFERENCES nucleo.Fase (IdFase),
    CONSTRAINT FK_Partido_Sede      FOREIGN KEY (IdSede)               REFERENCES nucleo.Sede (IdSede),
    CONSTRAINT FK_Partido_Local     FOREIGN KEY (IdSeleccionLocal)     REFERENCES nucleo.Seleccion (IdSeleccion),
    CONSTRAINT FK_Partido_Visitante FOREIGN KEY (IdSeleccionVisitante) REFERENCES nucleo.Seleccion (IdSeleccion)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Partido_Fecha' AND object_id = OBJECT_ID('nucleo.Partido'))
CREATE INDEX IX_Partido_Fecha ON nucleo.Partido (FechaHoraUTC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Partido_Fase' AND object_id = OBJECT_ID('nucleo.Partido'))
CREATE INDEX IX_Partido_Fase ON nucleo.Partido (IdFase);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Partido_Local' AND object_id = OBJECT_ID('nucleo.Partido'))
CREATE INDEX IX_Partido_Local ON nucleo.Partido (IdSeleccionLocal);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Partido_Visitante' AND object_id = OBJECT_ID('nucleo.Partido'))
CREATE INDEX IX_Partido_Visitante ON nucleo.Partido (IdSeleccionVisitante);
GO

-- Roles: 'Principal' (1), 'Asistente' (hasta 2), 'Cuarto' (1), 'VAR' (1).
-- Los cupos y el impedimento por nacionalidad los valida nucleo.SP_CONTROL_ARBITRAL.
IF OBJECT_ID('nucleo.DesignacionArbitral', 'U') IS NULL
CREATE TABLE nucleo.DesignacionArbitral (
    IdDesignacion INT IDENTITY(1,1) CONSTRAINT PK_DesignacionArbitral PRIMARY KEY,
    IdPartido     INT         NOT NULL,
    IdArbitro     INT         NOT NULL,
    Rol           VARCHAR(10) NOT NULL
        CONSTRAINT CK_DesignacionArbitral_Rol CHECK (Rol IN ('Principal', 'Asistente', 'Cuarto', 'VAR')),

    CONSTRAINT UQ_DesignacionArbitral_Partido_Arbitro UNIQUE (IdPartido, IdArbitro),

    CONSTRAINT FK_DesignacionArbitral_Partido FOREIGN KEY (IdPartido) REFERENCES nucleo.Partido (IdPartido),
    CONSTRAINT FK_DesignacionArbitral_Arbitro FOREIGN KEY (IdArbitro) REFERENCES nucleo.Arbitro (IdArbitro)
);
GO

-- Sanciones e informes post-partido que recibe un árbitro por un partido que dirigió.
IF OBJECT_ID('nucleo.Sancion', 'U') IS NULL
CREATE TABLE nucleo.Sancion (
    IdSancion     INT IDENTITY(1,1) CONSTRAINT PK_Sancion PRIMARY KEY,
    IdDesignacion INT          NOT NULL,
    Tipo          VARCHAR(20)  NOT NULL
        CONSTRAINT CK_Sancion_Tipo CHECK (Tipo IN ('Informe', 'Advertencia', 'Multa', 'Suspension')),
    Descripcion   VARCHAR(500) NOT NULL,
    Fecha         DATE         NOT NULL CONSTRAINT DF_Sancion_Fecha DEFAULT (CAST(GETDATE() AS DATE)),

    CONSTRAINT FK_Sancion_DesignacionArbitral FOREIGN KEY (IdDesignacion) REFERENCES nucleo.DesignacionArbitral (IdDesignacion)
);
GO

-- =========================================================================
-- DATOS DE REFERENCIA FIJOS: FASES DEL TORNEO
-- (catálogo cerrado que usan SP_CONTROL_ARBITRAL y los SP de partidos)
-- =========================================================================
IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Descripcion = 'Grupos')
    INSERT INTO nucleo.Fase (Descripcion, Orden, EsEliminatoria) VALUES ('Grupos', 1, 0);
IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Descripcion = 'Dieciseisavos')
    INSERT INTO nucleo.Fase (Descripcion, Orden, EsEliminatoria) VALUES ('Dieciseisavos', 2, 1);
IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Descripcion = 'Octavos')
    INSERT INTO nucleo.Fase (Descripcion, Orden, EsEliminatoria) VALUES ('Octavos', 3, 1);
IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Descripcion = 'Cuartos')
    INSERT INTO nucleo.Fase (Descripcion, Orden, EsEliminatoria) VALUES ('Cuartos', 4, 1);
IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Descripcion = 'Semifinal')
    INSERT INTO nucleo.Fase (Descripcion, Orden, EsEliminatoria) VALUES ('Semifinal', 5, 1);
IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Descripcion = 'Tercer puesto')
    INSERT INTO nucleo.Fase (Descripcion, Orden, EsEliminatoria) VALUES ('Tercer puesto', 6, 1);
IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Descripcion = 'Final')
    INSERT INTO nucleo.Fase (Descripcion, Orden, EsEliminatoria) VALUES ('Final', 7, 1);
GO
