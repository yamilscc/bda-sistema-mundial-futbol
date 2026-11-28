package ar.edu.unlam.bda.mundial.scraping;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import jakarta.annotation.PreDestroy;

/**
 * Pantalla de scraping (solo muestra: no importa nada a la base; la importación sigue siendo la de
 * scripts/importacion/sql).
 * - GET /scraping                      tarjetas por fuente con el último resultado que haya en resultados/
 * - GET /scraping/{fuente}/ejecutar    corre el script y transmite su salida en vivo (Server-Sent Events):
 *                                      eventos "linea" (una por línea), "fin" (código de salida) o "falla"
 * - GET /scraping/{fuente}/resultado   fragmento HTML con la tabla del archivo generado
 */
@Controller
public class ScrapingController {

    /** Tiempo de espera del navegador: el del script más un margen para leer y enviar la salida. */
    private static final long MARGEN_MS = 30_000;

    private final EjecutorScraping ejecutor;
    private final LectorResultados lector;
    private final long timeoutMs;
    private final ExecutorService hilos = Executors.newVirtualThreadPerTaskExecutor();

    public ScrapingController(EjecutorScraping ejecutor, LectorResultados lector,
                              @Value("${mundial.scraping.timeout-segundos:180}") long timeoutSegundos) {
        this.ejecutor = ejecutor;
        this.lector = lector;
        this.timeoutMs = timeoutSegundos * 1000 + MARGEN_MS;
    }

    /** Una tarjeta de la pantalla: la fuente y su último resultado (null si todavía no se generó). */
    public record Tarjeta(FuenteScraping fuente, TablaResultado resultado) {
    }

    @GetMapping("/scraping")
    public String pantalla(Model model) {
        List<Tarjeta> tarjetas = Arrays.stream(FuenteScraping.values()).map(this::tarjeta).toList();
        model.addAttribute("tarjetas", tarjetas);
        model.addAttribute("python", ejecutor.getPython());
        model.addAttribute("directorioResultados", ejecutor.directorioResultados().toString());
        return "scraping/lista";
    }

    @GetMapping("/scraping/{codigo}/resultado")
    public String resultado(@PathVariable String codigo, Model model) {
        model.addAttribute("t", tarjeta(fuente(codigo)));
        return "scraping/lista :: resultado";
    }

    @GetMapping(path = "/scraping/{codigo}/ejecutar", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @ResponseBody
    public SseEmitter ejecutar(@PathVariable String codigo) {
        FuenteScraping fuente = fuente(codigo);
        SseEmitter emisor = new SseEmitter(timeoutMs);
        hilos.execute(() -> {
            try {
                enviar(emisor, "linea", "$ " + ejecutor.getPython() + " " + fuente.getScript() + " "
                        + String.join(" ", fuente.getArgumentos()));
                int codigoSalida = ejecutor.ejecutar(fuente, linea -> enviar(emisor, "linea", linea));
                enviar(emisor, "fin", String.valueOf(codigoSalida));
            } catch (IllegalStateException ex) {
                enviar(emisor, "falla", ex.getMessage());
            } catch (IOException ex) {
                enviar(emisor, "falla", "No se pudo ejecutar Python (\"" + ejecutor.getPython() + "\"): "
                        + ex.getMessage() + ". Configurar mundial.scraping.python o la variable PYTHON_CMD.");
            } catch (InterruptedException ex) {
                Thread.currentThread().interrupt();
                enviar(emisor, "falla", "La ejecución se interrumpió.");
            } finally {
                emisor.complete();
            }
        });
        return emisor;
    }

    private Tarjeta tarjeta(FuenteScraping fuente) {
        return new Tarjeta(fuente, lector.leer(fuente, ejecutor.directorioResultados()).orElse(null));
    }

    private static FuenteScraping fuente(String codigo) {
        return FuenteScraping.desdeCodigo(codigo)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Fuente inexistente: " + codigo));
    }

    /** Envía un evento; si el navegador ya cerró la conexión, se ignora (el script sigue hasta terminar). */
    private static void enviar(SseEmitter emisor, String evento, String dato) {
        try {
            emisor.send(SseEmitter.event().name(evento).data(dato));
        } catch (IOException | IllegalStateException ex) {
            // conexión cerrada por el cliente
        }
    }

    @PreDestroy
    void cerrar() {
        hilos.shutdownNow();
    }
}
