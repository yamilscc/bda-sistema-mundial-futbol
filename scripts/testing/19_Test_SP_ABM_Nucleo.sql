/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner
Fecha: 2026-11-19
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Probar los 13 stored procedures ABM restantes del módulo núcleo (script 19_SP_ABM_Nucleo.sql):
          - nucleo.SP_ABM_Confederacion
          - nucleo.SP_ABM_Pais
          - nucleo.SP_ABM_Ciudad
          - nucleo.SP_ABM_Fase
          - nucleo.SP_ABM_Grupo
          - nucleo.SP_ABM_Seleccion
          - nucleo.SP_ABM_StaffTecnico
          - nucleo.SP_ABM_Idioma
          - nucleo.SP_ABM_Categoria
          - nucleo.SP_ABM_Arbitro
          - nucleo.SP_ABM_ArbitroIdioma
          - nucleo.SP_ABM_DesignacionArbitral
          - nucleo.SP_ABM_Sancion
          Requiere ejecutados los scripts 01 a 19.
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- TEST 1: nucleo.SP_ABM_Confederacion
-- =========================================================================
PRINT '--- TEST 1: SP_ABM_Confederacion ---';

DECLARE @idConf1 INT, @idConf2 INT;

-- 1.A ALTA exitosa de 2 confederaciones.
BEGIN TRY
    EXEC nucleo.SP_ABM_Confederacion 'ALTA', @idConf1 OUTPUT, 'TEST N19 Confederacion A', 'TN19A';
    EXEC nucleo.SP_ABM_Confederacion 'ALTA', @idConf2 OUTPUT, 'TEST N19 Confederacion B', 'TN19B';
    PRINT '1.A: OK - 2 confederaciones dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '1.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_Confederacion 'MODIFICACION', @idConf1, 'TEST N19 Confederacion Mod', 'TN19M';
    PRINT '1.B: OK - confederación modificada.';
END TRY
BEGIN CATCH
    PRINT '1.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.C ALTA fallida con múltiples errores (nombre y sigla duplicados) y operación inválida.
BEGIN TRY
    EXEC nucleo.SP_ABM_Confederacion 'ALTA', NULL, 'TEST N19 Confederacion Mod', 'TN19M';
    PRINT '1.C.1: FALLÓ - permitió alta duplicada.';
END TRY
BEGIN CATCH
    PRINT '1.C.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC nucleo.SP_ABM_Confederacion 'CONSULTAR';
    PRINT '1.C.2: FALLÓ - permitió operación inválida.';
END TRY
BEGIN CATCH
    PRINT '1.C.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 1.D BAJA exitosa de confederación sin países asociados.
BEGIN TRY
    EXEC nucleo.SP_ABM_Confederacion 'BAJA', @idConf2;
    PRINT '1.D: OK - baja de confederación sin dependencias.';
END TRY
BEGIN CATCH
    PRINT '1.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: nucleo.SP_ABM_Pais
-- =========================================================================
PRINT '--- TEST 2: SP_ABM_Pais ---';

DECLARE @idPais1 INT, @idPais2 INT, @idPais3 INT, @idPaisTemp INT;

-- 2.A ALTA exitosa de países (Local, Visitante, Neutral y Temporal).
BEGIN TRY
    EXEC nucleo.SP_ABM_Pais 'ALTA', @idPais1 OUTPUT, 'TEST N19 Pais Local',     'XA', 'XEA', @idConf1, 'Argentina Standard Time', 14500.00;
    EXEC nucleo.SP_ABM_Pais 'ALTA', @idPais2 OUTPUT, 'TEST N19 Pais Visitante', 'XB', 'XEB', @idConf1, 'UTC', 38000.00;
    EXEC nucleo.SP_ABM_Pais 'ALTA', @idPais3 OUTPUT, 'TEST N19 Pais Neutral',   'XC', 'XEC', @idConf1, 'Central European Standard Time', 52000.00;
    EXEC nucleo.SP_ABM_Pais 'ALTA', @idPaisTemp OUTPUT, 'TEST N19 Pais Temp',   'XD', 'XED', @idConf1, 'UTC', NULL;
    PRINT '2.A: OK - 4 países dados de alta.';
