# Entrega 3: Diseño Conceptual y Diagrama Entidad-Relación (DER)

**Universidad Nacional de La Matanza — Departamento de Ingeniería e Investigaciones Tecnológicas**

**Sistema de registro y gestión del Mundial de Fútbol — 3641 Bases de Datos Aplicadas**

| Campo | Detalle |
| :--- | :--- |
| **Materia y Comisión** | 3641 – Bases de Datos Aplicadas \| Comisión 01-2900 |
| **Grupo y Docentes** | Grupo 05 \| Docentes: Ing. Jair Ezequiel Hnatiuk, Ing. Luis Alfonso Palomares |
| **Integrantes (GitHub)** | Casella, Mateo Ezequiel (`MateoCasella`)<br>Chungara Tenorio, Denis Abner (`DenisChungara`)<br>Torczuk, Elías Alexei (`alexxe1`)<br>Canseco Carrizo, Yamil Simón (`yamilscc`) |
| **Repositorio y Artefacto** | `github.com/yamilscc/bda-sistema-mundial-futbol` \| Diagrama fuente: `Mundial2026` |

---

## 1. Objetivo y alcance del modelo conceptual

El presente documento formaliza el diseño conceptual de la base de datos para el **Sistema de registro y gestión del Mundial de Fútbol**, correspondiente a la Entrega 3 del Trabajo Práctico Integrador. El modelo releva la versión consolidada del diagrama (`Mundial2026`) y describe la totalidad de sus entidades, atributos, relaciones, cardinalidades y criterios de normalización.

Con el propósito de facilitar la lectura y la trazabilidad hacia el modelo relacional, las **28 entidades** y **34 relaciones** del diagrama se organizan en cinco dominios funcionales (**Núcleo Geográfico y Competencia**, **Arbitraje**, **Jugadores, Convocatoria y Alineaciones**, **Eventos de Partido** y **Publicidad**), complementados por un bloque de **3 entidades paramétricas de reglas** que permiten configurar topes reglamentarios sin codificar constantes fijas.

---

## 2. Convenciones de notación del diagrama

El diagrama `Mundial2026` utiliza notación Entidad-Relación estándar (Chen extendido) con las siguientes convenciones:

* **Entidades regulares y débiles:** 27 entidades se representan como entidades regulares (`Regular`) y **`EspacioPublicitario`** se representa explícitamente como **entidad débil (`Weak`)**, dependiente de `Partido` a través de la relación identificadora `se asocia a` y de su clave parcial `NumeroEspacio`.
* **Atributos clave y clave parcial:** Los atributos identificadores marcados como únicos (`Unique`) se resaltan con subrayado en el diagrama (`ID` en `Partido`, `Arbitro`, `StaffTecnico`, `Jugador`, `PiezaPublicitaria` y `Anunciante`; `IdPais` en `Pais`; `IdRegla` en la entidad de reglas de clasificación). La clave parcial de la entidad débil (`NumeroEspacio`) se señala como `Partially Unique`.
* **Atributos compuestos:** `Horario` (`HorarioUTC`, `HorarioLocal`) y `Resultado` (`ResultadoLocal`, `ResultadoVisitante`) en `Partido` se modelan como atributos compuestos (`Composite`). Los datos personales de `Jugador`, `StaffTecnico` y `Arbitro` se representan de forma atómica y directa sobre cada entidad (`ID`, `Nombre`, `Apellido`, `Sexo`).
* **Entidades paramétricas de reglas:** Las reglas globales del campeonato (`ReglaMaxMinConvocados`, `ReglaMaxMinCambios` y la regla de clasificación) se modelan como entidades independientes desacopladas de las tablas transaccionales.

---

## 3. Catálogo de entidades y atributos por dominio

### 3.1. Dominio Núcleo Geográfico y Competencia

