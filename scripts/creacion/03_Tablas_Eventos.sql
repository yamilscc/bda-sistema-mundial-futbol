/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Integrantes:
- Casella, Mateo Ezequiel
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Creación y eliminación de tablas de eventos de partido, reglas de suspensión e infraestructura de importación.
*/

-- Eliminar tablas existentes (en orden inverso de dependencias).

IF OBJECT_ID('eventos.LogImportacion', 'U') IS NOT NULL
    DROP TABLE eventos.LogImportacion;
GO
IF OBJECT_ID('eventos.StagingEvento', 'U') IS NOT NULL
    DROP TABLE eventos.StagingEvento;
GO
IF OBJECT_ID('eventos.Amonestacion', 'U') IS NOT NULL
    DROP TABLE eventos.Amonestacion;
GO
IF OBJECT_ID('eventos.Tarjeta', 'U') IS NOT NULL
    DROP TABLE eventos.Tarjeta;
GO
IF OBJECT_ID('eventos.Gol', 'U') IS NOT NULL
    DROP TABLE eventos.Gol;
GO
IF OBJECT_ID('eventos.Periodo', 'U') IS NOT NULL
    DROP TABLE eventos.Periodo;
GO
IF OBJECT_ID('eventos.TipoGol', 'U') IS NOT NULL
    DROP TABLE eventos.TipoGol;
GO
IF OBJECT_ID('eventos.ReglaSuspension', 'U') IS NOT NULL
    DROP TABLE eventos.ReglaSuspension;
GO

-- Creación de tablas de eventos de partido e importación.

-- Tabla aislada de parametrización para calcular suspensiones sin hardcodear valores.
IF OBJECT_ID('eventos.ReglaSuspension', 'U') IS NULL
CREATE TABLE eventos.ReglaSuspension (
    IdReglaSuspension       INT IDENTITY(1,1) CONSTRAINT PK_ReglaSuspension PRIMARY KEY,
    Criterio                VARCHAR(40) NOT NULL CONSTRAINT UQ_ReglaSuspension_Criterio UNIQUE,
    CantidadAmarillas       INT         NULL,
    PartidosSuspension      INT         NOT NULL CONSTRAINT CK_ReglaSuspension_Partidos CHECK (PartidosSuspension > 0),

    CONSTRAINT CK_ReglaSuspension_Criterio CHECK (Criterio IN ('Acumulacion Amarillas', 'Doble Amarilla', 'Roja Directa')),
    -- Exige cantidad de amarillas (>= 2) solo cuando el criterio es por acumulación.
    CONSTRAINT CK_ReglaSuspension_Amarillas CHECK (
           (Criterio = 'Acumulacion Amarillas' AND CantidadAmarillas >= 2)
        OR (Criterio <> 'Acumulacion Amarillas' AND CantidadAmarillas IS NULL))
);
GO

IF OBJECT_ID('eventos.TipoGol', 'U') IS NULL
CREATE TABLE eventos.TipoGol (
    IdTipoGol   INT IDENTITY(1,1) CONSTRAINT PK_TipoGol PRIMARY KEY,
    Descripcion VARCHAR(30) NOT NULL CONSTRAINT UQ_TipoGol_Descripcion UNIQUE
        CONSTRAINT CK_TipoGol_Descripcion CHECK (Descripcion IN ('Jugada', 'Penal', 'Tiro Libre', 'Cabezazo', 'En contra'))
);
GO

IF OBJECT_ID('eventos.Periodo', 'U') IS NULL
CREATE TABLE eventos.Periodo (
    IdPeriodo   INT IDENTITY(1,1) CONSTRAINT PK_Periodo PRIMARY KEY,
    Descripcion VARCHAR(30) NOT NULL CONSTRAINT UQ_Periodo_Descripcion UNIQUE
        CONSTRAINT CK_Periodo_Descripcion CHECK (Descripcion IN (
            'Primer Tiempo', 'Segundo Tiempo', 'Adicional PT', 'Adicional ST', 
            'Alargue PT', 'Alargue ST', 'Definicion por Penales'))
);
GO

