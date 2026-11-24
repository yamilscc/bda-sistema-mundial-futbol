/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Canseco Carrizo, Yamil Simón
Integrantes:
Casella, Mateo Ezequiel
Chungara Tenorio, Denis Abner
Torczuk, Elías Alexei
Canseco Carrizo, Yamil Simón
Objetivo:
	- Probar las restricciones DDL (PK, FK, UQ, CK y DEFAULT) de las tablas núcleo creadas
	  en 01_Tablas_Nucleo.sql:
		  Confederacion, Pais, Ciudad, Sede, Grupo, Fase, Seleccion, Partido,
		  StaffTecnico, Idioma, Categoria, Arbitro, ArbitroIdioma,
		  DesignacionArbitral, Sancion
	- Verificar los datos de referencia fijos de la tabla Fase
	- Requiere haber ejecutado 00_Reset_Total.sql y 01_Tablas_Nucleo.sql (BD sin otros datos
	  de Grupo, para que las letras de prueba no colisionen).
	- Los casos de prueba insertan directamente en las tablas porque se testean las
	  restricciones del DDL (los SP de ABM se prueban en otros scripts).
	- Todo corre dentro de una transacción que se deshace al final (ROLLBACK),
	  por lo que no deja datos en la base.
	- Convención de salida:
		"OK"            -> el caso se comportó como se esperaba.
		"OK (Bloqueado)"-> la restricción rechazó la operación inválida (se imprime el
		                   mensaje del motor, que debe nombrar la constraint esperada).
		"FALLÓ"         -> el caso no se comportó como se esperaba.
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- TEST 1: Confederacion
-- =========================================================================

-- 1.A Alta válida.
-- Esperado: OK, se inserta la confederación.
INSERT INTO nucleo.Confederacion (Nombre, Sigla, Region) VALUES ('TEST Confederacion 1', 'TC1', 'Region 1');
INSERT INTO nucleo.Confederacion (Nombre, Sigla, Region) VALUES ('TEST Confederacion 2', 'TC2', NULL);
DECLARE @idConf1 TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TC1');
DECLARE @idConf2 TINYINT = (SELECT IdConfederacion FROM nucleo.Confederacion WHERE Sigla = 'TC2');
IF @idConf1 IS NOT NULL AND @idConf2 IS NOT NULL
	PRINT 'TEST 1.A OK: Confederaciones insertadas (Region admite NULL).';
ELSE
	PRINT 'TEST 1.A FALLÓ: no se insertaron las confederaciones.';

-- 1.B Nombre duplicado.
-- Esperado: Bloqueado por UQ_Confederacion_Nombre.
BEGIN TRY
	INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST Confederacion 1', 'TC9');
	PRINT 'TEST 1.B FALLÓ: permitió nombre de confederación duplicado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 1.C Sigla duplicada.
-- Esperado: Bloqueado por UQ_Confederacion_Sigla.
BEGIN TRY
	INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES ('TEST Confederacion 9', 'TC1');
	PRINT 'TEST 1.C FALLÓ: permitió sigla de confederación duplicada.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 1.D Nombre NULL.
-- Esperado: Bloqueado por restricción NOT NULL.
BEGIN TRY
	INSERT INTO nucleo.Confederacion (Nombre, Sigla) VALUES (NULL, 'TC8');
	PRINT 'TEST 1.D FALLÓ: permitió nombre NULL.';
END TRY
BEGIN CATCH
	PRINT 'TEST 1.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: Pais
-- =========================================================================

-- 2.A Alta válida (con y sin PBI).
-- Esperado: OK, se insertan 3 países.
INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, PBIPerCapitaUSD, HusoHorarioComercial, IdConfederacion)
VALUES ('TEST Pais 1', 'TA', 'TAA', 13000.50, 'Argentina Standard Time', @idConf1),
       ('TEST Pais 2', 'TB', 'TBB', 0,        'UTC',                     @idConf1),
       ('TEST Pais 3', 'TC', 'TCC', NULL,     'UTC',                     @idConf2),
       ('TEST Pais 6', 'TF', 'TFF', 500,      'UTC',                     @idConf2);
DECLARE @idPais1 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TAA');
DECLARE @idPais2 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TBB');
DECLARE @idPais3 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TCC');
-- País 4: queda sin selección, se usa en los tests de Seleccion para aislar cada restricción.
DECLARE @idPais4 SMALLINT = (SELECT IdPais FROM nucleo.Pais WHERE CodigoISO3 = 'TFF');
IF @idPais1 IS NOT NULL AND @idPais2 IS NOT NULL AND @idPais3 IS NOT NULL AND @idPais4 IS NOT NULL
	PRINT 'TEST 2.A OK: Países insertados (PBI 0 y NULL permitidos).';
ELSE
	PRINT 'TEST 2.A FALLÓ: no se insertaron los países.';

-- 2.B Nombre duplicado.
-- Esperado: Bloqueado por UQ_Pais_Nombre.
BEGIN TRY
	INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
	VALUES ('TEST Pais 1', 'TD', 'TDD', 'UTC', @idConf1);
	PRINT 'TEST 2.B FALLÓ: permitió nombre de país duplicado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.C CodigoISO2 duplicado.
-- Esperado: Bloqueado por UQ_Pais_CodigoISO2.
BEGIN TRY
	INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
	VALUES ('TEST Pais 4', 'TA', 'TDD', 'UTC', @idConf1);
	PRINT 'TEST 2.C FALLÓ: permitió CodigoISO2 duplicado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.D CodigoISO3 duplicado.
-- Esperado: Bloqueado por UQ_Pais_CodigoISO3.
BEGIN TRY
	INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
	VALUES ('TEST Pais 4', 'TD', 'TAA', 'UTC', @idConf1);
	PRINT 'TEST 2.D FALLÓ: permitió CodigoISO3 duplicado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.E CodigoISO2 con formato inválido (dígitos).
-- Esperado: Bloqueado por CK_Pais_CodigoISO2_Valido.
BEGIN TRY
	INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
	VALUES ('TEST Pais 5', '1A', 'TEE', 'UTC', @idConf1);
	PRINT 'TEST 2.E FALLÓ: permitió CodigoISO2 con dígitos.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.F CodigoISO3 con formato inválido (dígito).
-- Esperado: Bloqueado por CK_Pais_CodigoISO3_Valido.
BEGIN TRY
	INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
	VALUES ('TEST Pais 5', 'TE', 'T1E', 'UTC', @idConf1);
	PRINT 'TEST 2.F FALLÓ: permitió CodigoISO3 con dígitos.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.F OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.G PBI per cápita negativo.
