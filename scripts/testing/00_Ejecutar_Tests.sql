/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Canseco Carrizo, Yamil Simón
Integrantes:
Casella, Mateo Ezequiel
Chungara Tenorio, Denis Abner
Torczuk, Elías Alexei
Canseco Carrizo, Yamil Simón
Objetivo:
	- Orquestar la ejecución de TODOS los scripts de testing en el orden de su número
	  (01 a 32 y el test del seed en importacion/), igual que 00_Reset_Total.sql orquesta los scripts de creación.
	- Entre test y test, deshacer cualquier transacción que haya quedado abierta, para que
	  un test cortado a mitad de camino no arrastre sus datos al siguiente.
	- Verificar al inicio que la base exista y esté recién creada (el test 01 lo requiere).

REQUISITOS PARA EJECUTARLO:
	- Ejecutar ANTES creacion\00_Reset_Total.sql (base recién creada, sin datos de prueba).
	- Activar el modo SQLCMD en SSMS: menú Consulta > Modo SQLCMD (sin esto fallan :setvar y :r).
	- Editar abajo la variable RUTA con la carpeta scripts\testing de TU copia del repositorio,
	  sin barra final. Ejemplo: C:\Users\elias\bda-sistema-mundial-futbol\scripts\testing
	- Recomendado: Resultados a texto (Ctrl+T) en vez de cuadrícula. Varios tests devuelven
	  muchos SELECT de evidencia y la cuadrícula consume mucha memoria en SSMS.

CÓMO LEER EL RESULTADO:
	- Cada test imprime su encabezado "===== TEST xx" en la pestaña Mensajes.
	- Buscar (Ctrl+F) "FALLÓ" en Mensajes: no debería aparecer ninguna vez.
	- Los casos que se verifican con SELECT traen el valor esperado en el nombre de la
	  columna (ej: Filas_Esperadas_0) o en el comentario "-- Esperado:" del test.
	- Se usa ":on error ignore" a propósito: un error no controlado en un test se informa
	  en Mensajes pero NO corta la corrida, así se ejecutan todos los tests igual.
*/

:on error ignore
:setvar RUTA C:\CAMBIAR\bda-sistema-mundial-futbol\scripts\testing

SET NOCOUNT ON;
GO

-- =========================================================================
-- VERIFICACIÓN PREVIA
-- =========================================================================
IF DB_ID('MundialFutbol') IS NULL
	PRINT 'ATENCIÓN: la base MundialFutbol no existe. Ejecutar primero creacion\00_Reset_Total.sql.';
GO

USE MundialFutbol;
GO

IF EXISTS (SELECT 1 FROM nucleo.Grupo) OR EXISTS (SELECT 1 FROM nucleo.Partido)
	PRINT 'ATENCIÓN: la base ya tiene grupos o partidos cargados. El test 01 espera una base recién '
	    + 'creada: conviene ejecutar antes creacion\00_Reset_Total.sql.';
GO

DECLARE @inicio DATETIME2(0) = SYSDATETIME();
PRINT 'Inicio de la corrida de tests: ' + CONVERT(VARCHAR(19), @inicio, 120);
GO

-- =========================================================================
-- EJECUCIÓN ORDENADA DE LOS TESTS
-- Después de cada :r va el bloque de control: deshace transacciones abiertas y vuelve a la
-- base MundialFutbol (por si un test cambió de contexto).
-- =========================================================================

