package ar.edu.unlam.bda.mundial.scraping;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class LectorResultadosTest {

    private final LectorResultados lector = new LectorResultados();

    @TempDir
    Path dir;

    @Test
    void sinArchivoNoHayResultado() {
        assertThat(lector.leer(FuenteScraping.DOSSIER, dir)).isEmpty();
    }

    @Test
    void leeElCsvDelDossierYSeparaLasCategorias() throws Exception {
        Files.writeString(dir.resolve("campanas_dossier.csv"), """
                Anunciante;Marca;Titulo;Agencia;Productora;Periodo;Categorias
                Quilmes;;Final;draftLine;LANDIA;;Film|Digital
                Ala;;Paralelismo;Urban Grupo de Comunicación;FeelCO;;Digital
                """, StandardCharsets.UTF_8);

        TablaResultado tabla = lector.leer(FuenteScraping.DOSSIER, dir).orElseThrow();

        assertThat(tabla.archivo()).isEqualTo("campanas_dossier.csv");
        assertThat(tabla.columnas()).containsExactly("Anunciante", "Marca", "Titulo", "Agencia", "Productora",
                "Periodo", "Categorias");
        assertThat(tabla.cantidadFilas()).isEqualTo(2);
        assertThat(tabla.filas().get(0)).containsExactly("Quilmes", "", "Final", "draftLine", "LANDIA", "",
                "Film, Digital");
        assertThat(tabla.filas().get(1).get(3)).isEqualTo("Urban Grupo de Comunicación");
    }

    @Test
    void leeElCsvDelFixture() throws Exception {
        Files.writeString(dir.resolve("fixture_sedes.csv"),
                "NumeroPartido;Fase;NombreEstadio\n1;Fase de grupos;Estadio Azteca\n", StandardCharsets.UTF_8);

        TablaResultado tabla = lector.leer(FuenteScraping.FIXTURE, dir).orElseThrow();

        assertThat(tabla.columnas()).containsExactly("NumeroPartido", "Fase", "NombreEstadio");
        assertThat(tabla.filas()).containsExactly(List.of("1", "Fase de grupos", "Estadio Azteca"));
    }

    @Test
    void delPbiTomaElUltimoAnioConDatoDeCadaPais() throws Exception {
        Files.writeString(dir.resolve("pbi_banco_mundial.json"), """
                [{"page":1},[
                  {"country":{"id":"AR","value":"Argentina"},"date":"2024","value":null},
                  {"country":{"id":"AR","value":"Argentina"},"date":"2023","value":13730.5},
                  {"country":{"id":"AR","value":"Argentina"},"date":"2022","value":13000},
                  {"country":{"id":"BR","value":"Brazil"},"date":"2024","value":10040}
                ]]
                """, StandardCharsets.UTF_8);

        TablaResultado tabla = lector.leer(FuenteScraping.PBI, dir).orElseThrow();

        assertThat(tabla.columnas()).containsExactly("País", "ISO2", "Año", "PBI per cápita (USD)");
        assertThat(tabla.cantidadFilas()).isEqualTo(2);
        assertThat(tabla.filas().get(0).subList(0, 3)).containsExactly("Argentina", "AR", "2023");
        assertThat(tabla.filas().get(1).subList(0, 3)).containsExactly("Brazil", "BR", "2024");
    }

    @Test
    void leeLasCotizaciones() throws Exception {
        Files.writeString(dir.resolve("cotizaciones_frankfurter.json"),
                "{\"base\":\"USD\",\"date\":\"2026-11-27\",\"rates\":{\"EUR\":0.92,\"BRL\":5.1}}", StandardCharsets.UTF_8);

        TablaResultado tabla = lector.leer(FuenteScraping.COTIZACIONES, dir).orElseThrow();

        assertThat(tabla.columnas()).containsExactly("Moneda base", "Moneda", "Tasa", "Fecha");
        assertThat(tabla.filas()).containsExactly(
                List.of("USD", "EUR", "0.92", "2026-11-27"),
                List.of("USD", "BRL", "5.1", "2026-11-27"));
    }
}
