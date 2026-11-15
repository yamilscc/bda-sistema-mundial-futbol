/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-15
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Agregar con ALTER TABLE las claves foráneas que cruzan módulos y que quedaron
          pendientes en los scripts 02, 03 y 04 (jugadores, eventos y publicidad hacia el núcleo).
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

-- publicidad.Pieza -> nucleo.Idioma
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Pieza_Idioma')
    ALTER TABLE publicidad.Pieza
        ADD CONSTRAINT FK_Pieza_Idioma
        FOREIGN KEY (IdIdioma) REFERENCES nucleo.Idioma (IdIdioma);
GO

-- publicidad.OrientacionPais -> nucleo.Pais
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_OrientacionPais_Pais')
    ALTER TABLE publicidad.OrientacionPais
        ADD CONSTRAINT FK_OrientacionPais_Pais
        FOREIGN KEY (IdPais) REFERENCES nucleo.Pais (IdPais);
GO

-- publicidad.EspacioPublicitario -> nucleo.Partido
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_EspacioPublicitario_Partido')
    ALTER TABLE publicidad.EspacioPublicitario
        ADD CONSTRAINT FK_EspacioPublicitario_Partido
        FOREIGN KEY (IdPartido) REFERENCES nucleo.Partido (IdPartido);
GO

-- publicidad.Anunciante -> nucleo.Pais (país de origen del anunciante)
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Anunciante_Pais')
    ALTER TABLE publicidad.Anunciante
        ADD CONSTRAINT FK_Anunciante_Pais
        FOREIGN KEY (IdPais) REFERENCES nucleo.Pais (IdPais);
GO
