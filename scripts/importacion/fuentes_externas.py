#!/usr/bin/env python3
"""
Universidad Nacional de La Matanza - Bases de Datos Aplicadas - Grupo 05
Autor: Torczuk, Elias Alexei
Descarga las fuentes externas de la Entrega 6 (nucleo y publicidad) a esta carpeta:
  pbi         -> pbi_banco_mundial.json      (API Banco Mundial, indicador NY.GDP.PCAP.CD)
  cotizaciones-> cotizaciones_frankfurter.json (API Frankfurter, base USD)
  fixture     -> fixture_sedes.csv           (scraping de Wikipedia + fixture del torneo)
Uso:  python fuentes_externas.py {pbi|cotizaciones|fixture|todo} [--offline]
Dependencias: solo para 'fixture' en vivo: pip install requests beautifulsoup4
--offline (solo fixture): no scrapea; usa las capacidades y coordenadas incluidas en este script.
Ninguna de las fuentes requiere API key.
"""
import argparse, csv, json, re, sys, urllib.request
from pathlib import Path

DESTINO = Path(__file__).resolve().parent
UA = {"User-Agent": "BDA-UNLaM-Grupo05/1.0 (trabajo practico universitario)"}
ISO2 = "AR;BR;UY;CO;CL;US;MX;CA;NL;ES;FR;DE;GB;PT;IT;CH;NO;SE;MA;JP;KR;AU"  # = nucleo.Pais.CodigoISO2 del seed
MONEDAS = "EUR,BRL,JPY,GBP"  # Frankfurter (BCE) no publica ARS
WIKI = "https://en.wikipedia.org/wiki/2026_FIFA_World_Cup"

# (estadio, ciudad, ISO3 del pais, huso Windows, capacidad, latitud, longitud, palabras para ubicarla en Wikipedia)
SEDES = [
    ("Estadio Azteca", "Ciudad de México", "MEX", "Central Standard Time (Mexico)", 83000, 19.302778, -99.150556, ["mexico city"]),
    ("MetLife Stadium", "East Rutherford", "USA", "Eastern Standard Time", 82500, 40.813611, -74.074444, ["new york", "rutherford"]),
    ("SoFi Stadium", "Inglewood", "USA", "Pacific Standard Time", 70000, 33.953500, -118.339200, ["los angeles", "inglewood"]),
    ("AT&T Stadium", "Arlington", "USA", "Central Standard Time", 80000, 32.747778, -97.092778, ["dallas", "arlington"]),
    ("BMO Field", "Toronto", "CAN", "Eastern Standard Time", 45000, 43.633333, -79.418611, ["toronto"]),
    ("BC Place", "Vancouver", "CAN", "Pacific Standard Time", 54000, 49.276800, -123.111900, ["vancouver"]),
    ("Estadio Akron", "Zapopan", "MEX", "Central Standard Time (Mexico)", 48000, 20.681944, -103.462500, ["guadalajara", "zapopan"]),
    ("Hard Rock Stadium", "Miami Gardens", "USA", "Eastern Standard Time", 65000, 25.958000, -80.238900, ["miami"]),
    ("Estadio BBVA", "Guadalupe", "MEX", "Central Standard Time (Mexico)", 53500, 25.669000, -100.244600, ["monterrey", "guadalupe"]),
]
AZT, MET, SOFI, ATT, BMO, BCP, AKR, HRD, BBV = range(9)

