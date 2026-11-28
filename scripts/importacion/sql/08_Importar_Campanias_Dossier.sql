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
Objetivo: Cargar las campañas del dossier de publicidad (campanas_dossier.csv, generado por scraping con
          scraping\scraping_dossier.py, en resultados\) hacia publicidad.StagingCampania mediante BULK INSERT estático (sin SQL dinámico)
          y ejecutar publicidad.SP_IMPORTAR_CAMPANIAS_CSV: crea anunciantes (país de origen Argentina), campañas y
          una pieza en español por campaña orientada a Argentina. Es idempotente: se puede re-ejecutar.
          Las filas inválidas quedan en eventos.LogImportacion.

REQUISITOS PARA EJECUTARLO:
  - Activar el modo SQLCMD en SSMS: menú Consulta > Modo SQLCMD.
  - Editar RUTA_IMP con la ruta local de la carpeta scripts\importacion, la que contiene sql, datos y resultados (sin barra final) (solo si se ejecuta suelto: ver abajo).
  - Haber ejecutado 04_Seed_Nucleo_Publicidad.sql (países e idiomas) y el script de creación 29.
  - ORDEN: después de 06 y 07, para no cambiar la pauta ya asignada en los partidos del seed: las campañas
    nuevas no tienen espacios y solo entran en las asignaciones de SP_ASIGNAR_PUBLICIDAD que se hagan después.
  - El CSV lo genera el scraping en scripts\importacion\resultados (solo local):  python scraping\scraping_dossier.py
*/

:on error exit
-- Con 00_Cargar_Seeds.sql la ruta se define una sola vez ahí. Si este script se ejecuta suelto, descomentar y editar:
-- :setvar RUTA_IMP "C:\CAMBIAR\bda-sistema-mundial-futbol\scripts\importacion"
:setvar ARCHIVO_CSV "campanas_dossier.csv"

USE MundialFutbol;
GO

SET NOCOUNT ON;

-- Limpiar cargas previas del mismo archivo en staging para evitar reprocesar filas viejas.
DELETE FROM publicidad.StagingCampania
WHERE NombreArchivo IN ('$(ARCHIVO_CSV)', 'PENDIENTE');

BULK INSERT publicidad.vw_CargaStagingCampania
FROM '$(RUTA_IMP)\resultados\$(ARCHIVO_CSV)'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ';', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

UPDATE publicidad.StagingCampania
SET NombreArchivo = '$(ARCHIVO_CSV)'
WHERE NombreArchivo = 'PENDIENTE';

DECLARE @filasProcesadas INT,
        @filasConError   INT;

EXEC publicidad.SP_IMPORTAR_CAMPANIAS_CSV
     @nombreArchivo   = '$(ARCHIVO_CSV)',
     @filasProcesadas = @filasProcesadas OUTPUT,
     @filasConError   = @filasConError   OUTPUT,
     @codigoISO3Pais  = 'ARG',
     @crearPiezas     = 1;

SELECT 'Campañas del dossier' AS Importacion, @filasProcesadas AS Procesadas, @filasConError AS ConError;

SELECT 'Totales' AS Control,
       (SELECT COUNT(*) FROM publicidad.Anunciante) AS Anunciantes,
       (SELECT COUNT(*) FROM publicidad.Campania)   AS Campanias,
       (SELECT COUNT(*) FROM publicidad.Pieza)      AS Piezas;

SELECT NombreArchivo, IdFilaStaging, MensajeError, DatosCrudos
FROM eventos.LogImportacion
WHERE NombreArchivo = '$(ARCHIVO_CSV)'
ORDER BY IdLogImportacion;
GO
