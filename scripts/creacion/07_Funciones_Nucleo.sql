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
Objetivo: Funciones del núcleo:
          - jugadores.fn_SeleccionesDelPartido(@idPartido): selecciones que disputan un partido
            (la usa nucleo.SP_CONTROL_ARBITRAL).
          - nucleo.fn_MercadosEnPrimeTime(@idPartido): países (mercados) donde el horario del
            partido cae en prime time (19:00 a 22:59 hora local del país).
*/

USE MundialFutbol;
GO

-- Devuelve una fila por selección definida del partido (0 filas si el cruce aún no está definido).
CREATE OR ALTER FUNCTION jugadores.fn_SeleccionesDelPartido (@idPartido INT)
RETURNS TABLE
AS
RETURN
(
    SELECT p.IdSeleccionLocal AS IdSeleccion,
           CAST('Local' AS VARCHAR(9)) AS Localia
    FROM nucleo.Partido AS p
    WHERE p.IdPartido = @idPartido
      AND p.IdSeleccionLocal IS NOT NULL

    UNION ALL

    SELECT p.IdSeleccionVisitante,
           CAST('Visitante' AS VARCHAR(9))
    FROM nucleo.Partido AS p
    WHERE p.IdPartido = @idPartido
      AND p.IdSeleccionVisitante IS NOT NULL
);
GO

/*
Prime time: hora local del país >= 19 y < 23 (valores fijos en la función porque una
función inline no puede declarar variables; si el criterio cambia, se modifica acá).
La hora local sale de FechaHoraUTC convertida a la zona horaria registrada del país
(AT TIME ZONE contempla horario de verano). Cada país tiene una única zona.
Devuelve solo los mercados en prime time; EsPaisParticipante marca los países de las
selecciones que juegan (primer criterio de priorización de publicidad).
*/
CREATE OR ALTER FUNCTION nucleo.fn_MercadosEnPrimeTime (@idPartido INT)
RETURNS TABLE
AS
RETURN
(
    SELECT pa.IdPartido,
           pais.IdPais,
           pais.Nombre      AS Pais,
           pais.CodigoISO3,
           pais.ZonaHoraria,
           CAST(hl.HoraLocal AS DATETIME2(0)) AS FechaHoraLocalMercado,
           CAST(CASE WHEN EXISTS (SELECT 1
                                  FROM jugadores.fn_SeleccionesDelPartido(pa.IdPartido) AS sp
                                  INNER JOIN nucleo.Seleccion AS s ON s.IdSeleccion = sp.IdSeleccion
                                  WHERE s.IdPais = pais.IdPais)
                     THEN 1 ELSE 0 END AS BIT) AS EsPaisParticipante
    FROM nucleo.Partido AS pa
    CROSS JOIN nucleo.Pais AS pais
    CROSS APPLY (SELECT (pa.FechaHoraUTC AT TIME ZONE 'UTC') AT TIME ZONE pais.ZonaHoraria AS HoraLocal) AS hl
    WHERE pa.IdPartido = @idPartido
      AND DATEPART(HOUR, hl.HoraLocal) >= 19
      AND DATEPART(HOUR, hl.HoraLocal) <  23
);
GO
