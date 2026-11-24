package ar.edu.unlam.bda.mundial.sede;

import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Ciudades para el desplegable del formulario de sedes (solo lectura). */
@Repository
public class CiudadRepository {

    private static final String SQL_LISTADO = """
            SELECT c.IdCiudad, c.Nombre, p.Nombre AS Pais, c.HusoHorario
            FROM nucleo.Ciudad AS c
            INNER JOIN nucleo.Pais AS p ON p.IdPais = c.IdPais
            ORDER BY p.Nombre, c.Nombre
            """;

    private final JdbcTemplate jdbc;

    public CiudadRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Ciudad> listar() {
        return jdbc.query(SQL_LISTADO, (rs, i) -> new Ciudad(
                rs.getInt("IdCiudad"),
                rs.getString("Nombre"),
                rs.getString("Pais"),
                rs.getString("HusoHorario")));
    }
}
