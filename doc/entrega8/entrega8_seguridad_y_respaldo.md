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
En cumplimiento de las leyes de protección de datos personales y las directivas de seguridad para competencias internacionales, se identificaron los siguientes campos críticos como datos sensibles:
* **`jugadores.Jugador`:** `Documento` (DNI, Pasaporte o cédula identificatoria del jugador).
* **`nucleo.Arbitro`:** `NombreApellido` y datos identificatorios del cuerpo arbitral.
* **`nucleo.StaffTecnico`:** `NombreApellido` de directores técnicos y ayudantes de campo.

### 2.2 Estrategia Criptográfica Implementada
Se implementó un esquema de cifrado simétrico mediante funciones y procedimientos almacenados en el esquema `nucleo`:
* **Algoritmo:** Cifrado simétrico AES a través de la infraestructura criptográfica de SQL Server (`ENCRYPTBYPASSPHRASE` / `DECRYPTBYPASSPHRASE`) gobernado por una clave segura canónica administrada por la función `nucleo.fn_ObtenerClaveCifrado()`.
* **Funciones escalares auxiliares:**
  * `nucleo.fn_CifrarTexto(@texto NVARCHAR(MAX)) RETURNS VARBINARY(MAX)`: Transforma el texto plano a representación binaria encriptada.
  * `nucleo.fn_DescifrarTexto(@cifrado VARBINARY(MAX)) RETURNS NVARCHAR(MAX)`: Reconstruye el texto plano original a partir del dato binario.
* **Stored Procedures dedicados:**
  * `nucleo.SP_CIFRAR_DATO`: Procedimiento que encapsula el cifrado mediante parámetros OUTPUT.
  * `nucleo.SP_DESCIFRAR_DATO`: Procedimiento que encapsula el descifrado mediante parámetros OUTPUT.

### 2.3 Script Modificatorio y Migración de Datos (`30_Seguridad_Cifrado.sql`)
Tal como solicita la consigna, la seguridad no se codificó de forma estática en la creación inicial, sino como un **script de modificación progresiva**:
1. **Alteración de tablas existentes:**
   * Se agregó la columna `DocumentoCifrado VARBINARY(256) NULL` a la tabla `jugadores.Jugador`.
   * Se agregaron las columnas `NombreApellidoCifrado VARBINARY(512) NULL` a las tablas `nucleo.Arbitro` y `nucleo.StaffTecnico`.
2. **Migración criptográfica:**
   * Se ejecutó un `UPDATE` masivo que encriptó los datos preexistentes en las nuevas columnas binarias.
3. **Enmascaramiento de datos públicos y ajuste de constraints:**
   * Se removió la restricción `UQ_Jugador_Documento` sobre el campo en texto plano.
   * Se aplicó una máscara a las columnas legibles preexistentes (ejemplo: `***-1234` para documentos de jugadores y `***-CONFIDENCIAL-ID***` para árbitros y staff).
4. **Actualización de Stored Procedures (ALTER PROCEDURE):**
   * Se actualizaron `jugadores.SP_ABM_Jugador`, `nucleo.SP_ABM_Arbitro` y `nucleo.SP_ABM_StaffTecnico` (junto con sus variantes `SP_ALTA_*` y `SP_MODIFICACION_*`). Los procedimientos reciben el dato sensible en texto plano por parámetro, validan unicidad contra los datos descifrados y almacenan los bytes cifrados en la base de datos junto con la máscara pública.
5. **Procedimientos de consulta segura:**
   * Se implementaron `jugadores.SP_CONSULTAR_JUGADOR_DESCIFRADO`, `nucleo.SP_CONSULTAR_ARBITRO_DESCIFRADO` y `nucleo.SP_CONSULTAR_STAFF_DESCIFRADO` para habilitar el consumo descifrado únicamente a través de los canales autorizados.


---

## 3. Roles de Seguridad y Permisos Granulares (RBAC)

