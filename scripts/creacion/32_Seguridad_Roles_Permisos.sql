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
Objetivo: Implementar la gestión de Roles de Seguridad y Permisos Granulares
          para la Entrega 8 mediante Stored Procedures en el esquema nucleo:
          1. nucleo.SP_CREAR_ROLES_SISTEMA: Crea 4 roles de seguridad
             (Rol_Administrador, Rol_OperadorResultados, Rol_GestorPublicidad, Rol_Consulta)
             y aplica permisos granulares (GRANT/DENY) sobre esquemas y procedimientos.
          2. nucleo.SP_ASIGNAR_USUARIO_ROL: Asocia un usuario a un rol.
          3. nucleo.SP_REVOCAR_USUARIO_ROL: Desvincula un usuario de un rol.
          4. nucleo.SP_CREAR_USUARIOS_PRUEBA: Genera usuarios de prueba (WITHOUT LOGIN)
             y los asigna a sus roles correspondientes para ejecutar los scripts de testing.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. SP_CREAR_ROLES_SISTEMA
-- Crea los 4 roles de base de datos y aplica los permisos granulares.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_CREAR_ROLES_SISTEMA
AS
BEGIN
    SET NOCOUNT ON;

    -- A. Creación de Roles de Base de Datos
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Rol_Administrador' AND type = 'R')
    BEGIN
        CREATE ROLE Rol_Administrador;
        PRINT 'Rol creado: Rol_Administrador';
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Rol_OperadorResultados' AND type = 'R')
    BEGIN
        CREATE ROLE Rol_OperadorResultados;
        PRINT 'Rol creado: Rol_OperadorResultados';
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Rol_GestorPublicidad' AND type = 'R')
    BEGIN
        CREATE ROLE Rol_GestorPublicidad;
        PRINT 'Rol creado: Rol_GestorPublicidad';
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Rol_Consulta' AND type = 'R')
    BEGIN
        CREATE ROLE Rol_Consulta;
        PRINT 'Rol creado: Rol_Consulta';
    END;

    -- =====================================================================
    -- B. ASIGNACIÓN GRANULAR DE PERMISOS
    -- =====================================================================

    -- ---------------------------------------------------------------------
    -- 1. Rol_Administrador: Control total sobre los esquemas de negocio
    -- ---------------------------------------------------------------------
    GRANT CONTROL ON SCHEMA::nucleo TO Rol_Administrador;
    GRANT CONTROL ON SCHEMA::jugadores TO Rol_Administrador;
    GRANT CONTROL ON SCHEMA::eventos TO Rol_Administrador;
    GRANT CONTROL ON SCHEMA::publicidad TO Rol_Administrador;

    -- ---------------------------------------------------------------------
    -- 2. Rol_OperadorResultados: Carga de goles, tarjetas, alineaciones y partidos
    -- ---------------------------------------------------------------------
    -- Permiso de ejecución en procedimientos de eventos y partidos
    GRANT EXECUTE ON SCHEMA::eventos TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::nucleo.SP_CONTROL_ARBITRAL TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::nucleo.SP_FINALIZAR_PARTIDO TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::jugadores.SP_REGISTRAR_FORMACION TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::jugadores.SP_AGREGAR_JUGADOR_FORMACION TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::jugadores.SP_REGISTRAR_SUSTITUCION TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::jugadores.SP_CONVOCAR_JUGADOR TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::jugadores.SP_REGISTRAR_BAJA_CONVOCATORIA TO Rol_OperadorResultados;
    
    -- Lectura sobre catálogos para consulta operativa
    GRANT SELECT ON SCHEMA::nucleo TO Rol_OperadorResultados;
    GRANT SELECT ON SCHEMA::jugadores TO Rol_OperadorResultados;
    GRANT SELECT ON SCHEMA::eventos TO Rol_OperadorResultados;

    -- DENY explícito sobre procedimientos de publicidad y administración
    DENY EXECUTE ON SCHEMA::publicidad TO Rol_OperadorResultados;

    -- ---------------------------------------------------------------------
    -- 3. Rol_GestorPublicidad: Asignación de pauta, anunciantes y piezas
    -- ---------------------------------------------------------------------
    GRANT EXECUTE ON SCHEMA::publicidad TO Rol_GestorPublicidad;
    GRANT SELECT ON SCHEMA::publicidad TO Rol_GestorPublicidad;

    -- Lectura sobre partidos y sedes para análisis de pauta
    GRANT SELECT ON OBJECT::nucleo.Partido TO Rol_GestorPublicidad;
    GRANT SELECT ON OBJECT::nucleo.vw_PartidoResultado TO Rol_GestorPublicidad;
    GRANT SELECT ON OBJECT::nucleo.Sede TO Rol_GestorPublicidad;
    GRANT SELECT ON OBJECT::nucleo.Seleccion TO Rol_GestorPublicidad;
    GRANT SELECT ON OBJECT::nucleo.Pais TO Rol_GestorPublicidad;

    -- DENY explícito sobre eventos de juego, alineaciones y jugadores
    DENY EXECUTE ON SCHEMA::eventos TO Rol_GestorPublicidad;
    DENY EXECUTE ON SCHEMA::jugadores TO Rol_GestorPublicidad;
    DENY EXECUTE ON OBJECT::nucleo.SP_CONTROL_ARBITRAL TO Rol_GestorPublicidad;
    DENY EXECUTE ON OBJECT::nucleo.SP_FINALIZAR_PARTIDO TO Rol_GestorPublicidad;
    DENY EXECUTE ON OBJECT::nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS TO Rol_GestorPublicidad;
    DENY EXECUTE ON OBJECT::nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO TO Rol_GestorPublicidad;

    -- ---------------------------------------------------------------------
    -- 4. Rol_Consulta: Acceso exclusivo a Reportes y lectura general
    -- ---------------------------------------------------------------------
    -- Permisos de ejecución sobre los reportes oficiales de la Entrega 7
    GRANT EXECUTE ON OBJECT::eventos.SP_REPORTE_GOLEADORES TO Rol_Consulta;
    GRANT EXECUTE ON OBJECT::eventos.SP_REPORTE_TARJETAS_SUSPENSIONES TO Rol_Consulta;
    GRANT EXECUTE ON OBJECT::nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES TO Rol_Consulta;
    GRANT EXECUTE ON OBJECT::publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA TO Rol_Consulta;
    GRANT EXECUTE ON OBJECT::publicidad.SP_REPORTE_MATRIZ_PRIME_TIME TO Rol_Consulta;
    GRANT EXECUTE ON OBJECT::jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS TO Rol_Consulta;
    GRANT EXECUTE ON OBJECT::nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS TO Rol_Consulta;

    -- Funciones de lectura (las funciones de tabla requieren GRANT SELECT en SQL Server)
    GRANT SELECT ON OBJECT::nucleo.fn_SeleccionesDelPartido TO Rol_Consulta;
    GRANT SELECT ON OBJECT::nucleo.fn_MercadosEnPrimeTime TO Rol_Consulta;
    GRANT SELECT ON OBJECT::nucleo.fn_DefinicionPartido TO Rol_Consulta;
    GRANT SELECT ON OBJECT::nucleo.fn_SeleccionesClasificadas TO Rol_Consulta;
    GRANT SELECT ON OBJECT::nucleo.vw_PartidoResultado TO Rol_Consulta;
    GRANT SELECT ON OBJECT::eventos.fn_ResultadoPartido TO Rol_Consulta;

    -- DENY explícito de modificación y ejecución de SPs transaccionales/ABMs
    DENY INSERT, UPDATE, DELETE ON SCHEMA::nucleo TO Rol_Consulta;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::jugadores TO Rol_Consulta;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::eventos TO Rol_Consulta;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::publicidad TO Rol_Consulta;

    DENY EXECUTE ON OBJECT::eventos.SP_REGISTRAR_GOL TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::eventos.SP_REGISTRAR_AMONESTACION TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::publicidad.SP_ASIGNAR_PUBLICIDAD TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::jugadores.SP_ABM_Jugador TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_ABM_Arbitro TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_FINALIZAR_PARTIDO TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_IMPORTAR_PBI_JSON TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_IMPORTAR_FIXTURE_CSV TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::publicidad.SP_IMPORTAR_COTIZACIONES_JSON TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::publicidad.SP_IMPORTAR_PAUTA_JSON TO Rol_Consulta;

    PRINT 'Permisos granulares asignados con éxito a los 4 roles.';
