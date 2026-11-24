# Entrega 6 — Procesos de Importación

**Universidad Nacional de La Matanza — Bases de Datos Aplicadas — Grupo 05**
**Fecha:** 2026-11-24

**Integrantes:**
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón

**Motor:** SQL Server (T-SQL). Base de datos `MundialFutbol`.

Este documento describe los procesos de importación del sistema de registro y gestión del Mundial de Fútbol, con foco en los módulos de **núcleo y publicidad** (secciones H e I del enunciado). Las importaciones de jugadores y eventos (módulos de Mateo) se resumen en la sección 5 para dar el panorama completo.

---

## 1. Objetivo y alcance

Importar información masiva a la base mediante stored procedures, tomando los archivos **tal cual se proveen** (CSV, JSON de APIs o XML) y sin modificarlos con herramientas externas. Los únicos pasos externos a SQL Server son las **descargas y el scraping** (scripts de Python que solo bajan datos); todo el procesamiento, la validación, la conversión de moneda y la carga se hacen en T-SQL.

| Importación | Fuente | SP | Módulo |
|---|---|---|---|
| PBI per cápita | API Banco Mundial (JSON) | `nucleo.SP_IMPORTAR_PBI_JSON` | núcleo |
| Cotizaciones | API Frankfurter (JSON) | `publicidad.SP_IMPORTAR_COTIZACIONES_JSON` | publicidad |
| Fixture y sedes | Scraping (CSV) | `nucleo.SP_IMPORTAR_FIXTURE_CSV` | núcleo |
| Pauta publicitaria | JSON de pauta con montos en distintas monedas | `publicidad.SP_IMPORTAR_PAUTA_JSON` | publicidad |
| Campañas del dossier | Scraping de `dossiermundial.netlify.app` (CSV) | `publicidad.SP_IMPORTAR_CAMPANIAS_CSV` | publicidad |
| Convocatoria | XML | `jugadores.SP_IMPORTAR_CONVOCATORIA_XML` | jugadores |
| Eventos de partido | CSV | `eventos.SP_IMPORTAR_EVENTOS_CSV` | eventos |

---

## 2. Cumplimiento de la consigna (Entrega 6)

| Requisito del enunciado | Cómo se cumple |
|---|---|
| Importar información masiva mediante SP | Cada fuente tiene su SP (tabla anterior). |
| Procesar CSV, XML o Excel tal cual se proveen | Los CSV se cargan con `BULK INSERT` estático a tablas de staging; los JSON con `OPENROWSET(BULK ..., SINGLE_CLOB)`; el XML con `OPENROWSET` y `.nodes()`. No se editan los archivos. |
| Descargar o scrapear un archivo e importarlo en la defensa | `scraping_dossier.py` regenera `campanas_dossier.csv` desde la web y `08_Importar_Campanias_Dossier.sql` lo importa (ver sección 8). |
| Upsert sin duplicados | Todos los SP buscan por **clave natural** y hacen alta si no existe, modificación si cambió algo y nada si el dato es idéntico. Re-ejecutar el mismo archivo no falla ni duplica. |
| Mantener el registro cuando es información histórica | Los espacios publicitarios de partidos **finalizados** son inmutables: ni el alta, ni la modificación, ni la baja se permiten. Una importación que traiga un dato distinto para un partido finalizado se rechaza y queda en el log (sección 6). Cada espacio guarda además un *snapshot* de tarifa y moneda, la fecha de asignación y el criterio aplicado. |
| Utilizar los SP de la Entrega 5 | Ningún SP de importación inserta ni actualiza tablas de negocio directamente: llaman a `SP_ALTA_*` y `SP_MODIFICACION_*` (por ejemplo `SP_ALTA_Anunciante`, `SP_ALTA_Campania`, `SP_ALTA_Pieza`, `SP_ALTA_OrientacionPais`, `SP_ALTA_EspacioPublicitario`, `SP_ALTA_Sede`, `SP_ALTA_Partido`). Las únicas escrituras directas son sobre tablas auxiliares: staging, log y `CotizacionMoneda`. |
| Conversión de moneda en T-SQL dentro del SP | `SP_IMPORTAR_PAUTA_JSON` convierte cada monto con `monto / tasa(origen) * tasa(destino)` usando `publicidad.CotizacionMoneda`, que carga `SP_IMPORTAR_COTIZACIONES_JSON` desde Frankfurter. |
| Importar registros correctos y reportar los errores | Importación **parcial**: cada fila se procesa en su propio `TRY/CATCH`; las inválidas van a `eventos.LogImportacion` con el dato crudo y el motivo, y el lote continúa. |
| Nombre de archivo como parámetro | Todos los SP reciben `@nombreArchivo`. Es obligatorio y se valida. |
| Archivos sin modificar con herramientas externas | Solo el scraping genera archivos; el resto se importa sin tocarlos. |
| Sin SQL dinámico, sin CLR | No se usa SQL dinámico ni cursores. Las rutas de archivos se resuelven con variables SQLCMD (`$(RUTA_IMP)`), de modo que el `BULK INSERT` sigue siendo estático. |

