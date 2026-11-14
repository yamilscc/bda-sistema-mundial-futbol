/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-14
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Agregar con ALTER TABLE las claves foráneas que cruzan módulos y que quedaron
          comentadas en los scripts 02 y 03 (jugadores/eventos hacia el núcleo).
          Se ejecuta después de crear todas las tablas.
*/

USE MundialFutbol;
GO

-- jugadores.Convocatoria -> nucleo.Seleccion
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Convocatoria_Seleccion')
    ALTER TABLE jugadores.Convocatoria
        ADD CONSTRAINT FK_Convocatoria_Seleccion
        FOREIGN KEY (IdSeleccion) REFERENCES nucleo.Seleccion (IdSeleccion);
GO

-- jugadores.Formacion -> nucleo.Partido
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Formacion_Partido')
    ALTER TABLE jugadores.Formacion
        ADD CONSTRAINT FK_Formacion_Partido
        FOREIGN KEY (IdPartido) REFERENCES nucleo.Partido (IdPartido);
GO

-- jugadores.Sustitucion -> nucleo.Partido
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Sustitucion_Partido')
    ALTER TABLE jugadores.Sustitucion
        ADD CONSTRAINT FK_Sustitucion_Partido
        FOREIGN KEY (IdPartido) REFERENCES nucleo.Partido (IdPartido);
GO

-- eventos.Gol -> nucleo.Partido
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Gol_Partido')
    ALTER TABLE eventos.Gol
        ADD CONSTRAINT FK_Gol_Partido
        FOREIGN KEY (IdPartido) REFERENCES nucleo.Partido (IdPartido);
GO

-- eventos.Amonestacion -> nucleo.StaffTecnico
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Amonestacion_Staff')
    ALTER TABLE eventos.Amonestacion
        ADD CONSTRAINT FK_Amonestacion_Staff
        FOREIGN KEY (IdStaffTecnico) REFERENCES nucleo.StaffTecnico (IdStaffTecnico);
GO

-- eventos.Amonestacion -> nucleo.Partido
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Amonestacion_Partido')
    ALTER TABLE eventos.Amonestacion
        ADD CONSTRAINT FK_Amonestacion_Partido
        FOREIGN KEY (IdPartido) REFERENCES nucleo.Partido (IdPartido);
GO
