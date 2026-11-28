package ar.edu.unlam.bda.mundial.scraping;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * Ejecuta un script de scraping como proceso externo y entrega cada línea que imprime.
 * Solo corre los scripts y argumentos fijos de {@link FuenteScraping}: el usuario elige la fuente, nunca el comando.
 * Hay una sola ejecución a la vez y un tiempo máximo (mundial.scraping.timeout-segundos).
 */
@Service
public class EjecutorScraping {

    private final String python;
    private final Path directorioImportacion;
    private final long timeoutSegundos;
    private final AtomicBoolean enCurso = new AtomicBoolean(false);

    public EjecutorScraping(@Value("${mundial.scraping.python:}") String python,
                            @Value("${mundial.scraping.directorio:../scripts/importacion}") String directorio,
                            @Value("${mundial.scraping.timeout-segundos:180}") long timeoutSegundos) {
        this.python = python == null || python.isBlank() ? pythonPorDefecto() : python.strip();
        this.directorioImportacion = Path.of(directorio).toAbsolutePath().normalize();
        this.timeoutSegundos = timeoutSegundos;
    }

    private static String pythonPorDefecto() {
        return System.getProperty("os.name", "").toLowerCase(Locale.ROOT).contains("win") ? "python" : "python3";
    }

    public Path directorioResultados() {
        return directorioImportacion.resolve("resultados");
    }

    public Path directorioScripts() {
        return directorioImportacion.resolve("scraping");
    }

    public String getPython() {
        return python;
    }

    public boolean estaEnCurso() {
        return enCurso.get();
    }

    /**
     * Corre el script de la fuente y pasa cada línea de salida (stdout y stderr) a {@code salida}.
     *
     * @return el código de salida del proceso (0 = terminó bien)
     * @throws IllegalStateException si ya hay una ejecución en curso o el script no existe
     */
    public int ejecutar(FuenteScraping fuente, Consumer<String> salida) throws IOException, InterruptedException {
        Path script = directorioScripts().resolve(fuente.getScript());
        if (!Files.isRegularFile(script)) {
            throw new IllegalStateException("No se encontró el script " + script
                    + ". Revisar mundial.scraping.directorio (carpeta scripts/importacion).");
        }
        if (!enCurso.compareAndSet(false, true)) {
            throw new IllegalStateException("Ya hay un scraping en curso: esperar a que termine.");
        }
        try {
            List<String> comando = new ArrayList<>(List.of(python, "-u", script.toString()));
            comando.addAll(fuente.getArgumentos());
            ProcessBuilder pb = new ProcessBuilder(comando)
                    .directory(directorioScripts().toFile())
                    .redirectErrorStream(true);
            pb.environment().put("PYTHONIOENCODING", "utf-8");
            Process proceso = pb.start();
            // Vigilante: si el script no termina a tiempo lo corta (aunque no esté imprimiendo nada).
            AtomicBoolean vencido = new AtomicBoolean(false);
            Thread vigilante = Thread.ofVirtual().start(() -> {
                try {
                    if (!proceso.waitFor(timeoutSegundos, TimeUnit.SECONDS)) {
                        vencido.set(true);
                        proceso.destroyForcibly();
                    }
                } catch (InterruptedException ex) {
                    Thread.currentThread().interrupt();
                }
            });
            try (BufferedReader lector = new BufferedReader(
                    new InputStreamReader(proceso.getInputStream(), StandardCharsets.UTF_8))) {
                String linea;
                while ((linea = lector.readLine()) != null) {
                    salida.accept(linea);
                }
            }
            int codigo = proceso.waitFor();
            vigilante.interrupt();
            if (vencido.get()) {
                salida.accept("Se superó el tiempo máximo de " + timeoutSegundos + " segundos: se detuvo el script.");
                return -1;
            }
            return codigo;
        } finally {
            enCurso.set(false);
        }
    }
}
