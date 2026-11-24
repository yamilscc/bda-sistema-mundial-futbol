# Sistema de registro y gestión del Mundial de Fútbol

**Universidad Nacional de La Matanza**
**Materia:** 3641 – Bases de Datos Aplicadas
**Comisión:** 01-2900
**Grupo:** 05
**Docentes:** HNATIUK, JAIR EZEQUIEL, PALOMARES, LUIS ALFONSO

Base de datos en **SQL Server (T-SQL)** para gestionar la operación de los partidos de un Mundial de Fútbol: sedes y partidos, convocatorias y alineaciones, eventos de juego (goles, tarjetas, suspensiones), designación de árbitros y asignación de publicidad según la audiencia de cada encuentro.

---

## Integrantes

| Alumno | Usuario de GitHub |
|---|---|
| Casella, Mateo Ezequiel | MateoCasella |
| Chungara Tenorio, Denis Abner | DenisChungara |
| Torczuk, Elías Alexei | alexxe1 |
| Canseco Carrizo, Yamil Simón | yamilscc |

---

## Requisitos

- Microsoft SQL Server 16.x
- SQL Server Management Studio (SSMS).

---

## Estructura del repositorio

```
.
├── README.md
├── doc/
│   └── nomenclaturas.md          # encabezado de scripts, commits, ramas y convenciones de nombres
└── scripts/
    ├── creacion/                 # scripts de creación (base, tablas, FK, funciones y SP)
    │   ├── 00_Reset_Total.sql    # maestro: borra y recrea la base, crea schemas y ejecuta el resto
    │   └── 01_… a 29_…           # un archivo por módulo, con prefijo numérico de orden de ejecución
    ├── testing/                  # scripts de testing (uno por cada script de creación probado)
    │   └── importacion/          # tests en espejo de scripts/importacion/ (ej. 03_Test_Seed_Jugadores_Eventos.sql)
    └── importacion/              # seeds e importaciones de datos externos (CSV/XML/API/scraping); 00_Cargar_Seeds.sql los lanza en orden
```

- Cada script empieza con dos dígitos que indican el orden de ejecución y con el encabezado definido en `doc/nomenclaturas.md`.
- Los scripts de `testing/` llevan el mismo número que el script de `creacion/` que prueban y tienen en comentarios el resultado esperado de cada caso.
- Schemas de la base `MundialFutbol`: `nucleo` (países, sedes, partidos, árbitros), `jugadores` (convocatoria, alineaciones, sustituciones), `eventos` (goles, tarjetas, suspensiones, staging y logs) y `publicidad` (monedas y cotizaciones, anunciantes, campañas, piezas, tarifas y espacios).

---

## Cómo ejecutar (corrida desde cero)

