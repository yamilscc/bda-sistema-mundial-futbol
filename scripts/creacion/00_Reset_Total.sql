/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Canseco Carrizo, Yamil Simón (versión original); ampliado por Torczuk, Elías Alexei
Fecha: 2026-11-15
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Script maestro. Se ejecuta SIEMPRE primero para levantar la base desde cero:
            1. Borra la base MundialFutbol si existe (con ella desaparecen tablas, SP, funciones,
               vistas, triggers, roles, usuarios y claves de cifrado de la base).
            2. Crea la base vacía y todos los schemas.
            3. Ejecuta en orden los scripts de creación (tablas, FK, funciones, SP).
            4. Muestra un resumen de los objetos creados.

REQUISITOS PARA EJECUTARLO:
  - Activar el modo SQLCMD en SSMS: menú Consulta > Modo SQLCMD (sin esto fallan :setvar y :r).
  - Editar abajo la variable RUTA con la carpeta scripts\creacion de TU copia del repositorio,
    sin barra final. Ejemplo: C:\Users\yamil\bda-sistema-mundial-futbol\scripts\creacion
  - Conectarse con un usuario que pueda borrar y crear bases (sysadmin o dbcreator).

Los scripts de testing y de seed NO se ejecutan desde acá (se corren aparte).
*/

:on error exit
:setvar RUTA C:\CAMBIAR\bda-sistema-mundial-futbol\scripts\creacion

SET NOCOUNT ON;
GO

USE master;
GO

-- =========================================================================
-- 1. BORRADO: elimina todo lo que ya exista
-- Se cierran las conexiones abiertas a la base y se la borra completa.
-- Al borrar la base se eliminan todos sus objetos (tablas, SP, funciones, vistas,
-- triggers, roles, usuarios, certificados y claves de la base).
-- Los logins se crean a nivel servidor y NO se borran con la base: si la entrega de
-- seguridad crea logins, hay que sumarlos acá con un DROP LOGIN ... validado.
-- =========================================================================
IF DB_ID('MundialFutbol') IS NOT NULL
BEGIN
    ALTER DATABASE MundialFutbol SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MundialFutbol;
    PRINT 'Base MundialFutbol eliminada.';
END
ELSE
    PRINT 'La base MundialFutbol no existía.';
GO

-- =========================================================================
-- 2. CREACIÓN DE LA BASE
-- =========================================================================
CREATE DATABASE MundialFutbol;
GO
PRINT 'Base MundialFutbol creada.';
GO

USE MundialFutbol;
GO

-- =========================================================================
-- 3. SCHEMAS
-- CREATE SCHEMA tiene que ir solo en su batch, por eso se ejecuta con EXEC con texto fijo
-- (único uso de SQL dinámico del proyecto, estrictamente necesario). Para agregar un schema
-- nuevo, sumar un bloque igual.
-- =========================================================================
IF SCHEMA_ID('nucleo') IS NULL            -- países, sedes, partidos, árbitros
BEGIN
    EXEC('CREATE SCHEMA nucleo');
    PRINT 'Schema creado: nucleo';
END;

IF SCHEMA_ID('jugadores') IS NULL         -- jugadores, convocatoria, formaciones, sustituciones
BEGIN
    EXEC('CREATE SCHEMA jugadores');
    PRINT 'Schema creado: jugadores';
END;

IF SCHEMA_ID('eventos') IS NULL           -- goles, tarjetas, suspensiones, staging y logs de importación
BEGIN
    EXEC('CREATE SCHEMA eventos');
    PRINT 'Schema creado: eventos';
END;

IF SCHEMA_ID('publicidad') IS NULL        -- anunciantes, piezas, espacios y asignaciones
BEGIN
    EXEC('CREATE SCHEMA publicidad');
    PRINT 'Schema creado: publicidad';
END;
GO

-- =========================================================================
-- 4. EJECUCIÓN ORDENADA DE LOS SCRIPTS DE CREACIÓN
-- :r incluye cada archivo en esta misma sesión (quedan en la base MundialFutbol).
-- Si alguno falla, :on error exit corta toda la ejecución en ese punto.
-- Cada PRINT lleva su GO para que el primer comando del archivo incluido (ej: CREATE OR ALTER
-- PROCEDURE, que exige ir primero en su batch) no comparta batch con el PRINT.
-- =========================================================================

PRINT '--- 01 Tablas del núcleo';
GO
:r $(RUTA)\01_Tablas_Nucleo.sql