-- Esperado: Bloqueado por CK_Pais_PBI_No_Negativo.
BEGIN TRY
	INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, PBIPerCapitaUSD, HusoHorarioComercial, IdConfederacion)
	VALUES ('TEST Pais 5', 'TE', 'TEE', -1, 'UTC', @idConf1);
	PRINT 'TEST 2.G FALLÓ: permitió PBI negativo.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.G OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.H Huso horario vacío (solo espacios).
-- Esperado: Bloqueado por CK_Pais_HusoHorarioComercial_NoVacio.
BEGIN TRY
	INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
	VALUES ('TEST Pais 5', 'TE', 'TEE', '   ', @idConf1);
	PRINT 'TEST 2.H FALLÓ: permitió huso horario vacío.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.H OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.I Confederación inexistente.
-- Esperado: Bloqueado por FK_Pais_Confederacion.
BEGIN TRY
	INSERT INTO nucleo.Pais (Nombre, CodigoISO2, CodigoISO3, HusoHorarioComercial, IdConfederacion)
	VALUES ('TEST Pais 5', 'TE', 'TEE', 'UTC', 250);
	PRINT 'TEST 2.I FALLÓ: permitió confederación inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.I OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.J Borrar una confederación con países asociados.
-- Esperado: Bloqueado por FK_Pais_Confederacion.
BEGIN TRY
	DELETE FROM nucleo.Confederacion WHERE IdConfederacion = @idConf1;
	PRINT 'TEST 2.J FALLÓ: permitió borrar una confederación con países.';
END TRY
BEGIN CATCH
	PRINT 'TEST 2.J OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: Ciudad
-- =========================================================================

-- 3.A Alta válida; el mismo nombre en otro país es válido.
-- Esperado: OK, se insertan 3 ciudades.
INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais)
VALUES ('TEST Ciudad 1', 'Argentina Standard Time', @idPais1),
       ('TEST Ciudad 2', 'Argentina Standard Time', @idPais1),
       ('TEST Ciudad 1', 'UTC',                     @idPais2);
DECLARE @idCiudad1 SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST Ciudad 1' AND IdPais = @idPais1);
DECLARE @idCiudad2 SMALLINT = (SELECT IdCiudad FROM nucleo.Ciudad WHERE Nombre = 'TEST Ciudad 2' AND IdPais = @idPais1);
IF @idCiudad1 IS NOT NULL AND @idCiudad2 IS NOT NULL
	AND (SELECT COUNT(*) FROM nucleo.Ciudad WHERE Nombre = 'TEST Ciudad 1') = 2
	PRINT 'TEST 3.A OK: Ciudades insertadas (mismo nombre permitido en países distintos).';
ELSE
	PRINT 'TEST 3.A FALLÓ: no se insertaron las ciudades esperadas.';

-- 3.B Mismo nombre en el mismo país.
-- Esperado: Bloqueado por UQ_Ciudad_Nombre_IdPais.
BEGIN TRY
	INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais) VALUES ('TEST Ciudad 1', 'UTC', @idPais1);
	PRINT 'TEST 3.B FALLÓ: permitió ciudad duplicada en el mismo país.';
END TRY
BEGIN CATCH
	PRINT 'TEST 3.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.C Nombre vacío.
-- Esperado: Bloqueado por CK_Ciudad_Nombre_NoVacio.
BEGIN TRY
	INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais) VALUES ('  ', 'UTC', @idPais1);
	PRINT 'TEST 3.C FALLÓ: permitió nombre de ciudad vacío.';
END TRY
BEGIN CATCH
	PRINT 'TEST 3.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.D Huso horario vacío.
-- Esperado: Bloqueado por CK_Ciudad_HusoHorario_NoVacio.
BEGIN TRY
	INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais) VALUES ('TEST Ciudad 9', '  ', @idPais1);
	PRINT 'TEST 3.D FALLÓ: permitió huso horario vacío.';
END TRY
BEGIN CATCH
	PRINT 'TEST 3.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.E País inexistente.
-- Esperado: Bloqueado por FK_Ciudad_Pais.
BEGIN TRY
	INSERT INTO nucleo.Ciudad (Nombre, HusoHorario, IdPais) VALUES ('TEST Ciudad 9', 'UTC', 32000);
	PRINT 'TEST 3.E FALLÓ: permitió ciudad con país inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 3.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: Sede
-- =========================================================================

-- 4.A Alta válida (con coordenadas y sin coordenadas ni capacidad).
-- Esperado: OK, se insertan 3 sedes.
INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, Latitud, Longitud, IdCiudad)
VALUES ('TEST Estadio 1', 50000, -34.603722, -58.381592, @idCiudad1),
       ('TEST Estadio 2', NULL, NULL,       NULL,        @idCiudad1),
       ('TEST Estadio 3', 30000, 90,        -180,        @idCiudad2);
DECLARE @idSede1 TINYINT = (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio = 'TEST Estadio 1');
DECLARE @idSede2 TINYINT = (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio = 'TEST Estadio 2');
DECLARE @idSede3 TINYINT = (SELECT IdSede FROM nucleo.Sede WHERE NombreEstadio = 'TEST Estadio 3');
IF @idSede1 IS NOT NULL AND @idSede2 IS NOT NULL AND @idSede3 IS NOT NULL
	PRINT 'TEST 4.A OK: Sedes insertadas (coordenadas en el límite y NULL permitidas).';
ELSE
	PRINT 'TEST 4.A FALLÓ: no se insertaron las sedes.';

-- 4.B Mismo estadio en la misma ciudad.
-- Esperado: Bloqueado por UQ_Sede_NombreEstadio_IdCiudad.
BEGIN TRY
	INSERT INTO nucleo.Sede (NombreEstadio, IdCiudad) VALUES ('TEST Estadio 1', @idCiudad1);
	PRINT 'TEST 4.B FALLÓ: permitió estadio duplicado en la misma ciudad.';
END TRY
BEGIN CATCH
	PRINT 'TEST 4.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.C Nombre de estadio vacío.
-- Esperado: Bloqueado por CK_Sede_NombreEstadio_NoVacio.
BEGIN TRY
	INSERT INTO nucleo.Sede (NombreEstadio, IdCiudad) VALUES ('  ', @idCiudad1);
	PRINT 'TEST 4.C FALLÓ: permitió nombre de estadio vacío.';
