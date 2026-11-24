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
	- Generar las tablas núcleo del sistema: 
		  Confederacion, Pais, Ciudad, Sede, Grupo, Fase, Partido, Seleccion, 
		  StaffTecnico, Idioma, Categoria, Arbitro, ArbitroIdioma,
	      DesignacionArbitral, Sancion
	- Inicializar la tabla Fase con datos de referencia fijos
*/

-- La base de datos y los schemas los crea 00_Reset_Total.sql, que se ejecuta 
-- siempre primero.

--Seleccionamos la BD que se utilizará
USE MundialFutbol;
GO

/* CREACIÓN DE TABLAS NÚCLEO (para garantizar idempotencia, se debe correr el script "00_Reset_Total") */

-- =========================================================================
-- CATÁLOGOS GEOGRÁFICOS
-- =========================================================================

-- Tabla Confederacion
IF OBJECT_ID('nucleo.Confederacion', 'U') IS NULL
BEGIN
	CREATE TABLE nucleo.Confederacion(
		IdConfederacion TINYINT NOT NULL IDENTITY(1,1),
		Nombre VARCHAR(100) NOT NULL,
		Sigla VARCHAR(8) NOT NULL,
		Region VARCHAR(100) NULL,

		CONSTRAINT PK_Confederacion PRIMARY KEY (IdConfederacion),
		CONSTRAINT UQ_Confederacion_Nombre UNIQUE (Nombre),
		CONSTRAINT UQ_Confederacion_Sigla UNIQUE (Sigla)
	);
END
GO

-- Tabla Pais
IF OBJECT_ID('nucleo.Pais', 'U') IS NULL
BEGIN
	CREATE TABLE nucleo.Pais(
		IdPais SMALLINT NOT NULL IDENTITY(1,1),
		Nombre VARCHAR(50) NOT NULL,
		CodigoISO2 CHAR(2) NOT NULL,
		CodigoISO3 CHAR(3) NOT NULL,
		PBIPerCapitaUSD DECIMAL(10,2),
		HusoHorarioComercial VARCHAR(50) NOT NULL,
		IdConfederacion TINYINT NOT NULL,

		CONSTRAINT PK_Pais PRIMARY KEY (IdPais),
		CONSTRAINT UQ_Pais_Nombre UNIQUE (Nombre),
		CONSTRAINT UQ_Pais_CodigoISO2 UNIQUE (CodigoISO2),
		CONSTRAINT UQ_Pais_CodigoISO3 UNIQUE (CodigoISO3),
		CONSTRAINT CK_Pais_CodigoISO2_Valido CHECK (CodigoISO2 LIKE '[A-Z][A-Z]'),
		CONSTRAINT CK_Pais_CodigoISO3_Valido CHECK (CodigoISO3 LIKE '[A-Z][A-Z][A-Z]'),
		CONSTRAINT CK_Pais_PBI_No_Negativo CHECK (PBIPerCapitaUSD >= 0),
		CONSTRAINT CK_Pais_HusoHorarioComercial_NoVacio CHECK (TRIM(HusoHorarioComercial) <> ''),
		CONSTRAINT FK_Pais_Confederacion FOREIGN KEY (IdConfederacion)
			REFERENCES nucleo.Confederacion (IdConfederacion)
	);
END
GO

-- Tabla Ciudad
IF OBJECT_ID('nucleo.Ciudad', 'U') IS NULL
BEGIN
	CREATE TABLE nucleo.Ciudad(
		IdCiudad SMALLINT NOT NULL IDENTITY(1,1),
		Nombre VARCHAR(100) NOT NULL,
		HusoHorario VARCHAR(50) NOT NULL,
		IdPais SMALLINT NOT NULL,

		CONSTRAINT PK_Ciudad PRIMARY KEY (IdCiudad),
		CONSTRAINT UQ_Ciudad_Nombre_IdPais UNIQUE (Nombre, IdPais),
		CONSTRAINT CK_Ciudad_Nombre_NoVacio CHECK (TRIM(Nombre) <> ''),
		CONSTRAINT CK_Ciudad_HusoHorario_NoVacio CHECK (TRIM(HusoHorario) <> ''),
		CONSTRAINT FK_Ciudad_Pais FOREIGN KEY (IdPais)
			REFERENCES nucleo.Pais (IdPais)
	);
END
GO