---

## 3. Arquitectura general

```
 Fuentes externas                Descarga (Python)              SQL Server (T-SQL)
 ----------------                -----------------              ------------------
 API Banco Mundial   ──┐
 API Frankfurter     ──┼──►  fuentes_externas.py  ──►  *.json / *.csv  ──┐
 Wikipedia (sedes)   ──┘                                                 │
 dossiermundial.netlify.app ─►  scraping_dossier.py ─►  campanas_dossier.csv ─┤
                                                                         ▼
                                              BULK INSERT / OPENROWSET (estático)
                                                                         ▼
                                              Staging (texto flexible, sin restricciones)
                                                                         ▼
                                  SP_IMPORTAR_*  (valida fila por fila, convierte, hace Upsert)
                                                                         ▼
                              SP_ALTA_* / SP_MODIFICACION_* (Entrega 5)  ──►  tablas de negocio
                                                                         │
                                        filas inválidas ──►  eventos.LogImportacion
```

Principios de diseño:

1. **Staging tolerante.** Las tablas de aterrizaje usan `VARCHAR` más anchos que los de destino a propósito: un texto demasiado largo llega a staging y el SP lo informa por fila, en vez de que el `BULK INSERT` lo trunque o falle en silencio.
2. **Vistas de aterrizaje.** `BULK INSERT` carga a través de una vista (`eventos.vw_CargaStagingFixture`, `publicidad.vw_CargaStagingCampania`, `eventos.vw_CargaStagingEvento`) que omite las columnas `IdFila` y `NombreArchivo`. `NombreArchivo` toma el default `'PENDIENTE'` y el lanzador lo reemplaza por el nombre real, así el SP puede filtrar por archivo.
3. **Validaciones en dos niveles.** Las validaciones generales (nombre de archivo, filas presentes, JSON válido, moneda destino existente) se agrupan en **un único mensaje** y abortan con `THROW 52000`. Las validaciones por fila se agrupan en un mensaje por fila y se guardan en el log.
4. **Clave natural.** Cada entidad se busca por su clave natural y no por Id.
5. **Idempotencia.** Solo se invoca `SP_MODIFICACION_*` cuando algún valor cambió.

---

## 4. Fuentes de datos y APIs

Ninguna fuente requiere API key.

