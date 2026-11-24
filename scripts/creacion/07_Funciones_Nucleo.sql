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
	- Generar las funciones inline del esquema nucleo:
		  - nucleo.fn_MercadosEnPrimeTime: mercados (países) donde el horario de un partido
		  cae en prime time local.
		  - nucleo.fn_SeleccionesDelPartido: selecciones que disputan un partido.
		  - nucleo.fn_SeleccionConPartidoCercano: selecciones que tienen otro partido a menos de
		    48 horas de un horario dado (regla de descanso, única fuente para los SP de partidos).
		  - nucleo.fn_PartidoTieneRegistros: qué registros asociados tiene un partido
		    (formaciones, sustituciones, goles, amonestaciones, designaciones, sanciones y
		    espacios publicitarios), única fuente para los SP de partidos.
	- Funciones escalares de búsqueda y de nombre visible de árbitros y staff técnico
	  (nucleo.fn_IdArbitroPorNombre, nucleo.fn_IdStaffPorNombre, nucleo.fn_NombreArbitro y
	  nucleo.fn_NombreStaff). Son el único punto por el que importaciones, seeds y reportes
	  buscan o muestran estos nombres: 31_Seguridad_Cifrado.sql las modifica para que operen
	  sobre los datos cifrados sin tocar a quienes las usan.
*/

USE MundialFutbol;
GO

/*
nucleo.fn_MercadosEnPrimeTime
Propósito: devolver los mercados (países) donde el partido se juega en prime time, para la
           asignación de los espacios publicitarios.
Parámetros:
	@IdPartido: partido a evaluar.
Columnas devueltas (una fila por país en prime time; 0 filas si el partido no existe):
	IdPartido, IdPais, Nombre, CodigoISO3,
	PBIPerCapitaUSD       -> segundo criterio de priorización (mayor PBI primero).
	HusoHorarioComercial  -> zona horaria de Windows (sys.time_zone_info) usada en la conversión.
	FechaHoraLocalMercado -> FechaHoraUTC convertida a la hora local del país.
	EsPaisParticipante    -> 1 si el país es el de la selección local o visitante del partido
	                         (primer criterio de priorización); 0 en caso contrario o si el cruce
	                         aún no está definido.
Criterios:
	- Prime time: hora local >= 19 y < 23 (19:00:00 entra, 23:00:00 no entra). Alcanza con
	  DATEPART(HOUR) porque la hora es entera y FechaHoraUTC no tiene fracciones.
	- La hora local sale de FechaHoraUTC (AT TIME ZONE 'UTC') convertida con AT TIME ZONE a la
	  zona del país; esa conversión aplica el horario de verano vigente en esa fecha.
	- Cada país tiene una única zona (HusoHorarioComercial).
	- Feriados: fuera de alcance (no hay tabla de feriados).
	- Solo devuelve mercados en prime time: un país participante o de alto PBI fuera de franja
	  no aparece (el SP de asignación debe tomarlos directamente de Seleccion/Pais).
	- HusoHorarioComercial debe ser un nombre válido de sys.time_zone_info (se valida en el ABM
	  de País); la función no puede validarlo y un nombre inválido hace fallar la consulta.
	- Función inline: no admite variables, por eso la franja se fija en la cláusula VALUES.
*/
CREATE OR ALTER FUNCTION nucleo.fn_MercadosEnPrimeTime (@IdPartido SMALLINT)
RETURNS TABLE
AS
RETURN
(
	SELECT pa.IdPartido,
	       pais.IdPais,
	       pais.Nombre,
	       pais.CodigoISO3,
	       pais.PBIPerCapitaUSD,
	       pais.HusoHorarioComercial,
	       CAST(hl.HoraLocal AS DATETIME2(0)) AS FechaHoraLocalMercado,
	       CAST(CASE WHEN EXISTS (SELECT 1
	                              FROM nucleo.Seleccion AS s
	                              WHERE s.IdPais = pais.IdPais
	                                AND s.IdSeleccion IN (pa.IdSeleccionLocal, pa.IdSeleccionVisitante))
	                 THEN 1 ELSE 0 END AS BIT) AS EsPaisParticipante
	FROM nucleo.Partido AS pa
	CROSS JOIN nucleo.Pais AS pais
	CROSS APPLY (VALUES (19, 23)) AS franja (HoraDesde, HoraHasta)
	CROSS APPLY (SELECT (pa.FechaHoraUTC AT TIME ZONE 'UTC') AT TIME ZONE pais.HusoHorarioComercial AS HoraLocal) AS hl
	WHERE pa.IdPartido = @IdPartido
	  AND DATEPART(HOUR, hl.HoraLocal) >= franja.HoraDesde
	  AND DATEPART(HOUR, hl.HoraLocal) <  franja.HoraHasta
);
GO

