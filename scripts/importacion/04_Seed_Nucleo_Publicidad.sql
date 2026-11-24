/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-23
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Seed de catálogos y entidades base de nucleo y publicidad (idempotente: se puede re-ejecutar):
          confederaciones, 22 países (16 participantes + 6 neutrales), 4 grupos, 16 selecciones, cuerpo técnico,
          idiomas, categorías, 18 árbitros con idiomas, monedas, 9 anunciantes de 9 países y 12 piezas con
          sus países de orientación. Usa los SP ABM de las entregas anteriores (sin SQL dinámico ni cursores).
          Los grupos respetan el contrato con Mateo, salvo que BRA se ubica en el Grupo A (junto a ARG) porque
          SP_ALTA_Partido exige que los partidos de fase de grupos sean entre selecciones del mismo grupo y el
          partido 1 debe ser ARG vs BRA. Los partidos y sedes los carga 05_Importar_Nucleo_Publicidad.sql.
ORDEN: ejecutar primero (antes de 05, 06 y 07 de esta carpeta y de los scripts de Mateo).
*/
USE MundialFutbol;
GO
SET NOCOUNT ON;
GO

-- ===== Catálogos simples (INSERT idempotente) =====
INSERT INTO nucleo.Confederacion (Nombre, Sigla, Region)
SELECT v.Nombre, v.Sigla, v.Region
FROM (VALUES ('Unión de Asociaciones Europeas de Fútbol', 'UEFA', 'Europa'),
             ('Confederación Sudamericana de Fútbol', 'CONMEBOL', 'Sudamérica'),
             ('Confederación de Norte, Centroamérica y el Caribe', 'CONCACAF', 'Norte y Centroamérica'),
             ('Confederación Africana de Fútbol', 'CAF', 'África'),
             ('Confederación Asiática de Fútbol', 'AFC', 'Asia y Oceanía')) AS v (Nombre, Sigla, Region)
WHERE NOT EXISTS (SELECT 1 FROM nucleo.Confederacion AS c WHERE c.Sigla = v.Sigla);

INSERT INTO nucleo.Idioma (Nombre)
SELECT v.Nombre FROM (VALUES ('Español'), ('Inglés'), ('Francés'), ('Portugués'), ('Alemán'), ('Italiano'), ('Japonés')) AS v (Nombre)
WHERE NOT EXISTS (SELECT 1 FROM nucleo.Idioma AS i WHERE i.Nombre = v.Nombre);

INSERT INTO nucleo.Categoria (Nombre)
SELECT v.Nombre FROM (VALUES ('Elite FIFA'), ('Internacional FIFA')) AS v (Nombre)
WHERE NOT EXISTS (SELECT 1 FROM nucleo.Categoria AS c WHERE c.Nombre = v.Nombre);

INSERT INTO nucleo.Grupo (Nombre)
SELECT v.Nombre FROM (VALUES ('A'), ('B'), ('C'), ('D')) AS v (Nombre)
WHERE NOT EXISTS (SELECT 1 FROM nucleo.Grupo AS g WHERE g.Nombre = v.Nombre);

INSERT INTO publicidad.Moneda (Codigo, Nombre)
SELECT v.Codigo, v.Nombre
FROM (VALUES ('USD', 'Dólar estadounidense'), ('EUR', 'Euro'), ('ARS', 'Peso argentino'),
             ('BRL', 'Real brasileño'), ('JPY', 'Yen japonés'), ('GBP', 'Libra esterlina')) AS v (Codigo, Nombre)
WHERE NOT EXISTS (SELECT 1 FROM publicidad.Moneda AS m WHERE m.Codigo = v.Codigo);
GO