END;
GO

-- =========================================================================
-- 2. SP_ASIGNAR_USUARIO_ROL
-- Asocia un usuario de base de datos a un rol específico.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ASIGNAR_USUARIO_ROL
    @nombreUsuario SYSNAME,
    @nombreRol     SYSNAME
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @nombreRol AND type = 'R')
        THROW 53001, 'El rol indicado no existe en la base de datos.', 1;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @nombreUsuario AND type IN ('S', 'U', 'G'))
        THROW 53002, 'El usuario indicado no existe en la base de datos.', 1;

    DECLARE @sql NVARCHAR(500);
    SET @sql = N'ALTER ROLE ' + QUOTENAME(@nombreRol) + N' ADD MEMBER ' + QUOTENAME(@nombreUsuario) + N';';
    EXEC sys.sp_executesql @sql;

    PRINT 'Usuario [' + @nombreUsuario + '] asignado exitosamente al rol [' + @nombreRol + '].';
END;
GO

-- =========================================================================
-- 3. SP_REVOCAR_USUARIO_ROL
-- Desvincula un usuario de un rol específico.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_REVOCAR_USUARIO_ROL
    @nombreUsuario SYSNAME,
    @nombreRol     SYSNAME
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @nombreRol AND type = 'R')
        THROW 53003, 'El rol indicado no existe en la base de datos.', 1;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @nombreUsuario AND type IN ('S', 'U', 'G'))
        THROW 53004, 'El usuario indicado no existe en la base de datos.', 1;

    DECLARE @sql NVARCHAR(500);
    SET @sql = N'ALTER ROLE ' + QUOTENAME(@nombreRol) + N' DROP MEMBER ' + QUOTENAME(@nombreUsuario) + N';';
    EXEC sys.sp_executesql @sql;

    PRINT 'Usuario [' + @nombreUsuario + '] desvinculado exitosamente del rol [' + @nombreRol + '].';
