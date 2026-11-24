package ar.edu.unlam.bda.mundial.sede;

import java.math.BigDecimal;

/**
 * Datos del formulario de alta y modificación de sedes.
 * Es una clase con getters y setters (y no un record) porque th:field de Thymeleaf necesita
 * propiedades JavaBean para leer y volver a mostrar lo que cargó el usuario.
 * No valida reglas de negocio: eso lo hacen los SP del script 09, que devuelven un único
 * mensaje con todas las condiciones incumplidas.
 */
public class SedeForm {

    private Integer idSede;          // null en el alta
    private String nombreEstadio;
    private Integer idCiudad;
    private Integer capacidad;       // opcional
    private BigDecimal latitud;      // opcional (junto con la longitud)
    private BigDecimal longitud;     // opcional (junto con la latitud)

    public static SedeForm desde(Sede sede) {
        SedeForm form = new SedeForm();
        form.setIdSede(sede.idSede());
        form.setNombreEstadio(sede.nombreEstadio());
        form.setIdCiudad(sede.idCiudad());
        form.setCapacidad(sede.capacidad());
        form.setLatitud(sede.latitud());
        form.setLongitud(sede.longitud());
        return form;
    }

    public boolean esAlta() {
        return idSede == null;
    }

    public Integer getIdSede() { return idSede; }
    public void setIdSede(Integer idSede) { this.idSede = idSede; }

    public String getNombreEstadio() { return nombreEstadio; }
    public void setNombreEstadio(String nombreEstadio) { this.nombreEstadio = nombreEstadio; }

    public Integer getIdCiudad() { return idCiudad; }
    public void setIdCiudad(Integer idCiudad) { this.idCiudad = idCiudad; }

    public Integer getCapacidad() { return capacidad; }
    public void setCapacidad(Integer capacidad) { this.capacidad = capacidad; }

    public BigDecimal getLatitud() { return latitud; }
    public void setLatitud(BigDecimal latitud) { this.latitud = latitud; }

    public BigDecimal getLongitud() { return longitud; }
    public void setLongitud(BigDecimal longitud) { this.longitud = longitud; }
}
