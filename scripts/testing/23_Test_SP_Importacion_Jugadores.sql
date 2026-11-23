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
Objetivo: Probar jugadores.SP_IMPORTAR_CONVOCATORIA_XML (script 23_SP_Importacion_Jugadores.sql):
          alta inicial, re-ejecución idempotente (Upsert sin duplicados), errores parciales
          registrados en eventos.LogImportacion sin abortar el lote válido y validaciones
          de cabecera XML.
          Requiere ejecutados los scripts 01 a 23.
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- PREPARACIÓN DE ESCENARIO MÍNIMO (AUTOCONTENIDO)
-- =========================================================================
DELETE FROM jugadores.ReglaConvocados;
INSERT INTO jugadores.ReglaConvocados (Minimo, Maximo) VALUES (2, 3);

INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST IMP Confederacion', 'TI0');
DECLARE @idConf INT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TI0');

-- Los códigos ISO y FIFA deben ser solo letras (CHECK [A-Z]); se usan ZZA y ZZB.
INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, PBIPerCapitaUSD, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST IMP Pais 1', 'ZA', 'ZZA', 1000, 'Argentina Standard Time', @idConf),
       ('TEST IMP Pais 2', 'ZB', 'ZZB', 1000, 'Argentina Standard Time', @idConf);

DECLARE @idPais1 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'ZZA');
DECLARE @idPais2 INT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'ZZB');

-- Seleccion exige grupo, código FIFA y ranking.
IF NOT EXISTS (SELECT 1 FROM nucleo.Grupo WHERE Nombre = 'Z')
    INSERT INTO nucleo.Grupo (Nombre) VALUES ('Z');
DECLARE @idGrupo INT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');

INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo)
VALUES ('ZZA', 1000, 0, @idPais1, @idGrupo),
       ('ZZB', 1001, 0, @idPais2, @idGrupo);
DECLARE @idSel1 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais1);
DECLARE @idSel2 INT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE IdPais = @idPais2);

DECLARE @procOK INT, @procErr INT;

-- =========================================================================
-- TEST 1: Alta masiva inicial desde XML
-- Resultado esperado: ProcesadosOK = 3, ConError = 0, 3 convocados insertados.
-- =========================================================================
DECLARE @xmlInicial XML = N'
<Convocatorias>
  <Seleccion CodigoISO3="ZZA">
    <Jugador>
      <Nombre>Emiliano</Nombre>
      <Apellido>Martinez</Apellido>
      <Documento>TEST_IMP_J1</Documento>
      <FechaNacimiento>1992-09-02</FechaNacimiento>
      <Sexo>M</Sexo>
      <Posicion>Arquero</Posicion>
      <Club>TEST Aston Villa</Club>
      <Dorsal>23</Dorsal>
      <FechaAlta>2026-05-20</FechaAlta>
    </Jugador>
    <Jugador>
      <Nombre>Lionel</Nombre>
      <Apellido>Messi</Apellido>
      <Documento>TEST_IMP_J2</Documento>
      <FechaNacimiento>1987-06-24</FechaNacimiento>
      <Sexo>M</Sexo>
      <Posicion>Delantero</Posicion>
      <Club>TEST Inter Miami</Club>
      <Dorsal>10</Dorsal>
      <FechaAlta>2026-05-20</FechaAlta>
    </Jugador>
  </Seleccion>
  <Seleccion CodigoISO3="ZZB">
    <Jugador>
      <Nombre>Rival</Nombre>
      <Apellido>Uno</Apellido>
      <Documento>TEST_IMP_J3</Documento>
      <Sexo>M</Sexo>
      <Posicion>Defensor</Posicion>
      <Dorsal>4</Dorsal>
    </Jugador>
  </Seleccion>
</Convocatorias>';

EXEC jugadores.SP_IMPORTAR_CONVOCATORIA_XML
    @nombreArchivo   = 'test_convocatoria_1.xml',
    @contenidoXML    = @xmlInicial,
    @filasProcesadas = @procOK OUTPUT,
    @filasConError   = @procErr OUTPUT;

SELECT '1' AS Test, @procOK AS OK_Esperado_3, @procErr AS Error_Esperado_0,
       (SELECT COUNT(*) FROM jugadores.Convocatoria WHERE IdSeleccion IN (@idSel1, @idSel2)) AS Convocados_Esperado_3;

-- =========================================================================
-- TEST 2: Re-ejecución idempotente (Upsert)
-- Se modifica el club y el dorsal de TEST_IMP_J2 sin duplicar registros.
-- Resultado esperado: ProcesadosOK = 3, ConError = 0, sigue habiendo 3 convocados y dorsal = 19.
-- =========================================================================
DECLARE @xmlUpsert XML = N'
<Convocatorias>
  <Seleccion CodigoISO3="ZZA">
    <Jugador>
      <Nombre>Emiliano</Nombre>
      <Apellido>Martinez</Apellido>
      <Documento>TEST_IMP_J1</Documento>
      <FechaNacimiento>1992-09-02</FechaNacimiento>
      <Sexo>M</Sexo>
      <Posicion>Arquero</Posicion>
      <Club>TEST Aston Villa</Club>
      <Dorsal>23</Dorsal>
      <FechaAlta>2026-05-20</FechaAlta>
    </Jugador>
    <Jugador>
      <Nombre>Lionel</Nombre>
      <Apellido>Messi</Apellido>
      <Documento>TEST_IMP_J2</Documento>
      <FechaNacimiento>1987-06-24</FechaNacimiento>
      <Sexo>M</Sexo>
      <Posicion>Delantero</Posicion>
      <Club>TEST Barcelona FC</Club>
      <Dorsal>19</Dorsal>
      <FechaAlta>2026-05-20</FechaAlta>
    </Jugador>
  </Seleccion>
  <Seleccion CodigoISO3="ZZB">
    <Jugador>
      <Nombre>Rival</Nombre>
      <Apellido>Uno</Apellido>
      <Documento>TEST_IMP_J3</Documento>
      <Sexo>M</Sexo>
      <Posicion>Defensor</Posicion>
      <Dorsal>4</Dorsal>
    </Jugador>
  </Seleccion>