END TRY
BEGIN CATCH
	PRINT 'TEST 4.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.D Capacidad cero.
-- Esperado: Bloqueado por CK_Sede_Capacidad_Positiva.
BEGIN TRY
	INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad) VALUES ('TEST Estadio 9', 0, @idCiudad1);
	PRINT 'TEST 4.D FALLÓ: permitió capacidad 0.';
END TRY
BEGIN CATCH
	PRINT 'TEST 4.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.E Latitud fuera de rango.
-- Esperado: Bloqueado por CK_Sede_Latitud_Rango.
BEGIN TRY
	INSERT INTO nucleo.Sede (NombreEstadio, Latitud, Longitud, IdCiudad) VALUES ('TEST Estadio 9', 91, 0, @idCiudad1);
	PRINT 'TEST 4.E FALLÓ: permitió latitud 91.';
END TRY
BEGIN CATCH
	PRINT 'TEST 4.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.F Longitud fuera de rango.
-- Esperado: Bloqueado por CK_Sede_Longitud_Rango.
BEGIN TRY
	INSERT INTO nucleo.Sede (NombreEstadio, Latitud, Longitud, IdCiudad) VALUES ('TEST Estadio 9', 0, 181, @idCiudad1);
	PRINT 'TEST 4.F FALLÓ: permitió longitud 181.';
END TRY
BEGIN CATCH
	PRINT 'TEST 4.F OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.G Latitud sin longitud.
-- Esperado: Bloqueado por CK_Sede_Coordenadas.
BEGIN TRY
	INSERT INTO nucleo.Sede (NombreEstadio, Latitud, Longitud, IdCiudad) VALUES ('TEST Estadio 9', 10, NULL, @idCiudad1);
	PRINT 'TEST 4.G FALLÓ: permitió latitud sin longitud.';
END TRY
BEGIN CATCH
	PRINT 'TEST 4.G OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.H Longitud sin latitud.
-- Esperado: Bloqueado por CK_Sede_Coordenadas.
BEGIN TRY
	INSERT INTO nucleo.Sede (NombreEstadio, Latitud, Longitud, IdCiudad) VALUES ('TEST Estadio 9', NULL, 10, @idCiudad1);
	PRINT 'TEST 4.H FALLÓ: permitió longitud sin latitud.';
END TRY
BEGIN CATCH
	PRINT 'TEST 4.H OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 4.I Ciudad inexistente.
-- Esperado: Bloqueado por FK_Sede_Ciudad.
BEGIN TRY
	INSERT INTO nucleo.Sede (NombreEstadio, IdCiudad) VALUES ('TEST Estadio 9', 32000);
	PRINT 'TEST 4.I FALLÓ: permitió sede con ciudad inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 4.I OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 5: Grupo
-- =========================================================================

-- 5.A Alta válida.
-- Esperado: OK, se insertan los grupos 'Y' y 'Z'.
INSERT INTO nucleo.Grupo (Nombre) VALUES ('Y'), ('Z');
DECLARE @idGrupoY TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Y');
DECLARE @idGrupoZ TINYINT = (SELECT IdGrupo FROM nucleo.Grupo WHERE Nombre = 'Z');
IF @idGrupoY IS NOT NULL AND @idGrupoZ IS NOT NULL
	PRINT 'TEST 5.A OK: Grupos insertados.';
ELSE
	PRINT 'TEST 5.A FALLÓ: no se insertaron los grupos.';

-- 5.B Letra duplicada.
-- Esperado: Bloqueado por UQ_Grupo_Nombre.
BEGIN TRY
	INSERT INTO nucleo.Grupo (Nombre) VALUES ('Y');
	PRINT 'TEST 5.B FALLÓ: permitió grupo duplicado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 5.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 5.C Nombre que no es una letra.
-- Esperado: Bloqueado por CK_Grupo_Nombre_Letra.
BEGIN TRY
	INSERT INTO nucleo.Grupo (Nombre) VALUES ('1');
	PRINT 'TEST 5.C FALLÓ: permitió grupo con un dígito como nombre.';
END TRY
BEGIN CATCH
	PRINT 'TEST 5.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 6: Fase (datos de referencia fijos y restricciones)
-- =========================================================================

-- 6.A Datos de referencia cargados por el script 01.
-- Esperado: OK, hay exactamente 7 fases con el orden y EsEliminatoria definidos.
IF (SELECT COUNT(*) FROM nucleo.Fase) = 7
	AND (SELECT COUNT(*) FROM nucleo.Fase WHERE
			(Nombre = 'Fase de grupos'         AND Orden = 1 AND EsEliminatoria = 0)
		 OR (Nombre = 'Dieciseisavos de final' AND Orden = 2 AND EsEliminatoria = 1)
		 OR (Nombre = 'Octavos de final'       AND Orden = 3 AND EsEliminatoria = 1)
		 OR (Nombre = 'Cuartos de final'       AND Orden = 4 AND EsEliminatoria = 1)
		 OR (Nombre = 'Semifinal'              AND Orden = 5 AND EsEliminatoria = 1)
		 OR (Nombre = 'Tercer puesto'          AND Orden = 6 AND EsEliminatoria = 1)
		 OR (Nombre = 'Final'                  AND Orden = 7 AND EsEliminatoria = 1)) = 7
	PRINT 'TEST 6.A OK: Las 7 fases de referencia están cargadas correctamente.';
ELSE
	PRINT 'TEST 6.A FALLÓ: los datos de referencia de Fase no coinciden con lo esperado.';

-- 6.B Nombre de fase duplicado.
-- Esperado: Bloqueado por UQ_Fase_Nombre.
BEGIN TRY
	INSERT INTO nucleo.Fase (Nombre, Orden, EsEliminatoria) VALUES ('Final', 99, 1);
	PRINT 'TEST 6.B FALLÓ: permitió nombre de fase duplicado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 6.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 6.C Nombre de fase fuera de la lista permitida.
-- Esperado: Bloqueado por CK_Fase_Nombre_Valido.
BEGIN TRY
	INSERT INTO nucleo.Fase (Nombre, Orden, EsEliminatoria) VALUES ('Repechaje', 8, 1);
	PRINT 'TEST 6.C FALLÓ: permitió una fase con nombre no válido.';
END TRY
BEGIN CATCH
	PRINT 'TEST 6.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 6.D Orden duplicado (se prueba por UPDATE para aislar la restricción).
