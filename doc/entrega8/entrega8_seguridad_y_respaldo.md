# Entrega 8: Seguridad y Respaldo

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

## 1. Introducción y Alcance de la Entrega

El presente documento detalla la implementación técnica correspondiente a la **Entrega 8: Seguridad y Respaldo** para la base de datos `MundialFutbol`. Esta entrega abarca tres ejes fundamentales orientados a proteger la confidencialidad, integridad y disponibilidad del sistema:

1. **Cifrado de datos sensibles (PII):** Protección criptográfica de los datos personales de jugadores, árbitros y cuerpo técnico mediante scripts modificatorios y Stored Procedures.
2. **Roles de seguridad con permisos granulares (RBAC):** Definición y parametrización de cuatro roles de base de datos con privilegios estrictos basados en el principio de menor privilegio (*least privilege*).
3. **Política de respaldo (Backup y RPO):** Definición y justificación técnica de la estrategia de respaldo y contingencia, contemplando los picos de escritura transaccional durante los días y horarios de partidos.

---

## 2. Cifrado de Datos Sensibles

### 2.1 Identificación de Datos Sensibles (PII)
Se cifran los datos personales identificatorios de jugadores, árbitros y cuerpo técnico:
* **`jugadores.Jugador.Documento`** (DNI, pasaporte o cédula del jugador).
* **`nucleo.Arbitro.NombreApellido`**.
* **`nucleo.StaffTecnico.NombreApellido`** (directores técnicos y ayudantes de campo).

### 2.2 Estrategia Criptográfica Implementada
* **Jerarquía de claves de SQL Server:** clave simétrica `ClaveDatosSensibles` (**AES_256**), protegida por el certificado `CertDatosSensibles`, que está protegido por la master key de la base (y esta, por la service master key de la instancia).
* **Ninguna clave en el código:** la contraseña de la master key se genera al azar en `nucleo.SP_CONFIGURAR_CIFRADO` y no se guarda en ningún lado. Es el único SQL dinámico del script, y es estrictamente necesario: `CREATE MASTER KEY` no acepta una variable como contraseña.
* **Cifrado:** `nucleo.SP_CIFRAR_DATO` abre la clave, aplica `ENCRYPTBYKEY` y la cierra. Es un SP porque una función no puede abrir claves. El mismo texto cifrado dos veces da bytes distintos.
* **Descifrado:** `nucleo.fn_DescifrarTexto` (`DECRYPTBYKEYAUTOCERT`, `WITH EXECUTE AS OWNER`) y su envoltorio `nucleo.SP_DESCIFRAR_DATO`. Ningún rol salvo el administrador puede llamarlos directamente: los SP y reportes que descifran lo hacen por cadena de propiedad.
* **Búsquedas por hash:** como el dato cifrado no se puede comparar, se guarda además un hash SHA2_256 (`nucleo.fn_HashDato`) calculado con un secreto aleatorio de 32 bytes (`nucleo.ConfiguracionCifrado`), en mayúsculas y sin espacios en los extremos. Con el secreto, el hash no se puede recalcular por fuerza bruta a partir de documentos probables.
* **Columna pública enmascarada:** `***-` más los últimos 4 caracteres del documento, y `***-CONFIDENCIAL-<id>***` para los nombres.

### 2.3 Script Modificatorio (`31_Seguridad_Cifrado.sql`)
Tal como pide la consigna, el cifrado se aplica como **script de modificación** sobre componentes que ya existen:
1. **Tablas (`ALTER TABLE`):** columnas `DocumentoCifrado`/`DocumentoHash` en `jugadores.Jugador` y `NombreApellidoCifrado`/`NombreApellidoHash` en `nucleo.Arbitro` y `nucleo.StaffTecnico`. La restricción `UQ_Jugador_Documento` (sobre el texto plano) se reemplaza por el índice único filtrado `IX_Jugador_DocumentoHash`.
2. **Consultas:** redefine las funciones de búsqueda y de nombre visible creadas en los scripts 07 y 14 (`jugadores.fn_IdJugadorPorDocumento`, `nucleo.fn_IdArbitroPorNombre`, `nucleo.fn_IdStaffPorNombre`, `nucleo.fn_NombreArbitro` y `nucleo.fn_NombreStaff`). Las importaciones (23 y 24), los seeds (03, 04 y 06) y los reportes buscan y muestran solo a través de ellas, así que siguen funcionando con los datos cifrados sin modificarse. Primero buscan por hash y, si la fila no tiene hash (cargada directo en texto plano), por la columna pública.
3. **SP:** redefine `jugadores.fn_ValidarJugador` (unicidad por hash) y los `SP_ALTA_`/`SP_MODIFICACION_` de Jugador, Arbitro y StaffTecnico. Mantienen la firma y las validaciones; cambia cómo guardan el dato.
4. **Migración (`nucleo.SP_APLICAR_CIFRADO_DATOS_SENSIBLES`):** cifra, calcula el hash y enmascara las filas que estén en texto plano. Es set-based (sin cursores), corre en una sola transacción y es idempotente.
5. **Consulta descifrada:** `jugadores.SP_CONSULTAR_JUGADOR_DESCIFRADO`, `nucleo.SP_CONSULTAR_ARBITRO_DESCIFRADO` y `nucleo.SP_CONSULTAR_STAFF_DESCIFRADO`, con validación de parámetros, para el rol administrador.

