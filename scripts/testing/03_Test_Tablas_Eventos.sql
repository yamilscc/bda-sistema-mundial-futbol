/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Casella, Mateo Ezequiel
Integrantes:
- Casella, Mateo Ezequiel
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Pruebas de casos límite y restricciones DDL sobre las tablas del módulo de eventos.
*/

-- =========================================================================
-- PREPARACIÓN DE DATOS MÍNIMOS PARA PRUEBAS DE INTEGRIDAD
-- =========================================================================
DELETE FROM eventos.Amonestacion;
DELETE FROM eventos.Gol;
DELETE FROM eventos.Tarjeta;
DELETE FROM eventos.Periodo;
DELETE FROM eventos.TipoGol;
DELETE FROM eventos.ReglaSuspension;
DELETE FROM jugadores.Jugador WHERE Documento IN ('TEST_JUG_1', 'TEST_JUG_2');

INSERT INTO jugadores.Jugador (Nombre, Apellido, Documento, Sexo, Posicion, IdClub)
VALUES ('Lionel', 'Messi', 'TEST_JUG_1', 'M', 'Delantero', NULL),
       ('Angel', 'Di Maria', 'TEST_JUG_2', 'M', 'Delantero', NULL);

DECLARE @idJug1 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_JUG_1');
DECLARE @idJug2 INT = (SELECT IdJugador FROM jugadores.Jugador WHERE Documento = 'TEST_JUG_2');

INSERT INTO eventos.TipoGol (Descripcion) VALUES ('Jugada'), ('En contra');
INSERT INTO eventos.Periodo (Descripcion) VALUES ('Primer Tiempo'), ('Alargue ST');
INSERT INTO eventos.Tarjeta (Tipo) VALUES ('Amarilla'), ('Roja por doble amarilla'), ('Roja directa');

DECLARE @idTipoJugada INT = (SELECT IdTipoGol FROM eventos.TipoGol WHERE Descripcion = 'Jugada');
DECLARE @idPeriodoPT  INT = (SELECT IdPeriodo FROM eventos.Periodo WHERE Descripcion = 'Primer Tiempo');
DECLARE @idTarjetaAm  INT = (SELECT IdTarjeta FROM eventos.Tarjeta WHERE Tipo = 'Amarilla');

-- =========================================================================
-- TEST 1: ReglaSuspension - Consistencia entre Criterio y CantidadAmarillas
-- =========================================================================

-- 1.A Caso exitoso: Acumulación con 2 amarillas y Roja Directa con amarillas en NULL.
-- Resultado esperado: Inserción exitosa de 2 filas.
INSERT INTO eventos.ReglaSuspension (Criterio, CantidadAmarillas, PartidosSuspension)
VALUES ('Acumulacion Amarillas', 2, 1),
       ('Roja Directa', NULL, 2);

-- 1.B Caso límite fallido: Acumulación con 1 sola amarilla (viola CK_ReglaSuspension_Amarillas).
-- Resultado esperado: Error por restricción CHECK CK_ReglaSuspension_Amarillas.
BEGIN TRY
    INSERT INTO eventos.ReglaSuspension (Criterio, CantidadAmarillas, PartidosSuspension)
    VALUES ('Acumulacion Amarillas', 1, 1);
    PRINT 'TEST 1.B FALLÓ: Permitió acumulación con 1 amarilla.';
END TRY
BEGIN CATCH
    PRINT 'TEST 1.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 1.C Caso límite fallido: Roja Directa informando CantidadAmarillas (viola CK_ReglaSuspension_Amarillas).
-- Resultado esperado: Error por restricción CHECK CK_ReglaSuspension_Amarillas.
BEGIN TRY
    INSERT INTO eventos.ReglaSuspension (Criterio, CantidadAmarillas, PartidosSuspension)
    VALUES ('Doble Amarilla', 2, 1);
    PRINT 'TEST 1.C FALLÓ: Permitió CantidadAmarillas en criterio distinto a acumulación.';
END TRY
BEGIN CATCH
    PRINT 'TEST 1.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 2: Gol - Fronteras de Minuto (0, 1, 135, 136) y Auto-asistencia
-- =========================================================================