### 3.1 Definición de Roles
Se establecieron **cuatro (4) roles de base de datos** específicos que modelan los perfiles de usuario que operan el sistema:

1. **`Rol_Administrador`:** Responsable técnico de la plataforma. Posee permisos totales de administración y control sobre todos los esquemas (`nucleo`, `jugadores`, `eventos`, `publicidad`).
2. **`Rol_OperadorResultados`:** Personal operativo en sedes y salas de control de partidos. Autorizado a registrar goles, tarjetas, amonestaciones, alineaciones titulares y sustituciones.
3. **`Rol_GestorPublicidad`:** Departamento comercial y de marketing. Autorizado a gestionar anunciantes, campañas, piezas publicitarias y asignación de pauta en los 4 espacios perimetrales por partido.
4. **`Rol_Consulta`:** Auditores, organismos reguladores, prensa y medios de comunicación. Acceso exclusivo a los reportes estadísticos y vistas informativas consolidadas sin permisos de modificación ni acceso transaccional directo.

### 3.2 Cuadro / Matriz de Permisos Granulares

| Objeto / Esquema / Procedimiento | Rol_Administrador | Rol_OperadorResultados | Rol_GestorPublicidad | Rol_Consulta |
|---|:---:|:---:|:---:|:---:|
| **Control total de Esquemas (nucleo, jugadores, eventos, publicidad)** | **CONTROL** | DENY | DENY | DENY |
| `eventos.SP_REGISTRAR_GOL` | **GRANT EXECUTE** | **GRANT EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** |
| `eventos.SP_REGISTRAR_AMONESTACION` | **GRANT EXECUTE** | **GRANT EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** |
| `eventos.SP_ABM_*` | **GRANT EXECUTE** | **GRANT EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** |
| `jugadores.SP_REGISTRAR_FORMACION` | **GRANT EXECUTE** | **GRANT EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** |
| `jugadores.SP_AGREGAR_JUGADOR_FORMACION`| **GRANT EXECUTE** | **GRANT EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** |
| `jugadores.SP_REGISTRAR_SUSTITUCION` | **GRANT EXECUTE** | **GRANT EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** |
| `jugadores.SP_CONVOCAR_JUGADOR` | **GRANT EXECUTE** | **GRANT EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** |
| `jugadores.SP_REGISTRAR_BAJA_CONVOCATORIA`| **GRANT EXECUTE** | **GRANT EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** |
| `nucleo.SP_CONTROL_ARBITRAL` | **GRANT EXECUTE** | **GRANT EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** |
| `publicidad.SP_ASIGNAR_PUBLICIDAD` | **GRANT EXECUTE** | **DENY EXECUTE** | **GRANT EXECUTE** | **DENY EXECUTE** |
| `nucleo.SP_ABM_Anunciante` / `Pieza` / `Espacio` | **GRANT EXECUTE** | **DENY EXECUTE** | **GRANT EXECUTE** | **DENY EXECUTE** |
| `nucleo.SP_ABM_Arbitro` / `StaffTecnico` | **GRANT EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** |
| `jugadores.SP_ABM_Jugador` | **GRANT EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** |
| **Reportes Entrega 7** (`eventos.SP_REPORTE_*`, `nucleo.SP_REPORTE_*`, etc.) | **GRANT EXECUTE** | **GRANT EXECUTE** | **GRANT EXECUTE** | **GRANT EXECUTE** |
| **Tablas nucleo, jugadores, eventos (SELECT)** | **GRANT SELECT** | **GRANT SELECT** | **DENY / SELECT Parcial** | **GRANT SELECT** |
| **Modificación directa (INSERT, UPDATE, DELETE en tablas)** | **GRANT** | **DENY** | **DENY** | **DENY** |
| **Procedimientos de Backup** (`nucleo.SP_BACKUP_*`) | **GRANT EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** | **DENY EXECUTE** |