/*
nucleo.fn_SeleccionesDelPartido
Propósito: devolver las selecciones que disputan un partido.
Parámetros:
	@IdPartido: partido a consultar.
Columnas devueltas:
	IdSeleccion -> selección local o visitante.
	Localia     -> 'Local' o 'Visitante'.
Criterios:
	- Una fila por selección definida; 0 filas si el cruce aún no está definido
	  (IdSeleccionLocal / IdSeleccionVisitante NULL) o si el partido no existe.
*/
CREATE OR ALTER FUNCTION nucleo.fn_SeleccionesDelPartido (@IdPartido SMALLINT)
RETURNS TABLE
AS
RETURN
(
	SELECT p.IdSeleccionLocal AS IdSeleccion,
	       CAST('Local' AS VARCHAR(9)) AS Localia
	FROM nucleo.Partido AS p
	WHERE p.IdPartido = @IdPartido
	  AND p.IdSeleccionLocal IS NOT NULL

	UNION ALL

	SELECT p.IdSeleccionVisitante,
	       CAST('Visitante' AS VARCHAR(9))
	FROM nucleo.Partido AS p
	WHERE p.IdPartido = @IdPartido
	  AND p.IdSeleccionVisitante IS NOT NULL
);
GO

/*
nucleo.fn_SeleccionConPartidoCercano
Propósito: aplicar en un solo lugar la regla de descanso entre partidos de una selección (la usan
           nucleo.SP_ALTA_Partido, nucleo.SP_MODIFICACION_Partido y nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO).
Parámetros:
	@IdSeleccionLocal, @IdSeleccionVisitante: selecciones a evaluar (alguna puede ser NULL).
	@FechaHoraUTC:                            instante UTC del partido que se quiere programar.
	@IdPartidoExcluido:                       partido que no se compara (el propio, al modificar o asignar
	                                          un cruce); NULL si no hay que excluir ninguno.
Columnas devueltas (una fila por cada partido conflictivo de cada selección):
	IdSeleccion        -> selección con un partido cercano.
	IdPartidoCercano   -> partido que está a menos de HorasDescanso del horario evaluado.
	HorasDescanso      -> horas mínimas entre los inicios de dos partidos de una selección (48).
Criterios:
	- Hay conflicto si el otro partido empieza estrictamente a menos de 48 horas (antes o después):
	  a exactamente 48 horas no hay conflicto.
	- Se comparan todos los partidos de la selección, de cualquier fase y estado, como local o visitante.
	- 0 filas si no hay conflictos (o si ambas selecciones son NULL).
	- La regla vive solo acá: para cambiar las 48 horas se modifica este valor, que aparece tres veces
	  en la función (los dos DATEADD y la columna HorasDescanso).
*/
CREATE OR ALTER FUNCTION nucleo.fn_SeleccionConPartidoCercano
(
	@IdSeleccionLocal     INT,
	@IdSeleccionVisitante INT,
	@FechaHoraUTC         DATETIME2(0),
	@IdPartidoExcluido    INT
)
RETURNS TABLE
AS
RETURN
(
	SELECT s.IdSeleccion,
	       p.IdPartido AS IdPartidoCercano,
	       CAST(48 AS INT) AS HorasDescanso
	FROM (VALUES (@IdSeleccionLocal), (@IdSeleccionVisitante)) AS s(IdSeleccion)
	INNER JOIN nucleo.Partido AS p
	        ON s.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
	WHERE s.IdSeleccion IS NOT NULL
	  AND (@IdPartidoExcluido IS NULL OR p.IdPartido <> @IdPartidoExcluido)
	  AND p.FechaHoraUTC > DATEADD(HOUR, -48, @FechaHoraUTC)
	  AND p.FechaHoraUTC < DATEADD(HOUR,  48, @FechaHoraUTC)
);
GO