-- Esperado: Bloqueado por UQ_Fase_Orden.
BEGIN TRY
	UPDATE nucleo.Fase SET Orden = 1 WHERE Nombre = 'Final';
	PRINT 'TEST 6.D FALLÓ: permitió orden de fase duplicado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 6.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 6.E Orden cero (se prueba por UPDATE para aislar la restricción).
-- Esperado: Bloqueado por CK_Fase_Orden_Valido.
BEGIN TRY
	UPDATE nucleo.Fase SET Orden = 0 WHERE Nombre = 'Final';
	PRINT 'TEST 6.E FALLÓ: permitió orden de fase 0.';
END TRY
BEGIN CATCH
	PRINT 'TEST 6.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 7: Seleccion
-- =========================================================================

-- 7.A Alta válida; EsAnfitrion toma el valor por defecto 0.
-- Esperado: OK, se insertan 3 selecciones y EsAnfitrion = 0 en la que no lo informa.
INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo) VALUES ('TAA', 1, @idPais1, @idGrupoY);
INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, EsAnfitrion, IdPais, IdGrupo) VALUES ('TBB', 2, 1, @idPais2, @idGrupoY);
INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo) VALUES ('TCC', 3, @idPais3, @idGrupoZ);
DECLARE @idSel1 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TAA');
DECLARE @idSel2 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TBB');
DECLARE @idSel3 TINYINT = (SELECT IdSeleccion FROM nucleo.Seleccion WHERE CodigoFIFA = 'TCC');
IF @idSel1 IS NOT NULL AND @idSel2 IS NOT NULL AND @idSel3 IS NOT NULL
	AND (SELECT EsAnfitrion FROM nucleo.Seleccion WHERE IdSeleccion = @idSel1) = 0
	AND (SELECT EsAnfitrion FROM nucleo.Seleccion WHERE IdSeleccion = @idSel2) = 1
	PRINT 'TEST 7.A OK: Selecciones insertadas y DEFAULT de EsAnfitrion aplicado.';
ELSE
	PRINT 'TEST 7.A FALLÓ: no se insertaron las selecciones o el DEFAULT no se aplicó.';

-- 7.B CodigoFIFA duplicado.
-- Esperado: Bloqueado por UQ_Seleccion_CodigoFIFA.
BEGIN TRY
	INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo) VALUES ('TAA', 9, @idPais4, @idGrupoY);
	PRINT 'TEST 7.B FALLÓ: permitió CodigoFIFA duplicado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 7.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 7.C Dos selecciones para el mismo país.
-- Esperado: Bloqueado por UQ_Seleccion_IdPais.
BEGIN TRY
	INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo) VALUES ('TDD', 9, @idPais1, @idGrupoY);
	PRINT 'TEST 7.C FALLÓ: permitió dos selecciones del mismo país.';
END TRY
BEGIN CATCH
	PRINT 'TEST 7.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 7.D CodigoFIFA con formato inválido.
-- Esperado: Bloqueado por CK_Seleccion_CodigoFIFA_3_Letras.
BEGIN TRY
	INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo) VALUES ('T1D', 9, @idPais4, @idGrupoY);
	PRINT 'TEST 7.D FALLÓ: permitió CodigoFIFA con dígitos.';
END TRY
BEGIN CATCH
	PRINT 'TEST 7.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 7.E Ranking FIFA cero.
-- Esperado: Bloqueado por CK_Seleccion_RankingFIFA_Positivo.
BEGIN TRY
	INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo) VALUES ('TDD', 0, @idPais4, @idGrupoY);
	PRINT 'TEST 7.E FALLÓ: permitió ranking FIFA 0.';
END TRY
BEGIN CATCH
	PRINT 'TEST 7.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 7.F País inexistente.
-- Esperado: Bloqueado por FK_Seleccion_Pais.
BEGIN TRY
	INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo) VALUES ('TDD', 9, 32000, @idGrupoY);
	PRINT 'TEST 7.F FALLÓ: permitió selección con país inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 7.F OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 7.G Grupo inexistente.
-- Esperado: Bloqueado por FK_Seleccion_Grupo.
BEGIN TRY
	INSERT INTO nucleo.Seleccion (CodigoFIFA, RankingFIFA, IdPais, IdGrupo) VALUES ('TDD', 9, @idPais4, 250);
	PRINT 'TEST 7.G FALLÓ: permitió selección con grupo inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 7.G OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 8: Partido
-- =========================================================================
DECLARE @idFaseGrupos TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Fase de grupos');
DECLARE @idFaseOctavos TINYINT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Octavos de final');

-- 8.A Partido Programado sin resultado (selecciones opcionales: cruces eliminatorios aún no definidos).
-- Esperado: OK, se insertan un partido con selecciones y otro sin selecciones.
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (201, '2026-06-11 19:00', 'Programado', @idFaseGrupos, @idSede1, @idSel1, @idSel2);
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (202, '2026-06-12 19:00', 'Programado', @idFaseOctavos, @idSede1, NULL, NULL);
IF (SELECT COUNT(*) FROM nucleo.Partido WHERE NumeroPartido IN (201, 202)) = 2
	PRINT 'TEST 8.A OK: Partidos Programados insertados (con y sin selecciones).';
ELSE
	PRINT 'TEST 8.A FALLÓ: no se insertaron los partidos programados.';

-- 8.B Partido Finalizado con ambas selecciones y concurrencia (el resultado no se guarda en Partido:
-- se deriva de eventos.Gol con eventos.fn_ResultadoPartido).
-- Esperado: OK, se inserta el partido Finalizado.
INSERT INTO nucleo.Partido (NumeroPartido, Concurrencia, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (203, 45000, '2026-06-13 19:00', 'Finalizado', @idFaseGrupos, @idSede1, @idSel1, @idSel3);
IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE NumeroPartido = 203 AND Estado = 'Finalizado' AND Concurrencia = 45000)
	PRINT 'TEST 8.B OK: Partido Finalizado insertado.';
ELSE
	PRINT 'TEST 8.B FALLÓ: no se insertó el partido finalizado.';

-- 8.C Partido eliminatorio Finalizado con ambas selecciones.
-- Esperado: OK, se inserta el partido Finalizado de octavos.
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (204, '2026-06-14 19:00', 'Finalizado', @idFaseOctavos, @idSede1, @idSel2, @idSel3);
IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE NumeroPartido = 204 AND Estado = 'Finalizado')
	PRINT 'TEST 8.C OK: Partido eliminatorio Finalizado insertado.';
ELSE
	PRINT 'TEST 8.C FALLÓ: no se insertó el partido eliminatorio finalizado.';