| Entidad | Tipo | Atributos en el DER | Rol en el modelo |
| :--- | :--- | :--- | :--- |
| **`Confederacion`** | Regular | *Sin atributos detallados en el diagrama.* | Agrupa geográficamente a los países afiliados. |
| **`Pais`** | Regular | <u>`IdPais`</u>, `Nombre`, `PBIPerCapita`. | Entidad geográfica central: vincula ciudades, selecciones, árbitros y orientación publicitaria. |
| **`Ciudad`** | Regular | `HusoHorario`. | Localidad anfitriona; provee el huso horario para determinar el horario local de las sedes. |
| **`Sede`** | Regular | `NombreEstadio`, `Capacidad`. | Estadio donde se disputan los encuentros del torneo. |
| **`Grupo`** | Regular | `Nombre`. | Zona clasificatoria correspondiente a la fase de grupos. |
| **`Fase`** | Regular | `Descripcion`. | Etapa del torneo (fase de grupos e instancias eliminatorias). |
| **`Selección`** | Regular | *Identificada mediante vínculo 1:1 con `Pais`.* | Representativo nacional participante en el certamen. |
| **`StaffTecnico`** | Regular | <u>`ID`</u>, `Nombre`, `Apellido`, `Sexo`, `Rol`. | Integrantes del cuerpo técnico asignados a una selección. |
| **`Partido`** | Regular | <u>`ID`</u>, `Fecha`, `Concurrencia`; *`Horario`* (`HorarioUTC`, `HorarioLocal`); *`Resultado`* (`ResultadoLocal`, `ResultadoVisitante`). | Encuentro oficial entre dos selecciones en una sede y fase; eje articulador de alineaciones, eventos, arbitraje y publicidad. |

### 3.2. Dominio Arbitraje

| Entidad | Tipo | Atributos en el DER | Rol en el modelo |
| :--- | :--- | :--- | :--- |
| **`Arbitro`** | Regular | <u>`ID`</u>, `Nombre`, `Apellido`, `Sexo`. | Oficial habilitado para integrar ternas y equipo VAR en partidos, sujeto a control de nacionalidad por país. |
| **`Idioma`** | Regular | `Descripcion`. | Catálogo de idiomas hablados por los árbitros designados. |
| **`DesignacionArbitral`** | Regular | *Sin atributos detallados en el diagrama (en el modelo relacional incorpora `Rol`).* | Materializa la asignación de un árbitro a un partido determinado y sirve de anclaje para eventuales sanciones post-partido. |
| **`Sancion`** | Regular | `Descripcion`. | Sanciones disciplinarias o informes post-partido aplicados sobre una designación arbitral específica. |

### 3.3. Dominio Jugadores, Convocatoria y Alineaciones

| Entidad | Tipo | Atributos en el DER | Rol en el modelo |
| :--- | :--- | :--- | :--- |
| **`Club`** | Regular | *Sin atributos detallados en el diagrama.* | Institución de procedencia de cada futbolista. |
| **`Jugador`** | Regular | <u>`ID`</u>, `Nombre`, `Apellido`, `Sexo`, `PosicionHabitual`, `Dorsal`. | Futbolista elegible para convocatoria, formaciones, sustituciones, goles y amonestaciones. |
| **`Formacion`** | Regular | `Localia`, `EsquemaTactico`. | Planilla táctica presentada por el equipo local o visitante para un partido determinado. |
| **`Sustitucion`** | Regular | `JugadorSaliente`, `JugadorEntrante`, `Minuto`, `Motivo`, `Periodo`. | Modificación de futbolistas efectuada durante el tiempo regular o suplementario de un partido. |

### 3.4. Dominio Eventos de Partido

| Entidad | Tipo | Atributos en el DER | Rol en el modelo |
| :--- | :--- | :--- | :--- |
| **`Gol`** | Regular | `Minuto`. | Conversión registrada en un partido, vinculada a su autor, eventual asistente, tipo y período. |
| **`TipoDeGol`** | Regular | `Descripcion`. | Clasificación reglamentaria del tanto (jugada, penal, tiro libre, cabezazo, en contra). |
| **`Periodo`** | Regular | `Descripcion`. | Tramo temporal del encuentro en que ocurre el gol (tiempos regulares, adicionales, alargue o penales). |
| **`Amonestacion`** | Regular | `Minuto`, `Motivo`. | Registro disciplinario de tarjeta aplicada a un jugador o a un miembro del cuerpo técnico durante un encuentro. |
| **`Tarjeta`** | Regular | `Tipo`. | Catálogo unificado de tarjetas aplicables (amarilla, roja por doble amarilla y roja directa). |