PRINT '===== TEST 01 Tablas del núcleo';
GO
:r $(RUTA)\01_Test_Tablas_Nucleo.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 02 Tablas de jugadores';
GO
:r $(RUTA)\02_Test_Tablas_Jugadores.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 03 Tablas de eventos';
GO
:r $(RUTA)\03_Test_Tablas_Eventos.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 04 Tablas de publicidad';
GO
:r $(RUTA)\04_Test_Tablas_Publicidad.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 07 Funciones del núcleo';
GO
:r $(RUTA)\07_Test_Funciones_Nucleo.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 08 SP de control arbitral';
GO
:r $(RUTA)\08_Test_SP_ControlArbitral.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 09 SP de sedes y partidos';
GO
:r $(RUTA)\09_Test_SP_Sedes_Partidos.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 10 Funciones de eventos';
GO
:r $(RUTA)\10_Test_Funciones_Eventos.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 11 SP registrar gol';
GO
:r $(RUTA)\11_Test_SP_RegistrarGol.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 12 SP registrar amonestación';
GO
:r $(RUTA)\12_Test_SP_RegistrarAmonestacion.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 13 SP ABM de eventos';
GO
:r $(RUTA)\13_Test_SP_ABM_Eventos.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 14 Funciones de jugadores';
GO
:r $(RUTA)\14_Test_Funciones_Jugadores.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 15 SP de convocatoria y bajas';
GO
:r $(RUTA)\15_Test_SP_Convocatoria_Baja.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 16 SP registrar formación';
GO
:r $(RUTA)\16_Test_SP_RegistrarFormacion.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 17 SP registrar sustitución';
GO
:r $(RUTA)\17_Test_SP_RegistrarSustitucion.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 18 SP ABM de jugadores';
GO
:r $(RUTA)\18_Test_SP_ABM_Jugadores.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 19 SP ABM restantes del núcleo';
GO
:r $(RUTA)\19_Test_SP_ABM_Nucleo.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 20 SP ABM de publicidad';
GO
:r $(RUTA)\20_Test_SP_ABM_Publicidad.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 21 SP asignar publicidad';
GO
:r $(RUTA)\21_Test_SP_AsignarPublicidad.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 22 Importación de nucleo y publicidad (fixture, PBI, cotizaciones y pauta)';
GO
:r $(RUTA)\22_Test_SP_Importacion_Nucleo_Publicidad.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 23 SP importación XML de jugadores';
GO
:r $(RUTA)\23_Test_SP_Importacion_Jugadores.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 24 SP importación CSV de eventos';
GO
:r $(RUTA)\24_Test_SP_Importacion_Eventos.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 25 Funciones de partidos';
GO
:r $(RUTA)\25_Test_Funciones_Partidos.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 26 SP finalizar partido';
GO
:r $(RUTA)\26_Test_SP_FinalizarPartido.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 27 SP cálculo de selecciones clasificadas';
GO
:r $(RUTA)\27_Test_SP_CalculoSeleccionesClasificadas.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 28 SP definir cruce eliminatorio';
GO
:r $(RUTA)\28_Test_SP_DefinirCruceEliminatorio.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 29 SP importación de campañas del dossier';
GO
:r $(RUTA)\29_Test_SP_Importacion_Campanias.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST importacion/03 Seed de jugadores y eventos (escenario aislado)';
GO
:r $(RUTA)\importacion\03_Test_Seed_Jugadores_Eventos.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 29 Stored Procedures de Reportes (Entrega 7)';
GO
:r $(RUTA)\29_Test_SP_Reportes.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 30 Seguridad: Cifrado de Datos Sensibles (Entrega 8)';
GO
:r $(RUTA)\30_Test_Seguridad_Cifrado.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 31 Seguridad: Roles y Permisos (Entrega 8)';
GO
:r $(RUTA)\31_Test_Seguridad_Roles_Permisos.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

PRINT '===== TEST 32 Procedimientos de Backup (Entrega 8)';
GO
:r $(RUTA)\32_Test_Backups.sql
GO
WHILE @@TRANCOUNT > 0 BEGIN ROLLBACK TRANSACTION; PRINT 'Aviso: quedó una transacción abierta tras el test anterior; se deshizo.'; END;
GO
USE MundialFutbol;
GO

-- =========================================================================
-- CONTROL FINAL: los tests no deben dejar datos de prueba en la base
-- =========================================================================
PRINT '===== CONTROL FINAL';
SELECT 'Datos de prueba remanentes (esperado: 0 en todas las filas)' AS Control, t.Tabla, t.Cantidad
FROM (
	SELECT 'nucleo.Pais'          AS Tabla, COUNT(*) AS Cantidad FROM nucleo.Pais          WHERE Nombre        LIKE 'TEST%'
	UNION ALL
	SELECT 'nucleo.Confederacion',          COUNT(*)             FROM nucleo.Confederacion WHERE Nombre        LIKE 'TEST%'
	UNION ALL
	SELECT 'nucleo.Sede',                   COUNT(*)             FROM nucleo.Sede          WHERE NombreEstadio LIKE 'TEST%'
	UNION ALL
	SELECT 'nucleo.Arbitro',                COUNT(*)             FROM nucleo.Arbitro       WHERE NombreApellido LIKE 'TEST%'
	UNION ALL
	SELECT 'nucleo.Ciudad',                 COUNT(*)             FROM nucleo.Ciudad        WHERE Nombre        LIKE 'TEST%'
	UNION ALL
	SELECT 'nucleo.Categoria',              COUNT(*)             FROM nucleo.Categoria     WHERE Nombre        LIKE 'TEST%'
) AS t;

PRINT 'Fin de la corrida de tests: ' + CONVERT(VARCHAR(19), SYSDATETIME(), 120);
PRINT 'Buscar "FALLÓ" en la pestaña Mensajes: no debería aparecer ninguna vez.';
GO

SET NOCOUNT OFF;
GO
