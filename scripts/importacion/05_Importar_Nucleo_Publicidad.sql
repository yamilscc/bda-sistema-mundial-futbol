/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-23
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Lanzador de las 4 importaciones de nucleo y publicidad (sin SQL dinámico: la ruta de los archivos
          se resuelve con variables SQLCMD):
            1. PBI per cápita      <- pbi_banco_mundial.json       (API Banco Mundial)
            2. Sedes y 24 partidos <- fixture_sedes.csv            (scraping, BULK INSERT estático)
            3. Cotizaciones        <- cotizaciones_frankfurter.json (API Frankfurter)
            4. Pauta publicitaria  <- pauta_publicitaria.json      (convierte monedas con las cotizaciones)
          Es idempotente: se puede re-ejecutar. Las filas inválidas quedan en eventos.LogImportacion.

REQUISITOS PARA EJECUTARLO:
  - Modo SQLCMD activado en SSMS. Editar RUTA_IMP (carpeta scripts\importacion, sin barra final).
  - Haber ejecutado 04_Seed_Nucleo_Publicidad.sql.
  - Haber generado los archivos de las APIs:  python fuentes_externas.py todo
    (fixture_sedes.csv y pauta_publicitaria.json ya vienen en el repositorio).
*/

:on error exit
:setvar RUTA_IMP "C:\CAMBIAR\bda-sistema-mundial-futbol\scripts\importacion"

USE MundialFutbol;
GO
SET NOCOUNT ON;
GO

-- ===== 1. PBI per cápita (API Banco Mundial) =====
DECLARE @json NVARCHAR(MAX), @ok INT, @err INT;
SELECT @json = BulkColumn FROM OPENROWSET(BULK '$(RUTA_IMP)\pbi_banco_mundial.json', SINGLE_CLOB) AS f;
EXEC nucleo.SP_IMPORTAR_PBI_JSON @nombreArchivo = 'pbi_banco_mundial.json', @contenidoJSON = @json,
                                 @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
SELECT 'PBI' AS Importacion, @ok AS Procesadas, @err AS ConError;
GO

-- ===== 2. Sedes y fixture (scraping) =====
DELETE FROM eventos.StagingFixture WHERE NombreArchivo IN ('fixture_sedes.csv', 'PENDIENTE');

BULK INSERT eventos.vw_CargaStagingFixture
FROM '$(RUTA_IMP)\fixture_sedes.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ';', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

UPDATE eventos.StagingFixture SET NombreArchivo = 'fixture_sedes.csv' WHERE NombreArchivo = 'PENDIENTE';

DECLARE @ok INT, @err INT;
EXEC nucleo.SP_IMPORTAR_FIXTURE_CSV @nombreArchivo = 'fixture_sedes.csv',
                                    @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
SELECT 'Fixture' AS Importacion, @ok AS Procesadas, @err AS ConError;
GO

-- ===== 3. Cotizaciones (API Frankfurter) =====
DECLARE @json NVARCHAR(MAX), @ok INT, @err INT;
SELECT @json = BulkColumn FROM OPENROWSET(BULK '$(RUTA_IMP)\cotizaciones_frankfurter.json', SINGLE_CLOB) AS f;
EXEC publicidad.SP_IMPORTAR_COTIZACIONES_JSON @nombreArchivo = 'cotizaciones_frankfurter.json', @contenidoJSON = @json,
                                              @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
SELECT 'Cotizaciones' AS Importacion, @ok AS Procesadas, @err AS ConError;
GO

-- ===== 4. Pauta publicitaria (montos en moneda extranjera -> USD) =====
-- El archivo incluye a propósito 3 filas inválidas (ARS sin cotización, partido inexistente, anunciante
-- inexistente): se importan las 6 válidas y las 3 inválidas quedan en eventos.LogImportacion.
DECLARE @json NVARCHAR(MAX), @ok INT, @err INT;
SELECT @json = BulkColumn FROM OPENROWSET(BULK '$(RUTA_IMP)\pauta_publicitaria.json', SINGLE_CLOB) AS f;
EXEC publicidad.SP_IMPORTAR_PAUTA_JSON @nombreArchivo = 'pauta_publicitaria.json', @contenidoJSON = @json,
                                       @monedaDestino = 'USD', @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
SELECT 'Pauta' AS Importacion, @ok AS Procesadas_Esperado_6, @err AS ConError_Esperado_3;

SELECT NombreArchivo, IdFilaStaging, MensajeError, DatosCrudos
FROM eventos.LogImportacion
WHERE NombreArchivo IN ('pbi_banco_mundial.json', 'fixture_sedes.csv', 'cotizaciones_frankfurter.json', 'pauta_publicitaria.json')
ORDER BY IdLogImportacion;
GO