### 3.3 Implementación Mediante Stored Procedures (`31_Seguridad_Roles_Permisos.sql`)
La gestión de seguridad se encuentra 100% automatizada a través de procedimientos en el esquema `nucleo`:
* `nucleo.SP_CREAR_ROLES_SISTEMA`: Script idempotente que valida y crea los cuatro roles y aplica los `GRANT` y `DENY` correspondientes.
* `nucleo.SP_ASIGNAR_USUARIO_ROL`: Procedimiento parametrizado que valida la existencia del usuario y rol para ejecutar `ALTER ROLE ... ADD MEMBER ...`.
* `nucleo.SP_REVOCAR_USUARIO_ROL`: Procedimiento parametrizado para ejecutar `ALTER ROLE ... DROP MEMBER ...`.
* `nucleo.SP_CREAR_USUARIOS_PRUEBA`: Instancia usuarios de prueba `WITHOUT LOGIN` para permitir la verificación automatizada en cualquier entorno:
  * `usr_admin_test`
  * `usr_resultados_test`
  * `usr_publicidad_test`
  * `usr_consulta_test`

### 3.4 Evidencia de Testing por Rol (`31_Test_Seguridad_Roles_Permisos.sql`)
En cumplimiento de la consigna (*"Elaboren un script para cada usuario con el que prueben cada rol"*), se consolidaron las pruebas de los cuatro usuarios en el script unificado `scripts/testing/31_Test_Seguridad_Roles_Permisos.sql`. Mediante bloques independientes de suplantación de identidad (`EXECUTE AS USER = '...'` y `REVERT`), el script verifica tanto las operaciones autorizadas como los bloqueos controlados (capturando el **Error 229** de SQL Server en `TRY/CATCH`):

1. **`usr_admin_test` (`Rol_Administrador`):** Valida el control total en consultas sobre tablas y ejecución de procedimientos deportivos y publicitarios.
2. **`usr_resultados_test` (`Rol_OperadorResultados`):** Valida la consulta de partidos y reportes deportivos, y comprueba la denegación con **Error 229** al intentar ejecutar `publicidad.SP_ASIGNAR_PUBLICIDAD` o `publicidad.SP_ABM_Anunciante`.
3. **`usr_publicidad_test` (`Rol_GestorPublicidad`):** Valida la consulta de sedes/partidos y el reporte de ocupación publicitaria, y comprueba el **Error 229** al intentar ejecutar `eventos.SP_REGISTRAR_GOL` o `jugadores.SP_ABM_Jugador`.
4. **`usr_consulta_test` (`Rol_Consulta`):** Valida la ejecución de reportes oficiales y comprueba la denegación estricta (**Error 229**) ante cualquier `INSERT` directo en tablas o intento de ejecución de SPs transaccionales (`eventos.SP_REGISTRAR_AMONESTACION`).

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

```mermaid
flowchart LR
    A[Backup Completo FULL\nDomingo 02:00 AM] --> B[Backup Diferencial DIFF\nDiario 12:00 PM y 18:00 PM]
    B --> C[Backup de Log LOG\nCada 5 min en Partidos\nCada 30 min Base]
```

1. **Backup Completo (FULL):**
   * **Frecuencia:** Semanal (domingos a las 02:00 UTC) o diario nocturno fuera de franja de partidos.
   * **Propósito:** Genera la línea base completa de todos los datos y la estructura del sistema.
2. **Backup Diferencial (DIFF):**
   * **Frecuencia:** Cada 12 horas, programado inmediatamente antes del inicio de la primera tanda de partidos del día (ejemplo: 11:00 UTC).
   * **Propósito:** Captura únicamente las páginas de datos modificadas desde el último backup completo, reduciendo sustancialmente el RTO al momento de restaurar.
3. **Backup de Registro de Transacciones (LOG):**
   * **Frecuencia:**
     * **Durante horario de partidos:** Cada **5 minutos** (garantiza el RPO de 5 min).
     * **Fuera de horario de partidos:** Cada **30 minutos**.
   * **Propósito:** Trunca el registro inactivo, previene el desbordamiento del archivo `.ldf` y permite recuperar el sistema hasta el último bloque de 5 minutos previo a una falla.