### 3.5. Dominio Publicidad

| Entidad | Tipo | Atributos en el DER | Rol en el modelo |
| :--- | :--- | :--- | :--- |
| **`Anunciante`** | Regular | <u>`ID`</u>, `Nombre`. | Empresa o marca que contrata y provee piezas publicitarias para el torneo. |
| **`PiezaPublicitaria`** | Regular | <u>`ID`</u>, `Titulo`, `Descripcion`, `Idioma`. | Contenido comercial ofrecido por un anunciante y orientado a uno o más países objetivo. |
| **`EspacioPublicitario`** | **Débil** | <u>`NumeroEspacio`</u> *(clave parcial)*, `TarifaPublicitaria`, `Moneda`. | Cada una de las franjas publicitarias asociadas a un partido (1 a 4), conservando la tarifa y moneda vigentes al momento de la exhibición. |

### 3.6. Entidades Paramétricas de Reglas

| Entidad | Atributos en el DER | Propósito reglamentario |
| :--- | :--- | :--- |
| **`ReglaMaxMinConvocados`** | `Minimo`, `Maximo`. | Parametriza los límites inferior y superior de la lista de convocados por selección. |
| **`ReglaMaxMinCambios`** | `Cantidad Maxima Cambios Tiempo Regular`, `Cantidad Maxima Ventanas Tiempo Regular`, `Cantidad Maxima Cambios Tiempo Suplementario`, `Cantidad Maxima Ventanas Tiempo Suplementario`. | Define los topes de sustituciones y ventanas permitidas en tiempo regular y tiempo suplementario. |
| **`ReglaClasificacion`** *(rotulada `Entity` en el archivo fuente)* | <u>`IdRegla`</u>, `ClasificadosPorGrupo`, `MejoresTerceros`. | Configura cuántos equipos avanzan directamente por grupo y cuántos mejores terceros clasifican a instancias eliminatorias. |

---

## 4. Matriz de relaciones y cardinalidades

La siguiente tabla detalla las **34 relaciones** presentes en `Mundial2026`, indicando las entidades vinculadas, el rótulo de la relación, la cardinalidad y los atributos propios cuando corresponden:

