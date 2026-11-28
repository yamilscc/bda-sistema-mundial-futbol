/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elías Alexei
Fecha: 2026-11-24
Integrantes:
- Casella, Mateo Ezequiel
- Chungara Tenorio, Denis Abner
- Torczuk, Elías Alexei
- Canseco Carrizo, Yamil Simón
Objetivo: Lanzador de todos los seeds e importaciones de scripts/importacion/sql/, en el orden en que funcionan
          (se corta ante el primer error):
            04  Seed de nucleo y publicidad (países, selecciones, árbitros, anunciantes, tarifas y regla de cupos)
            05  Importación de PBI, fixture (scraping), cotizaciones y pauta
            06  Designaciones arbitrales y asignación de publicidad
            01  Convocatoria desde XML (antes que 03: el 03 completa solo los dorsales que el XML deja libres)
            03  Seed de jugadores, formaciones y eventos
            02  Eventos desde CSV
            07  Cierre de resultados de los partidos
            08  Campañas del dossier de publicidad (scraping)
          Es idempotente: se puede ejecutar de nuevo.

REQUISITOS PARA EJECUTARLO:
  - Ejecutar ANTES creacion\00_Reset_Total.sql.
  - Activar el modo SQLCMD en SSMS: menú Consulta > Modo SQLCMD (sin esto fallan :setvar y :r).
  - Editar abajo la variable RUTA_IMP con la carpeta scripts\importacion de TU copia del repositorio (la que
    contiene sql, scraping, datos y resultados), sin
    barra final. Es la única ruta a editar: los seeds que leen archivos usan esta misma variable.
  - Haber generado los archivos de las fuentes externas en scripts\importacion\resultados (solo existen en la
    copia local; no están en el repositorio), desde scripts\importacion\scraping:
        python fuentes_externas.py todo     -> pbi_banco_mundial.json, cotizaciones_frankfurter.json, fixture_sedes.csv
        python scraping_dossier.py          -> campanas_dossier.csv
    Sin internet: "python fuentes_externas.py fixture --offline" genera el fixture; los JSON de las APIs y el
    dossier necesitan conexión. Si falta un archivo, el BULK INSERT u OPENROWSET falla con "Cannot bulk load...
    does not exist" y la carga se corta.
  - Los archivos fijos del grupo (XML de convocatoria, CSV de eventos y JSON de pauta) están en
    scripts\importacion\datos y vienen en el repositorio.
    (pbi_banco_mundial.json y cotizaciones_frankfurter.json no vienen en el repositorio).
  - Recomendado: Resultados a texto (Ctrl+T).
*/

:on error exit
:setvar RUTA_IMP "C:\CAMBIAR\bda-sistema-mundial-futbol\scripts\importacion"

PRINT '===== 04 Seed de nucleo y publicidad';
GO
:r $(RUTA_IMP)\sql\04_Seed_Nucleo_Publicidad.sql
GO

PRINT '===== 05 Importación de PBI, fixture, cotizaciones y pauta';
GO
:r $(RUTA_IMP)\sql\05_Importar_Nucleo_Publicidad.sql
GO

PRINT '===== 06 Designaciones arbitrales y asignación de publicidad';
GO
:r $(RUTA_IMP)\sql\06_Seed_Designaciones_Publicidad.sql
GO

PRINT '===== 01 Convocatoria desde XML';
GO
:r $(RUTA_IMP)\sql\01_Importar_Convocatoria_XML.sql
GO

PRINT '===== 03 Seed de jugadores, formaciones y eventos';
GO
:r $(RUTA_IMP)\sql\03_Seed_Jugadores_Eventos.sql
GO

PRINT '===== 02 Eventos desde CSV';
GO
:r $(RUTA_IMP)\sql\02_Importar_Eventos_CSV.sql
GO

PRINT '===== 07 Cierre de resultados de los partidos';
GO
:r $(RUTA_IMP)\sql\07_Cierre_Resultados_Partidos.sql
GO

PRINT '===== 08 Campañas del dossier de publicidad';
GO
:r $(RUTA_IMP)\sql\08_Importar_Campanias_Dossier.sql
GO

PRINT '===== Seeds cargados';
GO
