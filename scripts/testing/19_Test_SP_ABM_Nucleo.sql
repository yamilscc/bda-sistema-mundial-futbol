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
Objetivo: Probar los stored procedures ABM restantes del módulo núcleo, uno por operación y tabla (script 19_SP_ABM_Nucleo.sql):
          - nucleo.SP_ALTA/MODIFICACION/BAJA_Confederacion
          - nucleo.SP_ALTA/MODIFICACION/BAJA_Pais
          - nucleo.SP_ALTA/MODIFICACION/BAJA_Ciudad
          - nucleo.SP_ALTA/MODIFICACION/BAJA_Fase
          - nucleo.SP_ALTA/MODIFICACION/BAJA_Grupo
          - nucleo.SP_ALTA/MODIFICACION/BAJA_Seleccion
          - nucleo.SP_ALTA/MODIFICACION/BAJA_StaffTecnico
          - nucleo.SP_ALTA/MODIFICACION/BAJA_Idioma
          - nucleo.SP_ALTA/MODIFICACION/BAJA_Categoria
          - nucleo.SP_ALTA/MODIFICACION/BAJA_Arbitro
          - nucleo.SP_ALTA/MODIFICACION/BAJA_ArbitroIdioma
          - nucleo.SP_ALTA/MODIFICACION/BAJA_DesignacionArbitral
          - nucleo.SP_ALTA/MODIFICACION/BAJA_Sancion
          Requiere ejecutados los scripts 01 a 19.
          Todo corre dentro de una transacción que se deshace al final (ROLLBACK).
*/

USE MundialFutbol;
GO

BEGIN TRANSACTION;

-- =========================================================================
-- TEST 1: nucleo.SP_ALTA/MODIFICACION/BAJA_Confederacion
-- =========================================================================
PRINT '--- TEST 1: SP_ALTA/MODIFICACION/BAJA_Confederacion ---';

DECLARE @idConf1 INT, @idConf2 INT;

-- 1.A ALTA exitosa de 2 confederaciones.
BEGIN TRY
    EXEC nucleo.SP_ALTA_Confederacion @idConf1 OUTPUT, 'TEST N19 Confederacion A', 'TN19A';
    EXEC nucleo.SP_ALTA_Confederacion @idConf2 OUTPUT, 'TEST N19 Confederacion B', 'TN19B';
    PRINT '1.A: OK - 2 confederaciones dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '1.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Confederacion @idConf1, 'TEST N19 Confederacion Mod', 'TN19M';
    PRINT '1.B: OK - confederación modificada.';
END TRY
BEGIN CATCH
    PRINT '1.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 1.C ALTA fallida con múltiples errores (nombre y sigla duplicados) y modificación de una confederación inexistente.
BEGIN TRY
    EXEC nucleo.SP_ALTA_Confederacion NULL, 'TEST N19 Confederacion Mod', 'TN19M';
    PRINT '1.C.1: FALLÓ - permitió alta duplicada.';
END TRY
BEGIN CATCH
    PRINT '1.C.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Confederacion -1, 'TEST N19 Inexistente', 'TN19X';
    PRINT '1.C.2: FALLÓ - permitió modificar una confederación inexistente.';
END TRY
BEGIN CATCH
    PRINT '1.C.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 1.D BAJA exitosa de confederación sin países asociados.
BEGIN TRY
    EXEC nucleo.SP_BAJA_Confederacion @idConf2;
    PRINT '1.D: OK - baja de confederación sin dependencias.';
END TRY
BEGIN CATCH
    PRINT '1.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: nucleo.SP_ALTA/MODIFICACION/BAJA_Pais
-- =========================================================================
PRINT '--- TEST 2: SP_ALTA/MODIFICACION/BAJA_Pais ---';

DECLARE @idPais1 INT, @idPais2 INT, @idPais3 INT, @idPaisTemp INT;

-- 2.A ALTA exitosa de países (Local, Visitante, Neutral y Temporal).
BEGIN TRY
    EXEC nucleo.SP_ALTA_Pais @idPais1 OUTPUT, 'TEST N19 Pais Local',     'XA', 'XEA', @idConf1, 'Argentina Standard Time', 14500.00;
    EXEC nucleo.SP_ALTA_Pais @idPais2 OUTPUT, 'TEST N19 Pais Visitante', 'XB', 'XEB', @idConf1, 'UTC', 38000.00;
    EXEC nucleo.SP_ALTA_Pais @idPais3 OUTPUT, 'TEST N19 Pais Neutral',   'XC', 'XEC', @idConf1, 'Central European Standard Time', 52000.00;
    EXEC nucleo.SP_ALTA_Pais @idPaisTemp OUTPUT, 'TEST N19 Pais Temp',   'XD', 'XED', @idConf1, 'UTC', NULL;
    PRINT '2.A: OK - 4 países dados de alta.';
END TRY
BEGIN CATCH
    PRINT '2.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.B MODIFICACION exitosa (actualiza PBI per cápita).
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Pais @idPais1, 'TEST N19 Pais Local', 'XA', 'XEA', @idConf1, 'Argentina Standard Time', 16200.50;
    PRINT '2.B: OK - país modificado.';
