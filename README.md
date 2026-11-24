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
    │   └── 01_… a 28_…           # un archivo por módulo, con prefijo numérico de orden de ejecución
    ├── testing/                  # scripts de testing (uno por cada script de creación probado)
    │   └── importacion/          # tests en espejo de scripts/importacion/ (ej. 03_Test_Seed_Jugadores_Eventos.sql)
    └── importacion/              # procesos de importación de datos externos (CSV/XML/API/scraping)
```

- Cada script empieza con dos dígitos que indican el orden de ejecución y con el encabezado definido en `doc/nomenclaturas.md`.
- Los scripts de `testing/` llevan el mismo número que el script de `creacion/` que prueban y tienen en comentarios el resultado esperado de cada caso.
- Schemas de la base `MundialFutbol`: `nucleo` (países, sedes, partidos, árbitros), `jugadores` (convocatoria, alineaciones, sustituciones), `eventos` (goles, tarjetas, suspensiones, staging y logs) y `publicidad` (anunciantes, piezas y espacios).

---

## Cómo ejecutar (corrida desde cero)

1. Abrir SSMS y activar el **modo SQLCMD** (menú *Consulta → Modo SQLCMD*).
2. Abrir `scripts/creacion/00_Reset_Total.sql` y editar la línea `:setvar RUTA "..."` con la ruta de la carpeta `scripts\creacion` de la copia local del repositorio (sin barra final).
3. Ejecutarlo. El script elimina la base `MundialFutbol` si existe, la recrea, crea los schemas y ejecuta en orden los scripts `01` a `28`. Si alguno falla, se corta en ese punto. Al final muestra un resumen de tablas, SP y funciones por schema.
4. Ejecutar los scripts de carga de datos (seed data), cuando estén disponibles.
5. Ejecutar `scripts/testing/00_Ejecutar_Tests.sql` (también en modo SQLCMD, editando su `:setvar RUTA` con la carpeta `scripts\testing`), que corre todos los tests en orden y al final controla que no queden datos de prueba.

Todos los scripts verifican la existencia de los objetos antes de crearlos o borrarlos, por lo que se pueden volver a ejecutar sin errores.

### Orden de ejecución

Cada archivo empieza con dos dígitos que marcan su orden. Los números 01 a 28 los ejecuta `00_Reset_Total.sql` en ese orden (el 22 no se usa). El responsable es el autor indicado en el encabezado de cada script.

| N.º | Script | Contenido | Responsable |
|---|---|---|---|
| 00 | `00_Reset_Total.sql` | Borra y recrea la base, crea los schemas y ejecuta los scripts 01 a 28 | Yamil / Elías |
| 01 | `01_Tablas_Nucleo.sql` | Tablas del núcleo: países, confederaciones, ciudades, sedes, fases, grupos, selecciones, staff técnico, árbitros, partidos, designaciones y sanciones | Yamil |
| 02 | `02_Tablas_Jugadores_y_Alineaciones.sql` | Tablas de jugadores, convocatoria, formaciones y sustituciones | Mateo |
| 03 | `03_Tablas_Eventos.sql` | Tablas de reglas de suspensión, tipos de gol, períodos, goles, tarjetas y amonestaciones | Mateo |
| 04 | `04_Tablas_Publicidad.sql` | Tablas de monedas, anunciantes, piezas, orientación por país y espacios publicitarios | Elías |
| 05 | `05_Tablas_Logs_Staging.sql` | Tablas de staging y log de importación | Mateo |
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
| 20 | `20_SP_ABM_Publicidad.sql` | ABM (`SP_ALTA_`, `SP_MODIFICACION_` y `SP_BAJA_`) de monedas, anunciantes, piezas, orientación por país (solo alta y baja) y espacios publicitarios | Denis |
| 21 | `21_SP_AsignarPublicidad.sql` | `SP_ASIGNAR_PUBLICIDAD`: asigna las piezas a los espacios libres de un partido según país de las selecciones, PBI y prime time | Elías |
| 22 | `22_SP_Importacion_Nucleo_Publicidad.sql` | Importación de nucleo y publicidad (fixture, PBI, cotizaciones y pauta) | Elías |
| 23 | `23_SP_Importacion_Jugadores.sql` | Importación XML de jugadores | Mateo |
| 24 | `24_SP_Importacion_Eventos.sql` | Importación CSV de eventos | Mateo |
| 25 | `25_Funciones_Partidos.sql` | `fn_DefinicionPartido`, `fn_SeleccionesClasificadas`, `fn_FaseEliminatoriaInicial`, `fn_ValidarFaseGruposCompleta` y la vista `vw_PartidoResultado` (ver [Clasificación](#clasificación)) | Yamil |
| 26 | `26_SP_FinalizarPartido.sql` | `SP_FINALIZAR_PARTIDO`: cierra un partido y registra la concurrencia, validando que los goles cargados definan el resultado | Yamil |
| 27 | `27_SP_CalculoSeleccionesClasificadas.sql` | `SP_CALCULO_DE_SELECCIONES_CLASIFICADAS`: posiciones, clasificados y fase inicial de la eliminación directa | Yamil |
| 28 | `28_SP_DefinirCruceEliminatorio.sql` | `SP_DEFINIR_CRUCE_ELIMINATORIO`: asigna las selecciones de un partido eliminatorio (ver [Cruces eliminatorios](#cruces-eliminatorios)) | Yamil |
| 29 | `29_SP_Reportes.sql` | Stored Procedures para los 7 reportes oficiales de la Entrega 7 | Denis |
| 30 | `30_Seguridad_Cifrado.sql` | Cifrado PII, funciones criptográficas y adaptación de SPs para datos sensibles | Denis |
| 31 | `31_Seguridad_Roles_Permisos.sql` | SPs de creación y gestión de 4 roles de seguridad y permisos granulares | Denis |
| 32 | `32_Procedimientos_Backups.sql` | SPs de configuración FULL y ejecución de backups (Full, Diff y Log) | Denis |

**Convención de los ABM:** cada tabla tiene un SP por operación: `SP_ALTA_<Tabla>`, `SP_MODIFICACION_<Tabla>` y `SP_BAJA_<Tabla>` (por ejemplo `nucleo.SP_ALTA_Partido`). Las tablas asociativas (`ArbitroIdioma` y `OrientacionPais`) solo tienen alta y baja. Los archivos conservan el nombre `SP_ABM_` del módulo.

Scripts de testing (en `scripts/testing/`):

| Script | Prueba | Responsable |
|---|---|---|
| `00_Ejecutar_Tests.sql` | Ejecuta en orden todos los tests y verifica que no queden datos de prueba | Yamil |
| `01_Test_Tablas_Nucleo.sql` | Restricciones de las tablas del núcleo | Yamil |
| `02_Test_Tablas_Jugadores.sql` | Restricciones de las tablas de jugadores, convocatoria, formaciones y sustituciones | Mateo |
| `03_Test_Tablas_Eventos.sql` | Restricciones de las tablas de eventos | Mateo |
| `04_Test_Tablas_Publicidad.sql` | Restricciones de las tablas de publicidad | Elías |
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
| `20_Test_SP_ABM_Publicidad.sql` | SP ABM de publicidad | Denis |
| `21_Test_SP_AsignarPublicidad.sql` | `SP_ASIGNAR_PUBLICIDAD` (prime time en más de cuatro mercados, criterios de prioridad y validaciones) | Elías |
| `22_Test_SP_Importacion_Nucleo_Publicidad.sql` | Importación de nucleo y publicidad (fixture, PBI, cotizaciones y pauta) | Elías |
| `23_Test_SP_Importacion_Jugadores.sql` | Importación XML de jugadores | Mateo |
| `24_Test_SP_Importacion_Eventos.sql` | Importación CSV de eventos | Mateo |
| `25_Test_Funciones_Partidos.sql` | Definición de partidos, tabla de posiciones, cupos, fase inicial, fase de grupos completa y vista de resultados | Yamil |
| `26_Test_SP_FinalizarPartido.sql` | `SP_FINALIZAR_PARTIDO` | Yamil |
| `27_Test_SP_CalculoSeleccionesClasificadas.sql` | `SP_CALCULO_DE_SELECCIONES_CLASIFICADAS` | Yamil |
| `28_Test_SP_DefinirCruceEliminatorio.sql` | `SP_DEFINIR_CRUCE_ELIMINATORIO` | Yamil |
| `importacion/03_Test_Seed_Jugadores_Eventos.sql` | Seed de jugadores y eventos: volúmenes mínimos y casos obligatorios (en espejo de `scripts/importacion/03_Seed_Jugadores_Eventos.sql`) | Mateo |
| `29_Test_SP_Reportes.sql` | Validación de los 7 reportes oficiales | Denis |
| `30_Test_Seguridad_Cifrado.sql` | Test de funciones de cifrado, persistencia binaria y evaluación de impacto | Denis |
| `31_Test_Rol_Administrador.sql` | Test de permisos de control total (usr_admin_test) | Denis |
| `31_Test_Rol_OperadorResultados.sql` | Test de permisos deportivos y denegación de publicidad (usr_resultados_test) | Denis |
| `31_Test_Rol_GestorPublicidad.sql` | Test de permisos comerciales y denegación de eventos (usr_publicidad_test) | Denis |
| `31_Test_Rol_Consulta.sql` | Test de reportes y denegación de modificaciones (usr_consulta_test) | Denis |
| `32_Test_Backups.sql` | Test de backups Full, Diff, Log y consulta de historial msdb | Denis |

Pendientes: Entrega 9 (plataforma BI, interfaz gráfica y dashboard analítico).

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

Ninguna requiere API key. Los archivos se generan con `scripts/importacion/fuentes_externas.py` (Python 3; `pip install requests beautifulsoup4` solo para el scraping).

| Fuente | URL y parámetros | Límites de uso | Destino |
|---|---|---|---|
| API Banco Mundial | `https://api.worldbank.org/v2/country/AR;BR;...;AU/indicator/NY.GDP.PCAP.CD?format=json&date=2018:2024&per_page=1000` (países por ISO2) | Pública y gratuita, sin API key; sin cuota publicada (se hace 1 sola consulta) | `nucleo.SP_IMPORTAR_PBI_JSON` -> `Pais.PBIPerCapitaUSD` (último año con dato) |
| API Frankfurter | `https://api.frankfurter.app/latest?from=USD&to=EUR,BRL,JPY,GBP` | Gratuita, sin API key ni límite fijo (se hace 1 consulta). Usa cotizaciones del BCE: **no publica ARS** | `publicidad.SP_IMPORTAR_COTIZACIONES_JSON` -> `CotizacionMoneda`; `SP_IMPORTAR_PAUTA_JSON` convierte a USD |
| Scraping Wikipedia | `https://en.wikipedia.org/wiki/2026_FIFA_World_Cup` (tabla de sedes: capacidad) | Sin API key; se envía un `User-Agent` identificatorio y se hace 1 sola descarga. `--offline` usa los datos incluidos en el script | `fixture_sedes.csv` -> `eventos.vw_CargaStagingFixture` -> `nucleo.SP_IMPORTAR_FIXTURE_CSV` |

El Banco Mundial se cruza por `CodigoISO2` y no por `CodigoISO3` porque varios códigos del torneo son códigos FIFA (NED, GER, ENG, SUI, CHI). Las coordenadas, el huso y el cruce de partidos del fixture salen del propio script; del scraping se toma la capacidad.

> Las claves foráneas que cruzan módulos (por ejemplo, de `Convocatoria` hacia `Seleccion` o de `EspacioPublicitario` hacia `Partido`) se agregan con `ALTER TABLE` en `06_FK_Cruzadas.sql`, una vez creadas todas las tablas.

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