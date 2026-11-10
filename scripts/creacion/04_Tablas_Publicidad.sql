/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Crear las tablas del módulo de publicidad: monedas, anunciantes,
          piezas publicitarias, países de orientación de cada pieza y los
          cuatro espacios publicitarios por partido.
*/

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

-- Anunciantes que contratan la pauta.
IF OBJECT_ID('publicidad.Anunciante', 'U') IS NULL
CREATE TABLE publicidad.Anunciante (
    IdAnunciante INT IDENTITY(1,1) CONSTRAINT PK_Anunciante PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL CONSTRAINT UQ_Anunciante_Nombre UNIQUE
);
GO

-- Piezas publicitarias ofrecidas por cada anunciante (una por idioma/mercado).
IF OBJECT_ID('publicidad.Pieza', 'U') IS NULL
CREATE TABLE publicidad.Pieza (
    IdPieza INT IDENTITY(1,1) CONSTRAINT PK_Pieza PRIMARY KEY,
    IdAnunciante INT NOT NULL,
    IdIdioma INT NOT NULL,
    Titulo VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(300) NULL,

    CONSTRAINT UQ_Pieza_Anunciante_Titulo_Idioma UNIQUE (IdAnunciante, Titulo, IdIdioma),

    CONSTRAINT FK_Pieza_Anunciante FOREIGN KEY (IdAnunciante) REFERENCES publicidad.Anunciante (IdAnunciante)
    -- FK a Idioma: se agrega en el script maestro con ALTER TABLE, una vez creada Idioma.
    -- , CONSTRAINT FK_Pieza_Idioma FOREIGN KEY (IdIdioma) REFERENCES <esquema>.Idioma (IdIdioma)
);
GO

-- Países a los que está orientada cada pieza (relación N a N entre Pieza y País).
IF OBJECT_ID('publicidad.OrientacionPais', 'U') IS NULL
CREATE TABLE publicidad.OrientacionPais (
    IdPieza INT NOT NULL,
    IdPais INT NOT NULL,

    CONSTRAINT PK_OrientacionPais PRIMARY KEY (IdPieza, IdPais),

    CONSTRAINT FK_OrientacionPais_Pieza FOREIGN KEY (IdPieza) REFERENCES publicidad.Pieza (IdPieza)
    -- FK a Pais: se agrega en el script maestro con ALTER TABLE, una vez creada Pais.
    -- , CONSTRAINT FK_OrientacionPais_Pais FOREIGN KEY (IdPais) REFERENCES <esquema>.Pais (IdPais)
);
GO

-- Espacios publicitarios de cada partido (entidad débil de Partido: 1 a 4).
-- Es también el registro histórico de lo exhibido, con la tarifa y la moneda
-- vigentes al momento de la asignación, para poder facturar.
IF OBJECT_ID('publicidad.EspacioPublicitario', 'U') IS NULL
CREATE TABLE publicidad.EspacioPublicitario (
    IdPartido INT NOT NULL,
    NumeroEspacio TINYINT NOT NULL
        CONSTRAINT CK_EspacioPublicitario_NumeroEspacio CHECK (NumeroEspacio BETWEEN 1 AND 4),
    IdPieza INT NOT NULL,
    TarifaPublicitaria DECIMAL(12,2) NOT NULL
        CONSTRAINT CK_EspacioPublicitario_TarifaPublicitaria CHECK (TarifaPublicitaria >= 0),
    IdMoneda INT NOT NULL,

    CONSTRAINT PK_EspacioPublicitario PRIMARY KEY (IdPartido, NumeroEspacio),
    CONSTRAINT UQ_EspacioPublicitario_Partido_Pieza UNIQUE (IdPartido, IdPieza),

    CONSTRAINT FK_EspacioPublicitario_Pieza  FOREIGN KEY (IdPieza)  REFERENCES publicidad.Pieza (IdPieza),
    CONSTRAINT FK_EspacioPublicitario_Moneda FOREIGN KEY (IdMoneda) REFERENCES publicidad.Moneda (IdMoneda)
    -- FK a Partido: se agrega en el script maestro con ALTER TABLE, una vez creada Partido.
    -- , CONSTRAINT FK_EspacioPublicitario_Partido FOREIGN KEY (IdPartido) REFERENCES <esquema>.Partido (IdPartido)
);
GO
