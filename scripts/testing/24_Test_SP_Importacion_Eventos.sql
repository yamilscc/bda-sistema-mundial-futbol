/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Fecha: 2026-11-21
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar eventos.SP_IMPORTAR_EVENTOS_CSV (script 24_SP_Importacion_Eventos.sql):
          procesamiento de goles y amonestaciones desde eventos.StagingEvento, conversión
          automática a doble amarilla, importación con errores parciales registrados en
          eventos.LogImportacion, re-ejecución idempotente (Upsert) y validaciones de entrada.
          Requiere ejecutados los scripts 01 a 24.
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- PREPARACIÓN DE ESCENARIO MÍNIMO (AUTOCONTENIDO)
-- =========================================================================
DELETE FROM jugadores.ReglaConvocados;
INSERT INTO jugadores.ReglaConvocados (Minimo, Maximo) VALUES (2, 5);

IF NOT EXISTS (SELECT 1 FROM eventos.TipoGol WHERE Descripcion = 'Jugada')
    INSERT INTO eventos.TipoGol (Descripcion) VALUES ('Jugada');
IF NOT EXISTS (SELECT 1 FROM eventos.TipoGol WHERE Descripcion = 'Penal')
    INSERT INTO eventos.TipoGol (Descripcion) VALUES ('Penal');

IF NOT EXISTS (SELECT 1 FROM eventos.Periodo WHERE Descripcion = 'Primer Tiempo')
    INSERT INTO eventos.Periodo (Descripcion) VALUES ('Primer Tiempo');
IF NOT EXISTS (SELECT 1 FROM eventos.Periodo WHERE Descripcion = 'Segundo Tiempo')
    INSERT INTO eventos.Periodo (Descripcion) VALUES ('Segundo Tiempo');

IF NOT EXISTS (SELECT 1 FROM eventos.Tarjeta WHERE Tipo = 'Amarilla')
    INSERT INTO eventos.Tarjeta (Tipo) VALUES ('Amarilla');
IF NOT EXISTS (SELECT 1 FROM eventos.Tarjeta WHERE Tipo = 'Roja por doble amarilla')
    INSERT INTO eventos.Tarjeta (Tipo) VALUES ('Roja por doble amarilla');
IF NOT EXISTS (SELECT 1 FROM eventos.Tarjeta WHERE Tipo = 'Roja directa')
    INSERT INTO eventos.Tarjeta (Tipo) VALUES ('Roja directa');

IF NOT EXISTS (SELECT 1 FROM eventos.ReglaSuspension WHERE Criterio = 'Acumulacion Amarillas')
    INSERT INTO eventos.ReglaSuspension (Criterio, CantidadAmarillas, PartidosSuspension) VALUES ('Acumulacion Amarillas', 2, 1);
IF NOT EXISTS (SELECT 1 FROM eventos.ReglaSuspension WHERE Criterio = 'Doble Amarilla')
    INSERT INTO eventos.ReglaSuspension (Criterio, CantidadAmarillas, PartidosSuspension) VALUES ('Doble Amarilla', NULL, 1);
IF NOT EXISTS (SELECT 1 FROM eventos.ReglaSuspension WHERE Criterio = 'Roja Directa')
    INSERT INTO eventos.ReglaSuspension (Criterio, CantidadAmarillas, PartidosSuspension) VALUES ('Roja Directa', NULL, 2);

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST EV CSV Conf', 'TEC');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TEC');

INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, IdConfederacion, HusoHorarioComercial)
VALUES ('TEST EV Pais 1', 'EA', 'TEA', @idConf, 'Argentina Standard Time'),
       ('TEST EV Pais 2', 'EB', 'TEB', @idConf, 'Argentina Standard Time');

DECLARE @idPais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TEA');
DECLARE @idPais2 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TEB');

IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo)
VALUES ('TEA', 101, @idPais1, @idGrupo),
       ('TEB', 102, @idPais2, @idGrupo);
DECLARE @idSel1 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais1);
DECLARE @idSel2 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais2);

INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST EV Ciudad', 'Argentina Standard Time', @idPais1);
DECLARE @idCiudad INT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST EV Ciudad');

DECLARE @idSede INT, @idPartido INT;
INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad)
VALUES ('TEST EV Estadio', 50000, @idCiudad);
SET @idSede = SCOPE_IDENTITY();

DECLARE @idFase INT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (233, '2026-06-12 20:00', 'Programado', @idFase, @idSede, @idSel1, @idSel2);
SET @idPartido = SCOPE_IDENTITY();

INSERT INTO nucleo.StaffTecnico (IdSeleccion, NombreApellido, Rol)
VALUES (@idSel1, 'TEST DT Eventos', 'Director Técnico');

-- Carga rápida de jugadores vía SP de importación XML
DECLARE @xmlJugadores XML = N'
<Convocatorias>
  <Seleccion CodigoISO3="TEA">
    <Jugador><Nombre>Uno</Nombre><Apellido>Local</Apellido><Documento>TEST_EV_J1</Documento><Sexo>M</Sexo><Posicion>Delantero</Posicion><Dorsal>10</Dorsal></Jugador>
    <Jugador><Nombre>Dos</Nombre><Apellido>Local</Apellido><Documento>TEST_EV_J2</Documento><Sexo>M</Sexo><Posicion>Mediocampista</Posicion><Dorsal>8</Dorsal></Jugador>
  </Seleccion>
  <Seleccion CodigoISO3="TEB">
    <Jugador><Nombre>Uno</Nombre><Apellido>Visita</Apellido><Documento>TEST_EV_J3</Documento><Sexo>M</Sexo><Posicion>Defensor</Posicion><Dorsal>4</Dorsal></Jugador>
  </Seleccion>