| Dominio | Entidad A — Entidad B | Relación | Card. | Atributos propios / Observaciones |
| :--- | :--- | :--- | :---: | :--- |
| Núcleo | `Pais` — `Confederacion` | `pertenece` | N : 1 | Cada país pertenece a una única confederación. |
| Núcleo | `Ciudad` — `Pais` | `pertenece` | N : 1 | Cada ciudad pertenece a un único país. |
| Núcleo | `Sede` — `Ciudad` | `contiene` | N : 1 | Una ciudad contiene una o más sedes y aporta el huso horario. |
| Núcleo | `Partido` — `Sede` | `aloja` | N : 1 | Una sede aloja múltiples partidos del calendario. |
| Núcleo | `Partido` — `Fase` | `ocurre en` | N : 1 | Cada partido pertenece a una única fase del campeonato. |
| Núcleo | `Pais` — `Selección` | `es representado por` | 1 : 1 | Correspondencia biunívoca entre país y selección nacional. |
| Núcleo | `Selección` — `Grupo` | `formado por` | N : 1 | Cada selección integra un único grupo en la primera fase. |
| Núcleo | `Partido` — `Selección` | `es jugado por local` | N : 1 | Identifica la selección que actúa como local en el encuentro. |
| Núcleo | `Partido` — `Selección` | `es jugador por visitante` | N : 1 | Identifica la selección que actúa como visitante en el encuentro. |
| Núcleo | `StaffTecnico` — `Selección` | `dirige` | N : 1 | Un cuerpo técnico de varios roles dirige a una selección. |
| Arbitraje | `Arbitro` — `Pais` | `pertenece` | N : 1 | Nacionalidad del árbitro para control de conflictos por partido. |
| Arbitraje | `Arbitro` — `Idioma` | `habla` | N : N | Un árbitro puede hablar uno o varios idiomas. |
| Arbitraje | `Partido` — `DesignacionArbitral` | `tiene` | 1 : N | Un partido posee múltiples designaciones arbitrales (Principal, Asistentes, Cuarto, VAR). |
| Arbitraje | `DesignacionArbitral` — `Arbitro` | `está asociada a` | N : 1 | Un árbitro puede participar en múltiples designaciones a lo largo del torneo. |
| Arbitraje | `DesignacionArbitral` — `Sancion` | `se aplica a` | 1 : N | Una designación arbitral puede recibir una o más sanciones o informes post-partido. |
| Jugadores | `Jugador` — `Club` | `juega en` | N : 1 | Club de procedencia del futbolista. |
| Jugadores | `Selección` — `Jugador` | `convoca` | 1 : N | Lista oficial de futbolistas convocados por selección. |
| Jugadores | `Selección` — `Jugador` | `tiene baja de` | 1 : N | Atributos propios: **`FechaDeCambio`**, **`Motivo`**. |
| Jugadores | `Partido` — `Formacion` | `posee` | 1 : N | Un partido posee las formaciones de ambos equipos (local y visitante). |
| Jugadores | `Formacion` — `Jugador` | `tiene` | N : N | Atributos propios: **`PosicionEnCampo`**, **`EstadoTitularidad`**. |
| Jugadores | `Partido` — `Sustitucion` | `posee` | 1 : N | Cambios registrados durante el encuentro. |
| Eventos | `Partido` — `Gol` | `tiene` | 1 : N | Goles convertidos en el partido. |
| Eventos | `Gol` — `Jugador` | `anotado por` | N : 1 | Futbolista autor del gol. |
| Eventos | `Gol` — `Jugador` | `es asistido` | N : 1 | Futbolista asistente (opcional en penales o goles en contra). |
| Eventos | `Gol` — `TipoDeGol` | `tipifica` | N : 1 | Asigna la categoría reglamentaria al gol. |
| Eventos | `Gol` — `Periodo` | `contiene` | N : 1 | Ubica el gol en un período reglamentario del encuentro. |
| Eventos | `Partido` — `Amonestacion` | `se vincula a` | 1 : N | Tarjetas exhibidas durante un partido. |
| Eventos | `Amonestacion` — `Tarjeta` | `se vincula a` | N : 1 | Define el tipo de tarjeta aplicada en la amonestación. |
| Eventos | `Amonestacion` — `Jugador` | `corresponde` | N : 1 | Atributo propio: **`CantidadDePartidos`** (suspensión derivada). |
| Eventos | `Amonestacion` — `StaffTecnico` | `corresponde` | N : 1 | Atributo propio: **`CantidadDePartidos`** (arco excluyente respecto de `Jugador`). |
| Publicidad | `PiezaPublicitaria` — `Anunciante` | `es ofrecida por` | N : 1 | Cada pieza pertenece a un único anunciante. |
| Publicidad | `PiezaPublicitaria` — `Pais` | `está orientada a` | N : N | Segmentación geográfica de mercados objetivo por pieza. |
| Publicidad | `EspacioPublicitario` — `PiezaPublicitaria` | `está asignada a` | N : 1 | Una pieza puede exhibirse en espacios de distintos partidos. |
| Publicidad | `Partido` — `EspacioPublicitario` | `se asocia a` | 1 : N | **Relación identificadora** (entidad débil): cada partido habilita 4 espacios numerados. |

---

## 5. Decisiones clave de modelado