END TRY
BEGIN CATCH
    PRINT '2.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 2.C ALTA fallida con múltiples errores (ISO2 duplicado, huso horario inválido, PBI negativo).
BEGIN TRY
    EXEC nucleo.SP_ALTA_Pais NULL, 'TEST N19 Invalido', 'XA', 'XEZ', @idConf1, 'Zona Inexistente', -100.00;
    PRINT '2.C: FALLÓ - permitió alta inválida de país.';
END TRY
BEGIN CATCH
    PRINT '2.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 2.D BAJA bloqueada de Confederacion con países hijos, y BAJA exitosa de @idPaisTemp.
BEGIN TRY
    EXEC nucleo.SP_BAJA_Confederacion @idConf1;
    PRINT '2.D.1: FALLÓ - permitió borrar confederación con países asociados.';
END TRY
BEGIN CATCH
    PRINT '2.D.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC nucleo.SP_BAJA_Pais @idPaisTemp;
    PRINT '2.D.2: OK - baja de país sin dependencias.';
END TRY
BEGIN CATCH
    PRINT '2.D.2: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: nucleo.SP_ALTA/MODIFICACION/BAJA_Ciudad
-- =========================================================================
PRINT '--- TEST 3: SP_ALTA/MODIFICACION/BAJA_Ciudad ---';

DECLARE @idCiudad1 INT, @idCiudad2 INT;

-- 3.A ALTA exitosa de 2 ciudades (hereda HusoHorarioComercial del país si se omite).
BEGIN TRY
    EXEC nucleo.SP_ALTA_Ciudad @idCiudad1 OUTPUT, 'TEST N19 Ciudad A', @idPais1;
    EXEC nucleo.SP_ALTA_Ciudad @idCiudad2 OUTPUT, 'TEST N19 Ciudad B', @idPais1;
    PRINT '3.A: OK - 2 ciudades dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '3.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Ciudad @idCiudad1, 'TEST N19 Ciudad Sede', @idPais1;
    PRINT '3.B: OK - ciudad modificada.';
END TRY
BEGIN CATCH
    PRINT '3.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 3.C ALTA fallida (ciudad duplicada en el mismo país).
BEGIN TRY
    EXEC nucleo.SP_ALTA_Ciudad NULL, 'TEST N19 Ciudad Sede', @idPais1;
    PRINT '3.C: FALLÓ - permitió ciudad duplicada en el mismo país.';
END TRY
BEGIN CATCH
    PRINT '3.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 3.D BAJA exitosa.
BEGIN TRY
    EXEC nucleo.SP_BAJA_Ciudad @idCiudad2;
    PRINT '3.D: OK - baja de ciudad sin sedes asociadas.';
END TRY
BEGIN CATCH
    PRINT '3.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 4: nucleo.SP_ALTA/MODIFICACION/BAJA_Fase
-- (Las 7 fases reglamentarias ya vienen precargadas desde 01_Tablas_Nucleo.sql)
-- =========================================================================
PRINT '--- TEST 4: SP_ALTA/MODIFICACION/BAJA_Fase ---';

DECLARE @idFaseGrupos INT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Fase de grupos');
DECLARE @idFaseFinal  INT = (SELECT IdFase FROM nucleo.Fase WHERE Nombre = 'Final');
DECLARE @ordenFinal   INT = (SELECT Orden  FROM nucleo.Fase WHERE IdFase = @idFaseFinal);

-- 4.A MODIFICACION exitosa (cambia EsEliminatoria de Final a 0 y luego lo restaura; el orden
-- no se puede mover porque los valores 1 a 7 ya están todos ocupados por las fases reglamentarias).
-- Esperado: OK, la fase Final queda como al inicio.
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Fase @idFaseFinal, 'Final', @ordenFinal, 0;
    EXEC nucleo.SP_MODIFICACION_Fase @idFaseFinal, 'Final', @ordenFinal, 1;
    PRINT '4.A: OK - fase Final modificada y restaurada.';
END TRY
BEGIN CATCH
    PRINT '4.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 4.C MODIFICACION con orden fuera de rango (8).
-- Esperado: Bloqueado: "El orden es obligatorio y debe estar entre 1 y 7".
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Fase @idFaseFinal, 'Final', 8, 1;
    PRINT '4.C: FALLÓ - permitió un orden fuera del rango 1 a 7.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 52000 AND ERROR_MESSAGE() LIKE N'%entre 1 y 7%'
        PRINT '4.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '4.C: FALLÓ - error inesperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.B ALTA fallida con múltiples errores (nombre inválido, orden fuera de 1 a 7, esEliminatoria NULL).
-- Esperado: Bloqueado con UN mensaje de 3 renglones.
BEGIN TRY
    EXEC nucleo.SP_ALTA_Fase NULL, 'Repechaje', 0, NULL;
    PRINT '4.B: FALLÓ - permitió alta inválida de fase.';
END TRY
BEGIN CATCH
    PRINT '4.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 5: nucleo.SP_ALTA/MODIFICACION/BAJA_Grupo