</Convocatorias>';

DECLARE @procOK INT, @procErr INT;
EXEC jugadores.SP_IMPORTAR_CONVOCATORIA_XML 'setup_eventos.xml', @xmlJugadores, @procOK OUTPUT, @procErr OUTPUT;

-- =========================================================================
-- TEST 1: Procesamiento de lote mixto desde vista / StagingEvento
-- (4 filas válidas + 4 filas con error parcial)
-- Resultado esperado: ProcesadosOK = 4, ConError = 4, 4 registros en eventos.LogImportacion.
-- =========================================================================
INSERT INTO eventos.vw_CargaStagingEvento (
    PartidoRef, TipoEvento, DocumentoSancionado, DocumentoAsistente,
    MinutoTexto, DetalleTipo, PeriodoOMotivo
)
VALUES
    -- Válidas (4):
    ('233', 'Gol',          'TEST_EV_J1',      'TEST_EV_J2', '15', 'Jugada',   'Primer Tiempo'),
    ('233', 'Amonestacion', 'TEST_EV_J3',      NULL,         '30', 'Amarilla', 'Falta táctica'),
    ('233', 'Amonestacion', 'TEST_EV_J3',      NULL,         '60', 'Amarilla', 'Segunda amarilla -> roja'),
    ('233', 'Amonestacion', 'TEST DT Eventos', NULL,         '70', 'Amarilla', 'Protesta desde el banco'),
    -- Inválidas (4):
    ('233',  'Gol',         'TEST_EV_J3',      NULL,         '75', 'Jugada',   'Segundo Tiempo'), -- ya expulsado al min 60
    ('233',  'Gol',         'DOC_NO_EXISTE',   NULL,         '80', 'Jugada',   'Segundo Tiempo'), -- documento inexistente
    ('233',  'Gol',         'TEST_EV_J1',      NULL,         '150','Jugada',   'Segundo Tiempo'), -- minuto fuera de rango
    ('9999', 'Gol',         'TEST_EV_J1',      NULL,         '85', 'Jugada',   'Segundo Tiempo'); -- partido inexistente

UPDATE eventos.StagingEvento
SET NombreArchivo = 'test_eventos_csv.csv'
WHERE NombreArchivo = 'PENDIENTE';

EXEC eventos.SP_IMPORTAR_EVENTOS_CSV
    @nombreArchivo       = 'test_eventos_csv.csv',
    @permitirFechaFutura = 1,
    @filasProcesadas     = @procOK OUTPUT,
    @filasConError       = @procErr OUTPUT;

SELECT '1' AS Test, @procOK AS OK_Esperado_4, @procErr AS Error_Esperado_4,
       (SELECT COUNT(*) FROM eventos.Gol WHERE IdPartido = @idPartido) AS Goles_Esperado_1,
       (SELECT COUNT(*) FROM eventos.Amonestacion WHERE IdPartido = @idPartido) AS Tarjetas_Esperado_3,
       (SELECT COUNT(*) FROM eventos.LogImportacion WHERE NombreArchivo = 'test_eventos_csv.csv') AS Logs_Esperado_4;

SELECT '1 - Logs' AS Detalle, IdFilaStaging, MensajeError, DatosCrudos
FROM eventos.LogImportacion
WHERE NombreArchivo = 'test_eventos_csv.csv';

-- =========================================================================
-- TEST 2: Re-ejecución idempotente (Upsert sin duplicar eventos)
-- Resultado esperado: ProcesadosOK = 4, ConError = 0, sigue habiendo 1 gol y 3 tarjetas.
-- =========================================================================
DELETE FROM eventos.StagingEvento
WHERE NombreArchivo = 'test_eventos_csv.csv'
  AND IdFila NOT IN (
      SELECT TOP (4) IdFila
      FROM eventos.StagingEvento
      WHERE NombreArchivo = 'test_eventos_csv.csv'
      ORDER BY IdFila
  );

EXEC eventos.SP_IMPORTAR_EVENTOS_CSV
    @nombreArchivo       = 'test_eventos_csv.csv',
    @permitirFechaFutura = 1,
    @filasProcesadas     = @procOK OUTPUT,
    @filasConError       = @procErr OUTPUT;

SELECT '2' AS Test, @procOK AS OK_Esperado_4, @procErr AS Error_Esperado_0,
       (SELECT COUNT(*) FROM eventos.Gol WHERE IdPartido = @idPartido) AS Goles_Esperado_1,
       (SELECT COUNT(*) FROM eventos.Amonestacion WHERE IdPartido = @idPartido) AS Tarjetas_Esperado_3;

-- =========================================================================
-- TEST 3: Validación de cabecera (archivo sin filas en StagingEvento)
-- Resultado esperado: THROW 52000.
-- =========================================================================
BEGIN TRY
    EXEC eventos.SP_IMPORTAR_EVENTOS_CSV @nombreArchivo = 'archivo_inexistente.csv';
    PRINT 'TEST 3 FALLÓ: aceptó archivo sin filas en StagingEvento.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3 OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- FIN: se deshacen todos los cambios de la prueba.
-- =========================================================================
ROLLBACK TRANSACTION;
GO