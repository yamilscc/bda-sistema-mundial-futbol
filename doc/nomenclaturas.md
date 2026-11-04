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
| Esquemas | camelCase | `jugador` |
| Tablas | PascalCase en singular | `Seleccion`, `EspacioPublicitario`, `Partido` |
| Claves primarias (PK) | `IdNombreTabla` | `IdPartido` |
| Claves foráneas (FK) | Mismo nombre que la PK referenciada | `IdPartido` |
| Constraints | Prefijos estandarizados | `PK_Tabla`, `FK_TablaHija_TablaPadre`, `UQ_Tabla_Campo`, `CK_Tabla_Regla`, `DF_Tabla_Campo` |
| Stored procedures | Prefijo `SP_` en mayúsculas | `SP_CONTROL_ARBITRAL`, `SP_CALCULO_DE_SELECCIONES_CLASIFICADAS` |
| Procedimientos ABM | Prefijo `SP_ABM_` | `SP_ABM_Partido` |
| Funciones | Prefijo `fn_` + PascalCase | `fn_MercadosEnPrimeTime` |
| Variables y parámetros | `@camelCase` | `@miVariable` |
| Triggers | `TR_Tabla_Evento` | `TR_Gol_Insert` |
| Índices | `IX_Tabla_Campo` | `IX_Partido_Fecha` |
| Scripts (archivos) | Numerados según el orden de ejecución | `01_Tablas_Nucleo.sql`, `02_SP_Partidos.sql` |