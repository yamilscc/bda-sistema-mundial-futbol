/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-14
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Crear las tablas de staging (eventos.StagingEvento, eventos.StagingFixture y
          publicidad.StagingCampania) y de log (eventos.LogImportacion) para los procesos de importación.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- CREACIÓN DE TABLAS
-- =========================================================================

-- Tabla de aterrizaje (staging) con campos de texto flexibles para tolerar datos sucios en BULK INSERT.
IF OBJECT_ID('eventos.StagingEvento', 'U') IS NULL
CREATE TABLE eventos.StagingEvento (
    IdFila              INT IDENTITY(1,1) CONSTRAINT PK_StagingEvento PRIMARY KEY,
    NombreArchivo       VARCHAR(255)  NOT NULL,
    PartidoRef          VARCHAR(100)  NULL,
    TipoEvento          VARCHAR(50)   NULL,
    DocumentoSancionado VARCHAR(50)   NULL,
    DocumentoAsistente  VARCHAR(50)   NULL,
    MinutoTexto         VARCHAR(20)   NULL,
    DetalleTipo         VARCHAR(100)  NULL,
    PeriodoOMotivo      VARCHAR(200)  NULL
);
GO

-- Registro persistente de fallos para cumplir con importación parcial sin abortar el lote válido.
IF OBJECT_ID('eventos.LogImportacion', 'U') IS NULL
CREATE TABLE eventos.LogImportacion (
    IdLogImportacion INT IDENTITY(1,1) CONSTRAINT PK_LogImportacion PRIMARY KEY,
    FechaHora        DATETIME      NOT NULL CONSTRAINT DF_LogImportacion_FechaHora DEFAULT (GETDATE()),
    NombreArchivo    VARCHAR(255)  NOT NULL,
    IdFilaStaging    INT           NULL,
    DatosCrudos      NVARCHAR(MAX) NULL,
    MensajeError     NVARCHAR(500) NOT NULL
);
GO

-- Staging del fixture (CSV del scraping). Mismo patrón que StagingEvento: NombreArchivo con default
-- 'PENDIENTE' para cargar por BULK INSERT estático a través de la vista eventos.vw_CargaStagingFixture.
-- (Antes se creaba en 22_SP_Importacion_Nucleo_Publicidad.sql; las tablas van en los scripts de tablas.)
IF OBJECT_ID('eventos.StagingFixture', 'U') IS NULL
CREATE TABLE eventos.StagingFixture (
    IdFila             INT IDENTITY(1,1) CONSTRAINT PK_StagingFixture PRIMARY KEY,
    NombreArchivo      VARCHAR(255) NOT NULL CONSTRAINT DF_StagingFixture_NombreArchivo DEFAULT ('PENDIENTE'),
    NumeroPartido      VARCHAR(20)  NULL,
    Fase               VARCHAR(50)  NULL,
    NombreEstadio      VARCHAR(100) NULL,
    Ciudad             VARCHAR(100) NULL,
    PaisISO3           VARCHAR(10)  NULL,
    HusoHorario        VARCHAR(50)  NULL,
    Capacidad          VARCHAR(20)  NULL,
    Latitud            VARCHAR(20)  NULL,
    Longitud           VARCHAR(20)  NULL,
    FechaHoraLocal     VARCHAR(30)  NULL,
    SeleccionLocal     VARCHAR(10)  NULL,
    SeleccionVisitante VARCHAR(10)  NULL
);
GO

-- Staging de las campañas del dossier de publicidad (CSV del scraping). Mismo patrón que StagingFixture
-- (NombreArchivo con default 'PENDIENTE', se carga por BULK INSERT estático a través de la vista
-- publicidad.vw_CargaStagingCampania), pero en el schema publicidad porque es de ese módulo; los errores por fila
-- siguen yendo a eventos.LogImportacion. Los largos superan los de las tablas destino (100) a propósito:
-- así los textos demasiado largos llegan a la tabla y el SP los informa por fila, en vez de truncarlos.
IF OBJECT_ID('publicidad.StagingCampania', 'U') IS NULL
CREATE TABLE publicidad.StagingCampania (
    IdFila        INT IDENTITY(1,1) CONSTRAINT PK_StagingCampania PRIMARY KEY,
    NombreArchivo VARCHAR(255) NOT NULL CONSTRAINT DF_StagingCampania_NombreArchivo DEFAULT ('PENDIENTE'),
    Anunciante    VARCHAR(300) NULL,
    Marca         VARCHAR(300) NULL,
    Titulo        VARCHAR(300) NULL,
    Agencia       VARCHAR(300) NULL,
    Productora    VARCHAR(300) NULL,
    Periodo       VARCHAR(100) NULL,
    Categorias    VARCHAR(300) NULL
);
GO
