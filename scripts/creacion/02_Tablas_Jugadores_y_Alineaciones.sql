-- Eliminar tablas existentes.

IF OBJECT_ID('jugadores.Sustitucion', 'U') IS NOT NULL
    DROP TABLE jugadores.Sustitucion;
GO
IF OBJECT_ID('jugadores.FormacionJugador', 'U') IS NOT NULL
    DROP TABLE jugadores.FormacionJugador;
GO
IF OBJECT_ID('jugadores.Formacion', 'U') IS NOT NULL
    DROP TABLE jugadores.Formacion;
GO
IF OBJECT_ID('jugadores.Baja', 'U') IS NOT NULL
    DROP TABLE jugadores.Baja;
GO
IF OBJECT_ID('jugadores.Convocatoria', 'U') IS NOT NULL
    DROP TABLE jugadores.Convocatoria;
GO
IF OBJECT_ID('jugadores.Jugador', 'U') IS NOT NULL
    DROP TABLE jugadores.Jugador;
GO
IF OBJECT_ID('jugadores.Club', 'U') IS NOT NULL
    DROP TABLE jugadores.Club;
GO
IF OBJECT_ID('jugadores.ReglaCambios', 'U') IS NOT NULL
    DROP TABLE jugadores.ReglaCambios;
GO 
IF OBJECT_ID('jugadores.ReglaConvocados', 'U') IS NOT NULL
    DROP TABLE jugadores.ReglaConvocados;
GO

-- Creación de tablas de los jugadores y las alineaciones.

IF OBJECT_ID('jugadores.ReglaConvocados', 'U') IS NULL
CREATE TABLE jugadores.ReglaConvocados (
    IdRegla INT IDENTITY(1,1) CONSTRAINT PK_ReglaConvocados PRIMARY KEY,
    Minimo INT NOT NULL CONSTRAINT CK_ReglaConvocados_Minimo CHECK (Minimo > 0),
    Maximo INT NOT NULL, 
    CONSTRAINT CK_ReglaConvocados_Maximo CHECK (Maximo >= Minimo)
);
GO

IF OBJECT_ID('jugadores.ReglaCambios', 'U') IS NULL
CREATE TABLE jugadores.ReglaCambios (
    IdRegla INT IDENTITY(1,1) CONSTRAINT PK_ReglaCambios PRIMARY KEY,
    MaxCambiosRegular INT NOT NULL CONSTRAINT CK_ReglaCambios_CambReg CHECK (MaxCambiosRegular >= 0),
    MaxVentanasRegular INT NOT NULL CONSTRAINT CK_ReglaCambios_VentReg CHECK (MaxVentanasRegular >= 0),
    MaxCambiosSuplementario INT NOT NULL CONSTRAINT CK_ReglaCambios_CambSup CHECK (MaxCambiosSuplementario >= 0),
    MaxVentanasSuplementario INT NOT NULL CONSTRAINT CK_ReglaCambios_VentSup CHECK (MaxVentanasSuplementario >= 0)
);
GO

IF OBJECT_ID('jugadores.Club', 'U') IS NULL
CREATE TABLE jugadores.Club (
    IdClub INT IDENTITY(1,1) CONSTRAINT PK_Club PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL CONSTRAINT UQ_Club_Nombre UNIQUE
);
GO

IF OBJECT_ID('jugadores.Jugador', 'U') IS NULL
CREATE TABLE jugadores.Jugador (
    IdJugador INT IDENTITY(1,1) CONSTRAINT PK_Jugador PRIMARY KEY,
    Nombre VARCHAR(60) NOT NULL,
    Apellido VARCHAR(60) NOT NULL,
    Documento VARCHAR(20) NOT NULL CONSTRAINT UQ_Jugador_Documento UNIQUE,
    Sexo CHAR(1) NOT NULL CONSTRAINT CK_Jugador_Sexo CHECK (Sexo IN ('M', 'F')),
    Posicion VARCHAR(20) NOT NULL
        CONSTRAINT CK_Jugador_Posicion CHECK (Posicion IN ('Arquero', 'Defensor', 'Mediocampista', 'Delantero')),
    IdClub INT NULL CONSTRAINT FK_Jugador_Club REFERENCES jugadores.Club (IdClub)
);
GO

IF OBJECT_ID('jugadores.Convocatoria', 'U') IS NULL
CREATE TABLE jugadores.Convocatoria (
    IdConvocatoria INT IDENTITY(1,1) CONSTRAINT PK_Convocatoria PRIMARY KEY,
    IdSeleccion INT NOT NULL,
    IdJugador INT NOT NULL,
    Dorsal INT NOT NULL CONSTRAINT CK_Convocatoria_Dorsal CHECK (Dorsal BETWEEN 1 AND 99),
    FechaAlta DATE NOT NULL CONSTRAINT DF_Convocatoria_FechaAlta DEFAULT (CAST(GETDATE() AS DATE)),

    CONSTRAINT UQ_Convocatoria_Jugador UNIQUE (IdJugador),
    CONSTRAINT UQ_Convocatoria_Dorsal_Seleccion UNIQUE (IdSeleccion, Dorsal),

    CONSTRAINT FK_Convocatoria_Jugador FOREIGN KEY (IdJugador) REFERENCES jugadores.Jugador (IdJugador)
    -- , CONSTRAINT FK_Convocatoria_Seleccion FOREIGN KEY (IdSeleccion) REFERENCES <esquema>.Seleccion (IdSeleccion)
);
GO

