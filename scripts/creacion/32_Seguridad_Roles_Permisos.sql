/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner (versión original); adaptado al modelo actual por Torczuk, Elías Alexei
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Roles de seguridad con permisos granulares (Entrega 8), implementados con Stored Procedures:
          1. nucleo.SP_CREAR_ROLES_SISTEMA: crea los 4 roles y aplica los GRANT / DENY del cuadro de permisos.
          2. nucleo.SP_ASIGNAR_USUARIO_ROL: agrega un usuario a un rol.
          3. nucleo.SP_REVOCAR_USUARIO_ROL: quita un usuario de un rol.
          4. nucleo.SP_CREAR_USUARIOS_PRUEBA: crea un usuario de prueba (WITHOUT LOGIN) por rol.
          Sin SQL dinámico: la membresía se gestiona con sp_addrolemember / sp_droprolemember, que reciben el
          rol y el usuario como parámetros (ALTER ROLE no admite variables).
          Requiere ejecutados los scripts 01 a 31.
          Tests correspondientes: testing/32_Test_Seguridad_Roles_Permisos.sql (los SP) y un script por usuario:
          32_Test_Rol_Administrador.sql, 32_Test_Rol_OperadorResultados.sql, 32_Test_Rol_GestorPublicidad.sql y
          32_Test_Rol_Consulta.sql.

CUADRO DE PERMISOS (resumen; el detalle está en doc/entrega8/entrega8_seguridad_y_respaldo.md):
  Objeto                                         Administrador  OperadorResultados  GestorPublicidad  Consulta
  Esquemas nucleo, jugadores, eventos, publicidad CONTROL        -                   -                 -
  SELECT nucleo, jugadores, eventos               (CONTROL)      GRANT               solo partidos,    solo vistas y
                                                                                     sedes, países     funciones de
                                                                                     y selecciones     lectura
  SELECT / EXECUTE publicidad                     (CONTROL)      DENY EXECUTE        GRANT             DENY escritura
  EXECUTE eventos (goles, tarjetas, ABM)          (CONTROL)      GRANT               DENY              DENY registro
  SP de jugadores, formaciones y convocatoria     (CONTROL)      GRANT               DENY              -
  SP de partido (control arbitral, finalizar,     (CONTROL)      GRANT               DENY              DENY
    clasificación, cruces)
  Reportes de la entrega 7                        (CONTROL)      los de su área      ocupación y       GRANT los 7
                                                                                     prime time
  INSERT / UPDATE / DELETE directo en tablas      (CONTROL)      -                   -                 DENY
  Descifrado y secreto del hash                   (CONTROL)      DENY                DENY              DENY
  Backups (nucleo.SP_BACKUP_*)                    (CONTROL)      -                   -                 DENY
  "-" = sin permiso (denegado por defecto). (CONTROL) = incluido en el CONTROL de los esquemas.
*/

USE MundialFutbol;
GO

