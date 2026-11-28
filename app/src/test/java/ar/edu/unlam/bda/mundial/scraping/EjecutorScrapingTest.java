package ar.edu.unlam.bda.mundial.scraping;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Prueba la ejecución con scripts de Python de prueba (no hace pedidos a internet).
 * Se omite si en la máquina no hay Python disponible con el comando por defecto.
 */
class EjecutorScrapingTest {

    @TempDir
    Path importacion;

    private EjecutorScraping ejecutor;

    @BeforeEach
    void preparar() throws Exception {
        Files.createDirectories(importacion.resolve("scraping"));
        Files.createDirectories(importacion.resolve("resultados"));
        ejecutor = new EjecutorScraping("", importacion.toString(), 5);
        assumeTrue(hayPython(ejecutor.getPython()), "Python no disponible: se omite el test");
    }

    @Test
    void transmiteCadaLineaYDevuelveElCodigoDeSalida() throws Exception {
        script("scraping_dossier.py", """
                import pathlib
                print("paso 1", flush=True)
                print("paso 2 con ñ y acentos: canción", flush=True)
                (pathlib.Path(__file__).resolve().parent.parent / "resultados" / "campanas_dossier.csv").write_text("A;B\\n1;2\\n")
                print("OK", flush=True)
                """);
        List<String> lineas = new ArrayList<>();

        int codigo = ejecutor.ejecutar(FuenteScraping.DOSSIER, lineas::add);

        assertThat(codigo).isZero();
        assertThat(lineas).containsExactly("paso 1", "paso 2 con ñ y acentos: canción", "OK");
        assertThat(importacion.resolve("resultados").resolve("campanas_dossier.csv")).exists();
        assertThat(ejecutor.estaEnCurso()).isFalse();
    }

    @Test
    void pasaLosArgumentosFijosDeLaFuenteYMuestraLosErrores() throws Exception {
        script("fuentes_externas.py", """
                import sys
                print("argumentos: " + " ".join(sys.argv[1:]), flush=True)
                print("falla simulada", file=sys.stderr, flush=True)
                sys.exit(3)
                """);
        List<String> lineas = new ArrayList<>();

        int codigo = ejecutor.ejecutar(FuenteScraping.COTIZACIONES, lineas::add);

        assertThat(codigo).isEqualTo(3);
        assertThat(lineas).containsExactly("argumentos: cotizaciones", "falla simulada");
    }

    @Test
    void cortaElScriptSiSuperaElTiempoMaximo() throws Exception {
        ejecutor = new EjecutorScraping("", importacion.toString(), 1);
        script("scraping_dossier.py", "import time\ntime.sleep(30)\n");
        List<String> lineas = new ArrayList<>();
        long inicio = System.nanoTime();

        int codigo = ejecutor.ejecutar(FuenteScraping.DOSSIER, lineas::add);

        assertThat(codigo).isEqualTo(-1);
        assertThat(TimeUnit.NANOSECONDS.toSeconds(System.nanoTime() - inicio)).isLessThan(15);
        assertThat(lineas).last().asString().contains("tiempo máximo");
    }

    @Test
    void rechazaUnScriptInexistente() {
        assertThatThrownBy(() -> ejecutor.ejecutar(FuenteScraping.FIXTURE, linea -> { }))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("No se encontró el script");
    }

    private void script(String nombre, String codigo) throws Exception {
        Files.writeString(importacion.resolve("scraping").resolve(nombre), codigo, StandardCharsets.UTF_8);
    }

    private static boolean hayPython(String comando) {
        try {
            return new ProcessBuilder(comando, "--version").redirectErrorStream(true).start().waitFor() == 0;
        } catch (Exception ex) {
            return false;
        }
    }
}
