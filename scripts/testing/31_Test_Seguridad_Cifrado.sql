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
Objetivo: Probar el cifrado de datos sensibles (scripts/creacion/31_Seguridad_Cifrado.sql):
            1. Infraestructura de claves (master key, certificado y clave simétrica) creada por SP.
            2. nucleo.SP_CIFRAR_DATO, nucleo.fn_DescifrarTexto y nucleo.fn_HashDato.
            3. SP_ALTA_/SP_MODIFICACION_ de Jugador, Arbitro y StaffTecnico guardan cifrado, hash y máscara.
            4. Las funciones de búsqueda y de nombre visible encuentran y muestran el dato real.
            5. nucleo.SP_APLICAR_CIFRADO_DATOS_SENSIBLES migra filas en texto plano y es idempotente.
            6. SP de consulta descifrada y sus validaciones.
            7. Impacto en tests previos: una búsqueda directa por la columna pública ya no encuentra la fila.
          Requiere ejecutados los scripts 01 a 31. Todo corre en una transacción que se deshace al final.
*/

USE MundialFutbol;
GO

SET NOCOUNT ON;
BEGIN TRANSACTION;

-- Escenario: un país, una categoría, un grupo y una selección de prueba.
INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST CF31 Confederacion', 'TF31');
DECLARE @idConf TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TF31');
INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST CF31 Pais', 'QW', 'QWA', 'UTC', @idConf);
DECLARE @idPais SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'QWA');
INSERT INTO nucleo.Categoria (Nombre) VALUES ('TEST CF31 Categoria');
DECLARE @idCat TINYINT = (SELECT IdCategoria FROM nucleo.Categoria WHERE Nombre = 'TEST CF31 Categoria');
IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z') INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
VALUES ('QWA', 150, 0, @idPais, (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z'));
DECLARE @idSel TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'QWA');

DECLARE @cifrado1 VARBINARY(512), @cifrado2 VARBINARY(512), @texto NVARCHAR(200), @id INT, @id2 INT,
        @j INT, @a INT, @s INT, @pendJ INT, @pendA INT, @pendS INT, @mensaje NVARCHAR(2048);

-- =========================================================================
-- TEST 1: infraestructura de claves
-- =========================================================================
PRINT '--- TEST 1: claves ---';
-- 1.A Resultado esperado: existen la master key, CertDatosSensibles, ClaveDatosSensibles (AES_256) y el secreto
-- del hash; una segunda ejecución de nucleo.SP_CONFIGURAR_CIFRADO no falla ni duplica nada.
BEGIN TRY
    EXEC nucleo.SP_CONFIGURAR_CIFRADO;
    IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
       AND EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'CertDatosSensibles')
       AND EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'ClaveDatosSensibles' AND algorithm_desc = 'AES_256')
       AND (SELECT COUNT(*) FROM nucleo.ConfiguracionCifrado) = 1
        PRINT '1.A: OK - master key, certificado, clave AES_256 y secreto del hash presentes (configuración idempotente).';
    ELSE PRINT '1.A: FALLÓ - falta algún componente de la infraestructura de cifrado.';
END TRY
BEGIN CATCH
    PRINT '1.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: cifrado, descifrado y hash
-- =========================================================================
PRINT '--- TEST 2: SP_CIFRAR_DATO, fn_DescifrarTexto y fn_HashDato ---';
-- 2.A Resultado esperado: dos cifrados del mismo texto dan bytes distintos y ambos se descifran al original;
-- el hash no distingue mayúsculas ni espacios de los extremos; NULL se cifra como NULL.
EXEC nucleo.SP_CIFRAR_DATO @textoPlano = N'Dato Confidencial Ñandú 38999111', @datoCifrado = @cifrado1 OUTPUT;
EXEC nucleo.SP_CIFRAR_DATO @textoPlano = N'Dato Confidencial Ñandú 38999111', @datoCifrado = @cifrado2 OUTPUT;
EXEC nucleo.SP_DESCIFRAR_DATO @datoCifrado = @cifrado2, @textoPlano = @texto OUTPUT;
IF @cifrado1 <> @cifrado2
   AND nucleo.fn_DescifrarTexto(@cifrado1) = N'Dato Confidencial Ñandú 38999111'
   AND @texto = N'Dato Confidencial Ñandú 38999111'
   AND nucleo.fn_HashDato(N'  abc-123 ') = nucleo.fn_HashDato(N'ABC-123')
   AND nucleo.fn_HashDato(N'abc-123') <> nucleo.fn_HashDato(N'abc-124')
    PRINT '2.A: OK - cifrado no determinista, descifrado exacto (con acentos) y hash normalizado.';