-- 8.D NumeroPartido duplicado.
-- Esperado: Bloqueado por UQ_Partido_NumeroPartido.
BEGIN TRY
	INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede)
	VALUES (201, '2026-06-20 19:00', 'Programado', @idFaseGrupos, @idSede2);
	PRINT 'TEST 8.D FALLÓ: permitió NumeroPartido duplicado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 8.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.E Dos partidos en la misma sede y el mismo instante.
-- Esperado: Bloqueado por UQ_Partido_IdSede_FechaHoraUTC.
BEGIN TRY
	INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede)
	VALUES (205, '2026-06-11 19:00', 'Programado', @idFaseGrupos, @idSede1);
	PRINT 'TEST 8.E FALLÓ: permitió dos partidos en la misma sede y horario.';
END TRY
BEGIN CATCH
	PRINT 'TEST 8.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.F Mismo horario en una sede distinta.
-- Esperado: OK, se inserta (la restricción es por sede).
INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede)
VALUES (205, '2026-06-11 19:00', 'Programado', @idFaseGrupos, @idSede2);
IF EXISTS (SELECT 1 FROM nucleo.Partido WHERE NumeroPartido = 205)
	PRINT 'TEST 8.F OK: Mismo horario permitido en otra sede.';
ELSE
	PRINT 'TEST 8.F FALLÓ: no se insertó el partido en la otra sede.';

-- 8.G Estado inválido (el sistema no maneja un estado "En juego").
-- Esperado: Bloqueado. El motor informa una sola constraint violada: puede nombrar
-- CK_Partido_Estado_Valido o CK_Partido_Resultado (ambas rechazan este estado).
BEGIN TRY
	INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede)
	VALUES (206, '2026-06-15 19:00', 'En juego', @idFaseGrupos, @idSede1);
	PRINT 'TEST 8.G FALLÓ: permitió un estado inválido.';
END TRY
BEGIN CATCH
	PRINT 'TEST 8.G OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.H Partido Finalizado sin selecciones.
-- Esperado: Bloqueado por CK_Partido_Resultado.
BEGIN TRY
	INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede)
	VALUES (206, '2026-06-15 19:00', 'Finalizado', @idFaseGrupos, @idSede1);
	PRINT 'TEST 8.H FALLÓ: permitió partido Finalizado sin selecciones.';
END TRY
BEGIN CATCH
	PRINT 'TEST 8.H OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.I Partido Finalizado con una sola selección definida.
-- Esperado: Bloqueado por CK_Partido_Resultado.
BEGIN TRY
	INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
	VALUES (206, '2026-06-15 19:00', 'Finalizado', @idFaseGrupos, @idSede1, @idSel1, NULL);
	PRINT 'TEST 8.I FALLÓ: permitió partido Finalizado con una sola selección.';
END TRY
BEGIN CATCH
	PRINT 'TEST 8.I OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.J Partido no guarda el resultado (3FN): no existen columnas de goles, penales ni asistencia.
-- Esperado: OK, ninguna de las 5 columnas existe en nucleo.Partido.
IF COL_LENGTH('nucleo.Partido', 'GolesLocal') IS NULL
   AND COL_LENGTH('nucleo.Partido', 'GolesVisitante') IS NULL
   AND COL_LENGTH('nucleo.Partido', 'PenalesLocal') IS NULL
   AND COL_LENGTH('nucleo.Partido', 'PenalesVisitante') IS NULL
   AND COL_LENGTH('nucleo.Partido', 'Asistencia') IS NULL
	PRINT 'TEST 8.J OK: Partido no guarda columnas de resultado.';
ELSE
	PRINT 'TEST 8.J FALLÓ: Partido todavía tiene columnas de resultado.';

-- 8.K Una selección contra sí misma.
-- Esperado: Bloqueado por CK_Partido_Equipos.
BEGIN TRY
	INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
	VALUES (206, '2026-06-15 19:00', 'Programado', @idFaseGrupos, @idSede1, @idSel1, @idSel1);
	PRINT 'TEST 8.K FALLÓ: permitió una selección contra sí misma.';
END TRY
BEGIN CATCH
	PRINT 'TEST 8.K OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.L Concurrencia negativa.
-- Esperado: Bloqueado por CK_Partido_Concurrencia_Positiva.
BEGIN TRY
	INSERT INTO nucleo.Partido (NumeroPartido, Concurrencia, FechaHoraUTC, Estado, IdFase, IdSede)
	VALUES (206, -1, '2026-06-15 19:00', 'Programado', @idFaseGrupos, @idSede1);
	PRINT 'TEST 8.L FALLÓ: permitió concurrencia negativa.';
END TRY
BEGIN CATCH
	PRINT 'TEST 8.L OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.M Fase inexistente.
-- Esperado: Bloqueado por FK_Partido_Fase.
BEGIN TRY
	INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede)
	VALUES (206, '2026-06-15 19:00', 'Programado', 250, @idSede1);
	PRINT 'TEST 8.M FALLÓ: permitió partido con fase inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 8.M OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.R Sede inexistente.
-- Esperado: Bloqueado por FK_Partido_Sede.
BEGIN TRY
	INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede)
	VALUES (206, '2026-06-15 19:00', 'Programado', @idFaseGrupos, 250);
	PRINT 'TEST 8.R FALLÓ: permitió partido con sede inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 8.R OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.S Selección local inexistente.
-- Esperado: Bloqueado por FK_Partido_Seleccion_Local.
BEGIN TRY
	INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal)
	VALUES (206, '2026-06-15 19:00', 'Programado', @idFaseGrupos, @idSede1, 250);
	PRINT 'TEST 8.S FALLÓ: permitió selección local inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 8.S OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.T Selección visitante inexistente.
-- Esperado: Bloqueado por FK_Partido_Seleccion_Visitante.
BEGIN TRY
	INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionVisitante)
	VALUES (206, '2026-06-15 19:00', 'Programado', @idFaseGrupos, @idSede1, 250);
	PRINT 'TEST 8.T FALLÓ: permitió selección visitante inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 8.T OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 8.U Índices asociados a Partido.
-- Esperado: OK, existen los 4 índices no clustered.
IF (SELECT COUNT(*) FROM sys.indexes
	WHERE object_id = OBJECT_ID('nucleo.Partido')
	AND name IN ('IX_Partido_Fecha', 'IX_Partido_Fase', 'IX_Partido_Local', 'IX_Partido_Visitante')) = 4
	PRINT 'TEST 8.U OK: Existen los índices IX_Partido_Fecha, _Fase, _Local y _Visitante.';
