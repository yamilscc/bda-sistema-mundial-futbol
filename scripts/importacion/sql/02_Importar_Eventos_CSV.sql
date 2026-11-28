/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-21
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Cargar un archivo CSV de eventos hacia eventos.StagingEvento mediante BULK INSERT
          estático (sin SQL dinámico) y ejecutar eventos.SP_IMPORTAR_EVENTOS_CSV.

REQUISITOS PARA EJECUTARLO:
  - Activar el modo SQLCMD en SSMS: menú Consulta > Modo SQLCMD.
  - Editar RUTA_IMP con la ruta local de la carpeta scripts\importacion, la que contiene sql, datos y resultados (sin barra final) (solo si se ejecuta suelto: ver abajo).
  - Tener cargados previamente los partidos y jugadores convocados.
*/

:on error exit
-- Con 00_Cargar_Seeds.sql la ruta se define una sola vez ahí. Si este script se ejecuta suelto, descomentar y editar:
-- :setvar RUTA_IMP "C:\CAMBIAR\bda-sistema-mundial-futbol\scripts\importacion"
:setvar ARCHIVO_CSV "eventos_partidos.csv"

USE MundialFutbol;
GO

SET NOCOUNT ON;

-- Limpiar cargas previas del mismo archivo en staging para evitar reprocesar filas viejas.
DELETE FROM eventos.StagingEvento
WHERE NombreArchivo IN ('$(ARCHIVO_CSV)', 'PENDIENTE');

BULK INSERT eventos.vw_CargaStagingEvento
FROM '$(RUTA_IMP)\datos\$(ARCHIVO_CSV)'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ';',
    ROWTERMINATOR   = '0x0a',
    CODEPAGE        = '65001',
    TABLOCK
);

UPDATE eventos.StagingEvento
SET NombreArchivo = '$(ARCHIVO_CSV)'
WHERE NombreArchivo = 'PENDIENTE';

DECLARE @filasProcesadas INT,
        @filasConError   INT;

EXEC eventos.SP_IMPORTAR_EVENTOS_CSV
    @nombreArchivo       = '$(ARCHIVO_CSV)',
    @permitirFechaFutura = 1,
    @filasProcesadas     = @filasProcesadas OUTPUT,
    @filasConError       = @filasConError OUTPUT;

SELECT *
FROM eventos.LogImportacion
WHERE NombreArchivo = '$(ARCHIVO_CSV)'
ORDER BY IdLogImportacion DESC;
GO