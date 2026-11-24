# Entrega 7: Reportes Oficiales del Torneo

**Universidad Nacional de La Matanza**  
**Departamento de Ingeniería e Investigaciones Tecnológicas**  
**Asignatura:** 3641 – Bases de Datos Aplicadas  
**Comisión:** 01-2900  
**Grupo:** 05  
**Docentes:** HNATIUK, JAIR EZEQUIEL; PALOMARES, LUIS ALFONSO  
**Fecha:** 24 de noviembre de 2026  

---

### Integrantes

| Alumno | DNI | Usuario de GitHub |
|---|---|---|
| Casella, Mateo Ezequiel | - | MateoCasella |
| Chungara Tenorio, Denis Abner | - | DenisChungara |
| Torczuk, Elías Alexei | - | alexxe1 |
| Canseco Carrizo, Yamil Simón | - | yamilscc |

---

## 1. Introducción y Alcance

El presente documento detalla la implementación técnica de la capa analítica de **Reportes Oficiales** correspondiente a la **Entrega 7** de la base de datos `MundialFutbol`.

Se desarrollaron **siete (7) Stored Procedures** en `scripts/creacion/30_SP_Reportes.sql`, implementados íntegramente en **T-SQL estático** (sin uso de SQL dinámico), combinando salidas tabulares, una matriz cruzada mediante `PIVOT` estático y dos estructuras jerárquicas en formato **XML** (`FOR XML PATH`).

---

## 2. Principios Técnicos de Implementación

* **T-SQL Estático (sin SQL dinámico):** Todos los procedimientos están precompilados de forma estática, respetando la pauta de la cátedra, eliminando riesgos de inyección SQL y optimizando la reutilización de planes de ejecución.
* **Tolerancia a datos parciales:** Mediante `LEFT JOIN`, `OUTER APPLY` e `ISNULL`, los reportes devuelven resultados consistentes aun cuando el torneo se encuentre en curso o existan partidos pendientes de disputa.
* **Filtros opcionales:** Todos los procedimientos admiten parámetros de filtrado con valor por defecto (`NULL` o `0`), permitiendo consultar tanto el panorama completo del torneo como recortes específicos por selección, fase, sede, árbitro o partido.

---

## 3. Detalle de los 7 Reportes Implementados (`30_SP_Reportes.sql`)

```mermaid
flowchart LR
    subgraph "Reportes Tabulares (5)"
        R1["1. SP_REPORTE_GOLEADORES"]
        R2["2. SP_REPORTE_TARJETAS_SUSPENSIONES"]
        R4["4. SP_REPORTE_OCUPACION_PUBLICITARIA"]
        R5["5. SP_REPORTE_MATRIZ_PRIME_TIME (PIVOT)"]
        R7["7. SP_REPORTE_RESULTADOS_ENCUENTROS"]
    end
    subgraph "Reportes XML Jerárquicos (2)"
        R3["3. SP_REPORTE_DESIGNACIONES_ARBITRALES"]
        R6["6. SP_REPORTE_SELECCIONES_PLANTILLAS"]
    end
```

### 3.1 `eventos.SP_REPORTE_GOLEADORES` (Tabular)
* **Parámetros:** `@codigoFIFA CHAR(3) = NULL`, `@idFase TINYINT = NULL`, `@incluirEnContra BIT = 0`.
* **Lógica:** Excluye los goles convertidos en `Definicion por Penales` (en coherencia con `eventos.fn_ResultadoPartido`). Desglosa por jugador y fase los goles según tipo (`Jugada`, `Cabezazo`, `Penal`, `Tiro Libre` y opcionalmente `En contra` sin sumarlos al total válido). Calcula asistencias, acumulados del torneo y puesto (`DENSE_RANK()`) mediante funciones ventana antes de aplicar los filtros opcionales.

### 3.2 `eventos.SP_REPORTE_TARJETAS_SUSPENSIONES` (Tabular)
* **Parámetros:** `@codigoFIFA CHAR(3) = NULL`, `@soloConSuspensionActiva BIT = 0`.
* **Lógica:** Contabiliza tarjetas amarillas, rojas por doble amarilla y rojas directas por selección y jugador. Determina si una suspensión por acumulación (`PartidosSuspension > 0`) sigue activa comparándola contra los partidos ya finalizados por su selección con posterioridad al encuentro de la tarjeta, e informa el próximo partido programado a cumplir (consistente con `eventos.fn_EstaSuspendido`).