ELSE
	PRINT 'TEST 8.U FALLÓ: faltan índices en nucleo.Partido.';

-- =========================================================================
-- TEST 9: StaffTecnico
-- =========================================================================

-- 9.A Alta válida de los 3 roles para una misma selección.
-- Esperado: OK, se insertan los 3 integrantes.
INSERT INTO nucleo.StaffTecnico (NombreApellido, Rol, IdSeleccion)
VALUES ('TEST DT 1',        'Director Técnico',    @idSel1),
       ('TEST Ayudante 1',  'Ayudante de campo 1', @idSel1),
       ('TEST Ayudante 2',  'Ayudante de campo 2', @idSel1);
IF (SELECT COUNT(*) FROM nucleo.StaffTecnico WHERE IdSeleccion = @idSel1) = 3
	PRINT 'TEST 9.A OK: Cuerpo técnico completo insertado.';
ELSE
	PRINT 'TEST 9.A FALLÓ: no se insertó el cuerpo técnico.';

-- 9.B Segundo Director Técnico en la misma selección.
-- Esperado: Bloqueado por UQ_StaffTecnico_IdSeleccion_Rol.
BEGIN TRY
	INSERT INTO nucleo.StaffTecnico (NombreApellido, Rol, IdSeleccion) VALUES ('TEST DT 2', 'Director Técnico', @idSel1);
	PRINT 'TEST 9.B FALLÓ: permitió dos directores técnicos en la misma selección.';
END TRY
BEGIN CATCH
	PRINT 'TEST 9.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 9.C Rol inválido.
-- Esperado: Bloqueado por CK_StaffTecnico_Rol_Valido.
BEGIN TRY
	INSERT INTO nucleo.StaffTecnico (NombreApellido, Rol, IdSeleccion) VALUES ('TEST Kinesiologo', 'Kinesiólogo', @idSel2);
	PRINT 'TEST 9.C FALLÓ: permitió un rol no válido.';
END TRY
BEGIN CATCH
	PRINT 'TEST 9.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 9.D Selección inexistente.
-- Esperado: Bloqueado por FK_StaffTecnico_Seleccion.
BEGIN TRY
	INSERT INTO nucleo.StaffTecnico (NombreApellido, Rol, IdSeleccion) VALUES ('TEST DT 3', 'Director Técnico', 250);
	PRINT 'TEST 9.D FALLÓ: permitió staff con selección inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 9.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 10: Idioma y Categoria
-- =========================================================================

-- 10.A Alta válida.
-- Esperado: OK, se insertan 2 idiomas y 2 categorías.
INSERT INTO nucleo.Idioma (Nombre) VALUES ('TEST Idioma 1'), ('TEST Idioma 2');
INSERT INTO nucleo.Categoria (Nombre) VALUES ('TEST Categoria 1'), ('TEST Categoria 2');
DECLARE @idIdioma1 TINYINT = (SELECT IdIdioma FROM nucleo.Idioma WHERE Nombre = 'TEST Idioma 1');
DECLARE @idIdioma2 TINYINT = (SELECT IdIdioma FROM nucleo.Idioma WHERE Nombre = 'TEST Idioma 2');
DECLARE @idCategoria1 TINYINT = (SELECT IdCategoria FROM nucleo.Categoria WHERE Nombre = 'TEST Categoria 1');
IF @idIdioma1 IS NOT NULL AND @idIdioma2 IS NOT NULL AND @idCategoria1 IS NOT NULL
	PRINT 'TEST 10.A OK: Idiomas y categorías insertados.';
ELSE
	PRINT 'TEST 10.A FALLÓ: no se insertaron idiomas o categorías.';

-- 10.B Idioma duplicado.
-- Esperado: Bloqueado por UQ_Idioma_Nombre.
BEGIN TRY
	INSERT INTO nucleo.Idioma (Nombre) VALUES ('TEST Idioma 1');
	PRINT 'TEST 10.B FALLÓ: permitió idioma duplicado.';
END TRY
BEGIN CATCH
	PRINT 'TEST 10.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 10.C Idioma con nombre vacío.
-- Esperado: Bloqueado por CK_Idioma_Nombre_NoVacio.
BEGIN TRY
	INSERT INTO nucleo.Idioma (Nombre) VALUES ('  ');
	PRINT 'TEST 10.C FALLÓ: permitió idioma con nombre vacío.';
END TRY
BEGIN CATCH
	PRINT 'TEST 10.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 10.D Categoría duplicada.
-- Esperado: Bloqueado por UQ_Categoria_Nombre.
BEGIN TRY
	INSERT INTO nucleo.Categoria (Nombre) VALUES ('TEST Categoria 1');
	PRINT 'TEST 10.D FALLÓ: permitió categoría duplicada.';
END TRY
BEGIN CATCH
	PRINT 'TEST 10.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 10.E Categoría con nombre vacío.
-- Esperado: Bloqueado por CK_Categoria_Nombre_NoVacio.
BEGIN TRY
	INSERT INTO nucleo.Categoria (Nombre) VALUES ('  ');
	PRINT 'TEST 10.E FALLÓ: permitió categoría con nombre vacío.';
END TRY
BEGIN CATCH
	PRINT 'TEST 10.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 11: Arbitro
-- =========================================================================

-- 11.A Alta válida; EstaHabilitado toma 'Y' por defecto y Sexo admite NULL.
-- Esperado: OK, se insertan 3 árbitros y EstaHabilitado = 'Y' en el que no lo informa.
INSERT INTO nucleo.Arbitro (NombreApellido, Sexo, FechaNacimiento, IdPais, IdCategoria)
VALUES ('TEST Arbitro 1', 'M', '1980-05-10', @idPais1, @idCategoria1);
INSERT INTO nucleo.Arbitro (NombreApellido, Sexo, EstaHabilitado, FechaNacimiento, IdPais, IdCategoria)
VALUES ('TEST Arbitro 2', 'F',  'N', '1985-03-20', @idPais2, @idCategoria1),
       ('TEST Arbitro 3', NULL, 'Y', '1990-07-01', @idPais3, @idCategoria1);
DECLARE @idArb1 SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST Arbitro 1');
DECLARE @idArb2 SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST Arbitro 2');
DECLARE @idArb3 SMALLINT = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = 'TEST Arbitro 3');
IF @idArb1 IS NOT NULL AND @idArb2 IS NOT NULL AND @idArb3 IS NOT NULL
	AND (SELECT EstaHabilitado FROM nucleo.Arbitro WHERE IdArbitro = @idArb1) = 'Y'
	PRINT 'TEST 11.A OK: Árbitros insertados y DEFAULT de EstaHabilitado aplicado.';