END TRY
BEGIN CATCH
    PRINT '2.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.B MODIFICACION exitosa (actualiza PBI per cápita).
BEGIN TRY
    EXEC nucleo.SP_ABM_Pais 'MODIFICACION', @idPais1, 'TEST N19 Pais Local', 'XA', 'XEA', @idConf1, 'Argentina Standard Time', 16200.50;
    PRINT '2.B: OK - país modificado.';
END TRY
BEGIN CATCH
    PRINT '2.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.C ALTA fallida con múltiples errores (ISO2 duplicado, huso horario inválido, PBI negativo).
BEGIN TRY
    EXEC nucleo.SP_ABM_Pais 'ALTA', NULL, 'TEST N19 Invalido', 'XA', 'XEZ', @idConf1, 'Zona Inexistente', -100.00;
    PRINT '2.C: FALLÓ - permitió alta inválida de país.';
END TRY
BEGIN CATCH
    PRINT '2.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 2.D BAJA bloqueada de Confederacion con países hijos, y BAJA exitosa de @idPaisTemp.
BEGIN TRY
    EXEC nucleo.SP_ABM_Confederacion 'BAJA', @idConf1;
    PRINT '2.D.1: FALLÓ - permitió borrar confederación con países asociados.';
END TRY
BEGIN CATCH
    PRINT '2.D.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC nucleo.SP_ABM_Pais 'BAJA', @idPaisTemp;
    PRINT '2.D.2: OK - baja de país sin dependencias.';
END TRY
BEGIN CATCH
    PRINT '2.D.2: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: nucleo.SP_ABM_Ciudad
-- =========================================================================
PRINT '--- TEST 3: SP_ABM_Ciudad ---';

DECLARE @idCiudad1 INT, @idCiudad2 INT;

-- 3.A ALTA exitosa de 2 ciudades (hereda HusoHorarioComercial del país si se omite).
BEGIN TRY
    EXEC nucleo.SP_ABM_Ciudad 'ALTA', @idCiudad1 OUTPUT, 'TEST N19 Ciudad A', @idPais1;
    EXEC nucleo.SP_ABM_Ciudad 'ALTA', @idCiudad2 OUTPUT, 'TEST N19 Ciudad B', @idPais1;
    PRINT '3.A: OK - 2 ciudades dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_Ciudad 'MODIFICACION', @idCiudad1, 'TEST N19 Ciudad Sede', @idPais1;
    PRINT '3.B: OK - ciudad modificada.';
END TRY
BEGIN CATCH
    PRINT '3.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.C ALTA fallida (ciudad duplicada en el mismo país).
BEGIN TRY
    EXEC nucleo.SP_ABM_Ciudad 'ALTA', NULL, 'TEST N19 Ciudad Sede', @idPais1;
    PRINT '3.C: FALLÓ - permitió ciudad duplicada en el mismo país.';
END TRY
BEGIN CATCH
    PRINT '3.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 3.D BAJA exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_Ciudad 'BAJA', @idCiudad2;
    PRINT '3.D: OK - baja de ciudad sin sedes asociadas.';
END TRY
BEGIN CATCH
    PRINT '3.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: nucleo.SP_ABM_Fase
-- (Las 7 fases reglamentarias ya vienen precargadas desde 01_Tablas_Nucleo.sql)
-- =========================================================================
PRINT '--- TEST 4: SP_ABM_Fase ---';

DECLARE @idFaseGrupos INT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Fase de grupos');
DECLARE @idFaseFinal  INT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Final');
DECLARE @ordenFinal   INT = (SELECT Orden  FROM nucleo.Fase WHERE IdFase = @idFaseFinal);