-- =========================================================================
-- 1. SP_CREAR_ROLES_SISTEMA
-- Crea los 4 roles (si faltan) y aplica los permisos. Idempotente: GRANT y DENY se pueden repetir.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_CREAR_ROLES_SISTEMA
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Rol_Administrador' AND type = 'R')
        CREATE ROLE Rol_Administrador;
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Rol_OperadorResultados' AND type = 'R')
        CREATE ROLE Rol_OperadorResultados;
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Rol_GestorPublicidad' AND type = 'R')
        CREATE ROLE Rol_GestorPublicidad;
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Rol_Consulta' AND type = 'R')
        CREATE ROLE Rol_Consulta;

    -- ---------------------------------------------------------------------
    -- 1. Rol_Administrador: control total sobre los esquemas de negocio (no es db_owner: no crea objetos en dbo
    --    ni administra la base).
    -- ---------------------------------------------------------------------
    GRANT CONTROL ON SCHEMA::nucleo     TO Rol_Administrador;
    GRANT CONTROL ON SCHEMA::jugadores  TO Rol_Administrador;
    GRANT CONTROL ON SCHEMA::eventos    TO Rol_Administrador;
    GRANT CONTROL ON SCHEMA::publicidad TO Rol_Administrador;

    -- ---------------------------------------------------------------------
    -- 2. Rol_OperadorResultados: carga de partidos, formaciones, sustituciones, goles y tarjetas.
    -- ---------------------------------------------------------------------
    GRANT EXECUTE ON SCHEMA::eventos   TO Rol_OperadorResultados;
    GRANT EXECUTE ON SCHEMA::jugadores TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::nucleo.SP_CONTROL_ARBITRAL                    TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::nucleo.SP_FINALIZAR_PARTIDO                   TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO          TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES    TO Rol_OperadorResultados;
    GRANT EXECUTE ON OBJECT::nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS       TO Rol_OperadorResultados;
    GRANT SELECT ON SCHEMA::nucleo    TO Rol_OperadorResultados;
    GRANT SELECT ON SCHEMA::jugadores TO Rol_OperadorResultados;
    GRANT SELECT ON SCHEMA::eventos   TO Rol_OperadorResultados;
    DENY EXECUTE ON SCHEMA::publicidad TO Rol_OperadorResultados;
    DENY EXECUTE ON OBJECT::jugadores.SP_CONSULTAR_JUGADOR_DESCIFRADO TO Rol_OperadorResultados;

    -- ---------------------------------------------------------------------
    -- 3. Rol_GestorPublicidad: anunciantes, campañas, piezas, tarifas, pauta e importaciones de publicidad.
    -- ---------------------------------------------------------------------
    GRANT EXECUTE ON SCHEMA::publicidad TO Rol_GestorPublicidad;
    GRANT SELECT  ON SCHEMA::publicidad TO Rol_GestorPublicidad;
    GRANT SELECT ON OBJECT::nucleo.Partido             TO Rol_GestorPublicidad;
    GRANT SELECT ON OBJECT::nucleo.vw_PartidoResultado TO Rol_GestorPublicidad;
    GRANT SELECT ON OBJECT::nucleo.Sede                TO Rol_GestorPublicidad;
    GRANT SELECT ON OBJECT::nucleo.Ciudad              TO Rol_GestorPublicidad;
    GRANT SELECT ON OBJECT::nucleo.Seleccion           TO Rol_GestorPublicidad;
    GRANT SELECT ON OBJECT::nucleo.Pais                TO Rol_GestorPublicidad;
    GRANT SELECT ON OBJECT::nucleo.Fase                TO Rol_GestorPublicidad;
    GRANT SELECT ON OBJECT::nucleo.fn_MercadosEnPrimeTime TO Rol_GestorPublicidad;
    DENY EXECUTE ON SCHEMA::eventos   TO Rol_GestorPublicidad;
    DENY EXECUTE ON SCHEMA::jugadores TO Rol_GestorPublicidad;
    DENY EXECUTE ON OBJECT::nucleo.SP_CONTROL_ARBITRAL                    TO Rol_GestorPublicidad;
    DENY EXECUTE ON OBJECT::nucleo.SP_FINALIZAR_PARTIDO                   TO Rol_GestorPublicidad;
    DENY EXECUTE ON OBJECT::nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS TO Rol_GestorPublicidad;
    DENY EXECUTE ON OBJECT::nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO          TO Rol_GestorPublicidad;

    -- ---------------------------------------------------------------------
    -- 4. Rol_Consulta: prensa, auditoría y organismos: solo reportes y vistas de lectura.
    -- ---------------------------------------------------------------------
    GRANT EXECUTE ON OBJECT::eventos.SP_REPORTE_GOLEADORES                 TO Rol_Consulta;
    GRANT EXECUTE ON OBJECT::eventos.SP_REPORTE_TARJETAS_SUSPENSIONES      TO Rol_Consulta;
    GRANT EXECUTE ON OBJECT::nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES    TO Rol_Consulta;
    GRANT EXECUTE ON OBJECT::publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA  TO Rol_Consulta;
    GRANT EXECUTE ON OBJECT::publicidad.SP_REPORTE_MATRIZ_PRIME_TIME       TO Rol_Consulta;
    GRANT EXECUTE ON OBJECT::jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS   TO Rol_Consulta;
    GRANT EXECUTE ON OBJECT::nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS       TO Rol_Consulta;
    GRANT SELECT ON OBJECT::nucleo.fn_SeleccionesDelPartido   TO Rol_Consulta;
    GRANT SELECT ON OBJECT::nucleo.fn_MercadosEnPrimeTime     TO Rol_Consulta;
    GRANT SELECT ON OBJECT::nucleo.fn_DefinicionPartido       TO Rol_Consulta;
    GRANT SELECT ON OBJECT::nucleo.fn_SeleccionesClasificadas TO Rol_Consulta;
    GRANT SELECT ON OBJECT::nucleo.vw_PartidoResultado        TO Rol_Consulta;
    GRANT SELECT ON OBJECT::eventos.fn_ResultadoPartido       TO Rol_Consulta;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::nucleo     TO Rol_Consulta;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::jugadores  TO Rol_Consulta;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::eventos    TO Rol_Consulta;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::publicidad TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::eventos.SP_REGISTRAR_GOL                       TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::eventos.SP_REGISTRAR_AMONESTACION              TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::publicidad.SP_ASIGNAR_PUBLICIDAD               TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::jugadores.SP_ALTA_Jugador                      TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::jugadores.SP_MODIFICACION_Jugador              TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::jugadores.SP_BAJA_Jugador                      TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_ALTA_Arbitro                         TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_MODIFICACION_Arbitro                 TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_BAJA_Arbitro                         TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_FINALIZAR_PARTIDO                    TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS  TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO           TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_IMPORTAR_PBI_JSON                    TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_IMPORTAR_FIXTURE_CSV                 TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::publicidad.SP_IMPORTAR_COTIZACIONES_JSON       TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::publicidad.SP_IMPORTAR_PAUTA_JSON              TO Rol_Consulta;
    DENY EXECUTE ON OBJECT::publicidad.SP_IMPORTAR_CAMPANIAS_CSV           TO Rol_Consulta;
    -- Los SP de backup se crean en 33_Procedimientos_Backups.sql, que vuelve a ejecutar este SP al final.
    IF OBJECT_ID('nucleo.SP_BACKUP_COMPLETO', 'P') IS NOT NULL
        DENY EXECUTE ON OBJECT::nucleo.SP_BACKUP_COMPLETO    TO Rol_Consulta;
    IF OBJECT_ID('nucleo.SP_BACKUP_DIFERENCIAL', 'P') IS NOT NULL
        DENY EXECUTE ON OBJECT::nucleo.SP_BACKUP_DIFERENCIAL TO Rol_Consulta;
    IF OBJECT_ID('nucleo.SP_BACKUP_LOG', 'P') IS NOT NULL
        DENY EXECUTE ON OBJECT::nucleo.SP_BACKUP_LOG         TO Rol_Consulta;

    -- ---------------------------------------------------------------------
    -- 5. Datos cifrados: solo el administrador descifra o consulta el secreto del hash. Los SP y reportes que
    --    descifran lo hacen por cadena de propiedad (mismo dueño), así que siguen funcionando para los roles
    --    que tienen permiso sobre ellos.
    -- ---------------------------------------------------------------------
    DENY SELECT  ON OBJECT::nucleo.ConfiguracionCifrado             TO Rol_OperadorResultados, Rol_GestorPublicidad, Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.fn_DescifrarTexto                TO Rol_OperadorResultados, Rol_GestorPublicidad, Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_DESCIFRAR_DATO                TO Rol_OperadorResultados, Rol_GestorPublicidad, Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_CONSULTAR_ARBITRO_DESCIFRADO  TO Rol_OperadorResultados, Rol_GestorPublicidad, Rol_Consulta;
    DENY EXECUTE ON OBJECT::nucleo.SP_CONSULTAR_STAFF_DESCIFRADO    TO Rol_OperadorResultados, Rol_GestorPublicidad, Rol_Consulta;
