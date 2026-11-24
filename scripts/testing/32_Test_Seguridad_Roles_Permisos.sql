/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Validar los permisos de los usuarios asociados a los cuatro roles de seguridad (Entrega 8):
          1. [Rol_Administrador] (usr_admin_test): permisos totales de CONTROL sobre los esquemas.
          2. [Rol_OperadorResultados] (usr_resultados_test): permisos de gestión deportiva y denegación en publicidad.
          3. [Rol_GestorPublicidad] (usr_publicidad_test): permisos de gestión publicitaria y denegación en eventos y jugadores.
          4. [Rol_Consulta] (usr_consulta_test): lectura y reportes oficiales, denegación en modificaciones y ABM.
          Requiere ejecutados los scripts 01 a 31 (usa los usuarios creados en 32_Seguridad_Roles_Permisos.sql).
*/

USE MundialFutbol;
GO

SET NOCOUNT ON;
GO

PRINT '=========================================================================';
PRINT 'TEST 31: VALIDACIÓN DE ROLES Y PERMISOS DE SEGURIDAD (ENTREGA 8)';
PRINT '=========================================================================';
GO

-- =========================================================================
-- 1. TEST ROL ADMINISTRADOR (usr_admin_test)
-- =========================================================================
PRINT '--- 1. Usuario [usr_admin_test] (Rol_Administrador) ---';
GO

EXECUTE AS USER = 'usr_admin_test';
PRINT 'Contexto actual: ' + USER_NAME();
GO

-- 1.1 CASO EXITOSO: Consulta sobre tablas del núcleo y jugadores
SELECT TOP 3 IdPais, Nombre, CodigoISO3 FROM nucleo.Pais;
SELECT TOP 3 IdJugador, Nombre, Apellido FROM jugadores.Jugador;
GO

-- 1.2 CASO EXITOSO: Ejecución de procedimientos de publicidad
EXEC publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA;
GO

-- 1.3 CASO EXITOSO: Ejecución de procedimientos deportivos
EXEC eventos.SP_REPORTE_GOLEADORES;
GO

REVERT;
PRINT 'Contexto restaurado: ' + USER_NAME();
PRINT 'Rol_Administrador: OK.';
GO

-- =========================================================================
-- 2. TEST ROL OPERADOR DE RESULTADOS (usr_resultados_test)
-- =========================================================================
PRINT '--- 2. Usuario [usr_resultados_test] (Rol_OperadorResultados) ---';
GO

EXECUTE AS USER = 'usr_resultados_test';
PRINT 'Contexto actual: ' + USER_NAME();
GO

-- 2.1 CASO EXITOSO: Consulta de partidos y selecciones autorizada
SELECT TOP 3 IdPartido, FechaHoraUTC, IdSede FROM nucleo.Partido;
GO

-- 2.2 CASO EXITOSO: Ejecución de reporte de eventos
EXEC eventos.SP_REPORTE_GOLEADORES;
GO

-- 2.3 CASO DENEGADO CONTROLADO: Intentar ejecutar SP de publicidad
BEGIN TRY
    PRINT 'Intentando ejecutar publicidad.SP_ASIGNAR_PUBLICIDAD...';
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = 1, @tarifaPublicitaria = 1000, @idMoneda = 1;
    PRINT 'FALLÓ: El operador no debía poder ejecutar SP de publicidad.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'OK (Bloqueado): Permiso denegado a SP de publicidad correctamente.';
    ELSE
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-- 2.4 CASO DENEGADO CONTROLADO: Intentar ejecutar ABM de Anunciante
BEGIN TRY
    PRINT 'Intentando ejecutar publicidad.SP_ABM_Anunciante...';
    EXEC publicidad.SP_ABM_Anunciante @operacion = 'ALTA', @nombre = 'TestDenegado';
    PRINT 'FALLÓ: El operador no debía poder gestionar anunciantes.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'OK (Bloqueado): Permiso denegado a SP_ABM_Anunciante correctamente.';
    ELSE
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
END CATCH;
GO

REVERT;
PRINT 'Contexto restaurado: ' + USER_NAME();
PRINT 'Rol_OperadorResultados: OK.';
GO