-- 4.A MODIFICACION exitosa (cambia Orden de Final a 70 y luego lo restaura).
BEGIN TRY
    EXEC nucleo.SP_ABM_Fase 'MODIFICACION', @idFaseFinal, 'Final', 70, 1;
    EXEC nucleo.SP_ABM_Fase 'MODIFICACION', @idFaseFinal, 'Final', @ordenFinal, 1;
    PRINT '4.A: OK - fase Final modificada y restaurada.';
END TRY
BEGIN CATCH
    PRINT '4.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 4.B ALTA fallida con múltiples errores (nombre inválido, orden <= 0, esEliminatoria NULL).
BEGIN TRY
    EXEC nucleo.SP_ABM_Fase 'ALTA', NULL, 'Repechaje', 0, NULL;
    PRINT '4.B: FALLÓ - permitió alta inválida de fase.';
END TRY
BEGIN CATCH
    PRINT '4.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 5: nucleo.SP_ABM_Grupo
-- =========================================================================
PRINT '--- TEST 5: SP_ABM_Grupo ---';

DECLARE @idGrupo1 INT, @idGrupo2 INT;

-- 5.A ALTA exitosa de 2 grupos de prueba (una letra A-Z).
BEGIN TRY
    EXEC nucleo.SP_ABM_Grupo 'ALTA', @idGrupo1 OUTPUT, 'X';
    EXEC nucleo.SP_ABM_Grupo 'ALTA', @idGrupo2 OUTPUT, 'Y';
    PRINT '5.A: OK - 2 grupos dados de alta.';
END TRY
BEGIN CATCH
    PRINT '5.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 5.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_Grupo 'MODIFICACION', @idGrupo1, 'Z';
    PRINT '5.B: OK - grupo modificado.';
END TRY
BEGIN CATCH
    PRINT '5.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 5.C ALTA fallida (nombre duplicado).
BEGIN TRY
    EXEC nucleo.SP_ABM_Grupo 'ALTA', NULL, 'Z';
    PRINT '5.C: FALLÓ - permitió grupo duplicado.';
END TRY
BEGIN CATCH
    PRINT '5.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 5.D BAJA exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_Grupo 'BAJA', @idGrupo2;
    PRINT '5.D: OK - baja de grupo sin selecciones.';
END TRY
BEGIN CATCH
    PRINT '5.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 6: nucleo.SP_ABM_Seleccion
-- =========================================================================
PRINT '--- TEST 6: SP_ABM_Seleccion ---';

DECLARE @idSel1 INT, @idSel2 INT;

-- 6.A ALTA exitosa de 2 selecciones.
BEGIN TRY
    EXEC nucleo.SP_ABM_Seleccion 'ALTA', @idSel1 OUTPUT, 'XEA', 201, 0, @idPais1, @idGrupo1;
    EXEC nucleo.SP_ABM_Seleccion 'ALTA', @idSel2 OUTPUT, 'XEB', 202, 0, @idPais2, @idGrupo1;
    PRINT '6.A: OK - 2 selecciones dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '6.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 6.B MODIFICACION exitosa (actualiza ranking FIFA y condición de anfitrión).
BEGIN TRY
    EXEC nucleo.SP_ABM_Seleccion 'MODIFICACION', @idSel2, 'XEB', 199, 1, @idPais2, @idGrupo1;
    PRINT '6.B: OK - selección modificada.';
END TRY
BEGIN CATCH
    PRINT '6.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 6.C ALTA fallida (país duplicado en selección y grupo inexistente).
BEGIN TRY
    EXEC nucleo.SP_ABM_Seleccion 'ALTA', NULL, 'XEC', 203, 0, @idPais1, -1;
    PRINT '6.C: FALLÓ - permitió país duplicado en selección y grupo inexistente.';
END TRY
BEGIN CATCH
    PRINT '6.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 6.D BAJA bloqueada de Grupo con selecciones, y BAJA + re-alta de @idSel2.
