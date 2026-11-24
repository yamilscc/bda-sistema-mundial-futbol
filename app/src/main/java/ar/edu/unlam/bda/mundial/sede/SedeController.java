package ar.edu.unlam.bda.mundial.sede;

import java.sql.SQLException;
import java.util.stream.Collectors;

import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * ABM de sedes.
 * - GET  /sedes                 listado
 * - GET  /sedes/nueva           formulario de alta
 * - POST /sedes                 alta (nucleo.SP_ALTA_Sede)
 * - GET  /sedes/{id}/editar     formulario de modificación
 * - POST /sedes/{id}            modificación (nucleo.SP_MODIFICACION_Sede)
 * - POST /sedes/{id}/baja       baja (nucleo.SP_BAJA_Sede)
 * Si el SP rechaza la operación, se muestra su mensaje consolidado tal cual (un renglón por validación).
 */
@Controller
public class SedeController {

    private final SedeRepository sedes;
    private final CiudadRepository ciudades;

    public SedeController(SedeRepository sedes, CiudadRepository ciudades) {
        this.sedes = sedes;
        this.ciudades = ciudades;
    }

    @GetMapping("/")
    public String inicio() {
        return "redirect:/sedes";
    }

    @GetMapping("/sedes")
    public String listar(Model model) {
        model.addAttribute("sedes", sedes.listar());
        return "sedes/lista";
    }

    @GetMapping("/sedes/nueva")
    public String nueva(Model model) {
        return formulario(model, new SedeForm(), null);
    }

    @PostMapping("/sedes")
    public String alta(@ModelAttribute("form") SedeForm form, BindingResult binding,
                       Model model, RedirectAttributes redirect) {
        form.setIdSede(null);
        if (binding.hasErrors()) {
            return formulario(model, form, erroresDeFormato(binding));
        }
        try {
            int id = sedes.alta(form);
            redirect.addFlashAttribute("ok", "Sede \"" + form.getNombreEstadio().strip() + "\" creada (Id " + id + ").");
            return "redirect:/sedes";
        } catch (DataAccessException ex) {
            return formulario(model, form, mensajeDe(ex));
        }
    }

    @GetMapping("/sedes/{id}/editar")
    public String editar(@PathVariable int id, Model model, RedirectAttributes redirect) {
        return sedes.buscar(id)
                .map(sede -> formulario(model, SedeForm.desde(sede), null))
                .orElseGet(() -> {
                    redirect.addFlashAttribute("error", "La sede " + id + " no existe.");
                    return "redirect:/sedes";
                });
    }

    @PostMapping("/sedes/{id}")
    public String modificacion(@PathVariable int id, @ModelAttribute("form") SedeForm form, BindingResult binding,
                               Model model, RedirectAttributes redirect) {
        form.setIdSede(id);
        if (binding.hasErrors()) {
            return formulario(model, form, erroresDeFormato(binding));
        }
        try {
            sedes.modificacion(form);
            redirect.addFlashAttribute("ok", "Sede " + id + " modificada.");
            return "redirect:/sedes";
        } catch (DataAccessException ex) {
            return formulario(model, form, mensajeDe(ex));
        }
    }

    @PostMapping("/sedes/{id}/baja")
    public String baja(@PathVariable int id, RedirectAttributes redirect) {
        try {
            sedes.baja(id);
            redirect.addFlashAttribute("ok", "Sede " + id + " dada de baja.");
        } catch (DataAccessException ex) {
            redirect.addFlashAttribute("error", mensajeDe(ex));
        }
        return "redirect:/sedes";
    }

    private String formulario(Model model, SedeForm form, String error) {
        model.addAttribute("form", form);
        model.addAttribute("ciudades", ciudades.listar());
        model.addAttribute("error", error);
        return "sedes/formulario";
    }

    /** Mensaje del SP: el texto del THROW (la primera SQLException de la cadena de causas). */
    static String mensajeDe(DataAccessException ex) {
        for (Throwable t = ex; t != null; t = t.getCause()) {
            if (t instanceof SQLException sql && sql.getMessage() != null) {
                return sql.getMessage();
            }
        }
        return ex.getMessage();
    }

    /** Valores que no se pudieron convertir (por ejemplo, letras en la capacidad); no llegan al SP. */
    private static String erroresDeFormato(BindingResult binding) {
        return "No se pudo enviar el formulario:\n" + binding.getFieldErrors().stream()
                .map(e -> "- El campo " + e.getField() + " tiene un valor con formato inválido.")
                .collect(Collectors.joining("\n"));
    }
}
