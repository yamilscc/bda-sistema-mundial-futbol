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
  - Editar RUTA_IMP con la ruta local de la carpeta scripts\importacion (sin barra final).
  - Tener cargadas previamente las selecciones en nucleo.Seleccion y la regla de cupos
    en jugadores.ReglaConvocados.
*/

:on error exit
:setvar RUTA_IMP "C:\CAMBIAR\bda-sistema-mundial-futbol\scripts\importacion"
:setvar ARCHIVO_XML "planteles_convocatoria.xml"

USE MundialFutbol;
GO

SET NOCOUNT ON;

DECLARE @xml             XML,
        @filasProcesadas INT,
        @filasConError   INT;

SELECT @xml = CAST(BulkColumn AS XML)
FROM OPENROWSET(BULK '$(RUTA_IMP)\$(ARCHIVO_XML)', SINGLE_BLOB) AS x;

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