END;
GO

-- =========================================================================
-- Validación compartida de SP_ASIGNAR_USUARIO_ROL y SP_REVOCAR_USUARIO_ROL.
-- Solo admite roles de usuario (no los roles fijos como db_owner) y usuarios de la base.
-- @esAlta = 1: el usuario no debe ser miembro; @esAlta = 0: debe serlo.
-- =========================================================================
CREATE OR ALTER FUNCTION nucleo.fn_ValidarMembresiaRol (@nombreUsuario SYSNAME, @nombreRol SYSNAME, @esAlta BIT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @errores NVARCHAR(MAX) = N'',
            @salto   NVARCHAR(2)   = CHAR(13) + CHAR(10),
            @idRol   INT,
            @idUsr   INT;

    SELECT @idRol = principal_id FROM sys.database_principals
    WHERE name = @nombreRol AND type = 'R' AND is_fixed_role = 0 AND name <> 'public';
    SELECT @idUsr = principal_id FROM sys.database_principals
    WHERE name = @nombreUsuario AND type IN ('S', 'U', 'G', 'E', 'X');

    IF @idRol IS NULL
        SET @errores += N'- El rol indicado no existe o es un rol fijo del sistema (no se administra desde acá).' + @salto;
    IF @idUsr IS NULL
        SET @errores += N'- El usuario indicado no existe en la base de datos.' + @salto;
    IF @idRol IS NOT NULL AND @idUsr IS NOT NULL
    BEGIN
        IF @esAlta = 1 AND EXISTS (SELECT 1 FROM sys.database_role_members WHERE role_principal_id = @idRol AND member_principal_id = @idUsr)
            SET @errores += N'- El usuario ya es miembro de ese rol.' + @salto;
        IF @esAlta = 0 AND NOT EXISTS (SELECT 1 FROM sys.database_role_members WHERE role_principal_id = @idRol AND member_principal_id = @idUsr)
            SET @errores += N'- El usuario no es miembro de ese rol.' + @salto;
    END;

    RETURN @errores;
END;
GO

-- =========================================================================
-- 2. SP_ASIGNAR_USUARIO_ROL
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_ASIGNAR_USUARIO_ROL
    @nombreUsuario SYSNAME,
    @nombreRol     SYSNAME
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = nucleo.fn_ValidarMembresiaRol(@nombreUsuario, @nombreRol, 1),
            @mensaje NVARCHAR(2048);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_ASIGNAR_USUARIO_ROL - No se pudo completar la operación:' + CHAR(13) + CHAR(10) + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    EXEC sys.sp_addrolemember @rolename = @nombreRol, @membername = @nombreUsuario;
END;
GO

-- =========================================================================
-- 3. SP_REVOCAR_USUARIO_ROL
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_REVOCAR_USUARIO_ROL
    @nombreUsuario SYSNAME,
    @nombreRol     SYSNAME
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = nucleo.fn_ValidarMembresiaRol(@nombreUsuario, @nombreRol, 0),
            @mensaje NVARCHAR(2048);

    IF LEN(@errores) > 0
    BEGIN
        SET @mensaje = LEFT(N'SP_REVOCAR_USUARIO_ROL - No se pudo completar la operación:' + CHAR(13) + CHAR(10) + @errores, 2048);
        THROW 52000, @mensaje, 1;
    END;

    EXEC sys.sp_droprolemember @rolename = @nombreRol, @membername = @nombreUsuario;
END;
GO

-- =========================================================================
-- 4. SP_CREAR_USUARIOS_PRUEBA
-- Un usuario WITHOUT LOGIN por rol, para los scripts de test por usuario. Idempotente.
-- =========================================================================
CREATE OR ALTER PROCEDURE nucleo.SP_CREAR_USUARIOS_PRUEBA
AS
BEGIN
    SET NOCOUNT ON;

    EXEC nucleo.SP_CREAR_ROLES_SISTEMA;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_admin_test')
        CREATE USER usr_admin_test WITHOUT LOGIN;
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_resultados_test')
        CREATE USER usr_resultados_test WITHOUT LOGIN;
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_publicidad_test')
        CREATE USER usr_publicidad_test WITHOUT LOGIN;
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_consulta_test')
        CREATE USER usr_consulta_test WITHOUT LOGIN;

    IF IS_ROLEMEMBER('Rol_Administrador', 'usr_admin_test') = 0
        EXEC nucleo.SP_ASIGNAR_USUARIO_ROL 'usr_admin_test', 'Rol_Administrador';
    IF IS_ROLEMEMBER('Rol_OperadorResultados', 'usr_resultados_test') = 0
        EXEC nucleo.SP_ASIGNAR_USUARIO_ROL 'usr_resultados_test', 'Rol_OperadorResultados';
    IF IS_ROLEMEMBER('Rol_GestorPublicidad', 'usr_publicidad_test') = 0
        EXEC nucleo.SP_ASIGNAR_USUARIO_ROL 'usr_publicidad_test', 'Rol_GestorPublicidad';
    IF IS_ROLEMEMBER('Rol_Consulta', 'usr_consulta_test') = 0
        EXEC nucleo.SP_ASIGNAR_USUARIO_ROL 'usr_consulta_test', 'Rol_Consulta';
END;
GO

-- Creación inicial de roles, permisos y usuarios de prueba.
EXEC nucleo.SP_CREAR_USUARIOS_PRUEBA;
GO

PRINT 'Script 32_Seguridad_Roles_Permisos ejecutado correctamente.';
GO
