package ar.edu.unlam.bda.mundial.scraping;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

/**
 * Fuentes externas que se pueden ejecutar desde la pantalla de scraping.
 * Cada una corre un script fijo de scripts/importacion/scraping con argumentos fijos (nunca texto del usuario)
 * y deja su resultado en scripts/importacion/resultados.
 */
public enum FuenteScraping {

    DOSSIER("dossier", "Dossier de publicidad",
            "Campañas publicitarias del Mundial desde dossiermundial.netlify.app (base Firestore pública). Un solo pedido.",
            "scraping_dossier.py", List.of(), "campanas_dossier.csv"),
    FIXTURE("fixture", "Fixture y sedes",
            "Capacidad de los estadios scrapeada de Wikipedia, combinada con el fixture de 24 partidos del grupo.",
            "fuentes_externas.py", List.of("fixture"), "fixture_sedes.csv"),
    PBI("pbi", "PBI per cápita",
            "API del Banco Mundial (indicador NY.GDP.PCAP.CD) para los 22 países del torneo.",
            "fuentes_externas.py", List.of("pbi"), "pbi_banco_mundial.json"),
    COTIZACIONES("cotizaciones", "Cotizaciones",
            "API Frankfurter (cotizaciones del BCE) con base USD.",
            "fuentes_externas.py", List.of("cotizaciones"), "cotizaciones_frankfurter.json");

    private final String codigo;
    private final String titulo;
    private final String descripcion;
    private final String script;
    private final List<String> argumentos;
    private final String archivoResultado;

    FuenteScraping(String codigo, String titulo, String descripcion, String script, List<String> argumentos,
                   String archivoResultado) {
        this.codigo = codigo;
        this.titulo = titulo;
        this.descripcion = descripcion;
        this.script = script;
        this.argumentos = argumentos;
        this.archivoResultado = archivoResultado;
    }

    public static Optional<FuenteScraping> desdeCodigo(String codigo) {
        return Arrays.stream(values()).filter(f -> f.codigo.equals(codigo)).findFirst();
    }

    public String getCodigo() { return codigo; }
    public String getTitulo() { return titulo; }
    public String getDescripcion() { return descripcion; }
    public String getScript() { return script; }
    public List<String> getArgumentos() { return argumentos; }
    public String getArchivoResultado() { return archivoResultado; }
}