</Convocatorias>';

EXEC jugadores.SP_IMPORTAR_CONVOCATORIA_XML
    @nombreArchivo   = 'test_convocatoria_1.xml',
    @contenidoXML    = @xmlUpsert,
    @filasProcesadas = @procOK OUTPUT,
    @filasConError   = @procErr OUTPUT;

SELECT '2' AS Test, @procOK AS OK_Esperado_3, @procErr AS Error_Esperado_0,
       (SELECT COUNT(*) FROM jugadores.Convocatoria WHERE IdSeleccion IN (@idSel1, @idSel2)) AS Convocados_Esperado_3,
       (SELECT c.Dorsal FROM jugadores.Convocatoria c INNER JOIN jugadores.Jugador j ON j.IdJugador = c.IdJugador WHERE j.Documento = 'TEST_IMP_J2') AS Dorsal_Esperado_19;

-- =========================================================================
-- TEST 3: Importación con errores parciales
--   - Fila 1 válida (entra como 3er convocado de ZZA, completando el tope Maximo = 3).
--   - Fila 2 falla por superar el cupo máximo de 3 convocados en ZZA.
--   - Fila 3 falla por CodigoISO3 'XXX' inexistente.
--   - Fila 4 falla por Dorsal 'ABC' no numérico.
-- Resultado esperado: ProcesadosOK = 1, ConError = 3, y 3 registros en eventos.LogImportacion.
-- =========================================================================
DECLARE @xmlParcial XML = N'
<Convocatorias>
  <Seleccion CodigoISO3="ZZA">
    <Jugador>
      <Nombre>Julian</Nombre>
      <Apellido>Alvarez</Apellido>
      <Documento>TEST_IMP_J4</Documento>
      <Sexo>M</Sexo>
      <Posicion>Delantero</Posicion>
      <Dorsal>9</Dorsal>
    </Jugador>
    <Jugador>
      <Nombre>Sobrante</Nombre>
      <Apellido>Cupo</Apellido>
      <Documento>TEST_IMP_J5</Documento>
      <Sexo>M</Sexo>
      <Posicion>Mediocampista</Posicion>
      <Dorsal>5</Dorsal>
    </Jugador>
  </Seleccion>
  <Seleccion CodigoISO3="XXX">
    <Jugador>
      <Nombre>Pais</Nombre>
      <Apellido>Inexistente</Apellido>
      <Documento>TEST_IMP_J6</Documento>
      <Sexo>M</Sexo>
      <Posicion>Defensor</Posicion>
      <Dorsal>2</Dorsal>
    </Jugador>
  </Seleccion>
  <Seleccion CodigoISO3="ZZB">
    <Jugador>
      <Nombre>Dorsal</Nombre>
      <Apellido>Invalido</Apellido>
      <Documento>TEST_IMP_J7</Documento>
      <Sexo>M</Sexo>
      <Posicion>Arquero</Posicion>
      <Dorsal>ABC</Dorsal>
    </Jugador>
  </Seleccion>
</Convocatorias>';

EXEC jugadores.SP_IMPORTAR_CONVOCATORIA_XML
    @nombreArchivo   = 'test_convocatoria_parcial.xml',
    @contenidoXML    = @xmlParcial,
    @filasProcesadas = @procOK OUTPUT,
    @filasConError   = @procErr OUTPUT;

SELECT '3' AS Test, @procOK AS OK_Esperado_1, @procErr AS Error_Esperado_3,
       (SELECT COUNT(*) FROM eventos.LogImportacion WHERE NombreArchivo = 'test_convocatoria_parcial.xml') AS Logs_Esperado_3;

SELECT '3 - Logs' AS Detalle, IdLogImportacion, MensajeError
FROM eventos.LogImportacion
WHERE NombreArchivo = 'test_convocatoria_parcial.xml';

-- =========================================================================
-- TEST 4: Validaciones de cabecera (XML sin nodos válidos y archivo vacío)
-- Resultado esperado: THROW 52000 en ambos casos.
-- =========================================================================
BEGIN TRY
    EXEC jugadores.SP_IMPORTAR_CONVOCATORIA_XML
        @nombreArchivo = 'test_vacio.xml',
        @contenidoXML  = N'<RootSinConvocatorias />';
    PRINT 'TEST 4.A FALLÓ: aceptó XML sin nodos válidos.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.A OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC jugadores.SP_IMPORTAR_CONVOCATORIA_XML
        @nombreArchivo = '   ',
        @contenidoXML  = @xmlInicial;
    PRINT 'TEST 4.B FALLÓ: aceptó nombre de archivo vacío.';
END TRY
BEGIN CATCH
    PRINT 'TEST 4.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- FIN: se deshacen todos los cambios de la prueba.
-- =========================================================================
ROLLBACK TRANSACTION;
GO