-- 2.A Caso límite exitoso: Minutos en los bordes exactos permitidos (1 y 135) con y sin asistencia.
-- Resultado esperado: Inserción exitosa de 2 goles.
INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
VALUES (1, @idJug1, @idJug2, @idTipoJugada, @idPeriodoPT, 1),
       (1, @idJug1, NULL,    @idTipoJugada, @idPeriodoPT, 135);

-- 2.B Caso límite fallido: Minuto = 0 (fuera de borde inferior).
-- Resultado esperado: Error por restricción CHECK CK_Gol_Minuto.
BEGIN TRY
    INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
    VALUES (1, @idJug1, NULL, @idTipoJugada, @idPeriodoPT, 0);
    PRINT 'TEST 2.B FALLÓ: Permitió gol en minuto 0.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.C Caso límite fallido: Minuto = 136 (fuera de borde superior).
-- Resultado esperado: Error por restricción CHECK CK_Gol_Minuto.
BEGIN TRY
    INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
    VALUES (1, @idJug1, NULL, @idTipoJugada, @idPeriodoPT, 136);
    PRINT 'TEST 2.C FALLÓ: Permitió gol en minuto 136.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 2.D Caso límite fallido: Jugador se asiste a sí mismo (IdJugadorAutor = IdJugadorAsistencia).
-- Resultado esperado: Error por restricción CHECK CK_Gol_AutorDistintoAsistente.
BEGIN TRY
    INSERT INTO eventos.Gol (IdPartido, IdJugadorAutor, IdJugadorAsistencia, IdTipoGol, IdPeriodo, Minuto)
    VALUES (1, @idJug1, @idJug1, @idTipoJugada, @idPeriodoPT, 45);
    PRINT 'TEST 2.D FALLÓ: Permitió que el autor sea su propio asistente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 2.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- =========================================================================
-- TEST 3: Amonestacion - Arco Exclusivo (Jugador XOR Staff Técnico)
-- =========================================================================

-- 3.A Caso exitoso: Amonestación solo a jugador y otra solo a staff técnico.
-- Resultado esperado: Inserción exitosa de 2 filas.
INSERT INTO eventos.Amonestacion (IdPartido, IdTarjeta, IdJugador, IdStaffTecnico, Minuto, Motivo, PartidosSuspension)
VALUES (1, @idTarjetaAm, @idJug1, NULL, 30, 'Falta táctica', 0),
       (1, @idTarjetaAm, NULL,    10,   65, 'Protestar fallos', 1);

-- 3.B Caso límite fallido: Amonestación asignada a Jugador y Staff al mismo tiempo.
-- Resultado esperado: Error por restricción CHECK CK_Amonestacion_SancionadoExclusivo.
BEGIN TRY
    INSERT INTO eventos.Amonestacion (IdPartido, IdTarjeta, IdJugador, IdStaffTecnico, Minuto, Motivo)
    VALUES (1, @idTarjetaAm, @idJug1, 10, 50, 'Ambos sancionados en misma fila');
    PRINT 'TEST 3.B FALLÓ: Permitió amonestar a jugador y staff simultáneamente.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.B OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.C Caso límite fallido: Amonestación sin Jugador ni Staff (ambos NULL).
-- Resultado esperado: Error por restricción CHECK CK_Amonestacion_SancionadoExclusivo.
BEGIN TRY
    INSERT INTO eventos.Amonestacion (IdPartido, IdTarjeta, IdJugador, IdStaffTecnico, Minuto, Motivo)
    VALUES (1, @idTarjetaAm, NULL, NULL, 50, 'Sin destinatario');
    PRINT 'TEST 3.C FALLÓ: Permitió amonestación huérfana de sancionado.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.C OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;

-- 3.D Caso límite fallido: PartidosSuspension negativo (-1).
-- Resultado esperado: Error por restricción CHECK CK_Amonestacion_Partidos.
BEGIN TRY
    INSERT INTO eventos.Amonestacion (IdPartido, IdTarjeta, IdJugador, IdStaffTecnico, Minuto, Motivo, PartidosSuspension)
    VALUES (1, @idTarjetaAm, @idJug1, NULL, 80, 'Conducta violenta', -1);
    PRINT 'TEST 3.D FALLÓ: Permitió cantidad negativa de partidos de suspensión.';
END TRY
BEGIN CATCH
    PRINT 'TEST 3.D OK (Bloqueado): ' + ERROR_MESSAGE();
END CATCH;
GO