ELSE PRINT '2.A: FALLÓ - el cifrado, el descifrado o el hash no se comportan como se espera.';

SET @cifrado1 = 0x00;
EXEC nucleo.SP_CIFRAR_DATO @textoPlano = NULL, @datoCifrado = @cifrado1 OUTPUT;
IF @cifrado1 IS NULL AND nucleo.fn_DescifrarTexto(NULL) IS NULL
    PRINT '2.B: OK - NULL se cifra y descifra como NULL.';
ELSE PRINT '2.B: FALLÓ - NULL no se mantuvo como NULL.';

-- =========================================================================
-- TEST 3: alta y modificación de jugador
-- =========================================================================
PRINT '--- TEST 3: jugador ---';
-- 3.A Alta con documento 'TEST-CF31-0001'. Resultado esperado: columna pública '***-0001', cifrado que se
-- descifra al documento, hash presente, y jugadores.fn_IdJugadorPorDocumento lo encuentra (también en minúsculas).
BEGIN TRY
    EXEC jugadores.SP_ALTA_Jugador @idJugador = @id OUTPUT, @nombre = 'Prueba', @apellido = 'Cifrado',
         @documento = 'TEST-CF31-0001', @fechaNacimiento = '2000-05-15', @sexo = 'M', @posicion = 'Delantero';
    IF EXISTS (SELECT 1 FROM jugadores.Jugador
               WHERE IdJugador = @id AND Documento = '***-0001' AND DocumentoHash IS NOT NULL
                 AND nucleo.fn_DescifrarTexto(DocumentoCifrado) = N'TEST-CF31-0001')
       AND jugadores.fn_IdJugadorPorDocumento('test-cf31-0001') = @id
        PRINT '3.A: OK - documento guardado cifrado, enmascarado y encontrable por la función de búsqueda.';
    ELSE PRINT '3.A: FALLÓ - el jugador no quedó guardado como se esperaba.';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.B Alta con el mismo documento. Resultado esperado: error 52000 "Ya existe otro jugador con ese documento".
BEGIN TRY
    EXEC jugadores.SP_ALTA_Jugador @nombre = 'Otro', @apellido = 'Duplicado', @documento = 'TEST-CF31-0001',
         @sexo = 'M', @posicion = 'Arquero';
    PRINT '3.B: FALLÓ - permitió un documento repetido.';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%Ya existe otro jugador con ese documento%'
        PRINT '3.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '3.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.C Modificación al documento 'TEST-CF31-0002'. Resultado esperado: el viejo ya no lo encuentra, el nuevo sí,
-- y la máscara pasa a '***-0002'.
BEGIN TRY
    EXEC jugadores.SP_MODIFICACION_Jugador @idJugador = @id, @nombre = 'Prueba', @apellido = 'Cifrado',
         @documento = 'TEST-CF31-0002', @fechaNacimiento = '2000-05-15', @sexo = 'M', @posicion = 'Delantero';
    IF jugadores.fn_IdJugadorPorDocumento('TEST-CF31-0001') IS NULL
       AND jugadores.fn_IdJugadorPorDocumento('TEST-CF31-0002') = @id
       AND EXISTS (SELECT 1 FROM jugadores.Jugador WHERE IdJugador = @id AND Documento = '***-0002')
        PRINT '3.C: OK - modificación recifrada y búsqueda actualizada.';
    ELSE PRINT '3.C: FALLÓ - la modificación no actualizó el dato cifrado.';
END TRY
BEGIN CATCH
    PRINT '3.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: árbitro y staff técnico