### 2.4 Testing (`31_Test_Seguridad_Cifrado.sql`)
Verifica con `OK`/`FALLÓ`:
* que existan las claves y que la configuración sea idempotente;
* el cifrado no determinista y el descifrado exacto, con acentos;
* el hash normalizado;
* los ABM con dato cifrado y documento duplicado rechazado;
* las búsquedas y los nombres visibles;
* la migración de filas en texto plano y que una segunda corrida no cambie nada;
* la consulta descifrada;
* el impacto en tests previos: una búsqueda directa por la columna pública devuelve 0 filas.

---

## 3. Roles de Seguridad y Permisos Granulares (RBAC)

### 3.1 Definición de Roles
Se establecieron **cuatro (4) roles de base de datos** específicos que modelan los perfiles de usuario que operan el sistema:

1. **`Rol_Administrador`:** Responsable técnico de la plataforma. Posee permisos totales de administración y control sobre todos los esquemas (`nucleo`, `jugadores`, `eventos`, `publicidad`).
2. **`Rol_OperadorResultados`:** Personal operativo en sedes y salas de control de partidos. Autorizado a registrar goles, tarjetas, amonestaciones, alineaciones titulares y sustituciones.
3. **`Rol_GestorPublicidad`:** Departamento comercial y de marketing. Autorizado a gestionar anunciantes, campañas, piezas publicitarias y asignación de pauta en los 4 espacios perimetrales por partido.
4. **`Rol_Consulta`:** Auditores, organismos reguladores, prensa y medios de comunicación. Acceso exclusivo a los reportes estadísticos y vistas informativas consolidadas sin permisos de modificación ni acceso transaccional directo.

### 3.2 Cuadro de Permisos

"—" = sin permiso: el rol no tiene ningún GRANT, así que el motor lo deniega por defecto. "DENY" = denegado explícitamente, aun si otro permiso lo habilitara. El administrador tiene `CONTROL` sobre los cuatro esquemas de negocio, pero no es `db_owner`: no puede crear objetos fuera de ellos ni administrar la base.

| Objeto | Rol_Administrador | Rol_OperadorResultados | Rol_GestorPublicidad | Rol_Consulta |
|---|:---:|:---:|:---:|:---:|
| Esquemas `nucleo`, `jugadores`, `eventos`, `publicidad` | CONTROL | — | — | — |
| SELECT sobre `nucleo`, `jugadores` y `eventos` | (CONTROL) | GRANT | Solo `Partido`, `vw_PartidoResultado`, `Sede`, `Ciudad`, `Seleccion`, `Pais`, `Fase` y `fn_MercadosEnPrimeTime` | Solo vistas y funciones de lectura (`vw_PartidoResultado`, `fn_SeleccionesDelPartido`, `fn_MercadosEnPrimeTime`, `fn_DefinicionPartido`, `fn_SeleccionesClasificadas`, `fn_ResultadoPartido`) |
| SELECT y EXECUTE sobre `publicidad` (ABM, asignación, importaciones y reportes) | (CONTROL) | DENY EXECUTE | GRANT | Solo los 2 reportes de publicidad |
| EXECUTE sobre `eventos` (goles, tarjetas, ABM y reportes) | (CONTROL) | GRANT | DENY | Solo los 2 reportes; DENY `SP_REGISTRAR_GOL` y `SP_REGISTRAR_AMONESTACION` |
| EXECUTE sobre `jugadores` (convocatoria, formaciones, sustituciones, ABM) | (CONTROL) | GRANT | DENY | Solo el reporte de plantillas; DENY ABM de jugadores |
| `nucleo.SP_CONTROL_ARBITRAL`, `SP_FINALIZAR_PARTIDO`, `SP_CALCULO_DE_SELECCIONES_CLASIFICADAS`, `SP_DEFINIR_CRUCE_ELIMINATORIO` | (CONTROL) | GRANT | DENY | DENY (salvo control arbitral, que queda en —) |
| Reportes de `nucleo` (designaciones y resultados) | (CONTROL) | GRANT | — | GRANT |
| ABM de árbitros (`SP_ALTA_`/`SP_MODIFICACION_`/`SP_BAJA_Arbitro`) | (CONTROL) | — | — | DENY |
| Importaciones (`SP_IMPORTAR_*`) | (CONTROL) | — | Solo las de `publicidad` | DENY |
| INSERT, UPDATE y DELETE directo en tablas | (CONTROL) | — | — | DENY |
| Descifrado (`fn_DescifrarTexto`, `SP_DESCIFRAR_DATO`, `SP_CONSULTAR_*_DESCIFRADO`) y secreto del hash (`ConfiguracionCifrado`) | (CONTROL) | DENY | DENY | DENY |
| Backups (`nucleo.SP_BACKUP_*`) | (CONTROL) | — | — | DENY |

