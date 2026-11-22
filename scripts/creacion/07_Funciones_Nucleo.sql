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