-- =========================================================================
PRINT '--- TEST 4: árbitro y staff técnico ---';
-- 4.A Alta de árbitro 'TEST CF31 Árbitro Uno' y de un director técnico 'TEST CF31 DT Uno'. Resultado esperado:
-- columna pública '***-CONFIDENCIAL-<id>***', nombre real con fn_NombreArbitro / fn_NombreStaff, y las búsquedas
-- por nombre devuelven el Id.
BEGIN TRY
    EXEC nucleo.SP_ALTA_Arbitro @idArbitro = @id OUTPUT, @nombreApellido = 'TEST CF31 Árbitro Uno', @sexo = 'F',
         @fechaNacimiento = '1985-03-10', @idPais = @idPais, @idCategoria = @idCat;
    EXEC nucleo.SP_ALTA_StaffTecnico @idStaffTecnico = @id2 OUTPUT, @idSeleccion = @idSel,
         @nombreApellido = 'TEST CF31 DT Uno', @rol = 'Director Técnico';
    IF EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE IdArbitro = @id
               AND NombreApellido = '***-CONFIDENCIAL-' + CAST(@id AS VARCHAR(10)) + '***')
       AND nucleo.fn_NombreArbitro(@id) = 'TEST CF31 Árbitro Uno'
       AND nucleo.fn_IdArbitroPorNombre('test cf31 árbitro uno') = @id
       AND EXISTS (SELECT 1 FROM nucleo.StaffTecnico WHERE IdStaffTecnico = @id2 AND NombreApellido LIKE '***-CONFIDENCIAL-%')
       AND nucleo.fn_NombreStaff(@id2) = 'TEST CF31 DT Uno'
       AND nucleo.fn_IdStaffPorNombre('TEST CF31 DT Uno') = @id2
        PRINT '4.A: OK - árbitro y staff cifrados, nombre visible descifrado y búsqueda por nombre.';
    ELSE PRINT '4.A: FALLÓ - el árbitro o el staff no quedaron guardados como se esperaba.';
END TRY
BEGIN CATCH
    PRINT '4.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 4.B Modificación del nombre del árbitro. Resultado esperado: fn_NombreArbitro devuelve el nombre nuevo y el
-- viejo ya no se encuentra.
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Arbitro @idArbitro = @id, @nombreApellido = 'TEST CF31 Árbitro Modificado', @sexo = 'F',
         @fechaNacimiento = '1985-03-10', @idPais = @idPais, @idCategoria = @idCat;
    IF nucleo.fn_NombreArbitro(@id) = 'TEST CF31 Árbitro Modificado'
       AND nucleo.fn_IdArbitroPorNombre('TEST CF31 Árbitro Uno') IS NULL
        PRINT '4.B: OK - nombre del árbitro recifrado.';
    ELSE PRINT '4.B: FALLÓ - la modificación del árbitro no actualizó el dato cifrado.';
END TRY
BEGIN CATCH
    PRINT '4.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 5: migración de filas en texto plano
-- =========================================================================
PRINT '--- TEST 5: SP_APLICAR_CIFRADO_DATOS_SENSIBLES ---';
-- Filas cargadas directo en texto plano (como las de los tests de entregas anteriores).
INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion)
VALUES ('Plano', 'Uno', 'TEST-CF31-P1', 'M', 'Arquero'), ('Plano', 'Dos', 'TEST-CF31-P2', 'M', 'Defensor');
INSERT INTO nucleo.Arbitro (NombreApellido, Sexo, FechaNacimiento, IdPais, IdCategoria)
VALUES ('TEST CF31 Árbitro Plano', 'M', '1980-01-01', @idPais, @idCat);

-- 5.A Antes de migrar, las funciones encuentran las filas en texto plano por la columna pública.
IF jugadores.fn_IdJugadorPorDocumento('TEST-CF31-P1') IS NOT NULL
   AND nucleo.fn_IdArbitroPorNombre('TEST CF31 Árbitro Plano') IS NOT NULL
    PRINT '5.A: OK - filas en texto plano encontradas antes de migrar.';
ELSE PRINT '5.A: FALLÓ - las funciones no encuentran filas en texto plano.';

-- 5.B Resultado esperado: se cifran exactamente las filas que estaban sin cifrar (al menos las 2 + 1 de prueba),
-- quedan enmascaradas y se siguen encontrando; una segunda corrida devuelve 0, 0 y 0.
SELECT @pendJ = (SELECT COUNT(*) FROM jugadores.Jugador WHERE DocumentoCifrado IS NULL),
       @pendA = (SELECT COUNT(*) FROM nucleo.Arbitro WHERE NombreApellidoCifrado IS NULL),
       @pendS = (SELECT COUNT(*) FROM nucleo.StaffTecnico WHERE NombreApellidoCifrado IS NULL);
