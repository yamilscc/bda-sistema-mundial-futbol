# Nomenclaturas del TP

## Encabezado de scripts

```sql
/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: <autor>
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: <qué hace este script>
*/
```

## Commits

Formato: `tipo: descripción en minúscula, en presente, sin punto final`.

| Tipo | Uso |
|---|---|
| `chore` | Mantenimiento y estructura (primer commit, carpetas, .gitignore) |
| `docs` | README, carátula, documentación |
| `feat` | Script nuevo (tabla, SP, función) |
| `fix` | Corrección de algo ya subido |
| `test` | Scripts de testing |
| `refactor` | Reordenar sin cambiar el comportamiento |

Ejemplos:

- `feat: agrega tabla EspacioPublicitario`
- `fix: corrige validación de prime time en SP_ASIGNAR_PUBLICIDAD`
- `test: adapta el test 20 a los ABM de Campania y Tarifa`

## Ramas

Formato: `tipo/descripcion-corta`, todo en minúscula y con guiones. Usa los mismos tipos que los commits.

Ejemplos:

- `feat/publicidad`
- `feat/nucleo-partidos`
- `feat/convocatoria`
- `feat/eventos-importacion`
- `fix/prime-time`
- `test/sp-importacion`
- `docs/readme`

## Base de datos

| Elemento | Convención | Ejemplo |
|---|---|---|
| Database | PascalCase | `MundialFutbol` |
| Esquemas | camelCase | `jugadores` |
| Tablas | PascalCase en singular, sin tildes ni ñ | `Seleccion`, `EspacioPublicitario`, `Partido`, `Campania` (no `Campaña`) |
| Claves primarias (PK) | `IdNombreTabla` | `IdPartido` |
| Claves foráneas (FK) | Mismo nombre que la PK referenciada | `IdPartido` |
| Constraints | Prefijos estandarizados; si abarca varios campos, se nombran en orden | `PK_Tabla`, `FK_TablaHija_TablaPadre`, `UQ_Tabla_Campo`, `UQ_Tarifa_Fase_Moneda_Vigencia`, `CK_Tabla_Regla`, `DF_Tabla_Campo` |
| Stored procedures | Prefijo `SP_` en mayúsculas | `SP_CONTROL_ARBITRAL`, `SP_CALCULO_DE_SELECCIONES_CLASIFICADAS` |
| Procedimientos ABM | Un SP por operación y tabla: `SP_ALTA_`, `SP_MODIFICACION_` o `SP_BAJA_` + nombre de la tabla. Las tablas asociativas solo tienen alta y baja | `SP_ALTA_Partido`, `SP_MODIFICACION_Campania`, `SP_BAJA_Tarifa`, `SP_ALTA_OrientacionPais` |
| Funciones | Prefijo `fn_` + PascalCase; las de validación de los ABM, `fn_Validar` + tabla | `fn_MercadosEnPrimeTime`, `fn_ValidarCampania` |
| Variables y parámetros | `@camelCase` | `@miVariable` |
| Triggers | `TR_Tabla_Evento` | `TR_Gol_Insert` |
| Índices | `IX_Tabla_Campo` | `IX_Partido_Fecha` |
| Scripts (archivos) | Numerados según el orden de ejecución | `01_Tablas_Nucleo.sql`, `02_SP_Partidos.sql` |