-- Tabla Sede
IF OBJECT_ID('nucleo.Sede', 'U') IS NULL
BEGIN
	CREATE TABLE nucleo.Sede(
		IdSede TINYINT NOT NULL IDENTITY(1,1),
		NombreEstadio VARCHAR(100) NOT NULL,
		Capacidad INT NULL,
		Latitud DECIMAL(8,6) NULL,
		Longitud DECIMAL(9,6) NULL,
		IdCiudad SMALLINT NOT NULL,
	
		CONSTRAINT PK_Sede PRIMARY KEY (IdSede),
		CONSTRAINT UQ_Sede_NombreEstadio_IdCiudad UNIQUE (NombreEstadio, IdCiudad),
		CONSTRAINT CK_Sede_NombreEstadio_NoVacio CHECK (TRIM(NombreEstadio) <> ''),
		CONSTRAINT CK_Sede_Capacidad_Positiva CHECK (Capacidad > 0),
		CONSTRAINT CK_Sede_Latitud_Rango CHECK (Latitud BETWEEN -90 AND 90),
		CONSTRAINT CK_Sede_Longitud_Rango CHECK (Longitud BETWEEN -180 AND 180),
		-- Latitud y longitud se informan juntas o ninguna (se usan para el mapa de BI).
		CONSTRAINT CK_Sede_Coordenadas CHECK (
			(Latitud IS NULL AND Longitud IS NULL)
			OR (Latitud IS NOT NULL AND Longitud IS NOT NULL)
		 ),
		CONSTRAINT FK_Sede_Ciudad FOREIGN KEY (IdCiudad)
			REFERENCES nucleo.Ciudad (IdCiudad)
	);
END
GO

-- =========================================================================
-- GRUPOS, FASES, SELECCIONES Y CUERPO TÉCNICO
-- =========================================================================

-- Tabla Grupo
IF OBJECT_ID('nucleo.Grupo','U') IS NULL
BEGIN
	CREATE TABLE nucleo.Grupo(
		IdGrupo TINYINT NOT NULL IDENTITY(1,1),
		Nombre CHAR(1) NOT NULL,

		CONSTRAINT PK_Grupo PRIMARY KEY (IdGrupo),
		CONSTRAINT UQ_Grupo_Nombre UNIQUE (Nombre),
		CONSTRAINT CK_Grupo_Nombre_Letra CHECK (Nombre LIKE '[A-Z]')
	);
END
GO

-- Tabla Fase
IF OBJECT_ID('nucleo.Fase','U') IS NULL
BEGIN
	CREATE TABLE nucleo.Fase(
		IdFase TINYINT NOT NULL IDENTITY(1,1),
		Nombre VARCHAR(28) NOT NULL,
		Orden TINYINT NOT NULL,
		EsEliminatoria BIT NOT NULL,

		CONSTRAINT PK_Fase PRIMARY KEY (IdFase),
		CONSTRAINT UQ_Fase_Nombre UNIQUE (Nombre),
		CONSTRAINT UQ_Fase_Orden UNIQUE (Orden),
		CONSTRAINT CK_Fase_Orden_Valido CHECK (Orden > 0),
		CONSTRAINT CK_Fase_Nombre_Valido CHECK (
			Nombre IN (
				'Fase de grupos',
				'Dieciseisavos de final',
				'Octavos de final',
				'Cuartos de final',
				'Semifinal',
				'Tercer puesto',
				'Final'
			)
		)	
	);
END
GO

-- Tabla Seleccion
IF OBJECT_ID('nucleo.Seleccion','U') IS NULL
BEGIN
	CREATE TABLE nucleo.Seleccion (
		IdSeleccion TINYINT NOT NULL IDENTITY (1,1),
		CodigoFIFA CHAR(3) NOT NULL,
		RankingFIFA SMALLINT NOT NULL,
		EsAnfitrion BIT NOT NULL CONSTRAINT DF_Seleccion_EsAnfitrion DEFAULT 0,
		IdPais SMALLINT NOT NULL,
		IdGrupo TINYINT NOT NULL,

		CONSTRAINT PK_Seleccion PRIMARY KEY (IdSeleccion),
		CONSTRAINT UQ_Seleccion_CodigoFIFA UNIQUE (CodigoFIFA),
		CONSTRAINT UQ_Seleccion_IdPais UNIQUE (IdPais),
		CONSTRAINT CK_Seleccion_CodigoFIFA_3_Letras CHECK (CodigoFIFA LIKE '[A-Z][A-Z][A-Z]'),
		CONSTRAINT CK_Seleccion_RankingFIFA_Positivo CHECK (RankingFIFA > 0),
		CONSTRAINT FK_Seleccion_Pais FOREIGN KEY (IdPais)
			REFERENCES nucleo.Pais (IdPais),
		CONSTRAINT FK_Seleccion_Grupo FOREIGN KEY (IdGrupo)
			REFERENCES nucleo.Grupo (IdGrupo)
	);
