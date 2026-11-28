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
Objetivo: Ejecutar la importación del archivo XML de convocatorias desde disco hacia
          jugadores.SP_IMPORTAR_CONVOCATORIA_XML sin alterar el archivo fuente y sin
          SQL dinámico.

REQUISITOS PARA EJECUTARLO:
  - Activar el modo SQLCMD en SSMS: menú Consulta > Modo SQLCMD.
  - Editar RUTA_IMP con la ruta local de la carpeta scripts\importacion, la que contiene sql, datos y resultados (sin barra final) (solo si se ejecuta suelto: ver abajo).
  - Tener cargadas previamente las selecciones en nucleo.Seleccion y la regla de cupos
    en jugadores.ReglaConvocados (las deja 04_Seed_Nucleo_Publicidad.sql).
  - ORDEN: después de 04, 05 y 06 y antes de 03_Seed_Jugadores_Eventos.sql, que completa los dorsales libres.
*/

:on error exit
-- Con 00_Cargar_Seeds.sql la ruta se define una sola vez ahí. Si este script se ejecuta suelto, descomentar y editar:
-- :setvar RUTA_IMP "C:\CAMBIAR\bda-sistema-mundial-futbol\scripts\importacion"
:setvar ARCHIVO_XML "planteles_convocatoria.xml"

USE MundialFutbol;
GO

SET NOCOUNT ON;

DECLARE @xml             XML,
        @filasProcesadas INT,
        @filasConError   INT;

SELECT @xml = CAST(BulkColumn AS XML)
FROM OPENROWSET(BULK '$(RUTA_IMP)\datos\$(ARCHIVO_XML)', SINGLE_BLOB) AS x;

EXEC jugadores.SP_IMPORTAR_CONVOCATORIA_XML
    @nombreArchivo   = '$(ARCHIVO_XML)',
    @contenidoXML    = @xml,
    @filasProcesadas = @filasProcesadas OUTPUT,
    @filasConError   = @filasConError OUTPUT;

SELECT *
FROM eventos.LogImportacion
WHERE NombreArchivo = '$(ARCHIVO_XML)'
ORDER BY IdLogImportacion DESC;
GO