IF OBJECT_ID('eventos.Gol', 'U') IS NULL
CREATE TABLE eventos.Gol (
    IdGol               INT IDENTITY(1,1) CONSTRAINT PK_Gol PRIMARY KEY,
    IdPartido           INT NOT NULL,
    IdJugadorAutor      INT NOT NULL,
    IdJugadorAsistencia INT NULL,
    IdTipoGol           INT NOT NULL,
    IdPeriodo           INT NOT NULL,
    Minuto              INT NOT NULL CONSTRAINT CK_Gol_Minuto CHECK (Minuto BETWEEN 1 AND 135),

    -- Evita que un jugador sea autor y asistente del mismo gol.
    CONSTRAINT CK_Gol_AutorDistintoAsistente CHECK (IdJugadorAsistencia IS NULL OR IdJugadorAutor <> IdJugadorAsistencia),

    CONSTRAINT FK_Gol_JugadorAutor      FOREIGN KEY (IdJugadorAutor)      REFERENCES jugadores.Jugador (IdJugador),
    CONSTRAINT FK_Gol_JugadorAsistencia FOREIGN KEY (IdJugadorAsistencia) REFERENCES jugadores.Jugador (IdJugador),
    CONSTRAINT FK_Gol_TipoGol           FOREIGN KEY (IdTipoGol)           REFERENCES eventos.TipoGol (IdTipoGol),
    CONSTRAINT FK_Gol_Periodo           FOREIGN KEY (IdPeriodo)           REFERENCES eventos.Periodo (IdPeriodo)
    -- , CONSTRAINT FK_Gol_Partido      FOREIGN KEY (IdPartido)           REFERENCES <esquema>.Partido (IdPartido)
);
GO

-- Unifica tarjeta y tipo de expulsión (evita tabla extra Expulsion con FKs nulas).
IF OBJECT_ID('eventos.Tarjeta', 'U') IS NULL
CREATE TABLE eventos.Tarjeta (
    IdTarjeta INT IDENTITY(1,1) CONSTRAINT PK_Tarjeta PRIMARY KEY,
    Tipo      VARCHAR(30) NOT NULL CONSTRAINT UQ_Tarjeta_Tipo UNIQUE
        CONSTRAINT CK_Tarjeta_Tipo CHECK (Tipo IN ('Amarilla', 'Roja por doble amarilla', 'Roja directa'))
);
GO

IF OBJECT_ID('eventos.Amonestacion', 'U') IS NULL
CREATE TABLE eventos.Amonestacion (
    IdAmonestacion     INT IDENTITY(1,1) CONSTRAINT PK_Amonestacion PRIMARY KEY,
    IdPartido          INT          NOT NULL,
    IdTarjeta          INT          NOT NULL,
    IdJugador          INT          NULL,
    IdStaffTecnico     INT          NULL,
    Minuto             INT          NOT NULL CONSTRAINT CK_Amonestacion_Minuto CHECK (Minuto BETWEEN 1 AND 135),
    Motivo             VARCHAR(200) NOT NULL,
    PartidosSuspension INT          NOT NULL CONSTRAINT DF_Amonestacion_Partidos DEFAULT (0)
        CONSTRAINT CK_Amonestacion_Partidos CHECK (PartidosSuspension >= 0),

    -- Arco exclusivo: la tarjeta aplica a un jugador o a un miembro del staff, nunca a ambos ni a ninguno.
    CONSTRAINT CK_Amonestacion_SancionadoExclusivo CHECK (
           (IdJugador IS NOT NULL AND IdStaffTecnico IS NULL)
        OR (IdJugador IS NULL     AND IdStaffTecnico IS NOT NULL)),

    CONSTRAINT FK_Amonestacion_Tarjeta      FOREIGN KEY (IdTarjeta)      REFERENCES eventos.Tarjeta (IdTarjeta),
    CONSTRAINT FK_Amonestacion_Jugador      FOREIGN KEY (IdJugador)      REFERENCES jugadores.Jugador (IdJugador)
    -- , CONSTRAINT FK_Amonestacion_Staff   FOREIGN KEY (IdStaffTecnico) REFERENCES <esquema>.StaffTecnico (IdStaffTecnico)
    -- , CONSTRAINT FK_Amonestacion_Partido FOREIGN KEY (IdPartido)      REFERENCES <esquema>.Partido (IdPartido)
);
GO

);