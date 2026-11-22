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
    │   └── 01_… a 21_…           # un archivo por módulo, con prefijo numérico de orden de ejecución
    ├── testing/                  # scripts de testing (uno por cada script de creación probado)
    └── importacion/              # procesos de importación de datos externos (CSV/XML/API/scraping)
```

- Cada script empieza con dos dígitos que indican el orden de ejecución y con el encabezado definido en `doc/nomenclaturas.md`.
- Los scripts de `testing/` llevan el mismo número que el script de `creacion/` que prueban y tienen en comentarios el resultado esperado de cada caso.
- Schemas de la base `MundialFutbol`: `nucleo` (países, sedes, partidos, árbitros), `jugadores` (convocatoria, alineaciones, sustituciones), `eventos` (goles, tarjetas, suspensiones, staging y logs) y `publicidad` (anunciantes, piezas y espacios).

---

## Cómo ejecutar (corrida desde cero)

1. Abrir SSMS y activar el **modo SQLCMD** (menú *Consulta → Modo SQLCMD*).
2. Abrir `scripts/creacion/00_Reset_Total.sql` y editar la línea `:setvar RUTA "..."` con la ruta de la carpeta `scripts\creacion` de la copia local del repositorio (sin barra final).
3. Ejecutarlo. El script elimina la base `MundialFutbol` si existe, la recrea, crea los schemas y ejecuta en orden los scripts `01` a `21`. Si alguno falla, se corta en ese punto. Al final muestra un resumen de tablas, SP y funciones por schema.
4. Ejecutar los scripts de carga de datos (seed data), cuando estén disponibles.
5. Ejecutar los scripts de `scripts/testing/` para validar el comportamiento.

Todos los scripts verifican la existencia de los objetos antes de crearlos o borrarlos, por lo que se pueden volver a ejecutar sin errores.

### Orden de ejecución

Cada archivo empieza con dos dígitos que marcan su orden. Los números 01 a 21 los ejecuta `00_Reset_Total.sql` en ese orden. El responsable es el autor indicado en el encabezado de cada script.

| N.º | Script | Contenido | Responsable |
|---|---|---|---|
| 00 | `00_Reset_Total.sql` | Borra y recrea la base, crea los schemas y ejecuta los scripts 01 a 21 | Yamil / Elías |
| 01 | `01_Tablas_Nucleo.sql` | Tablas del núcleo: países, confederaciones, ciudades, sedes, fases, grupos, selecciones, staff técnico, árbitros, partidos, designaciones y sanciones | Yamil |
| 02 | `02_Tablas_Jugadores_y_Alineaciones.sql` | Tablas de jugadores, convocatoria, formaciones y sustituciones | Mateo |
| 03 | `03_Tablas_Eventos.sql` | Tablas de reglas de suspensión, tipos de gol, períodos, goles, tarjetas y amonestaciones | Mateo |
| 04 | `04_Tablas_Publicidad.sql` | Tablas de monedas, anunciantes, piezas, orientación por país y espacios publicitarios | Elías |
| 05 | `05_Tablas_Logs_Staging.sql` | Tablas de staging y log de importación | Mateo |
| 06 | `06_FK_Cruzadas.sql` | Claves foráneas que cruzan módulos (jugadores, eventos y publicidad hacia el núcleo) | Elías |
| 07 | `07_Funciones_Nucleo.sql` | `fn_SeleccionesDelPartido` y `fn_MercadosEnPrimeTime` | Yamil |
| 08 | `08_SP_ControlArbitral.sql` | `SP_CONTROL_ARBITRAL`: designación de árbitros con validación de nacionalidad y advertencia de cruce | Elías |
| 09 | `09_SP_Sedes_Partidos.sql` | ABM de sedes y partidos, registro de resultados y cálculo de selecciones clasificadas | Yamil |
| 10 | `10_Funciones_Eventos.sql` | `fn_ResultadoPartido` y `fn_EstaSuspendido` | Mateo |
| 11 | `11_SP_RegistrarGol.sql` | `SP_REGISTRAR_GOL` | Mateo |
| 12 | `12_SP_RegistrarAmonestacion.sql` | `SP_REGISTRAR_AMONESTACION` con cálculo de suspensión | Mateo |
| 13 | `13_SP_ABM_Eventos.sql` | ABM de reglas de suspensión, tipos de gol, períodos, tarjetas y goles | Mateo |
| 14 | `14_Funciones_Jugadores.sql` | `fn_EsquemaValido`, `fn_JugadorEnCancha`, `fn_JugadoresEnCancha` y funciones de validación de convocatoria, formación y sustitución | Mateo |
| 15 | `15_SP_Convocatoria_Baja.sql` | `SP_CONVOCAR_JUGADOR` y `SP_REGISTRAR_BAJA_CONVOCATORIA` (con reemplazo opcional en la misma transacción) | Mateo |
| 16 | `16_SP_RegistrarFormacion.sql` | `SP_REGISTRAR_FORMACION` y `SP_AGREGAR_JUGADOR_FORMACION` (titulares y suplentes) | Mateo |
| 17 | `17_SP_RegistrarSustitucion.sql` | `SP_REGISTRAR_SUSTITUCION` con control de ventanas y cantidad de cambios | Mateo |
| 18 | `18_SP_ABM_Jugadores.sql` | ABM del módulo de jugadores (reglas, clubes, jugadores, convocatoria, bajas, formaciones y sustituciones) | Mateo |
| 19 | `19_SP_ABM_Nucleo.sql` | ABM restantes del núcleo: confederaciones, países, ciudades, fases, grupos, selecciones, staff técnico, idiomas, categorías, árbitros, designaciones y sanciones | Denis |
| 20 | `20_SP_ABM_Publicidad.sql` | ABM de monedas, anunciantes, piezas, orientación por país y espacios publicitarios | Denis |
| 21 | `21_SP_AsignarPublicidad.sql` | `SP_ASIGNAR_PUBLICIDAD`: asigna las piezas a los espacios libres de un partido según país de las selecciones, PBI y prime time | Elías |

Scripts de testing (en `scripts/testing/`):

| Script | Prueba |
|---|---|
| `01_Test_Tablas_Nucleo.sql` | Restricciones de las tablas del núcleo |
| `02_Test_Tablas_Jugadores.sql` | Restricciones de las tablas de jugadores, convocatoria, formaciones y sustituciones |
| `03_Test_Tablas_Eventos.sql` | Restricciones de las tablas de eventos |
| `04_Test_Tablas_Publicidad.sql` | Restricciones de las tablas de publicidad |
| `07_Test_Funciones_Nucleo.sql` | `fn_SeleccionesDelPartido` y `fn_MercadosEnPrimeTime` |
| `08_Test_SP_ControlArbitral.sql` | `SP_CONTROL_ARBITRAL` |
| `09_Test_SP_Sedes_Partidos.sql` | SP de sedes, partidos, resultados y clasificadas |
| `10_Test_Funciones_Eventos.sql` | Funciones de eventos |
| `11_Test_SP_RegistrarGol.sql` | `SP_REGISTRAR_GOL` |
| `12_Test_SP_RegistrarAmonestacion.sql` | `SP_REGISTRAR_AMONESTACION` |
| `13_Test_SP_ABM_Eventos.sql` | SP ABM de eventos |
| `14_Test_Funciones_Jugadores.sql` | Funciones de jugadores |
| `15_Test_SP_Convocatoria_Baja.sql` | `SP_CONVOCAR_JUGADOR` y `SP_REGISTRAR_BAJA_CONVOCATORIA` |
| `16_Test_SP_RegistrarFormacion.sql` | `SP_REGISTRAR_FORMACION` y `SP_AGREGAR_JUGADOR_FORMACION` |
| `17_Test_SP_RegistrarSustitucion.sql` | `SP_REGISTRAR_SUSTITUCION` |
| `18_Test_SP_ABM_Jugadores.sql` | SP ABM de jugadores |
| `19_Test_SP_ABM_Nucleo.sql` | SP ABM restantes del núcleo |
| `20_Test_SP_ABM_Publicidad.sql` | SP ABM de publicidad |
| `21_Test_SP_AsignarPublicidad.sql` | `SP_ASIGNAR_PUBLICIDAD` (prime time en más de cuatro mercados, criterios de prioridad y validaciones) |

Pendientes: importación de datos (`scripts/importacion/`), datos de prueba (seed), reportes, seguridad y respaldo.

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