BEGIN TRY
    EXEC nucleo.SP_APLICAR_CIFRADO_DATOS_SENSIBLES @jugadoresCifrados = @j OUTPUT, @arbitrosCifrados = @a OUTPUT,
         @staffCifrado = @s OUTPUT;
    IF @j = @pendJ AND @a = @pendA AND @s = @pendS AND @j >= 2 AND @a >= 1
       AND NOT EXISTS (SELECT 1 FROM jugadores.Jugador WHERE Documento IN ('TEST-CF31-P1', 'TEST-CF31-P2'))
       AND jugadores.fn_IdJugadorPorDocumento('TEST-CF31-P2') IS NOT NULL
       AND nucleo.fn_NombreArbitro(nucleo.fn_IdArbitroPorNombre('TEST CF31 Árbitro Plano')) = 'TEST CF31 Árbitro Plano'
    BEGIN
        EXEC nucleo.SP_APLICAR_CIFRADO_DATOS_SENSIBLES @jugadoresCifrados = @j OUTPUT, @arbitrosCifrados = @a OUTPUT,
             @staffCifrado = @s OUTPUT;
        IF @j = 0 AND @a = 0 AND @s = 0
            PRINT '5.B: OK - migración de ' + CAST(@pendJ AS VARCHAR(10)) + ' jugadores, ' + CAST(@pendA AS VARCHAR(10))
                  + ' árbitros y ' + CAST(@pendS AS VARCHAR(10)) + ' staff; la segunda corrida no cambia nada.';
        ELSE PRINT '5.B: FALLÓ - la segunda corrida volvió a cifrar filas.';
    END
    ELSE PRINT '5.B: FALLÓ - la migración no cifró lo esperado.';
END TRY
BEGIN CATCH
    PRINT '5.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 6: consulta descifrada
-- =========================================================================
PRINT '--- TEST 6: consulta descifrada ---';
-- 6.A Resultado esperado: SP_CONSULTAR_JUGADOR_DESCIFRADO devuelve el documento 'TEST-CF31-0002'.
DECLARE @consulta TABLE (IdJugador INT, Nombre VARCHAR(60), Apellido VARCHAR(60), DocumentoEnmascarado VARCHAR(20),
                         Documento VARCHAR(20), FechaNacimiento DATE, Sexo CHAR(1), Posicion VARCHAR(20), Club VARCHAR(100));
SET @id = jugadores.fn_IdJugadorPorDocumento('TEST-CF31-0002');
INSERT INTO @consulta EXEC jugadores.SP_CONSULTAR_JUGADOR_DESCIFRADO @idJugador = @id;
IF (SELECT Documento FROM @consulta) = 'TEST-CF31-0002' AND (SELECT DocumentoEnmascarado FROM @consulta) = '***-0002'
    PRINT '6.A: OK - el SP de consulta devuelve el documento descifrado y la máscara.';
ELSE PRINT '6.A: FALLÓ - el SP de consulta no devolvió el documento original.';

-- 6.B Jugador inexistente. Resultado esperado: error 52000.
BEGIN TRY
    EXEC jugadores.SP_CONSULTAR_JUGADOR_DESCIFRADO @idJugador = -1;
    PRINT '6.B: FALLÓ - aceptó un jugador inexistente.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 52000 PRINT '6.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
    ELSE PRINT '6.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 7: impacto en tests de entregas anteriores (consigna)
-- =========================================================================
PRINT '--- TEST 7: impacto en consultas previas ---';
-- 7.A Resultado esperado: una consulta como las de los tests anteriores (WHERE Documento = '...') ya no encuentra
-- al jugador dado de alta con el SP: devuelve 0 filas. Por eso esos tests requieren adecuación (doc/entrega8).
IF NOT EXISTS (SELECT 1 FROM jugadores.Jugador WHERE Documento = 'TEST-CF31-0002')
   AND NOT EXISTS (SELECT 1 FROM nucleo.Arbitro WHERE NombreApellido = 'TEST CF31 Árbitro Modificado')
    PRINT '7.A: OK - la columna pública ya no contiene el dato: las búsquedas directas devuelven 0 filas.';
ELSE PRINT '7.A: FALLÓ - el dato sensible sigue visible en la columna pública.';

ROLLBACK TRANSACTION;
GO
