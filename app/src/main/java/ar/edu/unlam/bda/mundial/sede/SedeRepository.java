package ar.edu.unlam.bda.mundial.sede;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlOutParameter;
import org.springframework.jdbc.core.SqlParameter;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

/**
 * Acceso a nucleo.Sede.
 * - Lectura: consulta directa (Sede + Ciudad + País) con JdbcTemplate.
 * - Alta, modificación y baja: SOLO a través de nucleo.SP_ALTA_Sede, nucleo.SP_MODIFICACION_Sede y
 *   nucleo.SP_BAJA_Sede (script 09). La app nunca escribe la tabla directamente.
 *
 * Los parámetros se declaran con los nombres exactos del script 09 (sin la @) y en el mismo orden
 * que en el SP, porque la llamada se arma por posición (withoutProcedureColumnMetaDataAccess).
 * Si el SP rechaza la operación (THROW 52000 con el mensaje consolidado), la excepción llega como
 * DataAccessException y la muestra el controlador.
 */
@Repository
public class SedeRepository {

    private static final String SQL_LISTADO = """
            SELECT s.IdSede, s.NombreEstadio, s.Capacidad, s.Latitud, s.Longitud,
                   c.IdCiudad, c.Nombre AS Ciudad, p.Nombre AS Pais, c.HusoHorario
            FROM nucleo.Sede AS s
            INNER JOIN nucleo.Ciudad AS c ON c.IdCiudad = s.IdCiudad
            INNER JOIN nucleo.Pais   AS p ON p.IdPais   = c.IdPais
            """;

    private final JdbcTemplate jdbc;
    private final SimpleJdbcCall spAlta;
    private final SimpleJdbcCall spModificacion;
    private final SimpleJdbcCall spBaja;

    public SedeRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;

        // nucleo.SP_ALTA_Sede (@nombreEstadio, @idCiudad, @capacidad, @latitud, @longitud, @idSede OUTPUT)
        this.spAlta = new SimpleJdbcCall(jdbc)
                .withSchemaName("nucleo")
                .withProcedureName("SP_ALTA_Sede")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(
                        new SqlParameter("nombreEstadio", Types.VARCHAR),
                        new SqlParameter("idCiudad", Types.INTEGER),
                        new SqlParameter("capacidad", Types.INTEGER),
                        new SqlParameter("latitud", Types.DECIMAL, 6),
                        new SqlParameter("longitud", Types.DECIMAL, 6),
                        new SqlOutParameter("idSede", Types.TINYINT));

        // nucleo.SP_MODIFICACION_Sede (@idSede, @nombreEstadio, @idCiudad, @capacidad, @latitud, @longitud)
        this.spModificacion = new SimpleJdbcCall(jdbc)
                .withSchemaName("nucleo")
                .withProcedureName("SP_MODIFICACION_Sede")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(
                        new SqlParameter("idSede", Types.INTEGER),
                        new SqlParameter("nombreEstadio", Types.VARCHAR),
                        new SqlParameter("idCiudad", Types.INTEGER),
                        new SqlParameter("capacidad", Types.INTEGER),
                        new SqlParameter("latitud", Types.DECIMAL, 6),
                        new SqlParameter("longitud", Types.DECIMAL, 6));

        // nucleo.SP_BAJA_Sede (@idSede)
        this.spBaja = new SimpleJdbcCall(jdbc)
                .withSchemaName("nucleo")
                .withProcedureName("SP_BAJA_Sede")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(new SqlParameter("idSede", Types.INTEGER));
    }

    public List<Sede> listar() {
        return jdbc.query(SQL_LISTADO + " ORDER BY p.Nombre, c.Nombre, s.NombreEstadio", SedeRepository::mapear);
    }

    public Optional<Sede> buscar(int idSede) {
        return jdbc.query(SQL_LISTADO + " WHERE s.IdSede = ?", SedeRepository::mapear, idSede)
                .stream()
                .findFirst();
    }

    /** Alta con nucleo.SP_ALTA_Sede. Devuelve el IdSede generado (parámetro OUTPUT @idSede). */
    public int alta(SedeForm form) {
        MapSqlParameterSource parametros = new MapSqlParameterSource()
                .addValue("nombreEstadio", form.getNombreEstadio())
                .addValue("idCiudad", form.getIdCiudad())
                .addValue("capacidad", form.getCapacidad())
                .addValue("latitud", form.getLatitud())
                .addValue("longitud", form.getLongitud());
        Map<String, Object> salida = spAlta.execute(parametros);
        return ((Number) salida.get("idSede")).intValue();
    }

    /** Modificación con nucleo.SP_MODIFICACION_Sede (reemplaza todos los campos). */
    public void modificacion(SedeForm form) {
        MapSqlParameterSource parametros = new MapSqlParameterSource()
                .addValue("idSede", form.getIdSede())
                .addValue("nombreEstadio", form.getNombreEstadio())
                .addValue("idCiudad", form.getIdCiudad())
                .addValue("capacidad", form.getCapacidad())
                .addValue("latitud", form.getLatitud())
                .addValue("longitud", form.getLongitud());
        spModificacion.execute(parametros);
    }

    /** Baja con nucleo.SP_BAJA_Sede (el SP rechaza sedes con partidos). */
    public void baja(int idSede) {
        spBaja.execute(new MapSqlParameterSource().addValue("idSede", idSede));
    }

    private static Sede mapear(ResultSet rs, int fila) throws SQLException {
        return new Sede(
                rs.getInt("IdSede"),
                rs.getString("NombreEstadio"),
                rs.getObject("Capacidad", Integer.class),
                rs.getObject("Latitud", BigDecimal.class),
                rs.getObject("Longitud", BigDecimal.class),
                rs.getInt("IdCiudad"),
                rs.getString("Ciudad"),
                rs.getString("Pais"),
                rs.getString("HusoHorario"));
    }
}