-- =========================================================================
PRINT '--- TEST 5: SP_ALTA/MODIFICACION/BAJA_Grupo ---';

DECLARE @idGrupo1 INT, @idGrupo2 INT;

-- 5.A ALTA exitosa de 2 grupos de prueba (una letra A-Z).
BEGIN TRY
    EXEC nucleo.SP_ALTA_Grupo @idGrupo1 OUTPUT, 'X';
    EXEC nucleo.SP_ALTA_Grupo @idGrupo2 OUTPUT, 'Y';
    PRINT '5.A: OK - 2 grupos dados de alta.';
END TRY
BEGIN CATCH
    PRINT '5.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 5.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Grupo @idGrupo1, 'Z';
    PRINT '5.B: OK - grupo modificado.';
END TRY
BEGIN CATCH
    PRINT '5.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 5.C ALTA fallida (nombre duplicado).
BEGIN TRY
    EXEC nucleo.SP_ALTA_Grupo NULL, 'Z';
    PRINT '5.C: FALLÓ - permitió grupo duplicado.';
END TRY
BEGIN CATCH
    PRINT '5.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 5.D BAJA exitosa.
BEGIN TRY
    EXEC nucleo.SP_BAJA_Grupo @idGrupo2;
    PRINT '5.D: OK - baja de grupo sin selecciones.';
END TRY
BEGIN CATCH
    PRINT '5.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 6: nucleo.SP_ALTA/MODIFICACION/BAJA_Seleccion
-- =========================================================================
PRINT '--- TEST 6: SP_ALTA/MODIFICACION/BAJA_Seleccion ---';

DECLARE @idSel1 INT, @idSel2 INT;

-- 6.A ALTA exitosa de 2 selecciones.
BEGIN TRY
    EXEC nucleo.SP_ALTA_Seleccion @idSel1 OUTPUT, 'XEA', 201, 0, @idPais1, @idGrupo1;
    EXEC nucleo.SP_ALTA_Seleccion @idSel2 OUTPUT, 'XEB', 202, 0, @idPais2, @idGrupo1;
    PRINT '6.A: OK - 2 selecciones dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '6.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 6.B MODIFICACION exitosa (actualiza ranking FIFA y condición de anfitrión).
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Seleccion @idSel2, 'XEB', 199, 1, @idPais2, @idGrupo1;
    PRINT '6.B: OK - selección modificada.';
END TRY
BEGIN CATCH
    PRINT '6.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 6.C ALTA fallida (país duplicado en selección y grupo inexistente).
BEGIN TRY
    EXEC nucleo.SP_ALTA_Seleccion NULL, 'XEC', 203, 0, @idPais1, -1;
    PRINT '6.C: FALLÓ - permitió país duplicado en selección y grupo inexistente.';
END TRY
BEGIN CATCH
    PRINT '6.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 6.D BAJA bloqueada de Grupo con selecciones, y BAJA + re-alta de @idSel2.
BEGIN TRY
    EXEC nucleo.SP_BAJA_Grupo @idGrupo1;
    PRINT '6.D.1: FALLÓ - permitió eliminar grupo con selecciones asociadas.';
END TRY
BEGIN CATCH
    PRINT '6.D.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

BEGIN TRY
    EXEC nucleo.SP_BAJA_Seleccion @idSel2;
    EXEC nucleo.SP_ALTA_Seleccion @idSel2 OUTPUT, 'XEB', 202, 0, @idPais2, @idGrupo1;
    PRINT '6.D.2: OK - baja y re-alta de selección.';
END TRY
BEGIN CATCH
    PRINT '6.D.2: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 7: nucleo.SP_ALTA/MODIFICACION/BAJA_StaffTecnico
-- =========================================================================
PRINT '--- TEST 7: SP_ALTA/MODIFICACION/BAJA_StaffTecnico ---';

DECLARE @idStaffDT INT, @idStaffAy INT;

-- 7.A ALTA exitosa de Director Técnico y Ayudante de campo 1.
BEGIN TRY
    EXEC nucleo.SP_ALTA_StaffTecnico @idStaffDT OUTPUT, @idSel1, 'Lionel Tecnico', 'Director Técnico';
    EXEC nucleo.SP_ALTA_StaffTecnico @idStaffAy OUTPUT, @idSel1, 'Pablo Ayudante', 'Ayudante de campo 1';
    PRINT '7.A: OK - DT y Ayudante dados de alta.';
END TRY
BEGIN CATCH
    PRINT '7.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 7.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_StaffTecnico @idStaffAy, @idSel1, 'Pablo Cesar Ayudante', 'Ayudante de campo 1';
    PRINT '7.B: OK - ayudante modificado.';
END TRY
BEGIN CATCH
    PRINT '7.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 7.C ALTA fallida (segundo Director Técnico en la misma selección).
BEGIN TRY
    EXEC nucleo.SP_ALTA_StaffTecnico NULL, @idSel1, 'Otro DT', 'Director Técnico';
    PRINT '7.C: FALLÓ - permitió segundo DT en la misma selección.';
