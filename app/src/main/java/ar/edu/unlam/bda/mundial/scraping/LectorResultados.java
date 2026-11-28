package ar.edu.unlam.bda.mundial.scraping;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.stereotype.Component;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Lee los archivos que generan los scripts de scraping (scripts/importacion/resultados) y los convierte en tablas.
 * - CSV (dossier y fixture): separador ";" sin comillas, primera fila = encabezado (mismo formato que importa el
 *   BULK INSERT). En el dossier, las categorías separadas por "|" se muestran separadas por coma.
 * - pbi_banco_mundial.json: formato de la API del Banco Mundial ([metadatos, [registros]]); se muestra el último
 *   año con dato de cada país, igual que nucleo.SP_IMPORTAR_PBI_JSON.
 * - cotizaciones_frankfurter.json: {"base", "date", "rates": {moneda: tasa}}.
 */
@Component
public class LectorResultados {

    private final JsonMapper json = JsonMapper.builder().build();

    public Optional<TablaResultado> leer(FuenteScraping fuente, Path directorioResultados) {
        Path archivo = directorioResultados.resolve(fuente.getArchivoResultado());
        if (!Files.isRegularFile(archivo)) {
            return Optional.empty();
        }
        try {
            LocalDateTime modificado = LocalDateTime.ofInstant(Files.getLastModifiedTime(archivo).toInstant(),
                    ZoneId.systemDefault());
            String contenido = Files.readString(archivo, StandardCharsets.UTF_8);
            TablaResultado tabla = switch (fuente) {
                case DOSSIER, FIXTURE -> csv(fuente, archivo, modificado, contenido);
                case PBI -> pbi(archivo, modificado, contenido);
                case COTIZACIONES -> cotizaciones(archivo, modificado, contenido);
            };
            return Optional.of(tabla);
        } catch (IOException ex) {
            throw new UncheckedIOException("No se pudo leer " + archivo, ex);
        }
    }

    private TablaResultado csv(FuenteScraping fuente, Path archivo, LocalDateTime modificado, String contenido) {
        List<String> lineas = contenido.lines().filter(l -> !l.isBlank()).toList();
        if (lineas.isEmpty()) {
            return new TablaResultado(archivo.getFileName().toString(), modificado, List.of(), List.of());
        }
        List<String> columnas = Arrays.asList(lineas.get(0).split(";", -1));
        int iCategorias = columnas.indexOf("Categorias");
        List<List<String>> filas = new ArrayList<>();
        for (String linea : lineas.subList(1, lineas.size())) {
            List<String> fila = new ArrayList<>(Arrays.asList(linea.split(";", -1)));
            if (fuente == FuenteScraping.DOSSIER && iCategorias >= 0 && iCategorias < fila.size()) {
                fila.set(iCategorias, fila.get(iCategorias).replace("|", ", "));
            }
            filas.add(fila);
        }
        return new TablaResultado(archivo.getFileName().toString(), modificado, columnas, filas);
    }

    private TablaResultado pbi(Path archivo, LocalDateTime modificado, String contenido) {
        JsonNode registros = json.readTree(contenido).path(1);
        // Por país: el año más reciente que tiene valor.
        Map<String, List<String>> ultimoPorPais = new LinkedHashMap<>();
        Map<String, Integer> anioPorPais = new LinkedHashMap<>();
        for (JsonNode r : registros) {
            JsonNode valor = r.path("value");
            if (valor.isNull() || !valor.isNumber()) {
                continue;
            }
            String iso2 = r.path("country").path("id").asString();
            String textoAnio = r.path("date").asString();
            int anio = textoAnio.matches("\\d+") ? Integer.parseInt(textoAnio) : 0;
            if (anio > anioPorPais.getOrDefault(iso2, -1)) {
                anioPorPais.put(iso2, anio);
                ultimoPorPais.put(iso2, List.of(r.path("country").path("value").asString(), iso2,
                        String.valueOf(anio), String.format("%,.2f", valor.asDouble())));
            }
        }
        List<List<String>> filas = new ArrayList<>(ultimoPorPais.values());
        filas.sort((a, b) -> a.get(0).compareToIgnoreCase(b.get(0)));
        return new TablaResultado(archivo.getFileName().toString(), modificado,
                List.of("País", "ISO2", "Año", "PBI per cápita (USD)"), filas);
    }

    private TablaResultado cotizaciones(Path archivo, LocalDateTime modificado, String contenido) {
        JsonNode raiz = json.readTree(contenido);
        String base = raiz.path("base").asString();
        String fecha = raiz.path("date").asString();
        List<List<String>> filas = new ArrayList<>();
        for (Map.Entry<String, JsonNode> tasa : raiz.path("rates").properties()) {
            filas.add(List.of(base, tasa.getKey(), String.valueOf(tasa.getValue().asDouble()), fecha));
        }
        return new TablaResultado(archivo.getFileName().toString(), modificado,
                List.of("Moneda base", "Moneda", "Tasa", "Fecha"), filas);
    }
}
