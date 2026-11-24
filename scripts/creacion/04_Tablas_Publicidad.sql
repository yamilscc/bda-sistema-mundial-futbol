/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Crear las tablas del módulo de publicidad: monedas, cotizaciones, anunciantes,
          campañas, piezas publicitarias, países de orientación de cada pieza, tarifas por
          fase y los cuatro espacios publicitarios por partido. Las FK hacia el núcleo
          (Idioma, Pais, Fase, Partido) se agregan en 06_FK_Cruzadas.sql.
          Jerarquía: Anunciante 1-N Campania 1-N Pieza N-N Pais (OrientacionPais).
*/

USE MundialFutbol;
GO

-- Monedas en las que se factura la pauta (código ISO 4217, ej. USD, ARS, EUR).
-- La regla del código se compara con collation binaria para que distinga mayúsculas.
IF OBJECT_ID('publicidad.Moneda', 'U') IS NULL
CREATE TABLE publicidad.Moneda (
    IdMoneda INT IDENTITY(1,1) CONSTRAINT PK_Moneda PRIMARY KEY,
    Codigo CHAR(3) NOT NULL
        CONSTRAINT UQ_Moneda_Codigo UNIQUE
        CONSTRAINT CK_Moneda_Codigo CHECK (Codigo COLLATE Latin1_General_BIN2 LIKE '[A-Z][A-Z][A-Z]'),
    Nombre VARCHAR(50) NOT NULL CONSTRAINT UQ_Moneda_Nombre UNIQUE
);
GO

-- Cotizaciones de la API de tipo de cambio: 1 unidad de MonedaBase = Tasa unidades de Moneda, a la Fecha indicada.
-- (Antes se creaba en 22_SP_Importacion_Nucleo_Publicidad.sql; las tablas van en los scripts de tablas.)
IF OBJECT_ID('publicidad.CotizacionMoneda', 'U') IS NULL
CREATE TABLE publicidad.CotizacionMoneda (
    MonedaBase CHAR(3)       NOT NULL,
    Moneda     CHAR(3)       NOT NULL,
    Fecha      DATE          NOT NULL,
    Tasa       DECIMAL(18,8) NOT NULL,

    CONSTRAINT PK_CotizacionMoneda PRIMARY KEY (MonedaBase, Moneda, Fecha),
    CONSTRAINT CK_CotizacionMoneda_Tasa CHECK (Tasa > 0),
    CONSTRAINT FK_CotizacionMoneda_MonedaBase FOREIGN KEY (MonedaBase) REFERENCES publicidad.Moneda (Codigo),
    CONSTRAINT FK_CotizacionMoneda_Moneda     FOREIGN KEY (Moneda)     REFERENCES publicidad.Moneda (Codigo)
);
GO

-- Anunciantes que contratan la pauta. IdPais es el país de origen del anunciante
-- (los criterios de aceptación piden anunciantes de al menos 6 países distintos).
-- La FK a Pais se agrega en 06_FK_Cruzadas.sql.
IF OBJECT_ID('publicidad.Anunciante', 'U') IS NULL
CREATE TABLE publicidad.Anunciante (
    IdAnunciante INT IDENTITY(1,1) CONSTRAINT PK_Anunciante PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL CONSTRAINT UQ_Anunciante_Nombre UNIQUE,
    IdPais SMALLINT NOT NULL
);
GO

-- Campañas de cada anunciante (historial de campañas publicitarias). Una campaña agrupa las piezas
-- que el anunciante ofrece para el torneo. Marca y Agencia son opcionales (datos del dossier de campañas).
IF OBJECT_ID('publicidad.Campania', 'U') IS NULL
CREATE TABLE publicidad.Campania (
    IdCampania INT IDENTITY(1,1) CONSTRAINT PK_Campania PRIMARY KEY,
    IdAnunciante INT NOT NULL,
    Titulo VARCHAR(100) NOT NULL,
    Marca VARCHAR(100) NULL,
    Agencia VARCHAR(100) NULL,
    FechaDesde DATE NULL,
    FechaHasta DATE NULL,

    CONSTRAINT UQ_Campania_IdAnunciante_Titulo UNIQUE (IdAnunciante, Titulo),
    CONSTRAINT CK_Campania_Titulo_NoVacio CHECK (TRIM(Titulo) <> ''),
    CONSTRAINT CK_Campania_Fechas CHECK (FechaDesde IS NULL OR FechaHasta IS NULL OR FechaHasta >= FechaDesde),

    CONSTRAINT FK_Campania_Anunciante FOREIGN KEY (IdAnunciante) REFERENCES publicidad.Anunciante (IdAnunciante)
);
GO