-- ===== Países (SP_ABM_Pais). El PBI lo completa SP_IMPORTAR_PBI_JSON (API Banco Mundial) =====
DECLARE @pais TABLE (Id INT IDENTITY(1,1) PRIMARY KEY, Nombre VARCHAR(50), Iso2 CHAR(2), Iso3 CHAR(3), Conf VARCHAR(8), Huso VARCHAR(50));
INSERT INTO @pais (Nombre, Iso2, Iso3, Conf, Huso) VALUES
 ('Argentina', 'AR', 'ARG', 'CONMEBOL', 'Argentina Standard Time'),
 ('Brasil', 'BR', 'BRA', 'CONMEBOL', 'E. South America Standard Time'),
 ('Uruguay', 'UY', 'URU', 'CONMEBOL', 'Montevideo Standard Time'),
 ('Colombia', 'CO', 'COL', 'CONMEBOL', 'SA Pacific Standard Time'),
 ('Chile', 'CL', 'CHI', 'CONMEBOL', 'Pacific SA Standard Time'),
 ('Estados Unidos', 'US', 'USA', 'CONCACAF', 'Eastern Standard Time'),
 ('México', 'MX', 'MEX', 'CONCACAF', 'Central Standard Time (Mexico)'),
 ('Canadá', 'CA', 'CAN', 'CONCACAF', 'Eastern Standard Time'),
 ('Países Bajos', 'NL', 'NED', 'UEFA', 'W. Europe Standard Time'),
 ('España', 'ES', 'ESP', 'UEFA', 'Romance Standard Time'),
 ('Francia', 'FR', 'FRA', 'UEFA', 'Romance Standard Time'),
 ('Alemania', 'DE', 'GER', 'UEFA', 'W. Europe Standard Time'),
 ('Inglaterra', 'GB', 'ENG', 'UEFA', 'GMT Standard Time'),
 ('Portugal', 'PT', 'POR', 'UEFA', 'GMT Standard Time'),
 ('Italia', 'IT', 'ITA', 'UEFA', 'W. Europe Standard Time'),
 ('Suiza', 'CH', 'SUI', 'UEFA', 'W. Europe Standard Time'),
 ('Noruega', 'NO', 'NOR', 'UEFA', 'W. Europe Standard Time'),
 ('Suecia', 'SE', 'SWE', 'UEFA', 'W. Europe Standard Time'),
 ('Marruecos', 'MA', 'MAR', 'CAF', 'Morocco Standard Time'),
 ('Japón', 'JP', 'JPN', 'AFC', 'Tokyo Standard Time'),
 ('Corea del Sur', 'KR', 'KOR', 'AFC', 'Korea Standard Time'),
 ('Australia', 'AU', 'AUS', 'AFC', 'AUS Eastern Standard Time');
DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @pais), @idConf INT, @nombre VARCHAR(50), @iso2 CHAR(2), @iso3 CHAR(3), @huso VARCHAR(50);
WHILE @i <= @n
BEGIN
    SELECT @nombre = p.Nombre, @iso2 = p.Iso2, @iso3 = p.Iso3, @huso = p.Huso, @idConf = c.IdConfederacion
    FROM @pais AS p INNER JOIN nucleo.Confederacion AS c ON c.Sigla = p.Conf WHERE p.Id = @i;
    IF NOT EXISTS (SELECT 1 FROM nucleo.Pais WHERE CodigoISO3 = @iso3)
        EXEC nucleo.SP_ALTA_Pais @nombre = @nombre, @codigoISO2 = @iso2, @codigoISO3 = @iso3,
                                 @idConfederacion = @idConf, @husoHorarioComercial = @huso;
    SET @i += 1;
END;
GO

-- ===== Selecciones (SP_ABM_Seleccion) y cuerpo técnico (SP_ABM_StaffTecnico) =====
DECLARE @sel TABLE (Id INT IDENTITY(1,1) PRIMARY KEY, Iso3 CHAR(3), Ranking SMALLINT, Anfitrion BIT, Grupo CHAR(1));
INSERT INTO @sel (Iso3, Ranking, Anfitrion, Grupo) VALUES
 ('ARG', 1, 0, 'A'), ('BRA', 5, 0, 'A'), ('USA', 12, 1, 'A'), ('JPN', 15, 0, 'A'),
 ('NED', 7, 0, 'B'), ('ESP', 2, 0, 'B'), ('MAR', 14, 0, 'B'), ('KOR', 16, 0, 'B'),
 ('FRA', 3, 0, 'C'), ('GER', 9, 0, 'C'), ('URU', 10, 0, 'C'), ('MEX', 13, 1, 'C'),
 ('ENG', 4, 0, 'D'), ('POR', 6, 0, 'D'), ('ITA', 8, 0, 'D'), ('COL', 11, 0, 'D');
DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @sel), @iso3 CHAR(3), @ranking SMALLINT, @anf BIT, @idPais INT, @idGrupo INT;
WHILE @i <= @n
BEGIN
    SELECT @iso3 = s.Iso3, @ranking = s.Ranking, @anf = s.Anfitrion, @idPais = p.IdPais, @idGrupo = g.IdGrupo
    FROM @sel AS s INNER JOIN nucleo.Pais AS p ON p.CodigoISO3 = s.Iso3 INNER JOIN nucleo.Grupo AS g ON g.Nombre = s.Grupo
    WHERE s.Id = @i;
    IF NOT EXISTS (SELECT 1 FROM nucleo.Seleccion WHERE CodigoFIFA = @iso3)
        EXEC nucleo.SP_ALTA_Seleccion @codigoFIFA = @iso3, @rankingFIFA = @ranking,
                                      @esAnfitrion = @anf, @idPais = @idPais, @idGrupo = @idGrupo;
    SET @i += 1;
END;

DECLARE @staff TABLE (Id INT IDENTITY(1,1) PRIMARY KEY, IdSeleccion INT, Rol VARCHAR(25), Nombre VARCHAR(200));
INSERT INTO @staff (IdSeleccion, Rol, Nombre)
SELECT s.IdSeleccion, r.Rol, r.Prefijo + ' ' + p.Nombre
FROM nucleo.Seleccion AS s
INNER JOIN nucleo.Pais AS p ON p.IdPais = s.IdPais
CROSS JOIN (VALUES ('Director Técnico', 'DT'), ('Ayudante de campo 1', 'Ayudante')) AS r (Rol, Prefijo)
ORDER BY s.IdSeleccion, r.Rol;
DECLARE @idSel INT, @rol VARCHAR(25), @nom VARCHAR(200);
SELECT @i = 1, @n = COUNT(*) FROM @staff;
WHILE @i <= @n
BEGIN
    SELECT @idSel = IdSeleccion, @rol = Rol, @nom = Nombre FROM @staff WHERE Id = @i;
    IF NOT EXISTS (SELECT 1 FROM nucleo.StaffTecnico WHERE IdSeleccion = @idSel AND Rol = @rol)
        EXEC nucleo.SP_ALTA_StaffTecnico @idSeleccion = @idSel, @nombreApellido = @nom, @rol = @rol;
    SET @i += 1;
END;
GO

-- ===== Árbitros (SP_ABM_Arbitro) e idiomas (SP_ABM_ArbitroIdioma): 12 neutrales + 6 de países participantes =====
DECLARE @arb TABLE (Id INT IDENTITY(1,1) PRIMARY KEY, Nombre VARCHAR(200), Sexo CHAR(1), Nacimiento DATE,
                    Iso3 CHAR(3), Categoria VARCHAR(100), Idioma1 VARCHAR(100), Idioma2 VARCHAR(100));
INSERT INTO @arb (Nombre, Sexo, Nacimiento, Iso3, Categoria, Idioma1, Idioma2) VALUES
 ('Lukas Meier', 'M', '1982-03-14', 'SUI', 'Elite FIFA', 'Alemán', 'Francés'),
 ('Elena Bachmann', 'F', '1986-09-02', 'SUI', 'Internacional FIFA', 'Francés', 'Inglés'),
 ('Henrik Solberg', 'M', '1981-11-23', 'NOR', 'Elite FIFA', 'Inglés', 'Alemán'),
 ('Ingrid Haugen', 'F', '1987-05-30', 'NOR', 'Internacional FIFA', 'Inglés', 'Español'),
 ('Erik Johansson', 'M', '1983-01-19', 'SWE', 'Elite FIFA', 'Inglés', 'Alemán'),
 ('Maja Nilsson', 'F', '1988-08-08', 'SWE', 'Internacional FIFA', 'Inglés', 'Francés'),
 ('Daniel Whitfield', 'M', '1980-06-27', 'AUS', 'Elite FIFA', 'Inglés', 'Japonés'),
 ('Chloe Mackenzie', 'F', '1989-12-11', 'AUS', 'Internacional FIFA', 'Inglés', 'Italiano'),
 ('Marc Tremblay', 'M', '1984-04-05', 'CAN', 'Elite FIFA', 'Francés', 'Inglés'),
 ('Olivia Grant', 'F', '1990-02-16', 'CAN', 'Internacional FIFA', 'Inglés', 'Español'),
 ('Matías Valdivia', 'M', '1982-10-09', 'CHI', 'Elite FIFA', 'Español', 'Inglés'),
 ('Camila Rojas', 'F', '1988-07-21', 'CHI', 'Internacional FIFA', 'Español', 'Portugués'),
 ('Néstor Ferrante', 'M', '1981-05-12', 'ARG', 'Elite FIFA', 'Español', 'Italiano'),
 ('Rafael Moreira', 'M', '1985-09-17', 'BRA', 'Internacional FIFA', 'Portugués', 'Español'),
 ('Julien Marchand', 'M', '1983-03-03', 'FRA', 'Elite FIFA', 'Francés', 'Inglés'),
 ('Javier Ortuño', 'M', '1986-12-28', 'ESP', 'Internacional FIFA', 'Español', 'Inglés'),
 ('Matthias Brandt', 'M', '1982-06-06', 'GER', 'Elite FIFA', 'Alemán', 'Inglés'),
 ('Kenji Watanabe', 'M', '1984-01-25', 'JPN', 'Internacional FIFA', 'Japonés', 'Inglés');
DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @arb), @idArb INT, @nombre VARCHAR(200), @sexo CHAR(1), @nac DATE,
        @idPais INT, @idCat INT, @idI1 INT, @idI2 INT;
WHILE @i <= @n
BEGIN
    SELECT @nombre = a.Nombre, @sexo = a.Sexo, @nac = a.Nacimiento, @idPais = p.IdPais, @idCat = c.IdCategoria,
           @idI1 = i1.IdIdioma, @idI2 = i2.IdIdioma
    FROM @arb AS a
    INNER JOIN nucleo.Pais AS p ON p.CodigoISO3 = a.Iso3
    INNER JOIN nucleo.Categoria AS c ON c.Nombre = a.Categoria
    INNER JOIN nucleo.Idioma AS i1 ON i1.Nombre = a.Idioma1
    INNER JOIN nucleo.Idioma AS i2 ON i2.Nombre = a.Idioma2
    WHERE a.Id = @i;
    SET @idArb = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = @nombre AND FechaNacimiento = @nac);
    IF @idArb IS NULL
    BEGIN
        EXEC nucleo.SP_ALTA_Arbitro @nombreApellido = @nombre, @sexo = @sexo, @estaHabilitado = 'Y',
                                    @fechaNacimiento = @nac, @idPais = @idPais, @idCategoria = @idCat;
        SET @idArb = (SELECT IdArbitro FROM nucleo.Arbitro WHERE NombreApellido = @nombre AND FechaNacimiento = @nac);
    END;
    IF NOT EXISTS (SELECT 1 FROM nucleo.ArbitroIdioma WHERE IdArbitro = @idArb AND IdIdioma = @idI1)
        EXEC nucleo.SP_ALTA_ArbitroIdioma @idArbitro = @idArb, @idIdioma = @idI1;
    IF NOT EXISTS (SELECT 1 FROM nucleo.ArbitroIdioma WHERE IdArbitro = @idArb AND IdIdioma = @idI2)
        EXEC nucleo.SP_ALTA_ArbitroIdioma @idArbitro = @idArb, @idIdioma = @idI2;
    SET @i += 1;
END;
GO

-- ===== Anunciantes (9 países), piezas (12) y países de orientación =====
DECLARE @anu TABLE (Id INT IDENTITY(1,1) PRIMARY KEY, Nombre VARCHAR(100), Iso3 CHAR(3));
INSERT INTO @anu (Nombre, Iso3) VALUES
 ('Pampa Telecom', 'ARG'), ('Verde Bebidas', 'BRA'), ('Sakura Motors', 'JPN'), ('Nordic Outdoor', 'NOR'),
 ('Helvetia Watches', 'SUI'), ('Maple Bank', 'CAN'), ('Liberty Sportswear', 'USA'), ('Rhein Auto', 'GER'),
 ('Soleil Parfums', 'FRA');
DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @anu), @nombre VARCHAR(100), @idPais INT;
WHILE @i <= @n
BEGIN
    SELECT @nombre = a.Nombre, @idPais = p.IdPais FROM @anu AS a INNER JOIN nucleo.Pais AS p ON p.CodigoISO3 = a.Iso3 WHERE a.Id = @i;
    IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE Nombre = @nombre)
        EXEC publicidad.SP_ALTA_Anunciante @nombre = @nombre, @idPais = @idPais;
    SET @i += 1;
END;