END
GO

-- Tabla Partido
IF OBJECT_ID('nucleo.Partido','U') IS NULL
BEGIN
	CREATE TABLE nucleo.Partido (
		IdPartido SMALLINT NOT NULL IDENTITY(1,1),
		NumeroPartido TINYINT NOT NULL,
		Concurrencia INT NULL,
		FechaHoraUTC DATETIME2(0) NOT NULL,
		Estado VARCHAR(10) NOT NULL,
		IdFase TINYINT NOT NULL,
		IdSede TINYINT NOT NULL,
		IdSeleccionLocal TINYINT NULL,
		IdSeleccionVisitante TINYINT NULL,

		CONSTRAINT PK_Partido PRIMARY KEY (IdPartido),
		CONSTRAINT UQ_Partido_NumeroPartido UNIQUE (NumeroPartido),
		-- Una sede no puede tener dos partidos en el mismo instante (el solapamiento fino lo valida el SP).
		CONSTRAINT UQ_Partido_IdSede_FechaHoraUTC UNIQUE (IdSede, FechaHoraUTC),
		CONSTRAINT CK_Partido_Concurrencia_Positiva CHECK (Concurrencia >= 0),
		CONSTRAINT CK_Partido_Estado_Valido CHECK (Estado IN ('Programado', 'Finalizado')),
		-- El resultado NO se guarda en Partido (3FN): se deriva de eventos.Gol con
		-- eventos.fn_ResultadoPartido. Finalizado exige ambas selecciones definidas.
		CONSTRAINT CK_Partido_Resultado CHECK (
			Estado = 'Programado'
			OR (Estado = 'Finalizado' AND IdSeleccionLocal IS NOT NULL AND IdSeleccionVisitante IS NOT NULL)
		),
		-- Check para validar que un equipo no se puede enfrentar a si mismo
		CONSTRAINT CK_Partido_Equipos CHECK (IdSeleccionLocal <> IdSeleccionVisitante),

		CONSTRAINT FK_Partido_Fase FOREIGN KEY (IdFase)
			REFERENCES nucleo.Fase (IdFase),
		CONSTRAINT FK_Partido_Sede FOREIGN KEY (IdSede)
			REFERENCES nucleo.Sede (IdSede),
		CONSTRAINT FK_Partido_Seleccion_Local FOREIGN KEY (IdSeleccionLocal)
			REFERENCES nucleo.Seleccion (IdSeleccion),
		CONSTRAINT FK_Partido_Seleccion_Visitante FOREIGN KEY (IdSeleccionVisitante)
			REFERENCES nucleo.Seleccion (IdSeleccion)
	);
END
GO

-- Indices asociados a tabla Partido
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Partido_Fecha' AND object_id = OBJECT_ID('nucleo.Partido'))
BEGIN
	CREATE NONCLUSTERED INDEX IX_Partido_Fecha ON nucleo.Partido (FechaHoraUTC);
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Partido_Fase' AND object_id = OBJECT_ID('nucleo.Partido'))
BEGIN
	CREATE NONCLUSTERED INDEX IX_Partido_Fase ON nucleo.Partido (IdFase);
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Partido_Local' AND object_id = OBJECT_ID('nucleo.Partido'))
BEGIN
	CREATE NONCLUSTERED INDEX IX_Partido_Local ON nucleo.Partido (IdSeleccionLocal);
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Partido_Visitante' AND object_id = OBJECT_ID('nucleo.Partido'))
BEGIN
	CREATE NONCLUSTERED INDEX IX_Partido_Visitante ON nucleo.Partido (IdSeleccionVisitante);
END
GO

