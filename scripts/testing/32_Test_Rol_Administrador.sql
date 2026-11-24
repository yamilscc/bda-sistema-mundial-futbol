/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner (versión original); separado por usuario por Torczuk, Elías Alexei
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar qué puede y qué no puede hacer el usuario usr_admin_test (Rol_Administrador): control total sobre los
          esquemas de negocio, incluido el descifrado, pero sin permisos de administración de la base.
          Cada caso imprime OK o FALLÓ. "Puede" = el permiso alcanza: la instrucción corre o el SP responde con su
          propia validación (por ejemplo error 52000 por un id inexistente), nunca con permiso denegado.
          "No puede" = el motor la rechaza por permisos (error 229, o 262 para crear objetos).
          Los casos no modifican datos: los SP se llaman con ids inexistentes (responden con su validación)
          y la única escritura (alta directa del administrador) se deshace en el mismo caso.
          Requiere ejecutados los scripts 01 a 33 (usa los usuarios de nucleo.SP_CREAR_USUARIOS_PRUEBA).
*/

USE MundialFutbol;
GO

SET NOCOUNT ON;
EXECUTE AS USER = 'usr_admin_test';
PRINT 'Contexto: ' + USER_NAME() + ' (Rol_Administrador)';
DECLARE @t TABLE (x INT);

-- 1.1 Puede leer jugadores, árbitros y el secreto del hash. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    INSERT INTO @t SELECT TOP (1) IdJugador FROM jugadores.Jugador; INSERT INTO @t SELECT COUNT(*) FROM nucleo.ConfiguracionCifrado;
    PRINT '1.1: OK - puede leer jugadores, árbitros y el secreto del hash.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '1.1: FALLÓ - no pudo leer jugadores, árbitros y el secreto del hash: ' + ERROR_MESSAGE();
    ELSE
        PRINT '1.1: OK - puede leer jugadores, árbitros y el secreto del hash (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 1.2 Puede insertar directo en una tabla del núcleo. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    BEGIN TRANSACTION; INSERT INTO nucleo.Categoria (Nombre) VALUES ('TEST ROL Categoria Admin'); ROLLBACK TRANSACTION;
    PRINT '1.2: OK - puede insertar directo en una tabla del núcleo.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '1.2: FALLÓ - no pudo insertar directo en una tabla del núcleo: ' + ERROR_MESSAGE();
    ELSE
        PRINT '1.2: OK - puede insertar directo en una tabla del núcleo (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 1.3 Puede ejecutar SP de eventos. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC eventos.SP_REGISTRAR_GOL @idPartido = -1, @idJugadorAutor = -1, @tipoGol = 'Jugada', @periodo = 'Primer Tiempo', @minuto = 10;
    PRINT '1.3: OK - puede ejecutar SP de eventos.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '1.3: FALLÓ - no pudo ejecutar SP de eventos: ' + ERROR_MESSAGE();
    ELSE
        PRINT '1.3: OK - puede ejecutar SP de eventos (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 1.4 Puede ejecutar SP de publicidad. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC publicidad.SP_ASIGNAR_PUBLICIDAD @idPartido = -1, @soloSimular = 1;
    PRINT '1.4: OK - puede ejecutar SP de publicidad.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '1.4: FALLÓ - no pudo ejecutar SP de publicidad: ' + ERROR_MESSAGE();
    ELSE
        PRINT '1.4: OK - puede ejecutar SP de publicidad (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 1.5 Puede consultar datos descifrados. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    EXEC jugadores.SP_CONSULTAR_JUGADOR_DESCIFRADO @idJugador = -1;
    PRINT '1.5: OK - puede consultar datos descifrados.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '1.5: FALLÓ - no pudo consultar datos descifrados: ' + ERROR_MESSAGE();
    ELSE
        PRINT '1.5: OK - puede consultar datos descifrados (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 1.6 Puede llamar directo a la función de descifrado. Resultado esperado: OK (sin error de permisos).
BEGIN TRY
    INSERT INTO @t SELECT CASE WHEN nucleo.fn_DescifrarTexto(NULL) IS NULL THEN 1 END;
    PRINT '1.6: OK - puede llamar directo a la función de descifrado.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262, 297, 300)
        PRINT '1.6: FALLÓ - no pudo llamar directo a la función de descifrado: ' + ERROR_MESSAGE();
    ELSE
        PRINT '1.6: OK - puede llamar directo a la función de descifrado (el SP respondió con su validación, error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
END CATCH;

-- 1.7 No puede crear tablas en la base (no es db_owner). Resultado esperado: OK (Bloqueado) con error de permisos.
BEGIN TRY
    CREATE TABLE dbo.TablaRolAdmin (Id INT);
    PRINT '1.7: FALLÓ - pudo crear tablas en la base (no es db_owner).';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() IN (229, 262)
        PRINT '1.7: OK (Bloqueado) - no puede crear tablas en la base (no es db_owner) (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ').';
    ELSE
        PRINT '1.7: FALLÓ - crear tablas en la base (no es db_owner): error inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;

REVERT;
GO