PRINT '--- 02 Tablas de jugadores y alineaciones';
GO
:r $(RUTA)\02_Tablas_Jugadores_y_Alineaciones.sql

PRINT '--- 03 Tablas de eventos';
GO
:r $(RUTA)\03_Tablas_Eventos.sql

PRINT '--- 04 Tablas de publicidad';
GO
:r $(RUTA)\04_Tablas_Publicidad.sql

PRINT '--- 05 Tablas de logs y staging';
GO
:r $(RUTA)\05_Tablas_Logs_Staging.sql

PRINT '--- 06 FK cruzadas entre módulos';
GO
:r $(RUTA)\06_FK_Cruzadas.sql

PRINT '--- 07 Funciones del núcleo';
GO
:r $(RUTA)\07_Funciones_Nucleo.sql

PRINT '--- 08 SP de control arbitral';
GO
:r $(RUTA)\08_SP_ControlArbitral.sql

PRINT '--- 09 SP de sedes y partidos';
GO
:r $(RUTA)\09_SP_Sedes_Partidos.sql

PRINT '--- 10 Funciones de eventos';
GO
:r $(RUTA)\10_Funciones_Eventos.sql

PRINT '--- 11 SP registrar gol';
GO
:r $(RUTA)\11_SP_RegistrarGol.sql

PRINT '--- 12 SP registrar amonestación';
GO
:r $(RUTA)\12_SP_RegistrarAmonestacion.sql

PRINT '--- 13 SP ABM de eventos';
GO
:r $(RUTA)\13_SP_ABM_Eventos.sql

PRINT '--- 14 Funciones de jugadores';
GO
:r $(RUTA)\14_Funciones_Jugadores.sql
GO

PRINT '--- 15 SP de convocatoria y bajas';
GO
:r $(RUTA)\15_SP_Convocatoria_Baja.sql
GO

PRINT '--- 16 SP registrar formación y titulares/suplentes';
GO
:r $(RUTA)\16_SP_RegistrarFormacion.sql
GO

PRINT '--- 17 SP registrar sustitución';
GO
:r $(RUTA)\17_SP_RegistrarSustitucion.sql
GO

PRINT '--- 18 SP ABM de jugadores';
GO
:r $(RUTA)\18_SP_ABM_Jugadores.sql
GO

PRINT '--- 19 SP ABM restantes del nucleo';
GO
:r $(RUTA)\19_SP_ABM_Nucleo.sql
GO

PRINT '--- 20 SP ABM de publicidad';
GO
:r $(RUTA)\20_SP_ABM_Publicidad.sql
GO

PRINT '--- 21 SP asignar publicidad';
GO
:r $(RUTA)\21_SP_AsignarPublicidad.sql
GO

PRINT '--- 22 SP importación de nucleo y publicidad (PBI, cotizaciones, pauta y fixture)';
GO
:r $(RUTA)\22_SP_Importacion_Nucleo_Publicidad.sql
GO

PRINT '--- 23 SP importación XML de jugadores';
GO
:r $(RUTA)\23_SP_Importacion_Jugadores.sql
GO

PRINT '--- 24 SP importación CSV de eventos';
GO
:r $(RUTA)\24_SP_Importacion_Eventos.sql
GO

-- Los próximos SP, vistas y funciones se suman acá, siempre en orden numérico.

-- =========================================================================
-- 5. RESUMEN
-- Resultado esperado: filas por schema con la cantidad de tablas, SP y funciones creadas.
-- =========================================================================
USE MundialFutbol;
GO

SELECT s.name AS [Schema],
       SUM(CASE WHEN o.type = 'U' THEN 1 ELSE 0 END)                AS Tablas,
       SUM(CASE WHEN o.type = 'P' THEN 1 ELSE 0 END)                AS StoredProcedures,
       SUM(CASE WHEN o.type IN ('FN', 'IF', 'TF') THEN 1 ELSE 0 END) AS Funciones,
       SUM(CASE WHEN o.type = 'V' THEN 1 ELSE 0 END)                AS Vistas
FROM sys.schemas AS s
LEFT JOIN sys.objects AS o ON o.schema_id = s.schema_id AND o.is_ms_shipped = 0
WHERE s.name IN ('nucleo', 'jugadores', 'eventos', 'publicidad')
GROUP BY s.name
ORDER BY s.name;
GO

PRINT 'Base MundialFutbol lista.';
GO