| Fuente | Qué se obtiene | Endpoint | Límites y notas |
|---|---|---|---|
| **Banco Mundial** | PBI per cápita (indicador `NY.GDP.PCAP.CD`), proxy de poder adquisitivo para el ranking de publicidad | `https://api.worldbank.org/v2/country/<ISO2;...>/indicator/NY.GDP.PCAP.CD?format=json` | Se piden todos los países en un solo pedido. El SP toma el último año con valor no nulo. Se usa **ISO2** como clave porque algunos `CodigoISO3` del torneo son códigos FIFA (NED, GER, ENG, SUI, CHI). |
| **Frankfurter** | Tipos de cambio (base USD) para convertir la pauta | `https://api.frankfurter.app/latest?from=USD&to=EUR,BRL,JPY,GBP` | Un solo pedido. Publica cotizaciones del BCE, que **no incluyen ARS**: una fila de pauta en ARS falla con el mensaje "No hay cotización para convertir ARS a USD". |
| **Wikipedia** | Datos de sedes del Mundial 2026 (se complementan con capacidades y coordenadas incluidas en el script; con `--offline` no se scrapea) | `https://en.wikipedia.org/wiki/2026_FIFA_World_Cup` | Un pedido. Requiere `requests` y `beautifulsoup4` solo en modo en vivo. |
| **Dossier de publicidad** | 75 campañas publicitarias del Mundial (63 anunciantes) | `https://dossiermundial.netlify.app/`, que lee la base Firestore pública `repositorio2026-61a28`, colección `campanas`. Se lee el mismo endpoint REST: `https://firestore.googleapis.com/v1/projects/repositorio2026-61a28/databases/(default)/documents/campanas?pageSize=300` | Un solo pedido (`pageSize=300`); solo se pide otra página si la respuesta trae `nextPageToken`. Se envía un `User-Agent` identificatorio del grupo. **No se lee ni se guarda el campo `creditos`**, que contiene nombres de personas. |

**Fixture y pauta:** `fixture_sedes.csv` (9 sedes, 24 partidos) y `pauta_publicitaria.json` vienen en el repositorio. Las tarifas del seed son valores ficticios en USD, definidos por el grupo.

**Cómo regenerar los archivos:**

```bash
cd scripts/importacion
python fuentes_externas.py todo       # pbi_banco_mundial.json, cotizaciones_frankfurter.json, fixture_sedes.csv
python scraping_dossier.py            # campanas_dossier.csv
```

`pbi_banco_mundial.json` y `cotizaciones_frankfurter.json` **no** vienen en el repositorio: hay que generarlos antes de correr el lanzador.

---

## 5. Procedimientos de importación

Todos los SP devuelven por parámetros de salida `@filasProcesadas` y `@filasConError`, y los errores por fila se guardan en `eventos.LogImportacion`.

### 5.1 `nucleo.SP_IMPORTAR_PBI_JSON` — script 22

```sql
EXEC nucleo.SP_IMPORTAR_PBI_JSON
     @nombreArchivo   = 'pbi_banco_mundial.json',
     @contenidoJSON   = @json,
     @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
```

- **Entrada:** respuesta cruda de la API (arreglo `[metadatos, [registros]]`).
- **Clave natural:** `country.id` del Banco Mundial = `Pais.CodigoISO2`.
- **Upsert:** por país toma el último año con valor no nulo y actualiza `Pais.PBIPerCapitaUSD` con `SP_MODIFICACION_Pais`. Si el PBI no cambió, no vuelve a modificar.
- **Errores por fila:** las filas que no se pueden aplicar (por ejemplo, un país que no existe en la base) se registran en el log y el lote continúa.

### 5.2 `publicidad.SP_IMPORTAR_COTIZACIONES_JSON` — script 22

```sql
EXEC publicidad.SP_IMPORTAR_COTIZACIONES_JSON
     @nombreArchivo = 'cotizaciones_frankfurter.json', @contenidoJSON = @json,
     @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
```

- **Entrada:** `{"amount":1.0,"base":"USD","date":"AAAA-MM-DD","rates":{"EUR":0.86,...}}`.
- **Upsert:** en `publicidad.CotizacionMoneda` por `(MonedaBase, Moneda, Fecha)`. También guarda la cotización base→base = 1. Las cotizaciones de fechas anteriores **se conservan** (historial).
- **Validaciones generales (un mensaje):** moneda base inexistente, fecha inválida, JSON sin cotizaciones.
- **Errores por fila:** moneda que no existe en `publicidad.Moneda` o tasa nula o menor o igual a cero.

### 5.3 `nucleo.SP_IMPORTAR_FIXTURE_CSV` — script 22

```sql
EXEC nucleo.SP_IMPORTAR_FIXTURE_CSV
     @nombreArchivo = 'fixture_sedes.csv',
     @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
```