-- =========================================================================
-- 3. TEST ROL GESTOR DE PUBLICIDAD (usr_publicidad_test)
-- =========================================================================
PRINT '--- 3. Usuario [usr_publicidad_test] (Rol_GestorPublicidad) ---';
GO

EXECUTE AS USER = 'usr_publicidad_test';
PRINT 'Contexto actual: ' + USER_NAME();
GO

-- 3.1 CASO EXITOSO: Consulta de partidos y sedes autorizada para análisis de pauta
SELECT TOP 3 IdSede, NombreEstadio, Capacidad FROM nucleo.Sede;
SELECT TOP 3 IdPartido, FechaHoraUTC FROM nucleo.Partido;
GO

-- 3.2 CASO EXITOSO: Ejecución de reporte de ocupación publicitaria
EXEC publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA;
GO

-- 3.3 CASO DENEGADO CONTROLADO: Intentar registrar un gol deportivo
BEGIN TRY
    PRINT 'Intentando ejecutar eventos.SP_REGISTRAR_GOL...';
    EXEC eventos.SP_REGISTRAR_GOL
        @idPartido       = 1,
        @idJugadorAutor  = 10,
        @minuto          = 45,
        @idTipoGol       = 1,
        @idPeriodo       = 1;
    PRINT 'FALLÓ: El gestor publicitario no debía poder registrar goles.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'OK (Bloqueado): Permiso denegado a SP_REGISTRAR_GOL correctamente.';
    ELSE
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-- 3.4 CASO DENEGADO CONTROLADO: Intentar modificar jugadores
BEGIN TRY
    PRINT 'Intentando ejecutar jugadores.SP_ABM_Jugador...';
    EXEC jugadores.SP_ABM_Jugador @operacion = 'ALTA', @nombre = 'Infiltrado';
    PRINT 'FALLÓ: El gestor publicitario no debía tener acceso al ABM de jugadores.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'OK (Bloqueado): Permiso denegado a SP_ABM_Jugador correctamente.';
    ELSE
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
END CATCH;
GO

REVERT;
PRINT 'Contexto restaurado: ' + USER_NAME();
PRINT 'Rol_GestorPublicidad: OK.';
GO

-- =========================================================================
-- 4. TEST ROL CONSULTA (usr_consulta_test)
-- =========================================================================
PRINT '--- 4. Usuario [usr_consulta_test] (Rol_Consulta) ---';
GO

EXECUTE AS USER = 'usr_consulta_test';
PRINT 'Contexto actual: ' + USER_NAME();
GO

-- 4.1 CASO EXITOSO: Ejecución autorizada de reportes
EXEC eventos.SP_REPORTE_GOLEADORES;
EXEC publicidad.SP_REPORTE_MATRIZ_PRIME_TIME;
GO

-- 4.2 CASO DENEGADO CONTROLADO: Intentar realizar un INSERT directo en tablas
BEGIN TRY
    PRINT 'Intentando insertar directamente en nucleo.Pais...';
    INSERT INTO nucleo.Pais (Nombre, CodigoISO3, IdConfederacion)
    VALUES ('PaisInfiltrado', 'XXX', 1);
    PRINT 'FALLÓ: El usuario de consulta no debe poder insertar datos.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'OK (Bloqueado): INSERT denegado correctamente.';
    ELSE
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-- 4.3 CASO DENEGADO CONTROLADO: Intentar ejecutar SP transaccional de registro
BEGIN TRY
    PRINT 'Intentando ejecutar eventos.SP_REGISTRAR_AMONESTACION...';
    EXEC eventos.SP_REGISTRAR_AMONESTACION @idPartido = 1, @idJugador = 1, @minuto = 10, @idTipoTarjeta = 1;
    PRINT 'FALLÓ: El usuario de consulta no debe poder registrar amonestaciones.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'OK (Bloqueado): Permiso denegado a SP_REGISTRAR_AMONESTACION correctamente.';
    ELSE
        PRINT 'Error inesperado: ' + ERROR_MESSAGE();
END CATCH;
GO

REVERT;
PRINT 'Contexto restaurado: ' + USER_NAME();
PRINT 'Rol_Consulta: OK.';
GO

PRINT '=========================================================================';
PRINT 'TEST 31 Roles y Permisos de Seguridad: FINALIZADO CON ÉXITO.';
PRINT '=========================================================================';
GO