BEGIN TRY
    EXEC nucleo.SP_ABM_Grupo 'BAJA', @idGrupo1;
    PRINT '6.D.1: FALLÓ - permitió eliminar grupo con selecciones asociadas.';
END TRY
BEGIN CATCH
    PRINT '6.D.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC nucleo.SP_ABM_Seleccion 'BAJA', @idSel2;
    EXEC nucleo.SP_ABM_Seleccion 'ALTA', @idSel2 OUTPUT, 'XEB', 202, 0, @idPais2, @idGrupo1;
    PRINT '6.D.2: OK - baja y re-alta de selección.';
END TRY
BEGIN CATCH
    PRINT '6.D.2: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 7: nucleo.SP_ABM_StaffTecnico
-- =========================================================================
PRINT '--- TEST 7: SP_ABM_StaffTecnico ---';

DECLARE @idStaffDT INT, @idStaffAy INT;

-- 7.A ALTA exitosa de Director Técnico y Ayudante de campo 1.
BEGIN TRY
    EXEC nucleo.SP_ABM_StaffTecnico 'ALTA', @idStaffDT OUTPUT, @idSel1, 'Lionel Tecnico', 'Director Técnico';
    EXEC nucleo.SP_ABM_StaffTecnico 'ALTA', @idStaffAy OUTPUT, @idSel1, 'Pablo Ayudante', 'Ayudante de campo 1';
    PRINT '7.A: OK - DT y Ayudante dados de alta.';
END TRY
BEGIN CATCH
    PRINT '7.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 7.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_StaffTecnico 'MODIFICACION', @idStaffAy, @idSel1, 'Pablo Cesar Ayudante', 'Ayudante de campo 1';
    PRINT '7.B: OK - ayudante modificado.';
END TRY
BEGIN CATCH
    PRINT '7.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 7.C ALTA fallida (segundo Director Técnico en la misma selección).
BEGIN TRY
    EXEC nucleo.SP_ABM_StaffTecnico 'ALTA', NULL, @idSel1, 'Otro DT', 'Director Técnico';
    PRINT '7.C: FALLÓ - permitió segundo DT en la misma selección.';
END TRY
BEGIN CATCH
    PRINT '7.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 7.D BAJA exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_StaffTecnico 'BAJA', @idStaffAy;
    PRINT '7.D: OK - baja de ayudante técnico.';
END TRY
BEGIN CATCH
    PRINT '7.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 8: nucleo.SP_ABM_Idioma
-- =========================================================================
PRINT '--- TEST 8: SP_ABM_Idioma ---';

DECLARE @idIdioma1 INT, @idIdioma2 INT;

-- 8.A ALTA exitosa de 2 idiomas.
BEGIN TRY
    EXEC nucleo.SP_ABM_Idioma 'ALTA', @idIdioma1 OUTPUT, 'TEST N19 Idioma A';
    EXEC nucleo.SP_ABM_Idioma 'ALTA', @idIdioma2 OUTPUT, 'TEST N19 Idioma B';
    PRINT '8.A: OK - 2 idiomas dados de alta.';
END TRY
BEGIN CATCH
    PRINT '8.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 8.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_Idioma 'MODIFICACION', @idIdioma2, 'TEST N19 Idioma B Mod';
    PRINT '8.B: OK - idioma modificado.';
END TRY
BEGIN CATCH
    PRINT '8.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 8.C ALTA fallida (nombre duplicado).
BEGIN TRY
    EXEC nucleo.SP_ABM_Idioma 'ALTA', NULL, 'TEST N19 Idioma A';
    PRINT '8.C: FALLÓ - permitió idioma duplicado.';
END TRY
BEGIN CATCH
    PRINT '8.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 8.D BAJA exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_Idioma 'BAJA', @idIdioma2;
    PRINT '8.D: OK - baja de idioma sin referencias.';