Las altas y modificaciones que cifran (por ejemplo `SP_ALTA_Jugador` ejecutado por el operador) y los reportes que descifran funcionan para los roles autorizados por **cadena de propiedad**: todos los objetos tienen el mismo dueño, así que el motor no vuelve a verificar permisos sobre el SP de cifrado ni la función de descifrado que usan por dentro.

### 3.3 Implementación Mediante Stored Procedures (`32_Seguridad_Roles_Permisos.sql`)
* `nucleo.SP_CREAR_ROLES_SISTEMA`: crea los cuatro roles y aplica los GRANT y DENY del cuadro. Es idempotente. El script 33 lo vuelve a ejecutar para cubrir los SP de backup.
* `nucleo.SP_ASIGNAR_USUARIO_ROL` / `nucleo.SP_REVOCAR_USUARIO_ROL`: validan con `nucleo.fn_ValidarMembresiaRol` y rechazan en un único mensaje (`THROW 52000`):
  * rol inexistente, o rol fijo del sistema como `db_owner`;
  * usuario inexistente;
  * membresía repetida o inexistente.

  No usan SQL dinámico: llaman a `sp_addrolemember` / `sp_droprolemember`, que reciben el rol y el usuario como parámetros (`ALTER ROLE` no acepta variables).
* `nucleo.SP_CREAR_USUARIOS_PRUEBA`: crea un usuario `WITHOUT LOGIN` por rol (`usr_admin_test`, `usr_resultados_test`, `usr_publicidad_test`, `usr_consulta_test`).

### 3.4 Testing: un script por usuario
Cada script se ejecuta como su usuario (`EXECUTE AS USER`) e imprime `OK`/`FALLÓ` en cada caso:
* **"Puede":** la instrucción corre, o el SP responde con su propia validación (error 52000 porque el id no existe). Nunca con un error de permisos.
* **"No puede":** el motor la rechaza por permisos (error 229, o 262 para crear objetos).

| Script | Usuario | Puede | No puede |
|---|---|---|---|
| `32_Test_Rol_Administrador.sql` | `usr_admin_test` | Leer todo (incluido el secreto del hash), insertar directo, ejecutar SP de eventos y de publicidad, descifrar | Crear tablas fuera de los esquemas de negocio |
| `32_Test_Rol_OperadorResultados.sql` | `usr_resultados_test` | Leer partidos y jugadores, registrar goles y tarjetas, convocar, finalizar partidos, ver goleadores | Asignar publicidad, dar de alta anunciantes, insertar directo, leer el secreto del hash, consultar documentos descifrados |
| `32_Test_Rol_GestorPublicidad.sql` | `usr_publicidad_test` | Leer partidos, sedes y anunciantes, simular la asignación, dar de alta anunciantes, importar campañas, ver la ocupación | Registrar goles, dar de alta jugadores, leer jugadores, finalizar partidos, consultar árbitros descifrados |
| `32_Test_Rol_Consulta.sql` | `usr_consulta_test` | Ejecutar los 7 reportes (los dos XML incluidos) y leer la vista de resultados | Insertar directo, registrar tarjetas, asignar publicidad, leer la tabla de jugadores, descifrar, ejecutar backups |

`32_Test_Seguridad_Roles_Permisos.sql` prueba los SP: idempotencia, permisos creados, alta y baja de un usuario y las validaciones agrupadas.

---

