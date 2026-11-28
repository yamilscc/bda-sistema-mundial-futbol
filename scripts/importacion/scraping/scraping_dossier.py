#!/usr/bin/env python3
"""
Universidad Nacional de La Matanza - Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elias Alexei
Scraping del dossier de publicidad del Mundial -> scripts/importacion/resultados/campanas_dossier.csv
(la carpeta se crea si no existe; su contenido es local y no se sube al repositorio).

Fuente: https://dossiermundial.netlify.app/  (sitio estatico que arma la pagina en el navegador con los datos
        de una base Firestore de lectura publica, sin clave). En vez de parsear el HTML renderizado, se lee el
        mismo endpoint REST que usa la pagina:
        https://firestore.googleapis.com/v1/projects/repositorio2026-61a28/databases/(default)/documents/campanas
Limites: se hace 1 solo pedido (pageSize=300, hoy hay 75 documentos); solo se pide una pagina mas si la
         respuesta trae nextPageToken. Se envia un User-Agent identificatorio del grupo. No requiere API key.
Datos:  Anunciante;Marca;Titulo;Agencia;Productora;Periodo;Categorias (UTF-8, separador ";", fin de linea LF).
        Categorias va separada por "|". El campo "creditos" del documento contiene nombres de personas y NO se
        lee ni se guarda. Los textos se normalizan para el BULK INSERT estatico: sin ";" ni saltos de linea.
Uso:    python scraping_dossier.py
Dependencias: solo la biblioteca estandar.
"""
import json, re, sys, urllib.parse, urllib.request
from pathlib import Path

DESTINO = Path(__file__).resolve().parent.parent / "resultados"  # scripts/importacion/resultados
UA = {"User-Agent": "BDA-UNLaM-Grupo05/1.0 (trabajo practico universitario)"}
URL = ("https://firestore.googleapis.com/v1/projects/repositorio2026-61a28/databases/(default)/documents/campanas"
       "?pageSize=300")
COLUMNAS = ["Anunciante", "Marca", "Titulo", "Agencia", "Productora", "Periodo", "Categorias"]
CAMPOS = ["anunciante", "marca", "titulo", "agencia", "productora", "periodo"]  # categorias va aparte (array)


def descargar(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def valor(campo):
    """Valor de texto de un campo tipado de Firestore (stringValue/integerValue); '' si falta."""
    if not campo:
        return ""
    for tipo in ("stringValue", "integerValue", "doubleValue"):
        if tipo in campo:
            return str(campo[tipo])
    return ""


def limpiar(texto):
    # El CSV se carga con BULK INSERT sin comillas: sin separador de campo ni saltos de linea dentro del texto.
    return re.sub(r"\s+", " ", texto.replace(";", ",")).strip()


def fila(documento):
    f = documento.get("fields", {})  # solo se leen los campos listados: "creditos" nunca se toca
    cats = [valor(v) for v in f.get("categorias", {}).get("arrayValue", {}).get("values", [])]
    return [limpiar(valor(f.get(c))) for c in CAMPOS] + ["|".join(limpiar(c) for c in cats if c)]


def main():
    DESTINO.mkdir(parents=True, exist_ok=True)
    documentos, token = [], None
    while True:
        url = URL + ("&pageToken=" + urllib.parse.quote(token) if token else "")
        datos = descargar(url)
        documentos += datos.get("documents", [])
        token = datos.get("nextPageToken")
        if not token:
            break
    if not documentos:
        sys.exit("La fuente no devolvio campanas: no se genera el CSV.")
    with open(DESTINO / "campanas_dossier.csv", "w", encoding="utf-8", newline="") as f:
        # Se escribe a mano: los textos ya no tienen ";" ni saltos de linea, y el BULK INSERT no interpreta comillas.
        f.write(";".join(COLUMNAS) + "\n")
        for d in documentos:
            f.write(";".join(fila(d)) + "\n")
    print("OK campanas_dossier.csv (%d campanas)" % len(documentos))


if __name__ == "__main__":
    main()
