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

> TO DO: Agregar

---

## Cómo ejecutar (corrida desde cero)

1. Abrir la solución en SSMS.
2. Ejecutar `00_Maestro.sql`, que elimina y recrea la base y corre los scripts numerados en orden.
3. Ejecutar los scripts de carga de datos (seed data).
4. Ejecutar los scripts de `test/` para validar el comportamiento.

Todos los scripts verifican la existencia de los objetos antes de crearlos o borrarlos, por lo que se pueden volver a ejecutar sin errores.

### Orden de ejecución

> Completar a medida que se cierren los scripts. Cada archivo empieza con dos dígitos que marcan su orden.

| N.º | Script | Contenido | Responsable |
|---|---|---|---|
| 01 | <...> | Base de datos y esquemas | Yamil |
| 02 | `02_Tablas_Jugadores.sql` | Tablas de jugadores, convocatoria y alineaciones | Mateo |
| <...> | <...> | Tablas del núcleo | Yamil |
| <...> | <...> | Tablas de eventos | Denis |
| <...> | <...> | Tablas de publicidad | Elías |
| <...> | <...> | Stored procedures | Todos |
| <...> | <...> | Funciones y vistas | Todos |

> Las claves foráneas que cruzan módulos (por ejemplo, de `Convocatoria` hacia `Seleccion`) se agregan con `ALTER TABLE` una vez creadas todas las tablas.

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