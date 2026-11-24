/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Chungara Tenorio, Denis Abner
Fecha: 2026-11-22
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Ejecutar y validar los 7 Stored Procedures de reportes de la Entrega 7
          (scripts/creacion/30_SP_Reportes.sql), indicando en comentarios el resultado
          esperado para cada prueba.
          Prerrequisito: tener ejecutados los scripts de creación (00_Reset_Total.sql)
          y los scripts de carga de datos (seed / importación).
*/

USE MundialFutbol;
GO

-- =========================================================================
-- TEST 1: eventos.SP_REPORTE_GOLEADORES
-- =========================================================================

-- 1A. Tabla general de goleadores del torneo (sin goles en contra ni tanda de penales)
-- Resultado esperado:
--   Listado ordenado por PuestoTorneo ASC (DENSE_RANK por goles y asistencias en el
--   torneo), desglosando por jugador y fase sus goles totales en la fase, tipo de
--   definición (Jugada, Cabezazo, Penal, Tiro Libre), asistencias en la fase,
--   acumulado individual en el torneo (TotalGolesJugadorTorneo) y goles totales
--   de su selección (TotalGolesSeleccionTorneo).
EXEC eventos.SP_REPORTE_GOLEADORES;
GO

-- 1B. Filtrado por selección ('ARG') e incluyendo goles en contra (@incluirEnContra = 1)
-- Resultado esperado:
--   Solo filas de jugadores convocados en 'ARG'. Si existen goles en contra, se
--   muestran en la columna GolesEnContra sin alterar el conteo de goles válidos
--   del jugador.
EXEC eventos.SP_REPORTE_GOLEADORES
    @codigoFIFA      = 'ARG',
    @incluirEnContra = 1;
GO

-- 1C. Filtrado por fase (IdFase = 1 -> Fase de grupos)
-- Resultado esperado:
--   Muestra los goleadores de la Fase de grupos manteniendo en TotalGolesJugadorTorneo
--   y PuestoTorneo sus valores acumulados en todo el campeonato.
EXEC eventos.SP_REPORTE_GOLEADORES
    @idFase = 1;
GO

-- =========================================================================
-- TEST 2: eventos.SP_REPORTE_TARJETAS_SUSPENSIONES
-- =========================================================================

-- 2A. Resumen general de tarjetas por selección y jugador
-- Resultado esperado:
--   Una fila por cada jugador que recibió al menos una tarjeta, mostrando el
--   conteo de Amarillas, AmarillasAcumulables, RojasDobleAmarilla, RojasDirectas,
--   TotalTarjetas, la bandera SuspensionActivaAcumulacion (1/0), la cantidad de
--   PartidosPendientesPorAcumulacion y el detalle textual del encuentro que originó
--   la sanción junto con el próximo partido programado a cumplir. Los jugadores
--   con suspensión activa aparecen primero.
EXEC eventos.SP_REPORTE_TARJETAS_SUSPENSIONES;
GO

-- 2B. Filtro exclusivo de jugadores con suspensión activa por acumulación
-- Resultado esperado:
--   Devuelve únicamente los jugadores que actualmente adeudan al menos una fecha
--   de suspensión por acumulación de tarjetas amarillas (caso obligatorio de los
--   criterios de aceptación del TP).
EXEC eventos.SP_REPORTE_TARJETAS_SUSPENSIONES
    @soloConSuspensionActiva = 1;
GO

