package ar.edu.unlam.bda.mundial.scraping;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.model;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.view;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import org.hamcrest.Matchers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class ScrapingControllerTest {

    @TempDir
    Path importacion;

    private MockMvc mvc;

    @BeforeEach
    void preparar() throws Exception {
        Files.createDirectories(importacion.resolve("resultados"));
        Files.writeString(importacion.resolve("resultados").resolve("campanas_dossier.csv"),
                "Anunciante;Titulo\nQuilmes;Final\n", StandardCharsets.UTF_8);
        EjecutorScraping ejecutor = new EjecutorScraping("python3", importacion.toString(), 5);
        mvc = MockMvcBuilders.standaloneSetup(new ScrapingController(ejecutor, new LectorResultados(), 5)).build();
    }

    @Test
    void laPantallaMuestraUnaTarjetaPorFuente() throws Exception {
        mvc.perform(get("/scraping"))
                .andExpect(status().isOk())
                .andExpect(view().name("scraping/lista"))
                .andExpect(model().attribute("tarjetas", Matchers.hasSize(FuenteScraping.values().length)));
    }

    @Test
    void elResultadoDevuelveElFragmentoConLaTabla() throws Exception {
        mvc.perform(get("/scraping/dossier/resultado"))
                .andExpect(status().isOk())
                .andExpect(view().name("scraping/lista :: resultado"))
                .andExpect(resultado -> {
                    var tarjeta = (ScrapingController.Tarjeta) resultado.getModelAndView().getModel().get("t");
                    assertThat(tarjeta.fuente()).isEqualTo(FuenteScraping.DOSSIER);
                    assertThat(tarjeta.resultado().filas()).hasSize(1);
                });
    }

    @Test
    void unaFuenteInexistenteDa404() throws Exception {
        mvc.perform(get("/scraping/inexistente/resultado")).andExpect(status().isNotFound());
        mvc.perform(get("/scraping/../../etc/ejecutar")).andExpect(status().isNotFound());
    }
}