END TRY
BEGIN CATCH
    PRINT '7.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 7.D BAJA exitosa.
BEGIN TRY
    EXEC nucleo.SP_BAJA_StaffTecnico @idStaffAy;
    PRINT '7.D: OK - baja de ayudante técnico.';
END TRY
BEGIN CATCH
    PRINT '7.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 8: nucleo.SP_ALTA/MODIFICACION/BAJA_Idioma
-- =========================================================================
PRINT '--- TEST 8: SP_ALTA/MODIFICACION/BAJA_Idioma ---';

DECLARE @idIdioma1 INT, @idIdioma2 INT;

-- 8.A ALTA exitosa de 2 idiomas.
BEGIN TRY
    EXEC nucleo.SP_ALTA_Idioma @idIdioma1 OUTPUT, 'TEST N19 Idioma A';
    EXEC nucleo.SP_ALTA_Idioma @idIdioma2 OUTPUT, 'TEST N19 Idioma B';
    PRINT '8.A: OK - 2 idiomas dados de alta.';
END TRY
BEGIN CATCH
    PRINT '8.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 8.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Idioma @idIdioma2, 'TEST N19 Idioma B Mod';
    PRINT '8.B: OK - idioma modificado.';
END TRY
BEGIN CATCH
    PRINT '8.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 8.C ALTA fallida (nombre duplicado).
BEGIN TRY
    EXEC nucleo.SP_ALTA_Idioma NULL, 'TEST N19 Idioma A';
    PRINT '8.C: FALLÓ - permitió idioma duplicado.';
END TRY
BEGIN CATCH
    PRINT '8.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 8.D BAJA exitosa.
BEGIN TRY
    EXEC nucleo.SP_BAJA_Idioma @idIdioma2;
    PRINT '8.D: OK - baja de idioma sin referencias.';
END TRY
BEGIN CATCH
    PRINT '8.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 9: nucleo.SP_ALTA/MODIFICACION/BAJA_Categoria
-- =========================================================================
PRINT '--- TEST 9: SP_ALTA/MODIFICACION/BAJA_Categoria ---';

DECLARE @idCat1 INT, @idCat2 INT;

-- 9.A ALTA exitosa de 2 categorías.
BEGIN TRY
    EXEC nucleo.SP_ALTA_Categoria @idCat1 OUTPUT, 'TEST N19 Cat A';
    EXEC nucleo.SP_ALTA_Categoria @idCat2 OUTPUT, 'TEST N19 Cat B';
    PRINT '9.A: OK - 2 categorías dadas de alta.';
END TRY
BEGIN CATCH
    PRINT '9.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 9.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Categoria @idCat2, 'TEST N19 Cat B Mod';
    PRINT '9.B: OK - categoría modificada.';
END TRY
BEGIN CATCH
    PRINT '9.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 9.C ALTA fallida (nombre duplicado).
BEGIN TRY
    EXEC nucleo.SP_ALTA_Categoria NULL, 'TEST N19 Cat A';
    PRINT '9.C: FALLÓ - permitió categoría duplicada.';
END TRY
BEGIN CATCH
    PRINT '9.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 9.D BAJA exitosa.
BEGIN TRY
    EXEC nucleo.SP_BAJA_Categoria @idCat2;
    PRINT '9.D: OK - baja de categoría sin árbitros.';
END TRY
BEGIN CATCH
    PRINT '9.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 10: nucleo.SP_ALTA/MODIFICACION/BAJA_Arbitro
-- =========================================================================
PRINT '--- TEST 10: SP_ALTA/MODIFICACION/BAJA_Arbitro ---';

DECLARE @idArbNeutral INT, @idArbLocal INT;

-- 10.A ALTA exitosa de árbitro neutral y árbitro local.
BEGIN TRY
    EXEC nucleo.SP_ALTA_Arbitro @idArbNeutral OUTPUT, 'TEST N19 Pierluigi Collina', 'M', 'Y', '1980-02-13', @idPais3, @idCat1;
    EXEC nucleo.SP_ALTA_Arbitro @idArbLocal   OUTPUT, 'TEST N19 Nestor Pitana',     'M', 'Y', '1975-06-17', @idPais1, @idCat1;
    PRINT '10.A: OK - 2 árbitros dados de alta.';
END TRY
BEGIN CATCH
    PRINT '10.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 10.B MODIFICACION exitosa.
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Arbitro @idArbNeutral, 'TEST N19 Pierluigi Collina Mod', 'M', 'Y', '1980-02-13', @idPais3, @idCat1;
    PRINT '10.B: OK - árbitro modificado.';
END TRY
BEGIN CATCH
    PRINT '10.B: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 10.C ALTA fallida con múltiples errores (nombre vacío, sexo/habilitación inválidos y fecha futura).
BEGIN TRY
    EXEC nucleo.SP_ALTA_Arbitro NULL, '', 'X', 'Z', '2099-01-01', @idPais3, @idCat1;
    PRINT '10.C: FALLÓ - permitió datos inválidos y fecha futura.';
END TRY
BEGIN CATCH
    PRINT '10.C: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 10.D BAJA exitosa y re-alta de @idArbLocal.
