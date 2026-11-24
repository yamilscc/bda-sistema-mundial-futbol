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
Objetivo: Validar los mecanismos de cifrado y descifrado de datos sensibles (Entrega 8):
          1. Verificación de almacenamiento binario y enmascaramiento en tablas.
          2. Prueba de funciones escalares nucleo.fn_CifrarTexto y nucleo.fn_DescifrarTexto.
          3. Prueba de inserción segura mediante SP_ABM_Jugador.
          4. Verificación de consulta descifrada mediante SP_CONSULTAR_JUGADOR_DESCIFRADO.
          5. Demostración de falla esperada en consultas previas basadas en texto plano.
*/

USE MundialFutbol;
GO

PRINT '=========================================================================';
PRINT 'TEST 1: Verificación de funciones nucleo.fn_CifrarTexto y nucleo.fn_DescifrarTexto';
PRINT '=========================================================================';
GO

-- Resultado esperado:
-- El texto plano cifrado devuelve un valor VARBINARY. Al descifrarlo,
-- coincide exactamente con el texto plano original.
DECLARE @textoOriginal NVARCHAR(100) = N'DatoConfidencial_DNI_38999111';
DECLARE @cifrado VARBINARY(MAX);
DECLARE @descifrado NVARCHAR(MAX);

SET @cifrado = nucleo.fn_CifrarTexto(@textoOriginal);
SET @descifrado = nucleo.fn_DescifrarTexto(@cifrado);

SELECT @textoOriginal AS Original,
       @cifrado       AS EncriptadoBinario,
       @descifrado    AS DescifradoResultado,
       CASE WHEN @textoOriginal = @descifrado THEN 'EXITO (Coinciden)' ELSE 'FALLA' END AS EstadoPrueba;
GO

PRINT '=========================================================================';
PRINT 'TEST 2: Alta de jugador con documento sensible y verificación en tabla';
PRINT '=========================================================================';
GO

-- Resultado esperado:
-- El procedimiento jugadores.SP_ABM_Jugador inserta el registro almacenando
-- la máscara '***-9999' en la columna pública Documento y los bytes cifrados en DocumentoCifrado.
DECLARE @idNuevo INT;
DECLARE @docPrueba VARCHAR(20) = '40123999';

EXEC jugadores.SP_ABM_Jugador
    @operacion       = 'ALTA',
    @idJugador       = @idNuevo OUTPUT,
    @nombre          = 'PruebaCifrado',
    @apellido        = 'TestSeguridad',
    @documento       = @docPrueba,
    @fechaNacimiento = '2000-05-15',
    @sexo            = 'M',
    @posicion        = 'Delantero',
    @idClub          = NULL;

-- Consultar directamente la tabla para evidenciar que el dato no es legible en texto plano
SELECT IdJugador,
       Nombre,
       Apellido,
       Documento AS [DocumentoEnTabla (Mascara)],
       DocumentoCifrado AS [DocumentoEnTabla (BinarioCifrado)]
FROM jugadores.Jugador
WHERE IdJugador = @idNuevo;

PRINT '=========================================================================';
PRINT 'TEST 3: Consulta descifrada autorizada';
PRINT '=========================================================================';
-- Resultado esperado:
-- SP_CONSULTAR_JUGADOR_DESCIFRADO retorna DocumentoOriginal = '40123999'.
EXEC jugadores.SP_CONSULTAR_JUGADOR_DESCIFRADO @idJugador = @idNuevo;

PRINT '=========================================================================';
PRINT 'TEST 4: Demostración de impacto en testing previo (Consigna Entrega 8)';
PRINT '=========================================================================';
-- Resultado esperado:
-- Una consulta directa de testing anterior que filtre WHERE Documento = '40123999'
-- no devolverá filas (0 filas) porque el documento fue enmascarado, justificando
-- por qué las pruebas de entregas previas requieren adecuación.
SELECT COUNT(*) AS [FilasEncontradasConQueryTradicional]
FROM jugadores.Jugador
WHERE Documento = '40123999';

-- Limpieza del jugador de prueba
EXEC jugadores.SP_ABM_Jugador @operacion = 'BAJA', @idJugador = @idNuevo;
PRINT 'Jugador de prueba eliminado.';
GO
