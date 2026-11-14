/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Canseco Carrizo, Yamil Simón (versión original); ampliado por Torczuk, Elías Alexei
Fecha: 2026-11-14
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Script maestro de arranque. Se ejecuta SIEMPRE primero, cada vez que se quiere
          levantar la base desde cero:
            1. Elimina la base MundialFutbol si existe (con ella desaparecen tablas, SP,
               funciones, vistas, triggers, roles y usuarios viejos).
            2. Crea la base MundialFutbol vacía.
            3. Crea todos los schemas del proyecto.
          Después se ejecutan los demás scripts numerados (01, 02, 03...) en orden.
*/

SET NOCOUNT ON;
GO

USE master;
GO

-- =========================================================================
-- 1. ELIMINAR LA BASE ANTERIOR
-- Se cierran las conexiones abiertas a la base para poder borrarla.
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
-- 2. CREAR LA BASE
-- =========================================================================
CREATE DATABASE MundialFutbol;
GO
PRINT 'Base MundialFutbol creada.';
GO

USE MundialFutbol;
GO

-- =========================================================================
-- 3. CREAR LOS SCHEMAS
-- CREATE SCHEMA no admite variables ni IF dentro de su batch, por eso es uno de los pocos
-- casos donde el SQL dinámico es estrictamente necesario. La lista se recorre con un cursor.
-- Para agregar un schema nuevo, sumarlo a la lista de abajo.
-- =========================================================================
DECLARE @schemas TABLE (Nombre SYSNAME PRIMARY KEY);

INSERT INTO @schemas (Nombre)
VALUES ('nucleo'),       -- países, sedes, partidos, árbitros
       ('jugadores'),    -- jugadores, convocatoria, formaciones, sustituciones
       ('eventos'),      -- goles, tarjetas, suspensiones, staging y logs de importación
       ('publicidad');   -- anunciantes, campañas, espacios y asignaciones

DECLARE @nombreSchema SYSNAME;

DECLARE cSchemas CURSOR LOCAL FAST_FORWARD FOR
    SELECT Nombre FROM @schemas ORDER BY Nombre;

OPEN cSchemas;
FETCH NEXT FROM cSchemas INTO @nombreSchema;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF SCHEMA_ID(@nombreSchema) IS NULL
    BEGIN
        EXEC('CREATE SCHEMA ' + @nombreSchema);
        PRINT 'Schema creado: ' + @nombreSchema;
    END;

    FETCH NEXT FROM cSchemas INTO @nombreSchema;
END;

CLOSE cSchemas;
DEALLOCATE cSchemas;
GO

-- =========================================================================
-- VERIFICACIÓN
-- Resultado esperado: una fila por cada schema de la lista, y 0 tablas.
-- =========================================================================
SELECT s.name AS SchemaCreado
FROM sys.schemas AS s
WHERE s.name IN ('nucleo', 'jugadores', 'eventos', 'publicidad')
ORDER BY s.name;

SELECT COUNT(*) AS TablasExistentes_Esperado_0 FROM sys.tables;
GO

PRINT 'Reset completo. Ejecutar ahora los scripts 01, 02, 03... en orden.';
GO