1. **Materialización de `DesignacionArbitral`:** En lugar de modelar una relación N:N directa entre `Partido` y `Arbitro` sumada a una relación ternaria con `Sancion`, se elevó **`DesignacionArbitral`** a entidad propia. Esto garantiza que toda sanción o informe post-partido (`Sancion`) apunte únicamente a un árbitro efectivamente designado en ese partido, reforzando la integridad referencial.
2. **Unificación de expulsiones en `Tarjeta` y `Amonestacion`:** Se prescindió de una entidad separada `Expulsión`, absorbiendo los tipos de expulsión dentro del catálogo `Tarjeta` (*Amarilla*, *Roja por doble amarilla*, *Roja directa*). De esta forma se evita una tabla extra y claves foráneas nulas innecesarias en `Amonestacion`.
3. **Explicitación de selecciones contendientes en `Partido`:** Las relaciones `es jugado por local` y `es jugador por visitante` entre `Partido` y `Selección` permiten gestionar el fixture, validar descansos mínimos, bloquear conflictos arbitrales por nacionalidad y priorizar mercados publicitarios sin depender de recorrer las formaciones.
4. **Aplanamiento de datos personales:** `Jugador`, `StaffTecnico` y `Arbitro` exponen directamente sus atributos atómicos (`ID`, `Nombre`, `Apellido`, `Sexo`), dejando el diagrama alineado con 1FN y listo para el mapeo relacional.
5. **Entidad débil `EspacioPublicitario` y registro histórico:** Modelar `EspacioPublicitario` como entidad débil identificada por `(Partido.ID, NumeroEspacio)` asegura la dependencia existencial de las cuatro franjas por partido y resguarda `TarifaPublicitaria` y `Moneda` vigentes al momento de emisión como respaldo de facturación histórica.
6. **Parametrización de reglas de negocio:** Los límites de convocatoria (`ReglaMaxMinConvocados`), cambios/ventanas (`ReglaMaxMinCambios`) y clasificación (`ReglaClasificacion`) se separan en entidades de configuración para evitar valores rígidos en la lógica del sistema.
7. **Depuración de relaciones identificadoras:** Se restringió la notación identificadora únicamente a `EspacioPublicitario` — `Partido` (`se asocia a`), corrigiendo las demás relaciones del modelo como asociaciones estándar entre entidades regulares.

---

## 6. Análisis de normalización (1FN, 2FN y 3FN)

El modelo fue evaluado respecto de la Primera, Segunda y Tercera Forma Normal para prevenir redundancias y anomalías de inserción, actualización y borrado en el pasaje al esquema relacional:

### 6.1. Primera Forma Normal (1FN) — Atomicidad y eliminación de grupos repetitivos

* **Atributos atómicos:** Los atributos de `Jugador`, `StaffTecnico` y `Arbitro` ya se presentan atómicos (`ID`, `Nombre`, `Apellido`, `Sexo`). Los atributos compuestos remanentes en `Partido` (`Horario` y `Resultado`) se descomponen en sus columnas elementales (`HorarioUTC` y goles/penales) al pasar al modelo relacional.
* **Relaciones multivaluadas normalizadas:** Todos los vínculos N:N (`Arbitro`–`Idioma`, `Formacion`–`Jugador` y `PiezaPublicitaria`–`Pais`) se resuelven mediante relaciones asociativas independientes, eliminando listas concatenadas o grupos repetitivos.

### 6.2. Segunda Forma Normal (2FN) — Dependencia funcional completa

* **Claves compuestas sin dependencias parciales:** En la entidad débil `EspacioPublicitario` —identificada por $(\text{IdPartido}, \text{NumeroEspacio})$— tanto `TarifaPublicitaria` como `Moneda` dependen de la combinación completa de partido y número de espacio. Análogamente, en la relación N:N `Formacion`–`Jugador`, `EstadoTitularidad` y `PosicionEnCampo` dependen conjuntamente de la formación y del jugador.
* **Cuidado con `Dorsal` en el pasaje a tablas:** En el DER `Dorsal` figura como atributo de `Jugador`. En el esquema relacional debe almacenarse una sola vez (en la convocatoria del jugador para el torneo) y evitar su replicación en `FormacionJugador` salvo que se defina como dato histórico variable por partido; de lo contrario se introduciría la dependencia parcial $\text{IdJugador} \rightarrow \text{Dorsal}$ sobre la clave compuesta $(\text{IdFormacion}, \text{IdJugador})$, rompiendo 2FN.