### 4.4 Stored Procedures de Automatización (`32_Procedimientos_Backups.sql`)
Se desarrollaron procedimientos en el esquema `nucleo` para la ejecución estandarizada de copias de seguridad con compresión nativa y nombres con timestamp:
* `nucleo.SP_CONFIGURAR_POLITICA_BACKUP`: Valida y aplica el modo `RECOVERY FULL`.
* `nucleo.SP_BACKUP_COMPLETO`: Genera el archivo `MundialFutbol_FULL_YYYYMMDD_HHMMSS.bak`.
* `nucleo.SP_BACKUP_DIFERENCIAL`: Genera el archivo `MundialFutbol_DIFF_YYYYMMDD_HHMMSS.bak`.
* `nucleo.SP_BACKUP_LOG`: Genera el archivo `MundialFutbol_LOG_YYYYMMDD_HHMMSS.trn`.
* `nucleo.SP_CONSULTAR_HISTORIAL_BACKUPS`: Procedimiento de auditoría que consulta `msdb.dbo.backupset` para verificar los tiempos, tamaños y ubicación de las copias realizadas.

### 4.5 Protocolo de Restauración ante Desastres (Disaster Recovery Plan)
Ante un incidente crítico que destruya la base de datos, el procedimiento de recuperación para alcanzar el punto en el tiempo (*Point-in-Time*) consiste en:

```sql
-- 1. Restaurar el último Backup Completo (dejando la base en recuperación)
RESTORE DATABASE MundialFutbol 
FROM DISK = 'C:\Backups\MundialFutbol_FULL_20261123_020000.bak'
WITH NORECOVERY, REPLACE;

-- 2. Restaurar el último Backup Diferencial previo al incidente
RESTORE DATABASE MundialFutbol 
FROM DISK = 'C:\Backups\MundialFutbol_DIFF_20261123_110000.bak'
WITH NORECOVERY;

-- 3. Aplicar en cadena todos los Backups de Log hasta el último disponible
RESTORE LOG MundialFutbol 
FROM DISK = 'C:\Backups\MundialFutbol_LOG_20261123_110500.trn'
WITH NORECOVERY;

-- ... Aplicar sucesivos logs intermedios ...

-- 4. Aplicar el último log disponible dejando la base en estado operacional
RESTORE LOG MundialFutbol 
FROM DISK = 'C:\Backups\MundialFutbol_LOG_20261123_142500.trn'
WITH RECOVERY;
```

---

## 5. Resumen de Archivos Incorporados al Repositorio

| Carpeta | Archivo | Descripción |
|---|---|---|
| `scripts/creacion/` | `30_Seguridad_Cifrado.sql` | Cifrado PII, funciones criptográficas, `ALTER TABLE`, migración y adaptación de SPs ABM. |
| `scripts/creacion/` | `31_Seguridad_Roles_Permisos.sql` | SPs de creación y gestión de 4 roles, asignación granular de permisos y usuarios de prueba. |
| `scripts/creacion/` | `32_Procedimientos_Backups.sql` | SPs para modo FULL, backups Full, Diferencial y de Log de transacciones. |
| `scripts/testing/` | `30_Test_Seguridad_Cifrado.sql` | Test de funciones de cifrado, persistencia binaria y validación de impacto en queries previas. |
| `scripts/testing/` | `31_Test_Seguridad_Roles_Permisos.sql` | Test unificado de permisos y denegaciones (Error 229) para los 4 roles (`usr_admin_test`, `usr_resultados_test`, `usr_publicidad_test`, `usr_consulta_test`). |
| `scripts/testing/` | `32_Test_Backups.sql` | Validación de ejecución de respaldos Full, Diff, Log y consulta de historial en msdb. |
| `doc/entrega8/` | `entrega8_seguridad_y_respaldo.md` | Documento técnico formal de la Entrega 8. |