-- Tabla Staff Técnico
IF OBJECT_ID('nucleo.StaffTecnico','U') IS NULL
BEGIN
	CREATE TABLE nucleo.StaffTecnico (
		IdStaffTecnico SMALLINT NOT NULL IDENTITY (1,1),
		NombreApellido VARCHAR(200) NOT NULL,
		Rol VARCHAR(25) NOT NULL,
		IdSeleccion TINYINT NOT NULL,

		CONSTRAINT PK_StaffTecnico PRIMARY KEY (IdStaffTecnico),
		CONSTRAINT UQ_StaffTecnico_IdSeleccion_Rol UNIQUE (IdSeleccion, Rol),
		CONSTRAINT CK_StaffTecnico_Rol_Valido CHECK (
			Rol IN (
				'Director Técnico',
				'Ayudante de campo 1',
				'Ayudante de campo 2'
			)
		),
		CONSTRAINT FK_StaffTecnico_Seleccion FOREIGN KEY (IdSeleccion)
			REFERENCES nucleo.Seleccion (IdSeleccion)
	);
END
GO

-- =========================================================================
-- ARBITROS
-- =========================================================================

-- Tabla Idioma
IF OBJECT_ID('nucleo.Idioma','U') IS NULL
BEGIN
	CREATE TABLE nucleo.Idioma (
		IdIdioma TINYINT NOT NULL IDENTITY (1,1),
		Nombre VARCHAR(100) NOT NULL,

		CONSTRAINT PK_Idioma PRIMARY KEY (IdIdioma),
		CONSTRAINT UQ_Idioma_Nombre UNIQUE (Nombre),
		CONSTRAINT CK_Idioma_Nombre_NoVacio CHECK (TRIM(Nombre) <> '')
	);
END
GO

-- Tabla Categoria
IF OBJECT_ID('nucleo.Categoria','U') IS NULL
BEGIN
	CREATE TABLE nucleo.Categoria (
		IdCategoria TINYINT NOT NULL IDENTITY (1,1),
		Nombre VARCHAR(100) NOT NULL,

		CONSTRAINT PK_Categoria PRIMARY KEY (IdCategoria),
		CONSTRAINT UQ_Categoria_Nombre UNIQUE (Nombre),
		CONSTRAINT CK_Categoria_Nombre_NoVacio CHECK (TRIM(Nombre) <> '')
	);
END
GO

-- Tabla Arbitro
IF OBJECT_ID('nucleo.Arbitro','U') IS NULL
BEGIN
	CREATE TABLE nucleo.Arbitro (
		IdArbitro SMALLINT NOT NULL IDENTITY (1,1),
		NombreApellido VARCHAR(200) NOT NULL,
		Sexo CHAR(1) NULL,
		EstaHabilitado CHAR(1) NOT NULL CONSTRAINT DF_Arbitro_EstaHabilitado DEFAULT 'Y',
		FechaNacimiento DATE NOT NULL,
		IdPais SMALLINT NOT NULL,
		IdCategoria TINYINT NOT NULL,

		CONSTRAINT PK_Arbitro PRIMARY KEY (IdArbitro),
		CONSTRAINT CK_Arbitro_NombreApellido_NoVacio CHECK (TRIM(NombreApellido) <> ''),
		CONSTRAINT CK_Arbitro_Sexo_Valido CHECK (Sexo IN ('M','F')),
		CONSTRAINT CK_Arbitro_EstaHabilitado_Valido CHECK (EstaHabilitado IN ('Y','N')),
		CONSTRAINT CK_Arbitro_FechaNacimiento_Valida CHECK 
		(	FechaNacimiento >= '1930-01-01' 
			AND FechaNacimiento < CAST(GETDATE() AS DATE)
		),
		CONSTRAINT FK_Arbitro_Pais FOREIGN KEY (IdPais)
			REFERENCES nucleo.Pais (IdPais),
		CONSTRAINT FK_Arbitro_Categoria FOREIGN KEY (IdCategoria)
			REFERENCES nucleo.Categoria (IdCategoria)
	);
END
GO

-- Tabla ArbitroIdioma - Relación N:N árbitro-idioma (un árbitro habla varios idiomas)
IF OBJECT_ID('nucleo.ArbitroIdioma', 'U') IS NULL
BEGIN
	CREATE TABLE nucleo.ArbitroIdioma (
		IdArbitro SMALLINT NOT NULL,
		IdIdioma TINYINT NOT NULL,

		CONSTRAINT PK_ArbitroIdioma PRIMARY KEY (IdArbitro, IdIdioma),
		CONSTRAINT FK_ArbitroIdioma_Arbitro FOREIGN KEY (IdArbitro)
			REFERENCES nucleo.Arbitro (IdArbitro),
		CONSTRAINT FK_ArbitroIdioma_Idioma FOREIGN KEY (IdIdioma)
			REFERENCES nucleo.Idioma (IdIdioma)
	);
END
GO