## 4. Política de Respaldo y Recuperación (Backup y RPO)

### 4.1 Análisis del Escenario y Objetivos de Recuperación
Durante la disputa de la Copa del Mundo, el comportamiento transaccional del sistema varía drásticamente según el calendario:
* **Días sin partidos (Tráfico Base):** Volumen de escritura bajo o moderado, acotado a tareas administrativas, acreditaciones y consultas de fixture.
* **Días de partido (Pico Crítico):** Volumen de transacciones masivo y concurrente en tiempo real. Se registran sustituciones minuto a minuto, amonestaciones, goles, revisiones de VAR y consumo publicitario dinámico.

Teniendo esto en cuenta, se definen los siguientes parámetros de servicio:
* **RPO (Recovery Point Objective):**
  * **Días de partido:** **5 minutos**. Ante una falla de hardware catastrófica, la máxima pérdida de datos tolerada es de 5 minutos, garantizando que no se pierdan incidencias de un partido en disputa.
  * **Días sin partido:** **1 hora**.
* **RTO (Recovery Time Objective):** **30 minutos**. Tiempo máximo permitido para restaurar la base de datos a su estado operativo consistente tras una eventual contingencia.

### 4.2 Modelo de Recuperación de la Base de Datos
Para posibilitar un RPO de 5 minutos es mandatorio configurar la base en modo de recuperación **FULL**:
```sql
ALTER DATABASE MundialFutbol SET RECOVERY FULL;
```
Esto asegura que el log de transacciones no se trunque automáticamente y conserve todas las transacciones hasta que se realice un respaldo de log, permitiendo la restauración en un punto exacto en el tiempo (*Point-in-Time Recovery*).

### 4.3 Estrategia y Cronograma de Respaldos

| Backup | Frecuencia | Propósito |
|---|---|---|
| **Completo (FULL)** | Semanal (domingo 02:00 UTC) y diario nocturno a las 04:00 UTC, fuera de la franja de partidos | Línea base de datos y estructura |
| **Diferencial (DIFF)** | Dos por día: antes de la primera tanda de partidos (11:00 UTC) y al cerrar la jornada (03:00 UTC del día siguiente) | Acorta la restauración: después del FULL solo hace falta el último DIFF |
| **Log de transacciones (LOG)** | Cada **5 minutos** durante la franja de partidos (desde una hora antes del primero hasta una hora después del último) y cada **30 minutos** el resto del tiempo | Cumple el RPO y evita que el `.ldf` crezca sin control |

Con log cada 30 minutos fuera de los partidos, la pérdida máxima en esos días es de 30 minutos, menos que el RPO de 1 hora fijado para ellos.

La programación se hace con SQL Server Agent, o con el programador de tareas del sistema que llama a `sqlcmd` en las ediciones sin Agent.

### 4.4 Stored Procedures de Automatización (`33_Procedimientos_Backups.sql`)
* `nucleo.SP_CONFIGURAR_POLITICA_BACKUP`: deja la base en `RECOVERY FULL`.
* `nucleo.SP_BACKUP_COMPLETO`, `nucleo.SP_BACKUP_DIFERENCIAL` y `nucleo.SP_BACKUP_LOG`: generan `MundialFutbol_<TIPO>_aaaammdd_hhmmss.bak`/`.trn` con `CHECKSUM` y compresión (salvo en Express). Comparten `nucleo.SP_EJECUTAR_BACKUP`, que usa `BACKUP ... TO DISK = @ruta` estático, sin SQL dinámico. Validaciones agrupadas (`THROW 52000`):
  * tipo de backup inválido;
  * DIFF o LOG sin un FULL previo;
  * LOG con un modelo de recuperación distinto de FULL;
  * directorio de salida inválido.
* `nucleo.fn_ObtenerRutaBackupPredeterminada`: carpeta de backup de la instancia, con el separador correcto en Windows y en Linux.
* `nucleo.SP_CONSULTAR_HISTORIAL_BACKUPS`: últimos respaldos registrados en `msdb` (valida que la cantidad pedida esté entre 1 y 1000).

`33_Test_Backups.sql` verifica las validaciones, genera un FULL, un DIFF y un LOG y comprueba sus registros en `msdb`.

### 4.5 Respaldo de las Claves de Cifrado
Los datos cifrados solo se pueden leer con el certificado `CertDatosSensibles`. Restaurar en el mismo servidor no requiere nada extra, porque la master key queda protegida por la service master key. Restaurar en **otro** servidor exige haber respaldado antes la master key y el certificado, cada uno con una contraseña elegida en ese momento que **no se guarda en el repositorio** (va en un gestor de secretos):

