# Entrega 4: Instalación y Configuración del Motor de Base de Datos

**Universidad Nacional de La Matanza — Departamento de Ingeniería e Investigaciones Tecnológicas**

**Sistema de registro y gestión del Mundial de Fútbol — 3641 Bases de Datos Aplicadas**

*Documento técnico dirigido al administrador de bases de datos (DBA)*

| Campo | Detalle |
| :--- | :--- |
| **Materia y Comisión** | 3641 – Bases de Datos Aplicadas \| Comisión 01-2900 |
| **Grupo y Docentes** | Grupo 05 \| Docentes: Ing. Jair Ezequiel Hnatiuk, Ing. Luis Alfonso Palomares |
| **Integrantes (GitHub)** | Casella, Mateo Ezequiel (`MateoCasella`)<br>Chungara Tenorio, Denis Abner (`DenisChungara`)<br>Torczuk, Elías Alexei (`alexxe1`)<br>Canseco Carrizo, Yamil Simón (`yamilscc`) |
| **Repositorio** | `github.com/yamilscc/bda-sistema-mundial-futbol` |

---

## 1. Motor de base de datos

* **Motor:** Microsoft SQL Server 2022 (versión 16.x), instalado sobre Windows Server 2022.
* **Edición:** Standard.
* **Instancia:** Instancia predeterminada (`MSSQLSERVER`), en un servidor dedicado al motor de base de datos.

## 2. Alcance

* **Carga prevista:** Aproximadamente 1 GB, con picos de escritura simultánea en horario de partidos.
* **Entorno:** Uso exclusivo dentro de la LAN, con alta disponibilidad.

## 3. Servidor

### 3.1. Hardware

| Recurso | Valor |
| :--- | :--- |
| **CPU** | 4 núcleos |
| **Memoria RAM** | 16 GB |
| **Disco del sistema operativo** | 80 GB |
| **Discos adicionales** | Cuatro volúmenes separados: datos, logs, `tempdb` y backups |
| **Tipo de almacenamiento** | SSD |

### 3.2. Software y sistema

* **Servidor:** Windows Server 2022, con las últimas actualizaciones aplicadas.
* **Estaciones de administración:** Windows 11, con SQL Server Management Studio (SSMS) instalado. SSMS no se instaló en el servidor.

## 4. Instalación y configuración de la instancia

* **Instalación:** Se realizó una instalación independiente nueva, con las actualizaciones del producto aplicadas y las reglas de instalación sin fallas.
* **Características:** Se instalaron únicamente los Servicios de motor de base de datos.
* **Cuentas de servicio:** Se asignaron cuentas de dominio dedicadas al motor y al Agent. El Agent se configuró con inicio automático. A la cuenta del motor se le otorgó el privilegio de mantenimiento de volumen (inicialización instantánea de archivos).
* **Collation:** Se configuró `Modern_Spanish_CI_AS` (sin distinción de mayúsculas y con distinción de acentos).
* **Autenticación:** Se configuró el modo solo Windows. El único miembro de `sysadmin` es el grupo de DBAs.
* **Directorios:** Se asignaron rutas separadas para datos de usuario, logs de usuario, `tempdb` y backups (ver sección 5).
* **`tempdb`:** Se configuraron cuatro archivos de datos de igual tamaño, en un volumen dedicado.
* **Memoria:** Se establecieron los límites de memoria detallados en la sección 6.
* **Actualizaciones:** Se aplicó el último Cumulative Update estable publicado para SQL Server 2022.

## 5. Ubicación de archivos

| Contenido | Volumen | Ruta |
| :--- | :--- | :--- |
| **Binarios de la instancia** | Disco del sistema operativo | `C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER` |
| **Bases del sistema (`master`, `model`, `msdb`)** | Disco del sistema operativo | `C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA` |
| **Registro de errores** | Disco del sistema operativo | `C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Log` |
| **Archivos de datos de usuario (`.mdf`/`.ndf`)** | Datos | `D:\SQLData` |
| **Archivos de log de usuario (`.ldf`)** | Logs | `L:\SQLLogs` |
| **`tempdb` (datos y log)** | `tempdb` | `T:\SQLTempDB` |
| **Backups locales** | Backups (distinto al de datos) | `B:\SQLBackups` |
| **Copia adicional de backups** | Equipo o recurso de red de la LAN | Fuera del servidor de base de datos |

### 5.1. Tamaño y crecimiento

* **Tamaño inicial:** Datos: 2 GB. Log: 1 GB. Se dimensionaron para evitar crecimientos automáticos durante los partidos.
* **Crecimiento:** 256 MB fijos en datos y log, sin crecimiento porcentual.
* **Monitoreo:** Se monitorea el espacio libre de cada volumen.

## 6. Memoria

* **Memoria máxima del servidor:** Se configuraron 12288 MB (12 GB), reservando el resto de la RAM para el sistema operativo.
* **Memoria mínima del servidor:** Se configuraron 4096 MB (4 GB).

## 7. Seguridad

* **Autenticación:** Se configuró Windows Authentication como único modo. La cuenta `sa` quedó deshabilitada.
* **Mínimo privilegio:** Se otorgaron los accesos de las aplicaciones mediante roles de base de datos con permisos específicos.
* **Firewall:** Se habilitó el puerto TCP 1433 únicamente para las direcciones o subredes de la LAN que acceden al motor.
* **Cifrado:** Se habilitó «Forzar cifrado» para las conexiones al motor.
* **Auditoría:** Se configuró SQL Server Audit.
* **Parches:** Se definió una ventana periódica de actualización.