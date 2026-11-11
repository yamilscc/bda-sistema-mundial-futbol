/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Integrantes:
- Casella, Mateo Ezequiel
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Creación de las tablas de Staging y Log para los procesos de importación de datos.
*/

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
