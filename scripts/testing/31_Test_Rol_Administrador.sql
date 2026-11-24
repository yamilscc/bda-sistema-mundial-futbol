/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner
Fecha: 2026-11-23
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Validar los permisos del usuario [usr_admin_test] perteneciente al rol [Rol_Administrador].
          El Administrador posee permisos totales de CONTROL sobre los esquemas nucleo,
          jugadores, eventos y publicidad.
*/

USE MundialFutbol;
GO

PRINT '=========================================================================';
PRINT 'TEST DE PERMISOS: Usuario [usr_admin_test] (Rol_Administrador)';
PRINT '=========================================================================';
GO

-- Cambiar contexto de seguridad al usuario administrador
EXECUTE AS USER = 'usr_admin_test';
PRINT 'Contexto actual: ' + USER_NAME();
GO

-- 1. CASO EXITOSO: Consulta sobre tablas del núcleo y jugadores
-- Resultado esperado: Retorna filas sin error de permisos.
SELECT TOP 3 IdPais, Nombre, CodigoISO3 FROM nucleo.Pais;
SELECT TOP 3 IdJugador, Nombre, Apellido FROM jugadores.Jugador;
GO

-- 2. CASO EXITOSO: Ejecución de procedimientos de publicidad
-- Resultado esperado: Ejecución de SP de reportes o ABM de publicidad exitosa.
EXEC publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA;
GO

-- 3. CASO EXITOSO: Ejecución de procedimientos deportivos
-- Resultado esperado: Ejecución de SP de reportes de goleadores exitosa.
EXEC eventos.SP_REPORTE_GOLEADORES;
GO

-- Restaurar contexto
REVERT;
PRINT 'Contexto restaurado: ' + USER_NAME();
PRINT 'Test Rol_Administrador FINALIZADO CON ÉXITO.';
GO