- **Entrada:** `eventos.StagingFixture`, cargada con `BULK INSERT` desde `fixture_sedes.csv`. Una fila = un partido con los datos de su sede.
- **Upsert por clave natural:** `Ciudad (Nombre, IdPais)`, `Sede (NombreEstadio, IdCiudad)` y `Partido (NumeroPartido)`.
- **Zonas horarias:** `FechaHoraLocal` es la hora local de la sede; `SP_ALTA_Partido` la convierte a UTC.
- Solo modifica lo que cambió, así no toca partidos finalizados cuando el dato es idéntico. En fases eliminatorias las selecciones se dejan vacías.

### 5.4 `publicidad.SP_IMPORTAR_PAUTA_JSON` — script 22

```sql
EXEC publicidad.SP_IMPORTAR_PAUTA_JSON
     @nombreArchivo = 'pauta_publicitaria.json', @contenidoJSON = @json,
     @monedaDestino = 'USD',
     @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT;
```

- **Entrada:** arreglo JSON `[{"numeroPartido":1,"numeroEspacio":1,"anunciante":"...","titulo":"...","idioma":"...","monto":150000,"moneda":"EUR"}, ...]`.
- **Conversión de moneda (en T-SQL):** `monto / tasa(origen) * tasa(destino)` con la última fecha que tenga ambas cotizaciones contra la misma base. Si origen y destino coinciden no se convierte.
- **Upsert:** el espacio `(IdPartido, NumeroEspacio)` se crea con `SP_ALTA_EspacioPublicitario`; si existe y algo cambió, se usa `SP_MODIFICACION_EspacioPublicitario`.
- **Pieza:** se busca por anunciante, campaña, título e idioma. Como el archivo no informa la campaña, si un anunciante tiene dos piezas con igual título e idioma se toma la de menor `IdPieza`.
- **Validaciones generales (un mensaje):** nombre de archivo, moneda destino inexistente, JSON inválido o vacío.
- **Errores por fila (un mensaje agrupado por fila):** partido inexistente, número de espacio fuera de 1–4, pieza inexistente, monto nulo/negativo, moneda de origen inexistente y falta de cotización.

### 5.5 `publicidad.SP_IMPORTAR_CAMPANIAS_CSV` — script 29

```sql
EXEC publicidad.SP_IMPORTAR_CAMPANIAS_CSV
     @nombreArchivo   = 'campanas_dossier.csv',
     @filasProcesadas = @ok OUTPUT, @filasConError = @err OUTPUT,
     @codigoISO3Pais  = 'ARG',     -- país de origen de los anunciantes
     @crearPiezas     = 1;         -- 1 = crea una pieza en español por campaña
```

**Mapeo del dossier al modelo** (`Anunciante 1-N Campania 1-N Pieza N-N Pais`):

| Columna del CSV | Destino |
|---|---|
| `Anunciante` | `publicidad.Anunciante.Nombre` |
| `Titulo` | `publicidad.Campania.Titulo` (y el título de la pieza si `@crearPiezas = 1`) |
| `Marca` | `publicidad.Campania.Marca` |
| `Agencia` | `publicidad.Campania.Agencia` |
| `Productora`, `Periodo`, `Categorias` | llegan a staging, **no se guardan** (el modelo no tiene dónde) |

- **País:** el dossier son campañas argentinas y no informa país. `@codigoISO3Pais` (por defecto `'ARG'`) es el país de origen de los anunciantes y, con `@crearPiezas = 1`, el país de orientación de la pieza. Así las piezas participan de `SP_ASIGNAR_PUBLICIDAD`.
- **Upsert por clave natural:** `Anunciante (Nombre)`, `Campania (IdAnunciante, Titulo)`, `Pieza (IdCampania, Titulo, IdIdioma)` y `OrientacionPais (IdPieza, IdPais)`. La comparación distingue mayúsculas y acentos. Solo se modifica lo que cambió.
- **Validaciones generales (un mensaje, `THROW 52000`):** nombre de archivo obligatorio, filas presentes en staging para ese archivo e idioma Español existente (solo si `@crearPiezas = 1`).
- **Errores por fila:** anunciante o título vacío o de más de 100 caracteres, marca o agencia de más de 100 caracteres y país de origen inexistente. Cada una queda en el log con el `IdFila` de staging y los datos crudos.
- **Idempotente:** un segundo run del mismo archivo no cambia ni duplica nada.