ELSE
	PRINT 'TEST 11.A FALLÓ: no se insertaron los árbitros o el DEFAULT no se aplicó.';

-- 11.B Nombre vacío.
-- Esperado: Bloqueado por CK_Arbitro_NombreApellido_NoVacio.
BEGIN TRY
	INSERT INTO nucleo.Arbitro (NombreApellido, FechaNacimiento, IdPais, IdCategoria)
	VALUES ('  ', '1980-05-10', @idPais1, @idCategoria1);
	PRINT 'TEST 11.B FALLÓ: permitió árbitro con nombre vacío.';
END TRY
BEGIN CATCH
	PRINT 'TEST 11.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 11.C Sexo inválido.
-- Esperado: Bloqueado por CK_Arbitro_Sexo_Valido.
BEGIN TRY
	INSERT INTO nucleo.Arbitro (NombreApellido, Sexo, FechaNacimiento, IdPais, IdCategoria)
	VALUES ('TEST Arbitro 9', 'X', '1980-05-10', @idPais1, @idCategoria1);
	PRINT 'TEST 11.C FALLÓ: permitió sexo inválido.';
END TRY
BEGIN CATCH
	PRINT 'TEST 11.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 11.D EstaHabilitado inválido.
-- Esperado: Bloqueado por CK_Arbitro_EstaHabilitado_Valido.
BEGIN TRY
	INSERT INTO nucleo.Arbitro (NombreApellido, EstaHabilitado, FechaNacimiento, IdPais, IdCategoria)
	VALUES ('TEST Arbitro 9', 'S', '1980-05-10', @idPais1, @idCategoria1);
	PRINT 'TEST 11.D FALLÓ: permitió EstaHabilitado distinto de Y/N.';
END TRY
BEGIN CATCH
	PRINT 'TEST 11.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 11.E Fecha de nacimiento anterior a 1930.
-- Esperado: Bloqueado por CK_Arbitro_FechaNacimiento_Valida.
BEGIN TRY
	INSERT INTO nucleo.Arbitro (NombreApellido, FechaNacimiento, IdPais, IdCategoria)
	VALUES ('TEST Arbitro 9', '1929-12-31', @idPais1, @idCategoria1);
	PRINT 'TEST 11.E FALLÓ: permitió nacimiento anterior a 1930.';
END TRY
BEGIN CATCH
	PRINT 'TEST 11.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 11.F Fecha de nacimiento futura.
-- Esperado: Bloqueado por CK_Arbitro_FechaNacimiento_Valida.
BEGIN TRY
	INSERT INTO nucleo.Arbitro (NombreApellido, FechaNacimiento, IdPais, IdCategoria)
	VALUES ('TEST Arbitro 9', '2099-01-01', @idPais1, @idCategoria1);
	PRINT 'TEST 11.F FALLÓ: permitió fecha de nacimiento futura.';
END TRY
BEGIN CATCH
	PRINT 'TEST 11.F OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 11.G Fecha de nacimiento igual a la fecha actual (la restricción exige fecha estrictamente anterior).
-- Esperado: Bloqueado por CK_Arbitro_FechaNacimiento_Valida.
BEGIN TRY
	INSERT INTO nucleo.Arbitro (NombreApellido, FechaNacimiento, IdPais, IdCategoria)
	VALUES ('TEST Arbitro 9', CAST(GETDATE() AS DATE), @idPais1, @idCategoria1);
	PRINT 'TEST 11.G FALLÓ: permitió nacimiento en la fecha actual.';
END TRY
BEGIN CATCH
	PRINT 'TEST 11.G OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 11.H País inexistente.
-- Esperado: Bloqueado por FK_Arbitro_Pais.
BEGIN TRY
	INSERT INTO nucleo.Arbitro (NombreApellido, FechaNacimiento, IdPais, IdCategoria)
	VALUES ('TEST Arbitro 9', '1980-05-10', 32000, @idCategoria1);
	PRINT 'TEST 11.H FALLÓ: permitió árbitro con país inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 11.H OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 11.I Categoría inexistente.
-- Esperado: Bloqueado por FK_Arbitro_Categoria.
BEGIN TRY
	INSERT INTO nucleo.Arbitro (NombreApellido, FechaNacimiento, IdPais, IdCategoria)
	VALUES ('TEST Arbitro 9', '1980-05-10', @idPais1, 250);
	PRINT 'TEST 11.I FALLÓ: permitió árbitro con categoría inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 11.I OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 12: ArbitroIdioma
-- =========================================================================

-- 12.A Un árbitro con varios idiomas.
-- Esperado: OK, se insertan 2 relaciones para el árbitro 1.
INSERT INTO nucleo.ArbitroIdioma (IdArbitro, IdIdioma) VALUES (@idArb1, @idIdioma1), (@idArb1, @idIdioma2);
IF (SELECT COUNT(*) FROM nucleo.ArbitroIdioma WHERE IdArbitro = @idArb1) = 2
	PRINT 'TEST 12.A OK: Árbitro con dos idiomas registrado.';
ELSE
	PRINT 'TEST 12.A FALLÓ: no se registraron los idiomas del árbitro.';

-- 12.B Relación duplicada.
-- Esperado: Bloqueado por PK_ArbitroIdioma.
BEGIN TRY
	INSERT INTO nucleo.ArbitroIdioma (IdArbitro, IdIdioma) VALUES (@idArb1, @idIdioma1);
	PRINT 'TEST 12.B FALLÓ: permitió repetir el idioma de un árbitro.';
END TRY
BEGIN CATCH
	PRINT 'TEST 12.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 12.C Árbitro inexistente.
-- Esperado: Bloqueado por FK_ArbitroIdioma_Arbitro.
BEGIN TRY
	INSERT INTO nucleo.ArbitroIdioma (IdArbitro, IdIdioma) VALUES (32000, @idIdioma1);
	PRINT 'TEST 12.C FALLÓ: permitió idioma para un árbitro inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 12.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 12.D Idioma inexistente.
-- Esperado: Bloqueado por FK_ArbitroIdioma_Idioma.
BEGIN TRY
	INSERT INTO nucleo.ArbitroIdioma (IdArbitro, IdIdioma) VALUES (@idArb2, 250);
	PRINT 'TEST 12.D FALLÓ: permitió un idioma inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 12.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 13: DesignacionArbitral