DECLARE @pieza TABLE (Id INT IDENTITY(1,1) PRIMARY KEY, Anunciante VARCHAR(100), Titulo VARCHAR(100), Idioma VARCHAR(100), Paises VARCHAR(100));
INSERT INTO @pieza (Anunciante, Titulo, Idioma, Paises) VALUES
 ('Pampa Telecom', 'Conectá el Mundial', 'Español', 'ARG,URU,CHI'),
 ('Pampa Telecom', 'Roaming Mundialista', 'Inglés', 'ESP,ITA,FRA'),
 ('Verde Bebidas', 'Sabor de Torcida', 'Portugués', 'BRA,POR'),
 ('Verde Bebidas', 'Refresh Every Goal', 'Inglés', 'USA,AUS,ENG'),
 ('Sakura Motors', 'Drive the Future', 'Inglés', 'JPN,USA,KOR'),
 ('Sakura Motors', 'Último Golpe', 'Español', 'MEX,COL,ARG'),
 ('Nordic Outdoor', 'Beyond the Pitch', 'Inglés', 'NOR,SWE,CAN'),
 ('Helvetia Watches', 'Tiempo de Campeones', 'Alemán', 'SUI,GER,ITA'),
 ('Maple Bank', 'Banking Goals', 'Inglés', 'CAN,USA'),
 ('Liberty Sportswear', 'Pura Pasión', 'Español', 'ARG,BRA,URU'),
 ('Rhein Auto', 'Fahrfreude', 'Alemán', 'GER,NED,ESP'),
 ('Soleil Parfums', 'Allez les Bleus', 'Francés', 'FRA,MAR,SUI');
DECLARE @idAnu INT, @idIdioma INT, @titulo VARCHAR(100), @idPieza INT;
SELECT @i = 1, @n = COUNT(*) FROM @pieza;
WHILE @i <= @n
BEGIN
    SELECT @idAnu = an.IdAnunciante, @idIdioma = id.IdIdioma, @titulo = z.Titulo
    FROM @pieza AS z
    INNER JOIN publicidad.Anunciante AS an ON an.Nombre = z.Anunciante
    INNER JOIN nucleo.Idioma AS id ON id.Nombre = z.Idioma
    WHERE z.Id = @i;
    IF NOT EXISTS (SELECT 1 FROM publicidad.Pieza WHERE IdAnunciante = @idAnu AND Titulo = @titulo AND IdIdioma = @idIdioma)
        EXEC publicidad.SP_ALTA_Pieza @idAnunciante = @idAnu, @idIdioma = @idIdioma,
                                     @titulo = @titulo, @descripcion = 'Campaña Mundial 2026';
    SET @i += 1;
END;

DECLARE @orient TABLE (Id INT IDENTITY(1,1) PRIMARY KEY, IdPieza INT, IdPais INT);
INSERT INTO @orient (IdPieza, IdPais)
SELECT pz.IdPieza, pa.IdPais
FROM @pieza AS z
INNER JOIN publicidad.Anunciante AS an ON an.Nombre = z.Anunciante
INNER JOIN nucleo.Idioma AS id ON id.Nombre = z.Idioma
INNER JOIN publicidad.Pieza AS pz ON pz.IdAnunciante = an.IdAnunciante AND pz.IdIdioma = id.IdIdioma AND pz.Titulo = z.Titulo
CROSS APPLY STRING_SPLIT(z.Paises, ',') AS s
INNER JOIN nucleo.Pais AS pa ON pa.CodigoISO3 = s.value
ORDER BY pz.IdPieza, pa.IdPais;
DECLARE @idPz INT, @idPa INT;
SELECT @i = 1, @n = COUNT(*) FROM @orient;
WHILE @i <= @n
BEGIN
    SELECT @idPz = IdPieza, @idPa = IdPais FROM @orient WHERE Id = @i;
    IF NOT EXISTS (SELECT 1 FROM publicidad.OrientacionPais WHERE IdPieza = @idPz AND IdPais = @idPa)
        EXEC publicidad.SP_ALTA_OrientacionPais @idPieza = @idPz, @idPais = @idPa;
    SET @i += 1;
END;
GO

SELECT 'Seed nucleo/publicidad' AS Resumen,
       (SELECT COUNT(*) FROM nucleo.Pais) AS Paises_22, (SELECT COUNT(*) FROM nucleo.Seleccion) AS Selecciones_16,
       (SELECT COUNT(*) FROM nucleo.StaffTecnico) AS Staff_32, (SELECT COUNT(*) FROM nucleo.Arbitro) AS Arbitros_18,
       (SELECT COUNT(DISTINCT IdPais) FROM publicidad.Anunciante) AS PaisesAnunciantes_9,
       (SELECT COUNT(*) FROM publicidad.Pieza) AS Piezas_12;
GO