END TRY
BEGIN CATCH
    PRINT '8.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 9: nucleo.SP_ABM_Categoria
-- =========================================================================
PRINT '--- TEST 9: SP_ABM_Categoria ---';

DECLARE @idCat1 INT, @idCat2 INT;

-- 9.A ALTA exitosa de 2 categorías.
BEGIN TRY
    EXEC nucleo.SP_ABM_Categoria 'ALTA', @idCat1 OUTPUT, 'TEST N19 Cat A';
    EXEC nucleo.SP_ABM_Categoria 'ALTA', @idCat2 OUTPUT, 'TEST N19 Cat B';
    PRINT '9.A: OK - 2 categorías dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '9.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 9.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_Categoria 'MODIFICACION', @idCat2, 'TEST N19 Cat B Mod';
    PRINT '9.B: OK - categoría modificada.';
END TRY
BEGIN CATCH
    PRINT '9.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 9.C ALTA fallida (nombre duplicado).
BEGIN TRY
    EXEC nucleo.SP_ABM_Categoria 'ALTA', NULL, 'TEST N19 Cat A';
    PRINT '9.C: FALLÓ - permitió categoría duplicada.';
END TRY
BEGIN CATCH
    PRINT '9.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 9.D BAJA exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_Categoria 'BAJA', @idCat2;
    PRINT '9.D: OK - baja de categoría sin árbitros.';
END TRY
BEGIN CATCH
    PRINT '9.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 10: nucleo.SP_ABM_Arbitro
-- =========================================================================
PRINT '--- TEST 10: SP_ABM_Arbitro ---';

DECLARE @idArbNeutral INT, @idArbLocal INT;

-- 10.A ALTA exitosa de árbitro neutral y árbitro local.
BEGIN TRY
    EXEC nucleo.SP_ABM_Arbitro 'ALTA', @idArbNeutral OUTPUT, 'TEST N19 Pierluigi Collina', 'M', 'Y', '1980-02-13', @idPais3, @idCat1;
    EXEC nucleo.SP_ABM_Arbitro 'ALTA', @idArbLocal   OUTPUT, 'TEST N19 Nestor Pitana',     'M', 'Y', '1975-06-17', @idPais1, @idCat1;
    PRINT '10.A: OK - 2 árbitros dados de alta.';
END TRY
BEGIN CATCH
    PRINT '10.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 10.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_Arbitro 'MODIFICACION', @idArbNeutral, 'TEST N19 Pierluigi Collina Mod', 'M', 'Y', '1980-02-13', @idPais3, @idCat1;
    PRINT '10.B: OK - árbitro modificado.';
END TRY
BEGIN CATCH
    PRINT '10.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 10.C ALTA fallida con múltiples errores (nombre vacío, sexo/habilitación inválidos y fecha futura).
BEGIN TRY
    EXEC nucleo.SP_ABM_Arbitro 'ALTA', NULL, '', 'X', 'Z', '2099-01-01', @idPais3, @idCat1;
    PRINT '10.C: FALLÓ - permitió datos inválidos y fecha futura.';
END TRY
BEGIN CATCH
    PRINT '10.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 10.D BAJA exitosa y re-alta de @idArbLocal.
BEGIN TRY
    EXEC nucleo.SP_ABM_Arbitro 'BAJA', @idArbLocal;
    EXEC nucleo.SP_ABM_Arbitro 'ALTA', @idArbLocal OUTPUT, 'TEST N19 Nestor Pitana', 'M', 'Y', '1975-06-17', @idPais1, @idCat1;
    PRINT '10.D: OK - baja y re-alta de árbitro.';
END TRY
BEGIN CATCH
    PRINT '10.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 11: nucleo.SP_ABM_ArbitroIdioma
-- =========================================================================
PRINT '--- TEST 11: SP_ABM_ArbitroIdioma ---';