1. Abrir SSMS y activar el **modo SQLCMD** (menú *Consulta → Modo SQLCMD*).
2. Abrir `scripts/creacion/00_Reset_Total.sql` y editar la línea `:setvar RUTA "..."` con la ruta de la carpeta `scripts\creacion` de la copia local del repositorio (sin barra final).
3. Ejecutarlo. El script elimina la base `MundialFutbol` si existe, la recrea, crea los schemas y ejecuta en orden los scripts `01` a `29`. Si alguno falla, se corta en ese punto. Al final muestra un resumen de tablas, SP y funciones por schema.
4. Cargar los datos de `scripts/importacion/` con el lanzador `00_Cargar_Seeds.sql` (modo SQLCMD, editando `:setvar RUTA` con la carpeta `scripts\importacion`), que ejecuta en este orden y se corta ante el primer error: `04_Seed_Nucleo_Publicidad.sql` (también deja la regla de cupos de convocatoria), `05_Importar_Nucleo_Publicidad.sql` (requiere generar antes los archivos de las APIs, ver [Asignación de publicidad](#asignación-de-publicidad)), `06_Seed_Designaciones_Publicidad.sql`, `01_Importar_Convocatoria_XML.sql`, `03_Seed_Jugadores_Eventos.sql`, `02_Importar_Eventos_CSV.sql`, `07_Cierre_Resultados_Partidos.sql` y `08_Importar_Campanias_Dossier.sql` (campañas del dossier por scraping, ver [Campañas del dossier](#campañas-del-dossier-scraping)). El orden importa: el 01 va antes que el 03 porque el 03 completa solo los dorsales que el XML dejó libres, y el 04 va primero porque el 01 necesita la regla de cupos. Es idempotente: se puede ejecutar de nuevo. Si se prefiere correrlos a mano, el orden es el mismo; los que leen archivos llevan su propio `:setvar RUTA_IMP` con la carpeta `scripts\importacion`.
5. Ejecutar `scripts/testing/00_Ejecutar_Tests.sql` (también en modo SQLCMD, editando su `:setvar RUTA` con la carpeta `scripts\testing`), que corre todos los tests en orden y al final controla que no queden datos de prueba.

Todos los scripts verifican la existencia de los objetos antes de crearlos o borrarlos, por lo que se pueden volver a ejecutar sin errores.

### Orden de ejecución

Cada archivo empieza con dos dígitos que marcan su orden. Los números 01 a 29 los ejecuta `00_Reset_Total.sql` en ese orden. El responsable es el autor indicado en el encabezado de cada script.

| N.º | Script | Contenido | Responsable |
|---|---|---|---|
| 00 | `00_Reset_Total.sql` | Borra y recrea la base, crea los schemas y ejecuta los scripts 01 a 29 | Yamil / Elías |
| 01 | `01_Tablas_Nucleo.sql` | Tablas del núcleo: países, confederaciones, ciudades, sedes, fases, grupos, selecciones, staff técnico, árbitros, partidos, designaciones y sanciones | Yamil |
| 02 | `02_Tablas_Jugadores_y_Alineaciones.sql` | Tablas de jugadores, convocatoria, formaciones y sustituciones | Mateo |
| 03 | `03_Tablas_Eventos.sql` | Tablas de reglas de suspensión, tipos de gol, períodos, goles, tarjetas y amonestaciones | Mateo |
| 04 | `04_Tablas_Publicidad.sql` | Tablas de monedas, cotizaciones, anunciantes, campañas, piezas (cuelgan de la campaña), orientación por país, tarifas por fase y espacios publicitarios (con fecha y criterio de asignación) | Elías |
| 05 | `05_Tablas_Logs_Staging.sql` | Tablas de staging (eventos y fixture) y log de importación | Mateo |
| 06 | `06_FK_Cruzadas.sql` | Claves foráneas que cruzan módulos (jugadores, eventos y publicidad hacia el núcleo) | Elías |
| 07 | `07_Funciones_Nucleo.sql` | `fn_SeleccionesDelPartido`, `fn_MercadosEnPrimeTime`, `fn_SeleccionConPartidoCercano` (descanso de 48 horas) y `fn_PartidoTieneRegistros` | Yamil |
| 08 | `08_SP_ControlArbitral.sql` | `SP_CONTROL_ARBITRAL`: designación de árbitros con validación de nacionalidad y advertencia de cruce | Elías |
| 09 | `09_SP_Sedes_Partidos.sql` | ABM de sedes y partidos, registro de resultados y cálculo de selecciones clasificadas | Elías |
| 10 | `10_Funciones_Eventos.sql` | `fn_ResultadoPartido` y `fn_EstaSuspendido` | Mateo |
| 11 | `11_SP_RegistrarGol.sql` | `SP_REGISTRAR_GOL` | Mateo |
| 12 | `12_SP_RegistrarAmonestacion.sql` | `SP_REGISTRAR_AMONESTACION` con cálculo de suspensión | Mateo |
| 13 | `13_SP_ABM_Eventos.sql` | ABM (`SP_ALTA_`, `SP_MODIFICACION_` y `SP_BAJA_`) de reglas de suspensión, tipos de gol, períodos, tarjetas, goles y amonestaciones | Mateo |
| 14 | `14_Funciones_Jugadores.sql` | `fn_EsquemaValido`, `fn_JugadorEnCancha`, `fn_JugadoresEnCancha` y funciones de validación de convocatoria, formación y sustitución | Mateo |
| 15 | `15_SP_Convocatoria_Baja.sql` | `SP_CONVOCAR_JUGADOR` y `SP_REGISTRAR_BAJA_CONVOCATORIA` (con reemplazo opcional en la misma transacción) | Mateo |
| 16 | `16_SP_RegistrarFormacion.sql` | `SP_REGISTRAR_FORMACION` y `SP_AGREGAR_JUGADOR_FORMACION` (titulares y suplentes) | Mateo |
| 17 | `17_SP_RegistrarSustitucion.sql` | `SP_REGISTRAR_SUSTITUCION` con control de ventanas y cantidad de cambios | Mateo |
| 18 | `18_SP_ABM_Jugadores.sql` | ABM (`SP_ALTA_`, `SP_MODIFICACION_` y `SP_BAJA_`) del módulo de jugadores: reglas, clubes, jugadores, convocatoria, bajas, formaciones, jugadores de formación y sustituciones | Mateo |
| 19 | `19_SP_ABM_Nucleo.sql` | ABM restantes del núcleo (`SP_ALTA_`, `SP_MODIFICACION_` y `SP_BAJA_`): confederaciones, países, ciudades, fases, grupos, selecciones, staff técnico, idiomas, categorías, árbitros, idiomas de árbitros (solo alta y baja), designaciones, sanciones y regla de clasificación | Denis |
| 20 | `20_SP_ABM_Publicidad.sql` | ABM (`SP_ALTA_`, `SP_MODIFICACION_` y `SP_BAJA_`) de monedas, anunciantes, campañas, piezas, orientación por país (solo alta y baja), tarifas y espacios publicitarios (en un partido finalizado no se dan de alta, no se modifican ni se eliminan) | Denis |
| 21 | `21_SP_AsignarPublicidad.sql` | `SP_ASIGNAR_PUBLICIDAD`: propone y asigna las piezas de los espacios libres de un partido con un ranking determinista (países de las selecciones, PBI per cápita, prime time), una pieza por anunciante, tarifa de la fase y modo simulación (`@soloSimular`); registra el criterio aplicado | Elías |
| 22 | `22_SP_Importacion_Nucleo_Publicidad.sql` | `SP_IMPORTAR_FIXTURE_CSV`, `SP_IMPORTAR_PBI_JSON`, `SP_IMPORTAR_COTIZACIONES_JSON` y `SP_IMPORTAR_PAUTA_JSON` (con conversión de moneda), y la vista de aterrizaje del fixture | Elías |
| 23 | `23_SP_Importacion_Jugadores.sql` | Importación XML de jugadores | Mateo |
| 24 | `24_SP_Importacion_Eventos.sql` | Importación CSV de eventos | Mateo |
| 25 | `25_Funciones_Partidos.sql` | `fn_DefinicionPartido`, `fn_SeleccionesClasificadas`, `fn_FaseEliminatoriaInicial`, `fn_ValidarFaseGruposCompleta` y la vista `vw_PartidoResultado` (ver [Clasificación](#clasificación)) | Yamil |
| 26 | `26_SP_FinalizarPartido.sql` | `SP_FINALIZAR_PARTIDO`: cierra un partido y registra la concurrencia, validando que los goles cargados definan el resultado | Yamil |
| 27 | `27_SP_CalculoSeleccionesClasificadas.sql` | `SP_CALCULO_DE_SELECCIONES_CLASIFICADAS`: posiciones, clasificados y fase inicial de la eliminación directa | Yamil |
| 28 | `28_SP_DefinirCruceEliminatorio.sql` | `SP_DEFINIR_CRUCE_ELIMINATORIO`: asigna las selecciones de un partido eliminatorio (ver [Cruces eliminatorios](#cruces-eliminatorios)) | Yamil |
| 29 | `29_SP_Importacion_Campanias.sql` | `SP_IMPORTAR_CAMPANIAS_CSV` (campañas del dossier de publicidad, por scraping) y la vista de aterrizaje `publicidad.vw_CargaStagingCampania` | Elías |

**Convención de los ABM:** cada tabla tiene un SP por operación: `SP_ALTA_<Tabla>`, `SP_MODIFICACION_<Tabla>` y `SP_BAJA_<Tabla>` (por ejemplo `nucleo.SP_ALTA_Partido`). Las tablas asociativas (`ArbitroIdioma` y `OrientacionPais`) solo tienen alta y baja. Los archivos conservan el nombre `SP_ABM_` del módulo.

Scripts de testing (en `scripts/testing/`):

| Script | Prueba | Responsable |
|---|---|---|
| `00_Ejecutar_Tests.sql` | Ejecuta en orden todos los tests y verifica que no queden datos de prueba | Yamil |
| `01_Test_Tablas_Nucleo.sql` | Restricciones de las tablas del núcleo | Yamil |
| `02_Test_Tablas_Jugadores.sql` | Restricciones de las tablas de jugadores, convocatoria, formaciones y sustituciones | Mateo |
| `03_Test_Tablas_Eventos.sql` | Restricciones de las tablas de eventos | Mateo |
| `04_Test_Tablas_Publicidad.sql` | Restricciones de las tablas de publicidad (incluye campañas, tarifas y datos de asignación de los espacios) | Elías |
| `07_Test_Funciones_Nucleo.sql` | Funciones del núcleo (selecciones del partido, prime time, descanso y registros asociados) | Yamil |
| `08_Test_SP_ControlArbitral.sql` | `SP_CONTROL_ARBITRAL` | Elías |
| `09_Test_SP_Sedes_Partidos.sql` | SP de alta, modificación y baja de sedes y partidos | Yamil |
| `10_Test_Funciones_Eventos.sql` | Funciones de eventos | Mateo |
| `11_Test_SP_RegistrarGol.sql` | `SP_REGISTRAR_GOL` | Mateo |
| `12_Test_SP_RegistrarAmonestacion.sql` | `SP_REGISTRAR_AMONESTACION` | Mateo |
| `13_Test_SP_ABM_Eventos.sql` | SP ABM de eventos | Mateo |
| `14_Test_Funciones_Jugadores.sql` | Funciones de jugadores | Mateo |
| `15_Test_SP_Convocatoria_Baja.sql` | `SP_CONVOCAR_JUGADOR` y `SP_REGISTRAR_BAJA_CONVOCATORIA` | Mateo |
| `16_Test_SP_RegistrarFormacion.sql` | `SP_REGISTRAR_FORMACION` y `SP_AGREGAR_JUGADOR_FORMACION` | Mateo |
| `17_Test_SP_RegistrarSustitucion.sql` | `SP_REGISTRAR_SUSTITUCION` | Mateo |
| `18_Test_SP_ABM_Jugadores.sql` | SP ABM de jugadores | Mateo |
| `19_Test_SP_ABM_Nucleo.sql` | SP ABM restantes del núcleo | Denis |
| `20_Test_SP_ABM_Publicidad.sql` | SP ABM de publicidad (incluye campañas, tarifas, monedas con cotizaciones y espacios de partidos finalizados) | Denis |
| `21_Test_SP_AsignarPublicidad.sql` | `SP_ASIGNAR_PUBLICIDAD` (ranking exacto del partido ARG vs BRA con prime time en 6 mercados, determinismo, simulación, espacios cargados a mano, una pieza por anunciante, menos candidatas que espacios, tarifa por fase y errores agrupados; alta manual rechazada en partido finalizado) | Elías |
| `22_Test_SP_Importacion_Nucleo_Publicidad.sql` | Importación de fixture, PBI, cotizaciones y pauta (lotes con errores parciales, re-ejecución, conversión de moneda y pauta sobre partidos finalizados) | Elías |
| `23_Test_SP_Importacion_Jugadores.sql` | Importación XML de jugadores | Mateo |
| `24_Test_SP_Importacion_Eventos.sql` | Importación CSV de eventos | Mateo |
| `25_Test_Funciones_Partidos.sql` | Definición de partidos, tabla de posiciones, cupos, fase inicial, fase de grupos completa y vista de resultados | Yamil |
| `26_Test_SP_FinalizarPartido.sql` | `SP_FINALIZAR_PARTIDO` | Yamil |
| `27_Test_SP_CalculoSeleccionesClasificadas.sql` | `SP_CALCULO_DE_SELECCIONES_CLASIFICADAS` | Yamil |
| `28_Test_SP_DefinirCruceEliminatorio.sql` | `SP_DEFINIR_CRUCE_ELIMINATORIO` | Yamil |
| `29_Test_SP_Importacion_Campanias.sql` | `SP_IMPORTAR_CAMPANIAS_CSV` (primera y segunda corrida, filas inválidas en el log, acentos, modificación de Marca y Agencia, país inexistente, `@crearPiezas = 0` y cambio de país del anunciante) | Elías |
| `importacion/03_Test_Seed_Jugadores_Eventos.sql` | Seed de jugadores y eventos: volúmenes mínimos y casos obligatorios (en espejo de `scripts/importacion/03_Seed_Jugadores_Eventos.sql`) | Mateo |

Pendientes: reportes, seguridad y respaldo.

**Casos obligatorios de nucleo y publicidad:** partido 1 (ARG vs BRA, 23:00 UTC) en prime time en 6 mercados (ARG, BRA, URU, CHI, USA, CAN); árbitro argentino rechazado en ARG vs BRA (queda en `eventos.LogImportacion`, archivo `seed_designaciones`); importación de pauta con 6 filas válidas y 3 inválidas.

**Decisiones del fixture:** los 24 partidos son de *Fase de grupos* (4 grupos de 4 = 24 cruces). `SP_ALTA_Partido` no admite selecciones en fases eliminatorias (se asignarían con `SP_DEFINIR_CRUCE_ELIMINATORIO`, que no está en el repositorio) y las formaciones de Mateo exigen las dos selecciones definidas. BRA está en el Grupo A, junto a ARG, porque los partidos de grupos deben ser entre selecciones del mismo grupo. Las selecciones juegan con 5 días de separación (la regla real de descanso del SP es de 48 h).

## Clasificación

El resultado de cada partido no se guarda en `nucleo.Partido`: se calcula a partir de los goles (`eventos.fn_ResultadoPartido`; un gol en contra suma al rival y la tanda de penales se cuenta aparte). Para leerlo se usa la vista `nucleo.vw_PartidoResultado`. Los partidos se cierran con `nucleo.SP_FINALIZAR_PARTIDO`, que valida que los goles cargados definan el resultado.

Al terminar la fase de grupos, `nucleo.SP_CALCULO_DE_SELECCIONES_CLASIFICADAS` comprueba que todos los partidos de grupos estén cargados y finalizados, y devuelve las posiciones, los clasificados y la fase con la que empieza la eliminación directa.

**Cupo.** Lo define la tabla `nucleo.ReglaClasificacion` (una sola fila): `ClasificadosPorGrupo` pasan directo por grupo y `MejoresTerceros` se suman entre todos los grupos. El valor inicial es (2, 0).

| Modalidad | Regla | Clasificados | La eliminación empieza en |
|---|---|---|---|
| 8 grupos de 4 equipos (Catar 2022, por ejemplo) | (2, 0) | 16 | Octavos de final |
| 12 grupos de 4 equipos (Mundial 2026, por ejemplo) | (2, 8) | 32 | Dieciseisavos de final |

Con 8 clasificados empieza en cuartos de final. Cualquier otro total es inválido.

**Mejores terceros.** El cupo adicional se toma del puesto que sigue a los directos (`ClasificadosPorGrupo + 1`): con 2 por grupo son los terceros; con 1 por grupo serían los mejores segundos. Se ordenan entre grupos con el mismo desempate.

**Desempate** (decisión del grupo): puntos, diferencia de gol, goles a favor e `IdSeleccion`. El último criterio es arbitrario: si decide quién clasifica, el SP lo avisa (sin error), porque en un torneo real ese caso se resolvería por sorteo o fair play.

---

## Cruces eliminatorios

No hay un árbol eliminatorio pre-cargado: cada cruce se asigna con `nucleo.SP_DEFINIR_CRUCE_ELIMINATORIO`, que lo valida según la fase del partido.

| Fase del partido | Condición para las dos selecciones |
|---|---|
| Fase inicial (la que deduce el cupo) | Clasificaron, con la fase de grupos completa |
| Octavos, Cuartos, Semifinal y Final (cuando no son la inicial) | Ganaron un partido finalizado de la fase anterior, jugado antes que este (la Final mira a la Semifinal) |
| Tercer puesto | Perdieron una Semifinal finalizada |

Además:

- Una fase anterior a la inicial no se juega (por ejemplo, octavos cuando la eliminación empieza en cuartos).
- Ninguna selección puede estar en dos partidos de la misma fase ni tener otro partido a menos de 48 horas.
- Si el partido ya tiene formaciones, goles, designaciones u otros registros, no se le pueden cambiar las selecciones.
- No se restringen los emparejamientos posibles (por ejemplo, dos selecciones del mismo grupo pueden cruzarse en la fase inicial).

---

## Asignación de publicidad

**Modelo.** Cada anunciante tiene una o más campañas (`publicidad.Campania`) y cada campaña sus piezas (`Pieza`, una por idioma o mercado), orientadas a uno o más países (`OrientacionPais`). La tarifa de referencia de cada franja depende de la fase del torneo (`Tarifa`, con moneda y fecha de vigencia). `EspacioPublicitario` es el histórico de lo exhibido en cada partido: guarda la tarifa y la moneda aplicadas, la fecha y el criterio de asignación (`NULL` si se cargó a mano). Una vez finalizado el partido, sus espacios no se dan de alta, no se modifican ni se eliminan.

**Criterio de asignación (`publicidad.SP_ASIGNAR_PUBLICIDAD`).** Firma: `@idPartido INT, @soloSimular BIT = 0, @advertencia VARCHAR(200) = NULL OUTPUT`. El SP propone qué piezas ocupan los espacios libres (1 a 4) del partido:

1. **Candidatas:** toda pieza con al menos un país en `OrientacionPais` que no esté ya en el partido y cuyo anunciante no tenga ya un espacio en ese partido (cargado a mano, por la pauta importada o por una corrida anterior).
2. **Ranking**, calculado sobre los países de orientación de cada pieza, en este orden:
   1. `EsParticipante` (desc): alguno de sus países es el de la selección local o visitante (`nucleo.fn_SeleccionesDelPartido`).
   2. `PBIMax` (desc): el mayor `PBIPerCapitaUSD` entre sus países; si ninguno tiene PBI, la pieza queda última en este criterio.
   3. `EnPrimeTime` (desc): alguno de sus países está en prime time local (19:00 a 22:59) a la hora del partido (`nucleo.fn_MercadosEnPrimeTime`).
   4. `IdPieza` (asc): desempate final. Con los mismos datos, el resultado es siempre el mismo (no se usa `NEWID()`).
3. **Una pieza por anunciante:** de cada anunciante se queda solo su mejor pieza según el mismo orden.
4. Se toman las N mejores (N = espacios libres) y se asignan a los números libres de menor a mayor. Los espacios ocupados no se tocan. Si hay menos candidatas que espacios libres, se asignan las que hay y `@advertencia` informa cuáles quedaron sin asignar (no es un error).
5. **Tarifa:** sale de `publicidad.Tarifa` para la fase del partido: la de mayor `VigenciaDesde` que no supere la fecha del partido (`FechaHoraUTC`). Si en esa fecha hay tarifas en varias monedas, se elige USD y después el menor `IdTarifa`. El monto y la moneda se copian a cada espacio asignado.
6. `CriterioAsignacion` guarda el motivo en forma compacta, por ejemplo `Participante | PBI 27280 (POR) | Prime time`.
7. `@soloSimular = 1` devuelve la propuesta (espacio, pieza, anunciante, tarifa, moneda, criterio) **sin insertar nada**. En los dos modos el result set muestra los espacios ocupados del partido con su estado: `Ya ocupado`, `Asignado` o `Propuesto`.

Las validaciones se juntan en un único error (`THROW 52000`) antes de abrir la transacción: partido inexistente, partido finalizado, sin espacios libres, sin tarifa para la fase a la fecha del partido y sin ninguna pieza candidata.

Ninguna requiere API key. Los archivos se generan con `scripts/importacion/fuentes_externas.py` (Python 3; `pip install requests beautifulsoup4` solo para el scraping).

| Fuente | URL y parámetros | Límites de uso | Destino |
|---|---|---|---|
| API Banco Mundial | `https://api.worldbank.org/v2/country/AR;BR;...;AU/indicator/NY.GDP.PCAP.CD?format=json&date=2018:2024&per_page=1000` (países por ISO2) | Pública y gratuita, sin API key; sin cuota publicada (se hace 1 sola consulta) | `nucleo.SP_IMPORTAR_PBI_JSON` -> `Pais.PBIPerCapitaUSD` (último año con dato) |
| API Frankfurter | `https://api.frankfurter.app/latest?from=USD&to=EUR,BRL,JPY,GBP` | Gratuita, sin API key ni límite fijo (se hace 1 consulta). Usa cotizaciones del BCE: **no publica ARS** | `publicidad.SP_IMPORTAR_COTIZACIONES_JSON` -> `CotizacionMoneda`; `SP_IMPORTAR_PAUTA_JSON` convierte a USD |
| Scraping Wikipedia | `https://en.wikipedia.org/wiki/2026_FIFA_World_Cup` (tabla de sedes: capacidad) | Sin API key; se envía un `User-Agent` identificatorio y se hace 1 sola descarga. `--offline` usa los datos incluidos en el script | `fixture_sedes.csv` -> `eventos.vw_CargaStagingFixture` -> `nucleo.SP_IMPORTAR_FIXTURE_CSV` |

El Banco Mundial se cruza por `CodigoISO2` y no por `CodigoISO3` porque varios códigos del torneo son códigos FIFA (NED, GER, ENG, SUI, CHI). Las coordenadas, el huso y el cruce de partidos del fixture salen del propio script; del scraping se toma la capacidad.

> Las claves foráneas que cruzan módulos (por ejemplo, de `Convocatoria` hacia `Seleccion` o de `EspacioPublicitario` hacia `Partido`) se agregan con `ALTER TABLE` en `06_FK_Cruzadas.sql`, una vez creadas todas las tablas.

---

## Campañas del dossier (scraping)

Segundo dataset obtenido por scraping (además del fixture): las campañas de publicidad del Mundial de un dossier público.

| Dato | Detalle |
|---|---|
| Página de origen | `https://dossiermundial.netlify.app/` (sitio estático que arma la página en el navegador) |
| Técnica | La página carga sus datos desde una base Firestore de lectura pública, sin clave. En vez de parsear el HTML renderizado, `scripts/importacion/scraping_dossier.py` hace un `GET` al mismo endpoint REST (`https://firestore.googleapis.com/v1/projects/repositorio2026-61a28/databases/(default)/documents/campanas?pageSize=300`) y convierte el JSON tipado de Firestore (`stringValue`, `arrayValue`) a CSV |
| Límites de uso | Sin API key. Se hace **1 solo pedido** (hoy son 75 campañas, cabe en una página); solo se pide otra página si la respuesta trae `nextPageToken`. Se envía un `User-Agent` identificatorio del grupo. Solo biblioteca estándar de Python 3 |
| Datos que se guardan | `Anunciante;Marca;Titulo;Agencia;Productora;Periodo;Categorias` (UTF-8, separador `;`, categorías separadas por `\|`). El campo `creditos` del dossier tiene nombres de personas: **no se lee ni se guarda** |
| Cómo regenerar el CSV | `python scripts/importacion/scraping_dossier.py` (pisa `scripts/importacion/campanas_dossier.csv`). El repositorio incluye un snapshot para trabajar sin conexión |

**Importación.** `08_Importar_Campanias_Dossier.sql` (modo SQLCMD, editar `RUTA_IMP`) carga el CSV con `BULK INSERT` estático en `publicidad.StagingCampania` (a través de `publicidad.vw_CargaStagingCampania`) y ejecuta `publicidad.SP_IMPORTAR_CAMPANIAS_CSV @nombreArchivo, @filasProcesadas OUTPUT, @filasConError OUTPUT, @codigoISO3Pais = 'ARG', @crearPiezas = 1`. Va después de 06 y 07 para no cambiar la pauta ya asignada en los partidos del seed. Con el snapshot actual crea 63 anunciantes, 75 campañas y 75 piezas; ejecutado después del seed 04 (9 anunciantes, 9 campañas y 12 piezas) la base queda con 72 anunciantes, 84 campañas y 87 piezas.

El SP usa los SP ABM de `20_SP_ABM_Publicidad.sql` y crea, por cada fila (Upsert, sin duplicar y solo modificando lo que cambió, distinguiendo mayúsculas y acentos):

1. **Anunciante** por `Nombre`, con el país de origen indicado en `@codigoISO3Pais` (el dossier son campañas argentinas y no informa país).
2. **Campania** por (anunciante, título), con `Marca` y `Agencia`. `Productora`, `Periodo` y `Categorias` llegan a staging pero no se guardan: el modelo no tiene dónde. Si la campaña ya existe y cambió la marca o la agencia, se modifica conservando sus fechas.
3. Con `@crearPiezas = 1`: una **Pieza** en idioma Español con el título de la campaña y su **OrientacionPais** al país indicado, para que la campaña participe de `SP_ASIGNAR_PUBLICIDAD`.

Las filas inválidas (anunciante o título vacío, texto de más de 100 caracteres, país inexistente) no frenan el lote: quedan en `eventos.LogImportacion` con el `IdFila` de staging y los datos crudos. Las validaciones generales (nombre de archivo, archivo sin filas, idioma Español inexistente con `@crearPiezas = 1`) se informan juntas en un único error `THROW 52000`.

---

## Datos de prueba (criterios de aceptación)

El juego de datos contempla como mínimo:

- 8 sedes (con al menos 3 husos horarios distintos), 16 selecciones con 23 convocados cada una y 24 partidos con formación titular y suplentes.
- 15 árbitros con designación completa por partido.
- Historial de campañas publicitarias con anunciantes de 6 países o más.

Casos obligatorios: expulsión por doble amarilla y roja directa, jugador suspendido por acumulación fuera de la titular siguiente, cambio por lesión antes del minuto 20, partido en prime time en más de 4 mercados, designación arbitral descartada por conflicto de nacionalidad e importación con errores parciales.

---

## Notas

- No se incluyen datos privados ni credenciales en el repositorio.
- Cada script de creación de SP tiene su script de testing correspondiente (casos exitosos y casos de validación fallida), con el resultado esperado en comentarios.