-- Piezas publicitarias de cada campaña (una por idioma/mercado). El anunciante de la pieza se obtiene
-- a través de su campaña (no se repite acá: 3FN).
IF OBJECT_ID('publicidad.Pieza', 'U') IS NULL
CREATE TABLE publicidad.Pieza (
    IdPieza INT IDENTITY(1,1) CONSTRAINT PK_Pieza PRIMARY KEY,
    IdCampania INT NOT NULL,
    IdIdioma TINYINT NOT NULL,
    Titulo VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(300) NULL,

    CONSTRAINT UQ_Pieza_Campania_Titulo_Idioma UNIQUE (IdCampania, Titulo, IdIdioma),

    CONSTRAINT FK_Pieza_Campania FOREIGN KEY (IdCampania) REFERENCES publicidad.Campania (IdCampania)
    -- FK a Idioma (nucleo.Idioma): se agrega en 06_FK_Cruzadas.sql (FK_Pieza_Idioma).
);
GO

-- Países a los que está orientada cada pieza (relación N a N entre Pieza y País).
IF OBJECT_ID('publicidad.OrientacionPais', 'U') IS NULL
CREATE TABLE publicidad.OrientacionPais (
    IdPieza INT NOT NULL,
    IdPais SMALLINT NOT NULL,

    CONSTRAINT PK_OrientacionPais PRIMARY KEY (IdPieza, IdPais),

    CONSTRAINT FK_OrientacionPais_Pieza FOREIGN KEY (IdPieza) REFERENCES publicidad.Pieza (IdPieza)
    -- FK a Pais (nucleo.Pais): se agrega en 06_FK_Cruzadas.sql (FK_OrientacionPais_Pais).
);
GO

-- Tarifa de una franja publicitaria según la fase del torneo (vigente desde VigenciaDesde).
-- Es el dato maestro del cual sale la tarifa que se copia a EspacioPublicitario al asignar.
-- La FK a Fase (nucleo.Fase) se agrega en 06_FK_Cruzadas.sql (FK_Tarifa_Fase).
IF OBJECT_ID('publicidad.Tarifa', 'U') IS NULL
CREATE TABLE publicidad.Tarifa (
    IdTarifa INT IDENTITY(1,1) CONSTRAINT PK_Tarifa PRIMARY KEY,
    IdFase TINYINT NOT NULL,
    IdMoneda INT NOT NULL,
    Monto DECIMAL(12,2) NOT NULL
        CONSTRAINT CK_Tarifa_Monto CHECK (Monto >= 0),
    VigenciaDesde DATE NOT NULL
        CONSTRAINT DF_Tarifa_VigenciaDesde DEFAULT (CAST(GETDATE() AS DATE)),

    CONSTRAINT UQ_Tarifa_Fase_Moneda_Vigencia UNIQUE (IdFase, IdMoneda, VigenciaDesde),

    CONSTRAINT FK_Tarifa_Moneda FOREIGN KEY (IdMoneda) REFERENCES publicidad.Moneda (IdMoneda)
);
GO

-- Espacios publicitarios de cada partido (entidad débil de Partido: 1 a 4).
-- Es también el registro histórico de lo exhibido, con la tarifa y la moneda vigentes
-- al momento de la asignación, para poder facturar. FechaAsignacion y CriterioAsignacion
-- dejan constancia de cuándo y por qué regla se eligió la pieza (NULL si se cargó a mano).
-- Una vez finalizado el partido el registro no se modifica ni se elimina (lo controlan los SP).
IF OBJECT_ID('publicidad.EspacioPublicitario', 'U') IS NULL
CREATE TABLE publicidad.EspacioPublicitario (
    IdPartido SMALLINT NOT NULL,
    NumeroEspacio TINYINT NOT NULL
        CONSTRAINT CK_EspacioPublicitario_NumeroEspacio CHECK (NumeroEspacio BETWEEN 1 AND 4),
    IdPieza INT NOT NULL,
    TarifaPublicitaria DECIMAL(12,2) NOT NULL
        CONSTRAINT CK_EspacioPublicitario_TarifaPublicitaria CHECK (TarifaPublicitaria >= 0),
    IdMoneda INT NOT NULL,
    FechaAsignacion DATETIME2(0) NOT NULL
        CONSTRAINT DF_EspacioPublicitario_FechaAsignacion DEFAULT (SYSDATETIME()),
    CriterioAsignacion VARCHAR(60) NULL,

    CONSTRAINT PK_EspacioPublicitario PRIMARY KEY (IdPartido, NumeroEspacio),
    CONSTRAINT UQ_EspacioPublicitario_Partido_Pieza UNIQUE (IdPartido, IdPieza),

    CONSTRAINT FK_EspacioPublicitario_Pieza  FOREIGN KEY (IdPieza)  REFERENCES publicidad.Pieza (IdPieza),
    CONSTRAINT FK_EspacioPublicitario_Moneda FOREIGN KEY (IdMoneda) REFERENCES publicidad.Moneda (IdMoneda)
    -- FK a Partido (nucleo.Partido): se agrega en 06_FK_Cruzadas.sql (FK_EspacioPublicitario_Partido).
);
GO
