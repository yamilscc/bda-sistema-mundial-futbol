package ar.edu.unlam.bda.mundial.sede;

import java.math.BigDecimal;

/**
 * Fila del listado de sedes: nucleo.Sede unida con su ciudad (nucleo.Ciudad) y su país (nucleo.Pais).
 * La sede no guarda huso horario: lo hereda de la ciudad.
 */
public record Sede(
        int idSede,
        String nombreEstadio,
        Integer capacidad,
        BigDecimal latitud,
        BigDecimal longitud,
        int idCiudad,
        String ciudad,
        String pais,
        String husoHorario) {
}