-- (los cupos por rol y el impedimento por nacionalidad los valida SP_CONTROL_ARBITRAL,
--  acá solo se prueban las restricciones de la tabla)
-- =========================================================================
DECLARE @idPartidoDes SMALLINT = (SELECT IdPartido FROM nucleo.Partido WHERE NumeroPartido = 201);

-- 13.A Alta válida de dos roles distintos con árbitros distintos.
-- Esperado: OK, se insertan 2 designaciones.
INSERT INTO nucleo.DesignacionArbitral (Rol, IdArbitro, IdPartido)
VALUES ('Principal', @idArb1, @idPartidoDes),
       ('VAR',       @idArb2, @idPartidoDes);
DECLARE @idDes1 SMALLINT = (SELECT IdDesignacionArbitral FROM nucleo.DesignacionArbitral WHERE IdPartido = @idPartidoDes AND Rol = 'Principal');
IF @idDes1 IS NOT NULL AND (SELECT COUNT(*) FROM nucleo.DesignacionArbitral WHERE IdPartido = @idPartidoDes) = 2
	PRINT 'TEST 13.A OK: Designaciones insertadas.';
ELSE
	PRINT 'TEST 13.A FALLÓ: no se insertaron las designaciones.';

-- 13.B Mismo rol dos veces en el mismo partido.
-- Esperado: Bloqueado por UQ_DesignacionArbitral_IdPartido_Rol.
BEGIN TRY
	INSERT INTO nucleo.DesignacionArbitral (Rol, IdArbitro, IdPartido) VALUES ('Principal', @idArb3, @idPartidoDes);
	PRINT 'TEST 13.B FALLÓ: permitió dos árbitros con el mismo rol en un partido.';
END TRY
BEGIN CATCH
	PRINT 'TEST 13.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 13.C Mismo árbitro con dos roles en el mismo partido.
-- Esperado: Bloqueado por UQ_DesignacionArbitral_IdPartido_IdArbitro.
BEGIN TRY
	INSERT INTO nucleo.DesignacionArbitral (Rol, IdArbitro, IdPartido) VALUES ('Cuarto', @idArb1, @idPartidoDes);
	PRINT 'TEST 13.C FALLÓ: permitió el mismo árbitro con dos roles en un partido.';
END TRY
BEGIN CATCH
	PRINT 'TEST 13.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 13.D Rol inválido.
-- Esperado: Bloqueado por CK_DesignacionArbitral_Rol_Valido.
BEGIN TRY
	INSERT INTO nucleo.DesignacionArbitral (Rol, IdArbitro, IdPartido) VALUES ('Asistente 3', @idArb3, @idPartidoDes);
	PRINT 'TEST 13.D FALLÓ: permitió un rol arbitral no válido.';
END TRY
BEGIN CATCH
	PRINT 'TEST 13.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 13.E Árbitro inexistente.
-- Esperado: Bloqueado por FK_DesignacionArbitral_Arbitro.
BEGIN TRY
	INSERT INTO nucleo.DesignacionArbitral (Rol, IdArbitro, IdPartido) VALUES ('Cuarto', 32000, @idPartidoDes);
	PRINT 'TEST 13.E FALLÓ: permitió designar un árbitro inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 13.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 13.F Partido inexistente.
-- Esperado: Bloqueado por FK_DesignacionArbitral_Partido.
BEGIN TRY
	INSERT INTO nucleo.DesignacionArbitral (Rol, IdArbitro, IdPartido) VALUES ('Cuarto', @idArb3, 32000);
	PRINT 'TEST 13.F FALLÓ: permitió designación sobre un partido inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 13.F OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 14: Sancion
-- =========================================================================

-- 14.A Alta válida; Fecha toma la fecha actual por defecto.
-- Esperado: OK, se inserta la sanción con Fecha = fecha de hoy.
INSERT INTO nucleo.Sancion (Tipo, Descripcion, IdDesignacionArbitral)
VALUES ('Advertencia', 'TEST Sancion por demora en el partido', @idDes1);
IF EXISTS (SELECT 1 FROM nucleo.Sancion WHERE IdDesignacionArbitral = @idDes1 AND Fecha = CAST(GETDATE() AS DATE))
	PRINT 'TEST 14.A OK: Sanción insertada y DEFAULT de Fecha aplicado.';
ELSE
	PRINT 'TEST 14.A FALLÓ: no se insertó la sanción o el DEFAULT no se aplicó.';

-- 14.B Tipo de sanción inválido.
-- Esperado: Bloqueado por CK_Sancion_Tipo_Valido.
BEGIN TRY
	INSERT INTO nucleo.Sancion (Tipo, Descripcion, IdDesignacionArbitral) VALUES ('Destierro', 'TEST descripcion', @idDes1);
	PRINT 'TEST 14.B FALLÓ: permitió un tipo de sanción no válido.';
END TRY
BEGIN CATCH
	PRINT 'TEST 14.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 14.C Descripción vacía.
-- Esperado: Bloqueado por CK_Sancion_Descripcion_NoVacia.
BEGIN TRY
	INSERT INTO nucleo.Sancion (Tipo, Descripcion, IdDesignacionArbitral) VALUES ('Multa', '   ', @idDes1);
	PRINT 'TEST 14.C FALLÓ: permitió descripción vacía.';
END TRY
BEGIN CATCH
	PRINT 'TEST 14.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 14.D Designación inexistente.
-- Esperado: Bloqueado por FK_Sancion_DesignacionArbitral.
BEGIN TRY
	INSERT INTO nucleo.Sancion (Tipo, Descripcion, IdDesignacionArbitral) VALUES ('Multa', 'TEST descripcion', 32000);
	PRINT 'TEST 14.D FALLÓ: permitió sanción sobre una designación inexistente.';
END TRY
BEGIN CATCH
	PRINT 'TEST 14.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 14.E Borrar una designación que tiene sanciones.
-- Esperado: Bloqueado por FK_Sancion_DesignacionArbitral.
BEGIN TRY
	DELETE FROM nucleo.DesignacionArbitral WHERE IdDesignacionArbitral = @idDes1;
	PRINT 'TEST 14.E FALLÓ: permitió borrar una designación con sanciones.';
END TRY
BEGIN CATCH
	PRINT 'TEST 14.E OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- LIMPIEZA: se deshace todo lo insertado por los tests
-- =========================================================================
ROLLBACK TRANSACTION;
GO