# (NumeroPartido, sede, fecha-hora LOCAL de la sede, local, visitante). 4 grupos de 4 = 24 partidos, todos "Fase de grupos":
# 3 fechas separadas >= 5 dias (>= 72 h de descanso por seleccion) y como maximo un partido por sede y dia.
PARTIDOS = [
    (1, AZT, "2026-06-11T17:00:00", "ARG", "BRA"), (2, MET, "2026-06-11T15:00:00", "USA", "JPN"),
    (3, SOFI, "2026-06-11T12:00:00", "NED", "ESP"), (4, BMO, "2026-06-11T19:00:00", "MAR", "KOR"),
    (5, ATT, "2026-06-12T15:00:00", "FRA", "GER"), (6, BCP, "2026-06-12T18:00:00", "URU", "MEX"),
    (7, AKR, "2026-06-12T13:00:00", "ENG", "POR"), (8, HRD, "2026-06-12T20:00:00", "ITA", "COL"),
    (9, ATT, "2026-06-16T18:00:00", "ARG", "USA"), (10, HRD, "2026-06-16T15:00:00", "BRA", "JPN"),
    (11, MET, "2026-06-16T12:00:00", "NED", "MAR"), (12, BBV, "2026-06-16T20:00:00", "ESP", "KOR"),
    (13, AZT, "2026-06-17T14:00:00", "FRA", "URU"), (14, BMO, "2026-06-17T19:00:00", "GER", "MEX"),
    (15, SOFI, "2026-06-17T17:00:00", "ENG", "ITA"), (16, BCP, "2026-06-17T13:00:00", "POR", "COL"),
    (17, MET, "2026-06-21T20:00:00", "ARG", "JPN"), (18, AKR, "2026-06-21T16:00:00", "BRA", "USA"),
    (19, BBV, "2026-06-21T19:00:00", "NED", "KOR"), (20, AZT, "2026-06-21T13:00:00", "ESP", "MAR"),
    (21, SOFI, "2026-06-22T18:00:00", "FRA", "MEX"), (22, HRD, "2026-06-22T15:00:00", "GER", "URU"),
    (23, ATT, "2026-06-22T12:00:00", "ENG", "COL"), (24, BMO, "2026-06-22T20:00:00", "POR", "ITA"),
]


def descargar(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
        return r.read().decode("utf-8")


def guardar_json(nombre, texto):
    datos = json.loads(texto)  # valida que sea JSON; ensure_ascii evita problemas de codepage en OPENROWSET
    (DESTINO / nombre).write_text(json.dumps(datos, ensure_ascii=True), encoding="ascii")
    print("OK", nombre)


def pbi():
    url = f"https://api.worldbank.org/v2/country/{ISO2}/indicator/NY.GDP.PCAP.CD?format=json&date=2018:2024&per_page=1000"
    guardar_json("pbi_banco_mundial.json", descargar(url))


def cotizaciones():
    guardar_json("cotizaciones_frankfurter.json", descargar(f"https://api.frankfurter.app/latest?from=USD&to={MONEDAS}"))


def capacidades_wikipedia():
    """Scrapea la tabla de sedes de Wikipedia: devuelve {indice_de_SEDES: capacidad}. Si algo falla, devuelve {}."""
    try:
        from bs4 import BeautifulSoup
        sopa = BeautifulSoup(descargar(WIKI), "html.parser")
    except Exception as e:  # sin red o sin bs4
        print("AVISO: no se pudo scrapear Wikipedia:", e, file=sys.stderr)
        return {}
    capacidades = {}
    for tabla in sopa.select("table.wikitable"):
        filas = tabla.select("tr")
        enc = [th.get_text(" ", strip=True).lower() for th in filas[0].select("th")] if filas else []
        if not any("capacity" in h for h in enc):
            continue
        i_cap = next(i for i, h in enumerate(enc) if "capacity" in h)
        for fila in filas[1:]:
            celdas = [re.sub(r"\[.*?\]", "", c.get_text(" ", strip=True)) for c in fila.select("th,td")]
            if len(celdas) <= i_cap:
                continue
            texto = " ".join(celdas).lower()
            cap = re.sub(r"[^\d]", "", celdas[i_cap])
            for i, s in enumerate(SEDES):
                if cap and any(k in texto for k in s[7]):
                    capacidades[i] = int(cap)
    print(f"Scraping: capacidad leida para {len(capacidades)} de {len(SEDES)} sedes")
    return capacidades


def fixture(offline):
    caps = {} if offline else capacidades_wikipedia()
    with open(DESTINO / "fixture_sedes.csv", "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter=";", lineterminator="\n")
        w.writerow(["NumeroPartido", "Fase", "NombreEstadio", "Ciudad", "PaisISO3", "HusoHorario", "Capacidad",
                    "Latitud", "Longitud", "FechaHoraLocal", "SeleccionLocal", "SeleccionVisitante"])
        for nro, i, fecha, loc, vis in PARTIDOS:
            e, c, iso3, huso, cap, lat, lon, _ = SEDES[i]
            w.writerow([nro, "Fase de grupos", e, c, iso3, huso, caps.get(i, cap), f"{lat:.6f}", f"{lon:.6f}", fecha, loc, vis])
    print("OK fixture_sedes.csv")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("fuente", choices=["pbi", "cotizaciones", "fixture", "todo"])
    ap.add_argument("--offline", action="store_true")
    a = ap.parse_args()
    if a.fuente in ("pbi", "todo"): pbi()
    if a.fuente in ("cotizaciones", "todo"): cotizaciones()
    if a.fuente in ("fixture", "todo"): fixture(a.offline)