```sql
USE MundialFutbol;
BACKUP MASTER KEY TO FILE = 'C:\Backups\Claves\MundialFutbol_master.key'
    ENCRYPTION BY PASSWORD = '<contraseña del gestor de secretos>';
BACKUP CERTIFICATE CertDatosSensibles TO FILE = 'C:\Backups\Claves\CertDatosSensibles.cer'
    WITH PRIVATE KEY (FILE = 'C:\Backups\Claves\CertDatosSensibles.pvk',
                      ENCRYPTION BY PASSWORD = '<contraseña del gestor de secretos>');
```

Se hace una vez al crear las claves y cada vez que se regeneran, y los archivos se guardan separados de los backups de la base.

### 4.6 Protocolo de Restauración ante Desastres
Para recuperar hasta el último log disponible (*point in time*):

```sql
-- 1. Si es posible, respaldar la cola del log (lo escrito después del último backup de log).
BACKUP LOG MundialFutbol TO DISK = 'C:\Backups\MundialFutbol_LOG_cola.trn' WITH NORECOVERY;

-- 2. Último FULL, sin recuperar todavía.
RESTORE DATABASE MundialFutbol FROM DISK = 'C:\Backups\MundialFutbol_FULL_20261123_040000.bak' WITH NORECOVERY, REPLACE;

-- 3. Último DIFF posterior a ese FULL.
RESTORE DATABASE MundialFutbol FROM DISK = 'C:\Backups\MundialFutbol_DIFF_20261123_110000.bak' WITH NORECOVERY;

-- 4. Todos los LOG posteriores al DIFF, en orden, y la cola del log.
RESTORE LOG MundialFutbol FROM DISK = 'C:\Backups\MundialFutbol_LOG_20261123_110500.trn' WITH NORECOVERY;
-- ... logs intermedios ...
RESTORE LOG MundialFutbol FROM DISK = 'C:\Backups\MundialFutbol_LOG_cola.trn' WITH RECOVERY;

-- 5. En otro servidor: restaurar antes la master key y el certificado (sección 4.5).
```

---

## 5. Impacto del Cifrado en el Testing Previo

La consigna anticipa que, una vez aplicado el cifrado, algunos tests de entregas anteriores pueden dejar de pasar. Con la suite completa sobre la base con los seeds cargados:

| Test | Caso | Motivo |
|---|---|---|
| `02_Test_Tablas_Jugadores.sql` | `TEST 2.A` ("permitió documento duplicado") | El test inserta dos jugadores con el mismo `Documento` directo en la tabla y espera que lo rechace `UQ_Jugador_Documento`. El cifrado reemplaza esa restricción por el índice único sobre `DocumentoHash`, porque la columna pública pasa a ser una máscara que puede repetirse (`***-D-01` en varias selecciones). Los duplicados se siguen rechazando al dar de alta por `SP_ALTA_Jugador` (probado en el test 31, caso 3.B). |

El resto de la suite pasa. Los tests que cargan filas directo en texto plano siguen funcionando porque las funciones de búsqueda prueban también la columna pública cuando la fila no tiene hash. Los que dan de alta con los SP y buscan con esas funciones (importaciones, seeds) tampoco se ven afectados.

---

## 6. Resumen de Archivos

| Carpeta | Archivo | Descripción |
|---|---|---|
| `scripts/creacion/` | `31_Seguridad_Cifrado.sql` | Script de modificación del cifrado: tablas, claves, funciones, ABM, migración y consultas descifradas |
| `scripts/creacion/` | `32_Seguridad_Roles_Permisos.sql` | Roles, permisos y usuarios de prueba |
| `scripts/creacion/` | `33_Procedimientos_Backups.sql` | Modelo FULL, backups FULL/DIFF/LOG e historial |
| `scripts/testing/` | `31_Test_Seguridad_Cifrado.sql` | Test del cifrado |
| `scripts/testing/` | `32_Test_Seguridad_Roles_Permisos.sql` | Test de los SP de roles |
| `scripts/testing/` | `32_Test_Rol_Administrador.sql`, `32_Test_Rol_OperadorResultados.sql`, `32_Test_Rol_GestorPublicidad.sql`, `32_Test_Rol_Consulta.sql` | Un test por usuario: qué puede y qué no puede hacer |
| `scripts/testing/` | `33_Test_Backups.sql` | Test de los backups |
| `doc/entrega8/` | `entrega8_seguridad_y_respaldo.md` | Este documento |