### 3.3 `nucleo.SP_REPORTE_DESIGNACIONES_ARBITRALES` (XML #1)
* **Parámetros:** `@idArbitro SMALLINT = NULL`, `@idFase TINYINT = NULL`.
* **Estructura:** Genera un documento XML mediante `FOR XML PATH('Arbitro'), ROOT('DesignacionesArbitrales'), TYPE`. Incluye atributos de identificación y habilitación, país, categoría, idiomas agrupados con `STRING_AGG`, resumen de designaciones totales y como principal, y el detalle anidado de partidos junto con las amonestaciones/expulsiones señaladas cuando actuó como árbitro `Principal`.

### 3.4 `publicidad.SP_REPORTE_OCUPACION_PUBLICITARIA` (Tabular – 2 Result Sets)
* **Parámetros:** `@idSede TINYINT = NULL`, `@idPartido SMALLINT = NULL`.
* **Lógica:**
  * *Result set 1:* Detalle espacio por espacio (`1` a `4`) de cada partido y sede, indicando estado (`Ocupado`/`Libre`), anunciante, pieza publicitaria, idioma, tarifa, moneda y porcentaje de ocupación del encuentro.
  * *Result set 2:* Resumen consolidado de espacios ocupados e ingresos totales agrupados por **sede y moneda**, evitando sumar importes expresados en divisas distintas.

### 3.5 `publicidad.SP_REPORTE_MATRIZ_PRIME_TIME` (Tabular – `PIVOT` Estático)
* **Parámetros:** `@idPartido SMALLINT = NULL`, `@idFase TINYINT = NULL`.
* **Lógica:** Construye una tabla cruzada de partidos contra códigos ISO3 de mercados/países mediante el operador `PIVOT` estático, informando `'SI (HH:MM)'`, `'NO'` o `'N/D'`. Complementa la matriz con `TotalMercadosPrimeTime` y `MercadosEnPrimeTimeDetalle` calculados desde `nucleo.fn_MercadosEnPrimeTime`.

### 3.6 `jugadores.SP_REPORTE_SELECCIONES_PLANTILLAS` (XML #2)
* **Parámetros:** `@codigoFIFA CHAR(3) = NULL`, `@grupo CHAR(1) = NULL`, `@incluirBajas BIT = 0`.
* **Estructura:** Serializa con `FOR XML PATH('Seleccion'), ROOT('SeleccionesYPlantillas'), TYPE` cada selección (`@CodigoFIFA`, `@Grupo`, país, confederación, ranking FIFA, condición de anfitrión y cantidad de convocados activos), incluyendo el cuerpo técnico y el vector anidado de jugadores convocados con nombre, posición, club y dorsal.

### 3.7 `nucleo.SP_REPORTE_RESULTADOS_ENCUENTROS` (Tabular)
* **Parámetros:** `@idFase TINYINT = NULL`, `@codigoFIFA CHAR(3) = NULL`, `@estado VARCHAR(10) = NULL`.
* **Lógica:** Muestra el fixture completo con fecha/hora UTC y su conversión a hora local de la sede (`AT TIME ZONE`), instancia (grupo o eliminación directa), marcador reglamentario y de penales, selección ganadora, concurrencia, porcentaje de ocupación del estadio y árbitro principal designado.

---

## 4. Validación y Testing (`30_Test_SP_Reportes.sql`)

La verificación funcional se implementó en `scripts/testing/30_Test_SP_Reportes.sql`, integrado en el flujo maestro `00_Ejecutar_Tests.sql`. El script ejecuta y valida los 7 reportes tanto en consultas globales (sin filtros) como con combinaciones de parámetros opcionales (`@codigoFIFA`, `@idFase`, `@incluirEnContra`, `@soloConSuspensionActiva`, `@incluirBajas`, `@idSede`, `@idPartido`, `@estado`), documentando en comentarios el resultado esperado para cada caso.

---

## 5. Resumen de Archivos Incorporados al Repositorio

| Carpeta | Archivo | Descripción |
|---|---|---|
| `scripts/creacion/` | `30_SP_Reportes.sql` | Implementación en T-SQL estático de los 7 reportes oficiales (5 tabulares + 2 XML). |
| `scripts/testing/` | `30_Test_SP_Reportes.sql` | Pruebas integrales de los 7 reportes oficiales y sus filtros opcionales. |
| `doc/entrega7/` | `entrega7_reportes_oficiales.md` | Documento técnico formal de la Entrega 7 (Reportes Oficiales). |