END;
GO

-- =========================================================================
-- 4. SP_CREAR_USUARIOS_PRUEBA
-- Procedimiento auxiliar para instanciar usuarios de prueba WITHOUT LOGIN
-- vinculados a cada uno de los 4 roles para ejecutar los scripts de testing.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_CREAR_USUARIOS_PRUEBA
AS
BEGIN
    SET NOCOUNT ON;

    -- Asegurar roles creados
    EXEC nucleo.SP_CREAR_ROLES_SISTEMA;

    -- Usuario 1: Administrador
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_admin_test')
    BEGIN
        CREATE USER usr_admin_test WITHOUT LOGIN;
        PRINT 'Usuario creado: usr_admin_test';
    END;
    EXEC nucleo.SP_ASIGNAR_USUARIO_ROL 'usr_admin_test', 'Rol_Administrador';

    -- Usuario 2: Operador de Resultados
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_resultados_test')
    BEGIN
        CREATE USER usr_resultados_test WITHOUT LOGIN;
        PRINT 'Usuario creado: usr_resultados_test';
    END;
    EXEC nucleo.SP_ASIGNAR_USUARIO_ROL 'usr_resultados_test', 'Rol_OperadorResultados';

    -- Usuario 3: Gestor de Publicidad
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_publicidad_test')
    BEGIN
        CREATE USER usr_publicidad_test WITHOUT LOGIN;
        PRINT 'Usuario creado: usr_publicidad_test';
    END;
    EXEC nucleo.SP_ASIGNAR_USUARIO_ROL 'usr_publicidad_test', 'Rol_GestorPublicidad';

    -- Usuario 4: Consulta / Auditoría
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_consulta_test')
    BEGIN
        CREATE USER usr_consulta_test WITHOUT LOGIN;
        PRINT 'Usuario creado: usr_consulta_test';
    END;
    EXEC nucleo.SP_ASIGNAR_USUARIO_ROL 'usr_consulta_test', 'Rol_Consulta';

    PRINT 'Usuarios de prueba creados y asociados a sus roles.';
END;
GO

-- Ejecutar la creación inicial de roles y usuarios
EXEC nucleo.SP_CREAR_ROLES_SISTEMA;
EXEC nucleo.SP_CREAR_USUARIOS_PRUEBA;
GO

PRINT 'Script 32_Seguridad_Roles_Permisos ejecutado correctamente.';
GO