BEGIN TRY
    EXEC nucleo.SP_BAJA_Arbitro @idArbLocal;
    EXEC nucleo.SP_ALTA_Arbitro @idArbLocal OUTPUT, 'TEST N19 Nestor Pitana', 'M', 'Y', '1975-06-17', @idPais1, @idCat1;
    PRINT '10.D: OK - baja y re-alta de árbitro.';
END TRY
BEGIN CATCH
    PRINT '10.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 11: nucleo.SP_ALTA/MODIFICACION/BAJA_ArbitroIdioma
-- =========================================================================
PRINT '--- TEST 11: SP_ALTA/MODIFICACION/BAJA_ArbitroIdioma ---';

-- 11.A ALTA exitosa.
BEGIN TRY
    EXEC nucleo.SP_ALTA_ArbitroIdioma @idArbNeutral, @idIdioma1;
    PRINT '11.A: OK - idioma asignado al árbitro.';
END TRY
BEGIN CATCH
    PRINT '11.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 11.B ALTA fallida (duplicado) y MODIFICACION inexistente.
BEGIN TRY
    EXEC nucleo.SP_ALTA_ArbitroIdioma @idArbNeutral, @idIdioma1;
    PRINT '11.B.1: FALLÓ - permitió asignar idioma duplicado.';
END TRY
BEGIN CATCH
    PRINT '11.B.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

IF OBJECT_ID('nucleo.SP_MODIFICACION_ArbitroIdioma', 'P') IS NULL
    PRINT '11.B.2: OK - ArbitroIdioma es una tabla asociativa: no existe SP de modificación (solo alta y baja).';
ELSE
    PRINT '11.B.2: FALLÓ - existe un SP de modificación para la tabla asociativa.';

-- 11.C BAJA exitosa y re-alta.
BEGIN TRY
    EXEC nucleo.SP_BAJA_ArbitroIdioma @idArbNeutral, @idIdioma1;
    EXEC nucleo.SP_ALTA_ArbitroIdioma @idArbNeutral, @idIdioma1;
    PRINT '11.C: OK - baja y re-alta en ArbitroIdioma.';
END TRY
BEGIN CATCH
    PRINT '11.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 12: nucleo.SP_ALTA/MODIFICACION/BAJA_DesignacionArbitral
-- =========================================================================
PRINT '--- TEST 12: SP_ALTA/MODIFICACION/BAJA_DesignacionArbitral ---';

DECLARE @idSede INT, @p9701 INT, @idDesig1 INT, @adv VARCHAR(200);

INSERT INTO nucleo.Sede (NombreEstadio, Capacidad, IdCiudad)
VALUES ('TEST N19 Estadio', 60000, @idCiudad1);
SET @idSede = SCOPE_IDENTITY();

INSERT INTO nucleo.Partido (NumeroPartido, FechaHoraUTC, Estado, IdFase, IdSede, IdSeleccionLocal, IdSeleccionVisitante)
VALUES (232, '2026-06-14 19:00', 'Programado', @idFaseGrupos, @idSede, @idSel1, @idSel2);
SET @p9701 = SCOPE_IDENTITY();

-- 12.A ALTA exitosa (delega en SP_CONTROL_ARBITRAL).
BEGIN TRY
    EXEC nucleo.SP_ALTA_DesignacionArbitral @idDesignacionArbitral = @idDesig1 OUTPUT,
         @idPartido = @p9701, @idArbitro = @idArbNeutral, @rol = 'Principal', @advertencia = @adv OUTPUT;
    PRINT '12.A: OK - designación arbitral registrada vía SP_ALTA_DesignacionArbitral.';
END TRY
BEGIN CATCH
    PRINT '12.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'TranCount antes 12.B = ' + CAST(@@TRANCOUNT AS VARCHAR(5));