-- =========================================================================
-- TEST 3: nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES (FORMATO XML #1)
-- =========================================================================

-- 3A. Nómina completa de árbitros, partidos designados y tarjetas señaladas en XML
-- Resultado esperado:
--   Documento XML tipado con nodo raíz <DesignacionesArbitrales> y elementos
--   <Arbitro IdArbitro="..." Habilitado="Si|No">. Cada árbitro incluye sus datos
--   personales, idiomas, bloque <Resumen> (total de designaciones, partidos como
--   Principal, amarillas y expulsiones señaladas) y <PartidosDesignados>/<Partido>.
--   En los partidos donde actuó como 'Principal', se anida <TarjetasSenaladas> con
--   cada tarjeta amarilla/roja exhibida (minuto, tipo, sancionado, selección, motivo).
EXEC nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES;
GO

-- 3B. Filtrado por árbitro específico (@idArbitro = 1)
-- Resultado esperado:
--   Documento XML con un único nodo <Arbitro IdArbitro="1"> y sus encuentros.
EXEC nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES
    @idArbitro = 1;
GO

-- =========================================================================
-- TEST 4: publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA
-- =========================================================================

-- 4A. Detalle de ocupación e ingresos en todas las sedes y partidos
-- Resultado esperado:
--   Devuelve 2 conjuntos de resultados:
--   - Result set 1: exactamente 4 filas por cada partido (NumeroEspacio 1 a 4),
--     indicando EstadoEspacio ('Ocupado' o 'Libre'), Anunciante, PaisAnunciante,
--     PiezaPublicitaria, IdiomaPieza, TarifaPublicitaria, Moneda y porcentaje de
--     ocupación del encuentro.
--   - Result set 2: resumen agrupado por Sede y Moneda con PartidosEnSede,
--     CuposTotalesSede (partidos * 4), TotalEspaciosOcupadosSede, PorcentajeOcupacionSede,
--     EspaciosEnMoneda e IngresosGenerados discriminados por moneda.
EXEC publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA;
GO

-- 4B. Filtrado por una sede puntual (@idSede = 1)
-- Resultado esperado:
--   Ambos conjuntos de resultados acotados a los encuentros disputados en IdSede = 1.
EXEC publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA
    @idSede = 1;
GO

-- =========================================================================
-- TEST 5: publicidad.SP_REPORTE_MATRIZ_PRIME_TIME (PIVOT ESTÁTICO)
-- =========================================================================

-- 5A. Matriz cruzada completa de partidos vs. mercados por código ISO3
-- Resultado esperado:
--   Tabla pivotada en T-SQL estático con una fila por partido (IdPartido,
--   NumeroPartido, Fase, FechaHoraUTC, Encuentro, TotalMercadosPrimeTime,
--   MercadosEnPrimeTimeDetalle) y columnas por mercado ISO3 ([ALG]..[WAL]).
--   Cada celda muestra 'SI (HH:MM)' si el país está cargado en nucleo.Pais y
--   su hora local cae entre 19:00 y 22:59, 'NO' si está cargado pero fuera de
--   prime time, o 'N/D' si el código aún no figura en nucleo.Pais.
EXEC publicidad.SP_REPORTE_MATRIZ_PRIME_TIME;
GO

-- 5B. Matriz filtrada por Fase de grupos (@idFase = 1)
-- Resultado esperado:
--   Misma estructura cruzada acotada a los partidos de Fase de grupos.
EXEC publicidad.SP_REPORTE_MATRIZ_PRIME_TIME
    @idFase = 1;
GO

-- =========================================================================
-- TEST 6: jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS (FORMATO XML #2)
-- =========================================================================

-- 6A. Listado de selecciones con cuerpo técnico y vector anidado de convocados
-- Resultado esperado:
--   Documento XML tipado con nodo raíz <SeleccionesYPlantillas> y elementos
--   <Seleccion CodigoFIFA="..." Grupo="..."> ordenados por grupo y ranking FIFA.
--   Cada selección contiene <CuerpoTecnico>/<Integrante> y el vector anidado
--   <Convocados>/<Jugador Dorsal="..."> con <Nombre>, <Posicion>, <Club>,
--   <Dorsal>, <FechaAlta> y <EstadoConvocatoria> ('Activo').
EXEC jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS;
GO

-- 6B. Filtrado por selección ('ARG') incluyendo bajas de convocatoria (@incluirBajas = 1)
-- Resultado esperado:
--   XML de la selección 'ARG' mostrando tanto los jugadores activos como aquellos
--   dados de baja por lesión/reemplazo con su fecha y motivo en <EstadoConvocatoria>.
EXEC jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS
    @codigoFIFA   = 'ARG',
    @incluirBajas = 1;
GO

-- =========================================================================
-- TEST 7: nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS
-- =========================================================================

-- 7A. Cronograma completo de encuentros con resultados, horarios y asistencia
-- Resultado esperado:
--   Listado cronológico de todos los partidos con Fase, Instancia (Grupo o
--   Eliminación directa), FechaHoraUTC, FechaHoraLocalSede convertida al huso
--   horario de la ciudad sede, Estadio, Marcador (incluyendo definición por
--   penales cuando corresponde), Ganador, ConcurrenciaPublico, CapacidadEstadio,
--   PorcentajeOcupacionEstadio y ArbitroPrincipal.
EXEC nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS;
GO

-- 7B. Filtrado por partidos finalizados (@estado = 'Finalizado')
-- Resultado esperado:
--   Devuelve únicamente los encuentros ya disputados con sus marcadores y ganadores.
EXEC nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS
    @estado = 'Finalizado';
GO