### 5.6 Importaciones de otros módulos (resumen)

- `jugadores.SP_IMPORTAR_CONVOCATORIA_XML` (script 23, Mateo): importa las convocatorias desde `planteles_convocatoria.xml`, con Upsert, reutilizando los SP de la Entrega 5 y registrando errores parciales. Lanzador: `01_Importar_Convocatoria_XML.sql`.
- `eventos.SP_IMPORTAR_EVENTOS_CSV` (script 24, Mateo): importa eventos de partido desde `eventos_partidos.csv` vía `eventos.StagingEvento`, con Upsert y errores parciales. Lanzador: `02_Importar_Eventos_CSV.sql`.

---

## 6. Tablas auxiliares: staging y log

Definidas en `scripts/creacion/05_Tablas_Logs_Staging.sql`.

| Tabla | Uso |
|---|---|
| `eventos.StagingEvento` | Aterrizaje de `eventos_partidos.csv`. |
| `eventos.StagingFixture` | Aterrizaje de `fixture_sedes.csv`. |
| `publicidad.StagingCampania` | Aterrizaje de `campanas_dossier.csv`. Columnas: `IdFila`, `NombreArchivo` (default `'PENDIENTE'`), `Anunciante`, `Marca`, `Titulo`, `Agencia`, `Productora`, `Periodo`, `Categorias`. |
| `eventos.LogImportacion` | Registro persistente de errores: `IdLogImportacion`, `FechaHora`, `NombreArchivo`, `IdFilaStaging`, `DatosCrudos` y `MensajeError`. |

Para ver los errores de una importación:

```sql
SELECT FechaHora, NombreArchivo, IdFilaStaging, DatosCrudos, MensajeError
FROM eventos.LogImportacion
ORDER BY IdLogImportacion DESC;
```

---

## 7. Orden de ejecución y lanzadores

Los seeds y las importaciones tienen dependencias entre sí. El lanzador `scripts/importacion/00_Cargar_Seeds.sql` los ejecuta en el orden que funciona y se detiene ante el primer error (`:on error exit`):

| Paso | Script | Qué hace |
|---|---|---|
| 1 | `04_Seed_Nucleo_Publicidad.sql` | Países, selecciones, árbitros, anunciantes (9 países), campañas, piezas, tarifas por fase y regla de cupos. |
| 2 | `05_Importar_Nucleo_Publicidad.sql` | Importa PBI, fixture, cotizaciones y pauta. |
| 3 | `06_Seed_Designaciones_Publicidad.sql` | Designaciones arbitrales y asignación de publicidad. |
| 4 | `01_Importar_Convocatoria_XML.sql` | Convocatoria desde XML. Va antes que el 03: el 03 completa solo los dorsales que el XML deja libres. |
| 5 | `03_Seed_Jugadores_Eventos.sql` | Jugadores, formaciones y eventos. |
| 6 | `02_Importar_Eventos_CSV.sql` | Eventos desde CSV. |
| 7 | `07_Cierre_Resultados_Partidos.sql` | Cierre de resultados de los partidos. |
| 8 | `08_Importar_Campanias_Dossier.sql` | Campañas del dossier. Va al final para no cambiar la pauta ya asignada en los partidos del seed. |

**Requisitos para ejecutarlo:**

1. Ejecutar antes `scripts/creacion/00_Reset_Total.sql`.
2. En SSMS activar **Consulta > Modo SQLCMD** (sin esto fallan `:setvar` y `:r`).
3. Editar la variable `RUTA_IMP` al inicio del lanzador con la carpeta `scripts\importacion` de la copia local, sin barra final. Es la única ruta a editar.
4. Generar los archivos de las APIs: `python fuentes_externas.py todo`.
5. Recomendado: resultados a texto (`Ctrl+T`).

**Importante:** los seeds se ejecutan **una sola vez** tras el reset. En una segunda corrida, `02_Importar_Eventos_CSV` informa 8 errores porque el partido 1 ya está finalizado y sus eventos no pueden modificarse: es el bloqueo de historial funcionando, no un fallo.

---

## 8. Importación en vivo (defensa del TP)

Para demostrar la importación de un archivo scrapeado en el momento:

```bash
cd scripts/importacion
python scraping_dossier.py            # regenera campanas_dossier.csv desde la web
```

Luego, en SSMS con modo SQLCMD, abrir `08_Importar_Campanias_Dossier.sql`, **descomentar y editar** la línea `:setvar RUTA_IMP "..."` y ejecutarlo. El script:

1. borra de staging las cargas previas del mismo archivo,
2. carga el CSV con `BULK INSERT` estático,
3. renombra `'PENDIENTE'` por el nombre del archivo,
4. llama a `SP_IMPORTAR_CAMPANIAS_CSV` con el nombre del archivo como parámetro,
5. muestra procesadas, con error y totales.

Se puede ejecutar de nuevo para mostrar la idempotencia (no hay duplicados).

---

## 9. Testing

Todos los scripts de testing corren dentro de una transacción que se deshace al final (`ROLLBACK`) y no dejan datos. El resultado correcto es que **no aparezca `FALLÓ`** en la pestaña Mensajes. El runner `scripts/testing/00_Ejecutar_Tests.sql` ejecuta toda la suite.

| Test | Cubre |
|---|---|
| `22_Test_SP_Importacion_Nucleo_Publicidad.sql` | Fixture, PBI, cotizaciones y pauta: lote mixto con errores parciales en el log, re-ejecución idempotente, modificación de datos existentes, conversión de moneda y validaciones de entrada. Los JSON del test son datos de prueba con el formato de las APIs, no respuestas reales. |
| `29_Test_SP_Importacion_Campanias.sql` | Validaciones generales agrupadas; primera corrida (2 anunciantes, 3 campañas, 3 piezas, 3 orientaciones, 4 filas procesadas y 5 inválidas en el log, con acentos conservados); segunda corrida sin cambios ni duplicados; modificación de marca y agencia; país de origen inexistente; `@crearPiezas = 0`; anunciante existente con otro país. |
| `23_Test_SP_Importacion_Jugadores.sql` y `24_Test_SP_Importacion_Eventos.sql` | Importaciones de convocatoria y eventos. |

Los tests 22 y 29 cubren el caso obligatorio de **importación con errores parciales** (filas inválidas registradas en el log junto con filas válidas cargadas). Para el criterio de aceptación de **anunciantes de al menos 6 países**, el seed `04_Seed_Nucleo_Publicidad.sql` carga 9 anunciantes de 9 países.

---

## 10. Decisiones de diseño y limitaciones conocidas

- **Descarga fuera de SQL Server.** La consigna prohíbe scripts o software externos al motor en la Entrega 5, pero la Entrega 6 admite el scraping. Los scripts de Python **solo descargan**; todo el procesamiento es T-SQL. No se usa `sp_OACreate` ni CLR para llamar a las APIs desde el motor.
- **ARS sin cotización.** Frankfurter no publica el peso argentino. Una fila de pauta en ARS queda en el log con un mensaje claro. Si se necesitara, bastaría con cargar la cotización en `CotizacionMoneda` desde otra fuente.
- **Campos del dossier no guardados.** `Productora`, `Periodo` y `Categorias` llegan a staging pero el modelo no tiene dónde guardarlos. `creditos` (nombres de personas) nunca se lee.
- **País de los anunciantes del dossier.** El dossier no informa país; se asume Argentina (parámetro `@codigoISO3Pais`).
- **Campaña de la pieza en la pauta.** El JSON de pauta no informa la campaña; si hay ambigüedad se toma la pieza de menor `IdPieza`.
- **Codificación.** Los `BULK INSERT` usan `CODEPAGE = '65001'` (UTF-8), pensado para Windows/SSMS. En SQL Server para Linux ese valor no está soportado, por lo que las pruebas en Docker se hicieron con una copia temporal ajustada. **Falta confirmar en Windows** que los acentos se cargan bien. Los scripts 25–28 y el runner de testing están guardados en ISO-8859-1 y el resto en UTF-8.
- **Fixture real.** `fixture_sedes.csv` combina el scraping de sedes con un fixture de 24 partidos definido por el grupo para el juego de datos. El fixture oficial completo del torneo no se importa.