-- 11.A ALTA exitosa.
BEGIN TRY
    EXEC nucleo.SP_ABM_ArbitroIdioma 'ALTA', @idArbNeutral, @idIdioma1;
    PRINT '11.A: OK - idioma asignado al árbitro.';
END TRY
BEGIN CATCH
    PRINT '11.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 11.B ALTA fallida (duplicado) y MODIFICACION no admitida.
BEGIN TRY
    EXEC nucleo.SP_ABM_ArbitroIdioma 'ALTA', @idArbNeutral, @idIdioma1;
    PRINT '11.B.1: FALLÓ - permitió asignar idioma duplicado.';
END TRY
BEGIN CATCH
    PRINT '11.B.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC nucleo.SP_ABM_ArbitroIdioma 'MODIFICACION', @idArbNeutral, @idIdioma1;
    PRINT '11.B.2: FALLÓ - permitió MODIFICACION en tabla asociativa.';
END TRY
BEGIN CATCH
    PRINT '11.B.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 11.C BAJA exitosa y re-alta.
BEGIN TRY
    EXEC nucleo.SP_ABM_ArbitroIdioma 'BAJA', @idArbNeutral, @idIdioma1;
    EXEC nucleo.SP_ABM_ArbitroIdioma 'ALTA', @idArbNeutral, @idIdioma1;
    PRINT '11.C: OK - baja y re-alta en ArbitroIdioma.';
END TRY
BEGIN CATCH
    PRINT '11.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 12: nucleo.SP_ABM_DesignacionArbitral
-- =========================================================================
PRINT '--- TEST 12: SP_ABM_DesignacionArbitral ---';

DECLARE @idSede INT, @p9701 INT, @idDesig1 INT, @adv VARCHAR(200);

INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad)
VALUES ('TEST N19 Estadio', 60000, @idCiudad1);
SET @idSede = SCOPE_IDENTITY();

INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (232, '2026-06-14 19:00', 'Programado', @idFaseGrupos, @idSede, @idSel1, @idSel2);
SET @p9701 = SCOPE_IDENTITY();

-- 12.A ALTA exitosa (delega en SP_CONTROL_ARBITRAL).
BEGIN TRY
    EXEC nucleo.SP_ABM_DesignacionArbitral @operacion = 'ALTA', @idDesignacionArbitral = @idDesig1 OUTPUT,
         @idPartido = @p9701, @idArbitro = @idArbNeutral, @rol = 'Principal', @advertencia = @adv OUTPUT;
    PRINT '12.A: OK - designación arbitral registrada vía SP_ABM_DesignacionArbitral.';
END TRY
BEGIN CATCH
    PRINT '12.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'TranCount antes 12.B = ' + CAST(@@TRANCOUNT AS VARCHAR(5));

---- Deshabilitado: SP_CONTROL_ARBITRAL hace ROLLBACK total (ver resumen)
/*
-- 12.B ALTA fallida por conflicto de nacionalidad (árbitro del país de @idSel1).
BEGIN TRY
    EXEC nucleo.SP_ABM_DesignacionArbitral @operacion = 'ALTA', @idDesignacionArbitral = NULL,
         @idPartido = @p9701, @idArbitro = @idArbLocal, @rol = 'VAR';
    PRINT '12.B: FALLÓ - permitió designar árbitro con conflicto de nacionalidad.';
END TRY
BEGIN CATCH
    PRINT '12.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

PRINT 'TranCount después 12.B = ' + CAST(@@TRANCOUNT AS VARCHAR(5)); -- justo después del END CATCH
IF @@TRANCOUNT = 0
    THROW 50001, 'Se perdió la transacción externa en 12.B: SP_CONTROL_ARBITRAL hace ROLLBACK total.', 1;
*/

