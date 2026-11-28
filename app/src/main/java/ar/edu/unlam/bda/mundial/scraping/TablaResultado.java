package ar.edu.unlam.bda.mundial.scraping;

import java.time.LocalDateTime;
import java.util.List;

/** Contenido de un archivo de resultados listo para mostrar como tabla. */
public record TablaResultado(String archivo, LocalDateTime modificado, List<String> columnas, List<List<String>> filas) {

    public int cantidadFilas() {
        return filas.size();
    }
}
