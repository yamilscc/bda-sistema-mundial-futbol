/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner (versión original); rehecho por Torczuk, Elías Alexei
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar los SP de roles y permisos (scripts/creacion/32_Seguridad_Roles_Permisos.sql):
            1. nucleo.SP_CREAR_ROLES_SISTEMA: idempotente, crea los 4 roles y los DENY sobre datos cifrados.
            2. nucleo.SP_CREAR_USUARIOS_PRUEBA: cada usuario de prueba pertenece a su rol.
            3. nucleo.SP_ASIGNAR_USUARIO_ROL y nucleo.SP_REVOCAR_USUARIO_ROL: alta, baja y validaciones agrupadas
               (rol o usuario inexistente, rol fijo del sistema, membresía repetida o inexistente).
          Qué puede y qué no puede hacer cada usuario se prueba en un script por usuario:
          32_Test_Rol_Administrador.sql, 32_Test_Rol_OperadorResultados.sql, 32_Test_Rol_GestorPublicidad.sql y
          32_Test_Rol_Consulta.sql.
          Requiere ejecutados los scripts 01 a 33. Todo corre en una transacción que se deshace al final.
*/

USE MundialFutbol;
GO

SET NOCOUNT ON;
BEGIN TRANSACTION;

DECLARE @mensaje NVARCHAR(2048), @lineas INT;

-- =========================================================================
-- TEST 1: roles
-- =========================================================================
PRINT '--- TEST 1: SP_CREAR_ROLES_SISTEMA ---';
-- 1.A Resultado esperado: una segunda ejecución no falla; existen los 4 roles; los 3 roles no administradores
-- tienen DENY sobre nucleo.ConfiguracionCifrado y nucleo.fn_DescifrarTexto, y Rol_Administrador tiene CONTROL
-- sobre los 4 esquemas.
BEGIN TRY
    EXEC nucleo.SP_CREAR_ROLES_SISTEMA;
    IF (SELECT COUNT(*) FROM sys.database_principals
        WHERE type = 'R' AND name IN ('Rol_Administrador', 'Rol_OperadorResultados', 'Rol_GestorPublicidad', 'Rol_Consulta')) = 4
       AND (SELECT COUNT(*) FROM sys.database_permissions AS dp
            INNER JOIN sys.database_principals AS pr ON pr.principal_id = dp.grantee_principal_id
            WHERE dp.state = 'D' AND dp.major_id IN (OBJECT_ID('nucleo.ConfiguracionCifrado'), OBJECT_ID('nucleo.fn_DescifrarTexto'))
              AND pr.name IN ('Rol_OperadorResultados', 'Rol_GestorPublicidad', 'Rol_Consulta')) = 6
       AND (SELECT COUNT(*) FROM sys.database_permissions AS dp
            INNER JOIN sys.database_principals AS pr ON pr.principal_id = dp.grantee_principal_id
            WHERE pr.name = 'Rol_Administrador' AND dp.class_desc = 'SCHEMA' AND dp.permission_name = 'CONTROL' AND dp.state = 'G') = 4
        PRINT '1.A: OK - 4 roles, CONTROL del administrador y DENY sobre los datos cifrados (idempotente).';
    ELSE PRINT '1.A: FALLÓ - faltan roles o permisos.';
END TRY
BEGIN CATCH
    PRINT '1.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: usuarios de prueba
-- =========================================================================
PRINT '--- TEST 2: SP_CREAR_USUARIOS_PRUEBA ---';
-- 2.A Resultado esperado: una segunda ejecución no falla y cada usuario es miembro de su rol.
BEGIN TRY
    EXEC nucleo.SP_CREAR_USUARIOS_PRUEBA;
    IF IS_ROLEMEMBER('Rol_Administrador', 'usr_admin_test') = 1
       AND IS_ROLEMEMBER('Rol_OperadorResultados', 'usr_resultados_test') = 1
       AND IS_ROLEMEMBER('Rol_GestorPublicidad', 'usr_publicidad_test') = 1
       AND IS_ROLEMEMBER('Rol_Consulta', 'usr_consulta_test') = 1
        PRINT '2.A: OK - los 4 usuarios de prueba pertenecen a su rol.';
    ELSE PRINT '2.A: FALLÓ - algún usuario de prueba no está en su rol.';