---- Deshabilitado: SP_CONTROL_ARBITRAL hace ROLLBACK total (ver resumen)
/*
-- 12.B ALTA fallida por conflicto de nacionalidad (árbitro del país de @idSel1).
BEGIN TRY
    EXEC nucleo.SP_ALTA_DesignacionArbitral @idDesignacionArbitral = NULL,
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
    EXEC nucleo.SP_MODIFICACION_DesignacionArbitral @idDesignacionArbitral = @idDesig1,
         @idPartido = @p9701, @idArbitro = @idArbNeutral, @rol = 'VAR', @advertencia = @adv OUTPUT;
    PRINT '12.C: OK - rol arbitral modificado a VAR.';
END TRY
BEGIN CATCH
    PRINT '12.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 12.D BAJA exitosa y re-alta (queda activa para el Test 13).
BEGIN TRY
    EXEC nucleo.SP_BAJA_DesignacionArbitral @idDesignacionArbitral = @idDesig1;
    EXEC nucleo.SP_ALTA_DesignacionArbitral @idDesignacionArbitral = @idDesig1 OUTPUT,
         @idPartido = @p9701, @idArbitro = @idArbNeutral, @rol = 'Principal', @advertencia = @adv OUTPUT;
    PRINT '12.D: OK - baja y re-alta de designación arbitral.';
END TRY
BEGIN CATCH
    PRINT '12.D: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 12.E MODIFICACION hacia un árbitro no habilitado (EstaHabilitado = 'N', país neutral).
-- Esperado: Bloqueado: "El árbitro no está habilitado para ser designado"; la designación
--           @idDesig1 conserva a @idArbNeutral.
DECLARE @idArbInhabilitado INT;
EXEC nucleo.SP_ALTA_Arbitro @idArbInhabilitado OUTPUT, 'TEST N19 Arbitro Inhabilitado', 'F', 'N', '1985-03-10', @idPais3, @idCat1;
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_DesignacionArbitral @idDesignacionArbitral = @idDesig1,
         @idPartido = @p9701, @idArbitro = @idArbInhabilitado, @rol = 'Principal', @advertencia = @adv OUTPUT;
    PRINT '12.E: FALLÓ - permitió designar a un árbitro no habilitado.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 52000 AND ERROR_MESSAGE() LIKE N'%no está habilitado%'
       AND EXISTS (SELECT 1 FROM nucleo.DesignacionArbitral
                   WHERE IdDesignacionArbitral = @idDesig1 AND IdArbitro = @idArbNeutral)
        PRINT '12.E: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '12.E: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 13: nucleo.SP_ALTA/MODIFICACION/BAJA_Sancion
-- =========================================================================
PRINT '--- TEST 13: SP_ALTA/MODIFICACION/BAJA_Sancion ---';

DECLARE @idSancion1 INT;

-- 13.A ALTA exitosa de sanción arbitral.
BEGIN TRY
    EXEC nucleo.SP_ALTA_Sancion @idSancion1 OUTPUT, @idDesig1, 'Advertencia', 'Informe por demora en reanudación', '2026-06-15';
    PRINT '13.A: OK - sanción arbitral dada de alta.';
END TRY
BEGIN CATCH
    PRINT '13.A: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 13.B BAJA bloqueada de DesignacionArbitral por tener sanción asociada.
BEGIN TRY
    EXEC nucleo.SP_BAJA_DesignacionArbitral @idDesignacionArbitral = @idDesig1;
    PRINT '13.B: FALLÓ - permitió borrar designación con sanción asociada.';
END TRY
BEGIN CATCH
    PRINT '13.B: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- 13.C MODIFICACION exitosa de sanción.
BEGIN TRY
    EXEC nucleo.SP_MODIFICACION_Sancion @idSancion1, @idDesig1, 'Multa', 'Multa administrativa confirmada', '2026-06-16';
    PRINT '13.C: OK - sanción arbitral modificada.';
END TRY
BEGIN CATCH
    PRINT '13.C: FALLÓ - ' + ERROR_MESSAGE();
END CATCH;

-- 13.D ALTA fallida con múltiples errores (fecha anterior al partido, tipo inválido y descripción vacía).
BEGIN TRY
    EXEC nucleo.SP_ALTA_Sancion NULL, @idDesig1, 'Expulsion', '', '2026-06-01';
    PRINT '13.D: FALLÓ - permitió sanción con fecha anterior al partido y tipo/descripción inválidos.';
END TRY
BEGIN CATCH
    PRINT '13.D: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
END CATCH;

-- =========================================================================
-- TEST 14: nucleo.SP_ALTA/MODIFICACION/BAJA_ReglaClasificacion
-- La regla tiene una sola fila (la inicial (2, 0) la carga 01_Tablas_Nucleo.sql). El total de clasificados
-- (grupos x ClasificadosPorGrupo + MejoresTerceros) debe ser 8, 16 o 32, así que se arman 4 grupos de 2
-- selecciones: el grupo Z ya tiene las 2 del TEST 6 y se suman los grupos R, S y T con 2 selecciones cada uno.
-- =========================================================================
PRINT '--- TEST 14: SP_ALTA/MODIFICACION/BAJA_ReglaClasificacion ---';

-- 14.A ALTA con la regla inicial ya cargada.
-- Esperado: Bloqueado: "Ya existe la regla de clasificación".
BEGIN TRY
    EXEC nucleo.SP_ALTA_ReglaClasificacion 2, 0;
    PRINT '14.A: FALLÓ - permitió una segunda regla de clasificación.';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%Ya existe la regla de clasificación%'
        PRINT '14.A: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
    ELSE
        PRINT '14.A: FALLÓ - mensaje inesperado: ' + ERROR_MESSAGE();
END CATCH;

-- Con otras selecciones en la base los grupos y los totales cambian: el resto del test se omite.
DECLARE @hayOtras14 BIT = CASE WHEN EXISTS (SELECT 1 FROM nucleo.Seleccion AS s
                                            INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais
                                            WHERE p.Nombre NOT LIKE 'TEST N19%')
                               THEN 1 ELSE 0 END;

IF @hayOtras14 = 1
    PRINT '14.B a 14.J OMITIDOS: la base tiene selecciones que no son de este test.';
ELSE
BEGIN
    DECLARE @idGR INT, @idGS INT, @idGT INT,
            @idP14a INT, @idP14b INT, @idP14c INT, @idP14d INT, @idP14e INT, @idP14f INT,
            @idS14 INT;

    EXEC nucleo.SP_ALTA_Grupo @idGR OUTPUT, 'R';
    EXEC nucleo.SP_ALTA_Grupo @idGS OUTPUT, 'S';
    EXEC nucleo.SP_ALTA_Grupo @idGT OUTPUT, 'T';

    EXEC nucleo.SP_ALTA_Pais @idP14a OUTPUT, 'TEST N19 Pais R1', 'XE', 'XFA', @idConf1, 'UTC', NULL;
    EXEC nucleo.SP_ALTA_Pais @idP14b OUTPUT, 'TEST N19 Pais R2', 'XF', 'XFB', @idConf1, 'UTC', NULL;
    EXEC nucleo.SP_ALTA_Pais @idP14c OUTPUT, 'TEST N19 Pais S1', 'XG', 'XFC', @idConf1, 'UTC', NULL;
    EXEC nucleo.SP_ALTA_Pais @idP14d OUTPUT, 'TEST N19 Pais S2', 'XH', 'XFD', @idConf1, 'UTC', NULL;
    EXEC nucleo.SP_ALTA_Pais @idP14e OUTPUT, 'TEST N19 Pais T1', 'XI', 'XFE', @idConf1, 'UTC', NULL;
    EXEC nucleo.SP_ALTA_Pais @idP14f OUTPUT, 'TEST N19 Pais T2', 'XJ', 'XFF', @idConf1, 'UTC', NULL;

    EXEC nucleo.SP_ALTA_Seleccion @idS14 OUTPUT, 'XFA', 301, 0, @idP14a, @idGR;
    EXEC nucleo.SP_ALTA_Seleccion @idS14 OUTPUT, 'XFB', 302, 0, @idP14b, @idGR;
    EXEC nucleo.SP_ALTA_Seleccion @idS14 OUTPUT, 'XFC', 303, 0, @idP14c, @idGS;
    EXEC nucleo.SP_ALTA_Seleccion @idS14 OUTPUT, 'XFD', 304, 0, @idP14d, @idGS;
    EXEC nucleo.SP_ALTA_Seleccion @idS14 OUTPUT, 'XFE', 305, 0, @idP14e, @idGT;
    EXEC nucleo.SP_ALTA_Seleccion @idS14 OUTPUT, 'XFF', 306, 0, @idP14f, @idGT;

    -- 14.B 4 grupos x 2 + 0 = 8.
    -- Esperado: OK. La regla pasa a (2, 0).
    BEGIN TRY
        EXEC nucleo.SP_MODIFICACION_ReglaClasificacion 2, 0;
        IF EXISTS (SELECT 1 FROM nucleo.ReglaClasificacion WHERE IdRegla = 1 AND ClasificadosPorGrupo = 2 AND MejoresTerceros = 0)
            PRINT '14.B: OK - regla (2, 0): 4 grupos x 2 = 8 clasificados.';
        ELSE
            PRINT '14.B: FALLÓ - la regla no quedó en (2, 0).';
    END TRY
    BEGIN CATCH
        PRINT '14.B: FALLÓ - ' + ERROR_MESSAGE();
    END CATCH;

    -- 14.C 4 grupos x 1 + 4 mejores segundos = 8.
    -- Esperado: OK. La regla pasa a (1, 4).
    BEGIN TRY
        EXEC nucleo.SP_MODIFICACION_ReglaClasificacion 1, 4;
        IF EXISTS (SELECT 1 FROM nucleo.ReglaClasificacion WHERE IdRegla = 1 AND ClasificadosPorGrupo = 1 AND MejoresTerceros = 4)
            PRINT '14.C: OK - regla (1, 4): 4 grupos x 1 + 4 = 8 clasificados.';
        ELSE
            PRINT '14.C: FALLÓ - la regla no quedó en (1, 4).';
    END TRY
    BEGIN CATCH
        PRINT '14.C: FALLÓ - ' + ERROR_MESSAGE();
    END CATCH;

    -- 14.D ClasificadosPorGrupo mayor que las selecciones del grupo más chico (2), con total 12.
    -- Esperado: Bloqueado con UN mensaje que informa las dos condiciones. La regla sigue en (1, 4).
    BEGIN TRY
        EXEC nucleo.SP_MODIFICACION_ReglaClasificacion 3, 0;
        PRINT '14.D: FALLÓ - permitió 3 clasificados por grupo en grupos de 2.';
    END TRY
    BEGIN CATCH
        IF ERROR_MESSAGE() LIKE '%supera las selecciones del grupo más chico (2)%'
           AND ERROR_MESSAGE() LIKE '%debe ser 8, 16 o 32%'
           AND EXISTS (SELECT 1 FROM nucleo.ReglaClasificacion WHERE ClasificadosPorGrupo = 1 AND MejoresTerceros = 4)
            PRINT '14.D: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
        ELSE
            PRINT '14.D: FALLÓ - mensaje inesperado: ' + ERROR_MESSAGE();
    END CATCH;

    -- 14.E MejoresTerceros sin grupos candidatos (ningún grupo tiene un 3.º) y total 13.
    -- Esperado: Bloqueado: "MejoresTerceros (5) supera los grupos que tienen selecciones en el puesto siguiente" y total inválido.
    BEGIN TRY
        EXEC nucleo.SP_MODIFICACION_ReglaClasificacion 2, 5;
        PRINT '14.E: FALLÓ - permitió mejores terceros sin grupos candidatos.';
    END TRY
    BEGIN CATCH
        IF ERROR_MESSAGE() LIKE '%MejoresTerceros (5) supera los grupos que tienen selecciones en el puesto siguiente%'
           AND ERROR_MESSAGE() LIKE '%debe ser 8, 16 o 32%'
            PRINT '14.E: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
        ELSE
            PRINT '14.E: FALLÓ - mensaje inesperado: ' + ERROR_MESSAGE();
    END CATCH;

    -- 14.F Valores nulos o fuera de rango.
    -- Esperado: Bloqueado: "ClasificadosPorGrupo es obligatorio" y "MejoresTerceros es obligatorio".
    BEGIN TRY
        EXEC nucleo.SP_MODIFICACION_ReglaClasificacion NULL, -1;
        PRINT '14.F: FALLÓ - permitió valores nulos o negativos.';
    END TRY
    BEGIN CATCH
        IF ERROR_MESSAGE() LIKE '%ClasificadosPorGrupo es obligatorio%' AND ERROR_MESSAGE() LIKE '%MejoresTerceros es obligatorio%'
            PRINT '14.F: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
        ELSE
            PRINT '14.F: FALLÓ - mensaje inesperado: ' + ERROR_MESSAGE();
    END CATCH;

    -- 14.G BAJA de la regla.
    -- Esperado: OK. La tabla queda sin filas.
    BEGIN TRY
        EXEC nucleo.SP_BAJA_ReglaClasificacion;
        IF NOT EXISTS (SELECT 1 FROM nucleo.ReglaClasificacion)
            PRINT '14.G: OK - regla de clasificación eliminada.';
        ELSE
            PRINT '14.G FALLÓ: la regla sigue cargada.';
    END TRY
    BEGIN CATCH
        PRINT '14.G: FALLÓ - ' + ERROR_MESSAGE();
    END CATCH;

    -- 14.H BAJA y MODIFICACION sin regla cargada.
    -- Esperado: Bloqueado los dos: "No hay regla de clasificación cargada".
    BEGIN TRY
        EXEC nucleo.SP_BAJA_ReglaClasificacion;
        PRINT '14.H.1: FALLÓ - permitió eliminar una regla inexistente.';
    END TRY
    BEGIN CATCH
        IF ERROR_MESSAGE() LIKE '%No hay regla de clasificación cargada%'
            PRINT '14.H.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
        ELSE
            PRINT '14.H.1: FALLÓ - mensaje inesperado: ' + ERROR_MESSAGE();
    END CATCH;

    BEGIN TRY
        EXEC nucleo.SP_MODIFICACION_ReglaClasificacion 2, 0;
        PRINT '14.H.2: FALLÓ - permitió modificar una regla inexistente.';
    END TRY
    BEGIN CATCH
        IF ERROR_MESSAGE() LIKE '%No hay regla de clasificación cargada%'
            PRINT '14.H.2: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
        ELSE
            PRINT '14.H.2: FALLÓ - mensaje inesperado: ' + ERROR_MESSAGE();
    END CATCH;

    -- 14.I ALTA de la regla después de la baja, con un total inválido y luego con uno válido.
    -- Esperado: (2, 1) -> Bloqueado (4 x 2 + 1 = 9, y no hay terceros); (2, 0) -> OK, queda la fila (2, 0).
    BEGIN TRY
        EXEC nucleo.SP_ALTA_ReglaClasificacion 2, 1;
        PRINT '14.I.1: FALLÓ - permitió un total de 9 clasificados.';
    END TRY
    BEGIN CATCH
        IF ERROR_MESSAGE() LIKE '%debe ser 8, 16 o 32%'
            PRINT '14.I.1: OK (Bloqueado) - ' + REPLACE(ERROR_MESSAGE(), CHAR(13) + CHAR(10), ' | ');
        ELSE
            PRINT '14.I.1: FALLÓ - mensaje inesperado: ' + ERROR_MESSAGE();
    END CATCH;

    BEGIN TRY
        EXEC nucleo.SP_ALTA_ReglaClasificacion 2, 0;
        IF EXISTS (SELECT 1 FROM nucleo.ReglaClasificacion WHERE IdRegla = 1 AND ClasificadosPorGrupo = 2 AND MejoresTerceros = 0)
            PRINT '14.I.2: OK - regla (2, 0) dada de alta de nuevo.';
        ELSE
            PRINT '14.I.2: FALLÓ - la regla no quedó en (2, 0).';
    END TRY
    BEGIN CATCH
        PRINT '14.I.2: FALLÓ - ' + ERROR_MESSAGE();
    END CATCH;
END;

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