### 6.3. Tercera Forma Normal (3FN) — Ausencia de dependencias transitivas

* **Jerarquía geográfica normalizada:** La cadena `Sede → Ciudad → Pais → Confederacion` garantiza que `HusoHorario` dependa exclusivamente de `Ciudad` y `PBIPerCapita` dependa exclusivamente de `Pais`, eliminando dependencias transitivas desde `Partido` o `Sede`.
* **Catálogos desacoplados:** `Fase`, `Grupo`, `Club`, `TipoDeGol`, `Periodo`, `Tarjeta` e `Idioma` se separan en entidades propias para evitar duplicación de textos y dependencias transitivas en las tablas operativas.
* **Datos derivables (`HorarioLocal` y `Resultado`):** `HorarioLocal` se deriva dinámicamente a partir de `HorarioUTC` y `Ciudad.HusoHorario`, mientras que `ResultadoLocal` y `ResultadoVisitante` se derivan de la sumatoria de registros en `Gol`. Persistir únicamente los datos base evita inconsistencias en 3FN; si el modelo físico almacena el resultado final al cerrar el partido por motivos de consulta, debe mantenerse sincronizado exclusivamente mediante procedimientos almacenados.
* **Dependencia de `CantidadDePartidos` en `Amonestacion`:** Dado que la suspensión depende de la incidencia particular (acumulación de amarillas, doble amarilla o gravedad de una roja directa) y no de una correspondencia fija desde `Tarjeta`, el atributo depende directamente de la amonestación y cumple 3FN.
* **Persistencia histórica en `EspacioPublicitario`:** Conservar `TarifaPublicitaria` y `Moneda` en cada espacio publicitario del partido no viola 3FN, ya que la tarifa acordada depende específicamente del encuentro y franja contratada, resguardando la trazabilidad histórica de facturación.

---

## 7. Verificación técnica y observaciones sobre el archivo fuente (`Mundial2026`)

Al auditar la definición del diagrama `Mundial2026` se identificaron seis ajustes menores de dibujo/rotulación a tener presentes para la exportación final de la imagen y el pasaje al esquema relacional:

| Elemento en `Mundial2026` | Observación detectada | Acción recomendada / Resolución en SQL |
| :--- | :--- | :--- |
| **`Entity`** (`IdRegla`, `ClasificadosPorGrupo`, `MejoresTerceros`) | Conserva el nombre genérico por defecto `Entity`. | Renombrar la entidad a **`ReglaClasificacion`** antes de exportar la imagen definitiva del DER. |
| **`DesignacionArbitral`** | Al transformarse en entidad propia no se trasladó el atributo `Rol` desde la relación anterior. | Agregar el atributo **`Rol`** a `DesignacionArbitral` (en SQL es columna obligatoria con `CHECK`). |
| **`es jugador por visitante`** | Errata tipográfica ("jugador" en lugar de "jugado"). | Corregir el rótulo a **`es jugado por visitante`**. |
| **`Sustitucion`** | `JugadorSaliente`, `JugadorEntrante` y `Periodo` figuran como atributos sueltos en lugar de relaciones. | En el modelo relacional se implementan dos claves foráneas hacia `Jugador` (`IdJugadorSaliente`, `IdJugadorEntrante`) evitando autosustitución. |
| **`Amonestacion`** (doble `corresponde`) | Se vincula tanto a `Jugador` como a `StaffTecnico` sin notación explícita de exclusividad. | En el modelo relacional se aplica restricción `CHECK` de arco exclusivo (exactamente uno de los dos sancionados por registro). |
| **Atributos faltantes en el gráfico** | `Club` y `Confederacion` no muestran atributos; varias entidades regulares omiten su atributo `ID` subrayado; `HorarioLocal` y `Resultado` no están marcados como `Derived`. | Completar `Nombre` en `Club` y `Confederacion` e identificar las claves primarias en todas las tablas físicas siguiendo `doc/nomenclaturas.md`. |