END TRY
BEGIN CATCH
    PRINT '2.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: asignar y revocar
-- =========================================================================
PRINT '--- TEST 3: SP_ASIGNAR_USUARIO_ROL y SP_REVOCAR_USUARIO_ROL ---';
CREATE USER usr_test_32 WITHOUT LOGIN;

-- 3.A Alta y baja de un usuario nuevo en Rol_Consulta. Resultado esperado: queda miembro y después deja de serlo.
BEGIN TRY
    EXEC nucleo.SP_ASIGNAR_USUARIO_ROL @nombreUsuario = 'usr_test_32', @nombreRol = 'Rol_Consulta';
    IF IS_ROLEMEMBER('Rol_Consulta', 'usr_test_32') = 1
    BEGIN
        EXEC nucleo.SP_REVOCAR_USUARIO_ROL @nombreUsuario = 'usr_test_32', @nombreRol = 'Rol_Consulta';
        IF IS_ROLEMEMBER('Rol_Consulta', 'usr_test_32') = 0
            PRINT '3.A: OK - el usuario se agregó y se quitó del rol.';
        ELSE PRINT '3.A: FALLÓ - la revocación no quitó al usuario del rol.';
    END
    ELSE PRINT '3.A: FALLÓ - la asignación no agregó al usuario al rol.';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.B Rol y usuario inexistentes. Resultado esperado: error 52000 con 2 renglones.
BEGIN TRY
    EXEC nucleo.SP_ASIGNAR_USUARIO_ROL @nombreUsuario = 'usr_no_existe', @nombreRol = 'Rol_No_Existe';
    PRINT '3.B: FALLÓ - aceptó rol y usuario inexistentes.';
END TRY
BEGIN CATCH
    SET @mensaje = ERROR_MESSAGE();
    SET @lineas = (LEN(@mensaje) - LEN(REPLACE(@mensaje, CHAR(10) + '- ', ''))) / 3;
    IF ERROR_NUMBER() = 52000 AND @lineas = 2 PRINT '3.B: OK (Bloqueado) - ' + REPLACE(@mensaje, CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '3.B: FALLÓ - ' + @mensaje;
END CATCH;

-- 3.C Rol fijo del sistema (db_owner). Resultado esperado: error 52000 (no se administra desde este SP).
BEGIN TRY
    EXEC nucleo.SP_ASIGNAR_USUARIO_ROL @nombreUsuario = 'usr_test_32', @nombreRol = 'db_owner';
    PRINT '3.C: FALLÓ - permitió agregar un usuario a db_owner.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 52000 AND IS_ROLEMEMBER('db_owner', 'usr_test_32') = 0
        PRINT '3.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '3.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.D Membresía repetida y revocación de una membresía inexistente. Resultado esperado: dos errores 52000.
BEGIN TRY
    EXEC nucleo.SP_ASIGNAR_USUARIO_ROL @nombreUsuario = 'usr_consulta_test', @nombreRol = 'Rol_Consulta';
    PRINT '3.D: FALLÓ - permitió repetir la membresía.';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%ya es miembro%' PRINT '3.D: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '3.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;
BEGIN TRY
    EXEC nucleo.SP_REVOCAR_USUARIO_ROL @nombreUsuario = 'usr_test_32', @nombreRol = 'Rol_Consulta';
    PRINT '3.E: FALLÓ - permitió revocar una membresía inexistente.';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%no es miembro%' PRINT '3.E: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '3.E: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

ROLLBACK TRANSACTION;
GO