-- Tabla DesignacionArbitral
-- Los cupos y el impedimento por nacionalidad los valida nucleo.SP_CONTROL_ARBITRAL.
IF OBJECT_ID('nucleo.DesignacionArbitral','U') IS NULL
BEGIN
	CREATE TABLE nucleo.DesignacionArbitral (
		IdDesignacionArbitral SMALLINT NOT NULL IDENTITY (1,1),
		Rol VARCHAR(15) NOT NULL,
		IdArbitro SMALLINT NOT NULL,
		IdPartido SMALLINT NOT NULL,

		CONSTRAINT PK_DesignacionArbitral PRIMARY KEY (IdDesignacionArbitral),
		CONSTRAINT UQ_DesignacionArbitral_IdPartido_Rol UNIQUE (IdPartido, Rol),
		CONSTRAINT UQ_DesignacionArbitral_IdPartido_IdArbitro UNIQUE (IdPartido, IdArbitro),
		CONSTRAINT CK_DesignacionArbitral_Rol_Valido CHECK (
			Rol IN ('Principal','Asistente 1','Asistente 2','Cuarto','VAR')
		),
		CONSTRAINT FK_DesignacionArbitral_Arbitro FOREIGN KEY (IdArbitro)
			REFERENCES nucleo.Arbitro (IdArbitro),
		CONSTRAINT FK_DesignacionArbitral_Partido FOREIGN KEY (IdPartido)
			REFERENCES nucleo.Partido (IdPartido)
	);
END
GO

-- Tabla Sancion
IF OBJECT_ID('nucleo.Sancion','U') IS NULL
BEGIN
	CREATE TABLE nucleo.Sancion (
		IdSancion SMALLINT NOT NULL IDENTITY (1,1),
		Tipo VARCHAR(20) NOT NULL,
		Descripcion VARCHAR(300) NOT NULL,
		Fecha DATE NOT NULL CONSTRAINT DF_Sancion_Fecha DEFAULT (CAST(GETDATE() AS DATE)),
		IdDesignacionArbitral SMALLINT NOT NULL,

		CONSTRAINT PK_Sancion PRIMARY KEY (IdSancion),
		CONSTRAINT CK_Sancion_Tipo_Valido CHECK (
			Tipo IN ('Suspension Temporal', 'Inhabilitacion', 'Multa', 'Advertencia', 'Informe')
		),
		CONSTRAINT CK_Sancion_Descripcion_NoVacia CHECK (TRIM(Descripcion) <> ''),
		CONSTRAINT FK_Sancion_DesignacionArbitral FOREIGN KEY (IdDesignacionArbitral)
			REFERENCES nucleo.DesignacionArbitral (IdDesignacionArbitral)
	);
END
GO

-- =========================================================================
-- DATOS DE REFERENCIA FIJOS: FASES DEL TORNEO
-- (Valores que usan SP_CONTROL_ARBITRAL y los SP de partidos)
-- =========================================================================

IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Nombre = 'Fase de grupos')
BEGIN
	INSERT INTO nucleo.Fase (Nombre, Orden, EsEliminatoria) 
	VALUES ('Fase de grupos', 1, 0)
END
GO

IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Nombre = 'Dieciseisavos de final')
BEGIN
	INSERT INTO nucleo.Fase (Nombre, Orden, EsEliminatoria) 
	VALUES ('Dieciseisavos de final', 2, 1)
END
GO

IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Nombre = 'Octavos de final')
BEGIN
	INSERT INTO nucleo.Fase (Nombre, Orden, EsEliminatoria) 
	VALUES ('Octavos de final', 3, 1)
END
GO

IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Nombre = 'Cuartos de final')
BEGIN
	INSERT INTO nucleo.Fase (Nombre, Orden, EsEliminatoria) 
	VALUES ('Cuartos de final', 4, 1)
END
GO

IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Nombre = 'Semifinal')
BEGIN
	INSERT INTO nucleo.Fase (Nombre, Orden, EsEliminatoria) 
	VALUES ('Semifinal', 5, 1)
END
GO

IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Nombre = 'Tercer puesto')
BEGIN
	INSERT INTO nucleo.Fase (Nombre, Orden, EsEliminatoria) 
	VALUES ('Tercer puesto', 6, 1)
END
GO

IF NOT EXISTS (SELECT 1 FROM nucleo.Fase WHERE Nombre = 'Final')
BEGIN
	INSERT INTO nucleo.Fase (Nombre, Orden, EsEliminatoria) 
	VALUES ('Final', 7, 1)
END
GO