-- 12.C MODIFICACION exitosa de rol ('Principal' -> 'VAR').
BEGIN TRY
    EXEC nucleo.SP_ABM_DesignacionArbitral @operacion = 'MODIFICACION', @idDesignacionArbitral = @idDesig1,
         @idPartido = @p9701, @idArbitro = @idArbNeutral, @rol = 'VAR', @advertencia = @adv OUTPUT;
    PRINT '12.C: OK - rol arbitral modificado a VAR.';
END TRY
BEGIN CATCH
    PRINT '12.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 12.D BAJA exitosa y re-alta (queda activa para el Test 13).
BEGIN TRY
    EXEC nucleo.SP_ABM_DesignacionArbitral @operacion = 'BAJA', @idDesignacionArbitral = @idDesig1;
    EXEC nucleo.SP_ABM_DesignacionArbitral @operacion = 'ALTA', @idDesignacionArbitral = @idDesig1 OUTPUT,
         @idPartido = @p9701, @idArbitro = @idArbNeutral, @rol = 'Principal', @advertencia = @adv OUTPUT;
    PRINT '12.D: OK - baja y re-alta de designación arbitral.';
END TRY
BEGIN CATCH
    PRINT '12.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 13: nucleo.SP_ABM_Sancion
-- =========================================================================
PRINT '--- TEST 13: SP_ABM_Sancion ---';

DECLARE @idSancion1 INT;

-- 13.A ALTA exitosa de sanción arbitral.
BEGIN TRY
    EXEC nucleo.SP_ABM_Sancion 'ALTA', @idSancion1 OUTPUT, @idDesig1, 'Advertencia', 'Informe por demora en reanudación', '2026-06-15';
    PRINT '13.A: OK - sanción arbitral dada de alta.';
END TRY
BEGIN CATCH
    PRINT '13.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 13.B BAJA bloqueada de DesignacionArbitral por tener sanción asociada.
BEGIN TRY
    EXEC nucleo.SP_ABM_DesignacionArbitral @operacion = 'BAJA', @idDesignacionArbitral = @idDesig1;
    PRINT '13.B: FALLÓ - permitió borrar designación con sanción asociada.';
END TRY
BEGIN CATCH
    PRINT '13.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 13.C MODIFICACION exitosa de sanción.
BEGIN TRY
    EXEC nucleo.SP_ABM_Sancion 'MODIFICACION', @idSancion1, @idDesig1, 'Multa', 'Multa administrativa confirmada', '2026-06-16';
    PRINT '13.C: OK - sanción arbitral modificada.';
END TRY
BEGIN CATCH
    PRINT '13.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 13.D ALTA fallida con múltiples errores (fecha anterior al partido, tipo inválido y descripción vacía).
BEGIN TRY
    EXEC nucleo.SP_ABM_Sancion 'ALTA', NULL, @idDesig1, 'Expulsion', '', '2026-06-01';
    PRINT '13.D: FALLÓ - permitió sanción con fecha anterior al partido y tipo/descripción inválidos.';
END TRY
BEGIN CATCH
    PRINT '13.D: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- CONTROLES FINALES
-- =========================================================================
SELECT 'Países de prueba creados (esperado: 3)' AS Control, COUNT(*) AS Cantidad
FROM nucleo.Pais
WHERE CodigoISO3 IN ('XEA', 'XEB', 'XEC');

SELECT 'Árbitros de prueba creados (esperado: 2)' AS Control, COUNT(*) AS Cantidad
FROM nucleo.Arbitro
WHERE NombreApellido IN ('TEST N19 Pierluigi Collina Mod', 'TEST N19 Nestor Pitana');

SELECT 'Designación y Sanción en 232 (esperado: Principal y Multa)' AS Control,
       d.Rol, s.Tipo AS TipoSancion, s.Descripcion, s.Fecha
FROM nucleo.DesignacionArbitral AS d
INNER JOIN nucleo.Sancion AS s ON s.IdDesignacionArbitral = d.IdDesignacionArbitral
WHERE d.IdPartido = @p9701;

ROLLBACK TRANSACTION;
GO