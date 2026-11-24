package ar.edu.unlam.bda.mundial.sede;

/** Opción del desplegable de ciudades del formulario de sedes. */
public record Ciudad(int idCiudad, String nombre, String pais, String husoHorario) {

    /** Texto que se muestra en el desplegable: "País - Ciudad (huso horario)". */
    public String etiqueta() {
        return pais + " - " + nombre + " (" + husoHorario + ")";
    }
}