/*
nucleo.fn_PartidoTieneRegistros
Propósito: saber qué registros asociados tiene un partido, para impedir que se lo elimine o que se
           le cambien las selecciones, la fase, la sede o el horario (los usan nucleo.SP_BAJA_Partido,
           nucleo.SP_MODIFICACION_Partido y nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO).
Parámetros:
	@IdPartido: partido a evaluar.
Columnas devueltas (SIEMPRE una fila; con un partido inexistente todo es 0):
	TieneFormaciones, TieneSustituciones, TieneGoles, TieneAmonestaciones, TieneDesignaciones,
	TieneSanciones (sanciones de las designaciones del partido), TieneEspacios (espacios publicitarios),
	TieneAlguno -> 1 si tiene cualquiera de los anteriores.
*/
CREATE OR ALTER FUNCTION nucleo.fn_PartidoTieneRegistros (@IdPartido INT)
RETURNS TABLE
AS
RETURN
(
	SELECT r.TieneFormaciones, r.TieneSustituciones, r.TieneGoles, r.TieneAmonestaciones,
	       r.TieneDesignaciones, r.TieneSanciones, r.TieneEspacios,
	       CAST(CASE WHEN r.TieneFormaciones = 1 OR r.TieneSustituciones = 1 OR r.TieneGoles = 1
	                   OR r.TieneAmonestaciones = 1 OR r.TieneDesignaciones = 1 OR r.TieneSanciones = 1
	                   OR r.TieneEspacios = 1
	                 THEN 1 ELSE 0 END AS BIT) AS TieneAlguno
	FROM (
		SELECT CAST(CASE WHEN EXISTS (SELECT 1 FROM jugadores.Formacion WHERE IdPartido = @IdPartido)
		                 THEN 1 ELSE 0 END AS BIT) AS TieneFormaciones,
		       CAST(CASE WHEN EXISTS (SELECT 1 FROM jugadores.Sustitucion WHERE IdPartido = @IdPartido)
		                 THEN 1 ELSE 0 END AS BIT) AS TieneSustituciones,
		       CAST(CASE WHEN EXISTS (SELECT 1 FROM eventos.Gol WHERE IdPartido = @IdPartido)
		                 THEN 1 ELSE 0 END AS BIT) AS TieneGoles,
		       CAST(CASE WHEN EXISTS (SELECT 1 FROM eventos.Amonestacion WHERE IdPartido = @IdPartido)
		                 THEN 1 ELSE 0 END AS BIT) AS TieneAmonestaciones,
		       CAST(CASE WHEN EXISTS (SELECT 1 FROM nucleo.DesignacionArbitral WHERE IdPartido = @IdPartido)
		                 THEN 1 ELSE 0 END AS BIT) AS TieneDesignaciones,
		       CAST(CASE WHEN EXISTS (SELECT 1
		                              FROM nucleo.Sancion AS sa
		                              INNER JOIN nucleo.DesignacionArbitral AS d ON d.IdDesignacionArbitral = sa.IdDesignacionArbitral
		                              WHERE d.IdPartido = @IdPartido)
		                 THEN 1 ELSE 0 END AS BIT) AS TieneSanciones,
		       CAST(CASE WHEN EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE IdPartido = @IdPartido)
		                 THEN 1 ELSE 0 END AS BIT) AS TieneEspacios
	) AS r
);
GO

/*
nucleo.fn_IdArbitroPorNombre / nucleo.fn_IdStaffPorNombre
Propósito: devolver el Id del árbitro (o integrante del staff técnico) con ese nombre y apellido,
	o NULL si no existe. Si hay homónimos devuelve el de menor Id.
nucleo.fn_NombreArbitro / nucleo.fn_NombreStaff
Propósito: devolver el nombre y apellido visible de un árbitro (o integrante del staff técnico).
Versión inicial: comparan y devuelven la columna NombreApellido en texto plano. El script
31_Seguridad_Cifrado.sql las redefine (CREATE OR ALTER) para buscar por hash y descifrar.
*/
CREATE OR ALTER FUNCTION nucleo.fn_IdArbitroPorNombre (@nombreApellido VARCHAR(200))
RETURNS INT
AS
BEGIN
	RETURN (SELECT TOP (1) IdArbitro FROM nucleo.Arbitro
	        WHERE NombreApellido = LTRIM(RTRIM(@nombreApellido)) ORDER BY IdArbitro);
END;
GO

CREATE OR ALTER FUNCTION nucleo.fn_IdStaffPorNombre (@nombreApellido VARCHAR(200))
RETURNS INT
AS
BEGIN
	RETURN (SELECT TOP (1) IdStaffTecnico FROM nucleo.StaffTecnico
	        WHERE NombreApellido = LTRIM(RTRIM(@nombreApellido)) ORDER BY IdStaffTecnico);
END;
GO

CREATE OR ALTER FUNCTION nucleo.fn_NombreArbitro (@idArbitro INT)
RETURNS VARCHAR(200)
AS
BEGIN
	RETURN (SELECT NombreApellido FROM nucleo.Arbitro WHERE IdArbitro = @idArbitro);
END;
GO

CREATE OR ALTER FUNCTION nucleo.fn_NombreStaff (@idStaffTecnico INT)
RETURNS VARCHAR(200)
AS
BEGIN
	RETURN (SELECT NombreApellido FROM nucleo.StaffTecnico WHERE IdStaffTecnico = @idStaffTecnico);
END;
GO