IF OBJECT_ID('jugadores.Baja', 'U') IS NULL
CREATE TABLE jugadores.Baja (
    IdBaja INT IDENTITY(1,1) CONSTRAINT PK_Baja PRIMARY KEY,
    IdConvocatoria INT NOT NULL,
    FechaBaja DATE NOT NULL CONSTRAINT DF_Baja_FechaBaja DEFAULT (CAST(GETDATE() AS DATE)),
    Motivo VARCHAR(200) NOT NULL,

    CONSTRAINT UQ_Baja_Convocatoria UNIQUE (IdConvocatoria),

    CONSTRAINT FK_Baja_Convocatoria FOREIGN KEY (IdConvocatoria) REFERENCES jugadores.Convocatoria (IdConvocatoria)
);
GO

IF OBJECT_ID('jugadores.Formacion', 'U') IS NULL
CREATE TABLE jugadores.Formacion (
    IdFormacion INT IDENTITY(1,1) CONSTRAINT PK_Formacion PRIMARY KEY,
    IdPartido INT NOT NULL,
    Localia VARCHAR(9) NOT NULL CONSTRAINT CK_Formacion_Localia CHECK (Localia IN ('Visitante', 'Local')),
    EsquemaTactico VARCHAR(10) NOT NULL
        CONSTRAINT CK_Formacion_Esquema CHECK (EsquemaTactico LIKE '[1-9]-[1-9]-[1-9]' 
                                               OR EsquemaTactico LIKE '[1-9]-[1-9]-[1-9]-[1-9]'),

    CONSTRAINT UQ_Formacion_Localia_Partido UNIQUE (Localia, IdPartido)

    -- , CONSTRAINT FK_Formacion_Partido FOREIGN KEY (IdPartido) REFERENCES <esquema>.Partido (IdPartido)
);
GO

IF OBJECT_ID('jugadores.FormacionJugador', 'U') IS NULL
CREATE TABLE jugadores.FormacionJugador (
    IdFormacion       INT         NOT NULL,
    IdJugador         INT         NOT NULL,
    EstadoTitularidad VARCHAR(8)  NOT NULL CONSTRAINT CK_FormacionJugador_Estado CHECK (EstadoTitularidad IN ('Titular', 'Suplente')),
    PosicionEnCampo   VARCHAR(20) NULL,
    Dorsal            INT         NOT NULL CONSTRAINT CK_FormacionJugador_Dorsal CHECK (Dorsal BETWEEN 1 AND 99),

    CONSTRAINT PK_FormacionJugador PRIMARY KEY (IdFormacion, IdJugador),
    CONSTRAINT UQ_FormacionJugador_Dorsal UNIQUE (IdFormacion, Dorsal),
    CONSTRAINT CK_FormacionJugador_Posicion CHECK (
           (EstadoTitularidad = 'Titular'  AND PosicionEnCampo IS NOT NULL)
        OR (EstadoTitularidad = 'Suplente' AND PosicionEnCampo IS NULL)),

    CONSTRAINT FK_FormacionJugador_Formacion FOREIGN KEY (IdFormacion) REFERENCES jugadores.Formacion (IdFormacion),
    CONSTRAINT FK_FormacionJugador_Jugador   FOREIGN KEY (IdJugador)   REFERENCES jugadores.Jugador (IdJugador)
);
GO

IF OBJECT_ID('jugadores.Sustitucion', 'U') IS NULL
CREATE TABLE jugadores.Sustitucion (
    IdSustitucion     INT IDENTITY(1,1) CONSTRAINT PK_Sustitucion PRIMARY KEY,
    IdPartido         INT         NOT NULL,
    IdJugadorSaliente INT         NOT NULL,
    IdJugadorEntrante INT         NOT NULL,
    Minuto            INT         NOT NULL CONSTRAINT CK_Sustitucion_Minuto CHECK (Minuto > 0),
    Periodo           VARCHAR(13) NOT NULL CONSTRAINT CK_Sustitucion_Periodo CHECK (Periodo IN ('Regular', 'Suplementario')),
    Motivo            VARCHAR(10) NOT NULL CONSTRAINT CK_Sustitucion_Motivo CHECK (Motivo IN ('Tactico', 'Lesion', 'Precaucion')),

    CONSTRAINT CK_Sustitucion_Jugadores CHECK (IdJugadorSaliente <> IdJugadorEntrante),
    CONSTRAINT UQ_Sustitucion_Saliente UNIQUE (IdPartido, IdJugadorSaliente),
    CONSTRAINT UQ_Sustitucion_Entrante UNIQUE (IdPartido, IdJugadorEntrante),

    CONSTRAINT FK_Sustitucion_Saliente FOREIGN KEY (IdJugadorSaliente) REFERENCES jugadores.Jugador (IdJugador),
    CONSTRAINT FK_Sustitucion_Entrante FOREIGN KEY (IdJugadorEntrante) REFERENCES jugadores.Jugador (IdJugador)
    -- , CONSTRAINT FK_Sustitucion_Partido FOREIGN KEY (IdPartido) REFERENCES <esquema>.Partido (IdPartido)
);
GO
