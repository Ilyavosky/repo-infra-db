-- =============================================================================
-- GLAMSTOCK — OBJETOS DE BASE DE DATOS
-- Views, Stored Procedures, Funciones y Triggers
-- =============================================================================


-- =============================================================================
-- SECCIÓN 1: VISTAS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- vista_ventas_detallada
-- Propósito: Expone cada transacción de venta enriquecida con los datos de la
-- variante, producto maestro, sucursal, motivo y usuario. Incluye el cálculo
-- de utilidad por transacción (precio_venta_final - precio_adquisicion) * cantidad.
-- Usada por el módulo de historial de ventas y exportación de reportes.
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS vista_ventas_detallada CASCADE;

CREATE OR REPLACE VIEW vista_ventas_detallada AS
SELECT
  vb.id_transaccion,
  vb.id_variante,
  vb.id_sucursal,
  vb.id_motivo,
  vb.id_usuario,
  vb.cantidad,
  vb.precio_venta_final,
  vb.fecha_hora,
  pm.id_producto_maestro,
  pm.nombre              AS nombre_producto,
  pm.sku,
  v.sku_variante,
  v.modelo,
  v.color,
  v.precio_adquisicion,
  v.codigo_barras,
  s.nombre_lugar         AS nombre_sucursal,
  mt.descripcion         AS motivo,
  u.nombre               AS nombre_usuario,
  ROUND((vb.precio_venta_final - v.precio_adquisicion) * vb.cantidad, 2) AS utilidad
FROM ventas_bajas vb
JOIN variantes          v  ON vb.id_variante  = v.id_variante
JOIN productos_maestros pm ON v.id_producto_maestro = pm.id_producto_maestro
JOIN sucursales         s  ON vb.id_sucursal   = s.id_sucursal
JOIN motivos_transaccion mt ON vb.id_motivo    = mt.id_motivo
JOIN usuarios           u  ON vb.id_usuario    = u.id_usuario;


-- -----------------------------------------------------------------------------
-- vista_ranking_productos_global
-- Propósito: Vista materializada que agrega ventas por variante a nivel global
-- (todas las sucursales). Calcula ingresos totales, utilidad total y asigna dos
-- rankings simultáneos: más vendido y menos vendido. Se actualiza manualmente
-- con REFRESH MATERIALIZED VIEW CONCURRENTLY para no bloquear lecturas.
-- Indexada por id_variante (UNIQUE), ranking_mas_vendido y ranking_menos_vendido.
-- -----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS vista_ranking_productos_global CASCADE;

CREATE MATERIALIZED VIEW vista_ranking_productos_global AS
SELECT
  pm.id_producto_maestro,
  pm.sku,
  pm.nombre              AS nombre_producto,
  v.id_variante,
  v.sku_variante,
  v.modelo,
  v.color,
  v.precio_adquisicion,
  v.precio_venta_etiqueta,
  COALESCE(SUM(vb.cantidad), 0)                                              AS total_unidades_vendidas,
  COALESCE(ROUND(SUM(vb.precio_venta_final * vb.cantidad), 2), 0)            AS ingresos_totales,
  COALESCE(ROUND(SUM((vb.precio_venta_final - v.precio_adquisicion) * vb.cantidad), 2), 0) AS utilidad_total,
  RANK() OVER (
    ORDER BY COALESCE(SUM(vb.cantidad), 0) DESC
  ) AS ranking_mas_vendido,
  RANK() OVER (
    ORDER BY COALESCE(SUM(vb.cantidad), 0) ASC,
             pm.nombre ASC, v.modelo ASC, v.color ASC
  ) AS ranking_menos_vendido
FROM variantes v
JOIN productos_maestros pm ON v.id_producto_maestro = pm.id_producto_maestro
LEFT JOIN ventas_bajas  vb ON vb.id_variante = v.id_variante
WHERE EXISTS (
  SELECT 1 FROM inventario_sucursal i
  WHERE i.id_variante = v.id_variante AND i.stock_actual > 0
)
GROUP BY
  pm.id_producto_maestro, pm.sku, pm.nombre,
  v.id_variante, v.sku_variante, v.modelo, v.color,
  v.precio_adquisicion, v.precio_venta_etiqueta
WITH DATA;

CREATE UNIQUE INDEX idx_ranking_global_variante  ON vista_ranking_productos_global(id_variante);
CREATE        INDEX idx_ranking_global_mas        ON vista_ranking_productos_global(ranking_mas_vendido);
CREATE        INDEX idx_ranking_global_menos      ON vista_ranking_productos_global(ranking_menos_vendido);
CREATE        INDEX idx_ranking_global_producto   ON vista_ranking_productos_global(id_producto_maestro);


-- -----------------------------------------------------------------------------
-- vista_ranking_productos_por_sucursal
-- Propósito: Similar a la vista global pero particionada por sucursal. Permite
-- comparar el desempeño de cada variante dentro de su propia sucursal mediante
-- RANK() OVER (PARTITION BY s.id_sucursal). Solo incluye sucursales activas y
-- variantes con stock > 0 en esa sucursal.
-- -----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS vista_ranking_productos_por_sucursal CASCADE;

CREATE MATERIALIZED VIEW vista_ranking_productos_por_sucursal AS
SELECT
  s.id_sucursal,
  s.nombre_lugar         AS nombre_sucursal,
  pm.id_producto_maestro,
  pm.sku,
  pm.nombre              AS nombre_producto,
  v.id_variante,
  v.sku_variante,
  v.modelo,
  v.color,
  v.precio_adquisicion,
  v.precio_venta_etiqueta,
  COALESCE(SUM(vb.cantidad), 0)                                               AS total_unidades_vendidas,
  COALESCE(ROUND(SUM(vb.precio_venta_final * vb.cantidad), 2), 0)             AS ingresos_sucursal,
  COALESCE(ROUND(SUM((vb.precio_venta_final - v.precio_adquisicion) * vb.cantidad), 2), 0) AS utilidad_sucursal,
  RANK() OVER (
    PARTITION BY s.id_sucursal
    ORDER BY COALESCE(SUM(vb.cantidad), 0) DESC,
             pm.nombre ASC, v.modelo ASC, v.color ASC
  ) AS ranking_mas_vendido,
  RANK() OVER (
    PARTITION BY s.id_sucursal
    ORDER BY COALESCE(SUM(vb.cantidad), 0) ASC,
             pm.nombre ASC, v.modelo ASC, v.color ASC
  ) AS ranking_menos_vendido
FROM sucursales s
CROSS JOIN variantes v
JOIN productos_maestros pm ON v.id_producto_maestro = pm.id_producto_maestro
LEFT JOIN ventas_bajas  vb ON vb.id_variante = v.id_variante
                           AND vb.id_sucursal = s.id_sucursal
WHERE s.activo = TRUE
  AND EXISTS (
    SELECT 1 FROM inventario_sucursal i
    WHERE i.id_variante  = v.id_variante
      AND i.id_sucursal  = s.id_sucursal
      AND i.stock_actual > 0
  )
GROUP BY
  s.id_sucursal, s.nombre_lugar,
  pm.id_producto_maestro, pm.sku, pm.nombre,
  v.id_variante, v.sku_variante, v.modelo, v.color,
  v.precio_adquisicion, v.precio_venta_etiqueta
WITH DATA;

CREATE UNIQUE INDEX idx_ranking_suc_variante_suc ON vista_ranking_productos_por_sucursal(id_sucursal, id_variante);
CREATE        INDEX idx_ranking_suc_mas          ON vista_ranking_productos_por_sucursal(id_sucursal, ranking_mas_vendido);
CREATE        INDEX idx_ranking_suc_menos        ON vista_ranking_productos_por_sucursal(id_sucursal, ranking_menos_vendido);
CREATE        INDEX idx_ranking_suc_producto     ON vista_ranking_productos_por_sucursal(id_sucursal, id_producto_maestro);


-- -----------------------------------------------------------------------------
-- vista_resumen_ventas_por_sucursal
-- Propósito: Agrega el total de transacciones, unidades vendidas, ingresos
-- brutos, costo total y utilidad neta para cada sucursal activa. Sirve como
-- fuente de datos para el panel de dashboard de la aplicación.
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS vista_resumen_ventas_por_sucursal CASCADE;

CREATE OR REPLACE VIEW vista_resumen_ventas_por_sucursal AS
SELECT
  s.id_sucursal,
  s.nombre_lugar                                                              AS nombre_sucursal,
  COUNT(vb.id_transaccion)                                                    AS total_transacciones,
  COALESCE(SUM(vb.cantidad), 0)                                               AS total_unidades_vendidas,
  COALESCE(ROUND(SUM(vb.precio_venta_final * vb.cantidad), 2), 0)             AS ingresos_brutos,
  COALESCE(ROUND(SUM(v.precio_adquisicion  * vb.cantidad), 2), 0)             AS costo_total,
  COALESCE(ROUND(SUM((vb.precio_venta_final - v.precio_adquisicion) * vb.cantidad), 2), 0) AS utilidad_neta
FROM sucursales s
LEFT JOIN ventas_bajas vb ON vb.id_sucursal  = s.id_sucursal
LEFT JOIN variantes    v  ON vb.id_variante  = v.id_variante
WHERE s.activo = TRUE
GROUP BY s.id_sucursal, s.nombre_lugar
ORDER BY s.nombre_lugar;


-- -----------------------------------------------------------------------------
-- vista_hipotesis
-- Propósito: Vista de análisis de hipótesis de negocio. Evalúa si al menos
-- el 85 % de las transacciones se realizaron a un precio igual o mayor al
-- precio de etiqueta, lo que indicaría que los precios etiquetados están
-- alineados con el mercado real. Retorna el estado VALIDADA / NO VALIDADA.
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS vista_hipotesis CASCADE;

CREATE OR REPLACE VIEW vista_hipotesis AS
SELECT
  COUNT(*)                                                                          AS total_transacciones,
  COUNT(*) FILTER (WHERE vb.precio_venta_final >= v.precio_venta_etiqueta)         AS transacciones_sobre_etiqueta,
  ROUND(
    COUNT(*) FILTER (WHERE vb.precio_venta_final >= v.precio_venta_etiqueta)
    * 100.0 / NULLIF(COUNT(*), 0),
    2
  )                                                                                 AS porcentaje_sobre_etiqueta,
  85.00                                                                             AS meta_hipotesis,
  CASE
    WHEN ROUND(
      COUNT(*) FILTER (WHERE vb.precio_venta_final >= v.precio_venta_etiqueta)
      * 100.0 / NULLIF(COUNT(*), 0),
      2
    ) >= 85.00
    THEN 'VALIDADA'
    ELSE 'NO VALIDADA'
  END                                                                               AS estado_hipotesis
FROM ventas_bajas vb
JOIN variantes v ON vb.id_variante = v.id_variante;


-- =============================================================================
-- SECCIÓN 2: STORED PROCEDURES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- sp_registrar_venta
-- Propósito: Registra una transacción de venta de forma atómica. Bloquea la
-- fila de inventario con FOR UPDATE para evitar condiciones de carrera,
-- valida que exista stock suficiente y que el precio de venta no sea menor
-- al precio de adquisición, inserta en ventas_bajas y descuenta el stock.
-- Lanza EXCEPTION con mensaje descriptivo ante cualquier violación.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_venta(
  p_id_variante       INTEGER,
  p_id_sucursal       INTEGER,
  p_id_motivo         INTEGER,
  p_id_usuario        INTEGER,
  p_cantidad          INTEGER,
  p_precio_venta_final DECIMAL(12,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_stock              INTEGER;
  v_precio_adquisicion DECIMAL(12,2);
BEGIN
  SELECT inv.stock_actual, v.precio_adquisicion
  INTO   v_stock, v_precio_adquisicion
  FROM   inventario_sucursal inv
  JOIN   variantes v ON v.id_variante = inv.id_variante
  WHERE  inv.id_variante = p_id_variante
    AND  inv.id_sucursal  = p_id_sucursal
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La variante % no existe en la sucursal %', p_id_variante, p_id_sucursal;
  END IF;

  IF v_stock < p_cantidad THEN
    RAISE EXCEPTION 'Stock insuficiente. Disponible: %, Solicitado: %', v_stock, p_cantidad;
  END IF;

  IF p_precio_venta_final < v_precio_adquisicion THEN
    RAISE EXCEPTION 'Precio de venta (%) inferior al precio de adquisicion (%)', p_precio_venta_final, v_precio_adquisicion;
  END IF;

  INSERT INTO ventas_bajas (id_variante, id_sucursal, id_motivo, id_usuario, cantidad, precio_venta_final)
  VALUES (p_id_variante, p_id_sucursal, p_id_motivo, p_id_usuario, p_cantidad, p_precio_venta_final);

  UPDATE inventario_sucursal
  SET    stock_actual = stock_actual - p_cantidad
  WHERE  id_variante = p_id_variante
    AND  id_sucursal  = p_id_sucursal;
END;
$$;


-- -----------------------------------------------------------------------------
-- sp_transferir_stock
-- Propósito: Mueve una cantidad de stock de una sucursal origen a una sucursal
-- destino de forma transaccional. Bloquea la fila origen con FOR UPDATE,
-- valida stock disponible, descuenta en origen e incrementa en destino usando
-- INSERT ... ON CONFLICT DO UPDATE para crear el registro si no existía.
-- Hace ROLLBACK explícito ante cualquier error y relanza la excepción.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_transferir_stock(
  p_id_variante         INTEGER,
  p_id_sucursal_origen  INTEGER,
  p_id_sucursal_destino INTEGER,
  p_cantidad            INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_stock_origen INTEGER;
BEGIN
  SELECT stock_actual INTO v_stock_origen
  FROM   inventario_sucursal
  WHERE  id_variante = p_id_variante
    AND  id_sucursal  = p_id_sucursal_origen
  FOR UPDATE;

  IF NOT FOUND THEN
    ROLLBACK;
    RAISE EXCEPTION 'La variante % no existe en la sucursal origen %', p_id_variante, p_id_sucursal_origen;
  END IF;

  IF v_stock_origen < p_cantidad THEN
    ROLLBACK;
    RAISE EXCEPTION 'Stock insuficiente en origen. Disponible: %, Solicitado: %', v_stock_origen, p_cantidad;
  END IF;

  UPDATE inventario_sucursal
  SET    stock_actual = stock_actual - p_cantidad
  WHERE  id_variante = p_id_variante
    AND  id_sucursal  = p_id_sucursal_origen;

  INSERT INTO inventario_sucursal (id_variante, id_sucursal, stock_actual)
  VALUES (p_id_variante, p_id_sucursal_destino, p_cantidad)
  ON CONFLICT (id_variante, id_sucursal)
  DO UPDATE SET stock_actual = inventario_sucursal.stock_actual + EXCLUDED.stock_actual;

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE EXCEPTION 'Transferencia fallida: %', SQLERRM;
END;
$$;


-- -----------------------------------------------------------------------------
-- sp_ajustar_precios_producto
-- Propósito: Aplica un incremento porcentual al precio_venta_etiqueta de todas
-- las variantes de un producto maestro dado. Usa un cursor explícito para
-- recorrer variante por variante y solo actualiza aquellas en las que el nuevo
-- precio siga siendo mayor o igual al precio de adquisición (respetando el
-- CHECK de la tabla). Útil para ajustes masivos de precios por temporada.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_ajustar_precios_producto(
  p_id_producto   INTEGER,
  p_incremento_pct DECIMAL(5,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
  cur_variantes CURSOR FOR
    SELECT id_variante, precio_adquisicion, precio_venta_etiqueta
    FROM   variantes
    WHERE  id_producto_maestro = p_id_producto;
  rec            RECORD;
  v_nuevo_precio DECIMAL(12,2);
BEGIN
  IF NOT EXISTS (SELECT 1 FROM productos_maestros WHERE id_producto_maestro = p_id_producto) THEN
    RAISE EXCEPTION 'El producto % no existe', p_id_producto;
  END IF;

  OPEN cur_variantes;
  LOOP
    FETCH cur_variantes INTO rec;
    EXIT WHEN NOT FOUND;

    v_nuevo_precio := ROUND(rec.precio_venta_etiqueta * (1 + p_incremento_pct / 100.0), 2);

    IF v_nuevo_precio >= rec.precio_adquisicion THEN
      UPDATE variantes
      SET    precio_venta_etiqueta = v_nuevo_precio
      WHERE  id_variante = rec.id_variante;
    END IF;
  END LOOP;
  CLOSE cur_variantes;
END;
$$;


-- =============================================================================
-- SECCIÓN 3: FUNCIONES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- fn_margen_porcentaje  (escalar)
-- Propósito: Calcula el margen de ganancia como porcentaje sobre el precio de
-- adquisición: ((venta - adquisicion) / adquisicion) * 100. Devuelve 0.00 si
-- el precio de adquisición es NULL o cero para evitar divisiones por cero.
-- Se usa como auxiliar dentro de fn_variantes_por_sucursal y en queries ad hoc.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_margen_porcentaje(
  p_precio_adquisicion DECIMAL(12,2),
  p_precio_venta       DECIMAL(12,2)
)
RETURNS DECIMAL(5,2)
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_precio_adquisicion IS NULL OR p_precio_adquisicion = 0 THEN
    RETURN 0.00;
  END IF;
  RETURN ROUND(((p_precio_venta - p_precio_adquisicion) / p_precio_adquisicion) * 100.0, 2);
END;
$$;


-- -----------------------------------------------------------------------------
-- fn_variantes_por_sucursal  (retorna TABLE)
-- Propósito: Devuelve el catálogo de variantes con stock disponible (> 0) para
-- una sucursal específica, incluyendo nombre de producto, precios y el margen
-- calculado mediante fn_margen_porcentaje. Valida que la sucursal exista antes
-- de ejecutar la consulta. Usada por el endpoint GET /inventario/:id_sucursal.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_variantes_por_sucursal(p_id_sucursal INTEGER)
RETURNS TABLE (
  id_variante           INTEGER,
  nombre_producto       VARCHAR,
  sku_variante          VARCHAR,
  modelo                VARCHAR,
  color                 VARCHAR,
  stock_actual          INTEGER,
  precio_adquisicion    DECIMAL(12,2),
  precio_venta_etiqueta DECIMAL(12,2),
  margen_pct            DECIMAL(5,2)
)
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM sucursales WHERE id_sucursal = p_id_sucursal) THEN
    RAISE EXCEPTION 'La sucursal % no existe', p_id_sucursal;
  END IF;

  RETURN QUERY
  SELECT
    v.id_variante,
    pm.nombre::VARCHAR,
    v.sku_variante,
    v.modelo,
    v.color,
    inv.stock_actual,
    v.precio_adquisicion,
    v.precio_venta_etiqueta,
    fn_margen_porcentaje(v.precio_adquisicion, v.precio_venta_etiqueta)
  FROM inventario_sucursal inv
  JOIN variantes          v  ON inv.id_variante       = v.id_variante
  JOIN productos_maestros pm ON v.id_producto_maestro = pm.id_producto_maestro
  WHERE inv.id_sucursal  = p_id_sucursal
    AND inv.stock_actual > 0
  ORDER BY pm.nombre, v.modelo, v.color;
END;
$$;


-- =============================================================================
-- SECCIÓN 4: TRIGGERS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- update_timestamp  (función compartida por todos los triggers de updated_at)
-- Propósito: Función genérica BEFORE UPDATE que asigna CURRENT_TIMESTAMP a la
-- columna updated_at de cualquier tabla que la invoque. Al ser compartida, un
-- solo cambio en esta función aplica a los seis triggers que la referencian.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

-- Actualiza updated_at en productos_maestros ante cualquier UPDATE.
CREATE OR REPLACE TRIGGER productos_maestros_updated_at
  BEFORE UPDATE ON productos_maestros
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Actualiza updated_at en sucursales ante cualquier UPDATE.
CREATE OR REPLACE TRIGGER sucursales_updated_at
  BEFORE UPDATE ON sucursales
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Actualiza updated_at en usuarios ante cualquier UPDATE.
CREATE OR REPLACE TRIGGER usuarios_updated_at
  BEFORE UPDATE ON usuarios
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Actualiza updated_at en variantes ante cualquier UPDATE.
CREATE OR REPLACE TRIGGER variantes_updated_at
  BEFORE UPDATE ON variantes
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Actualiza updated_at en inventario_sucursal ante cualquier UPDATE de stock.
CREATE OR REPLACE TRIGGER inventario_sucursal_updated_at
  BEFORE UPDATE ON inventario_sucursal
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Actualiza updated_at en ventas_bajas ante cualquier UPDATE.
CREATE OR REPLACE TRIGGER ventas_bajas_updated_at
  BEFORE UPDATE ON ventas_bajas
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();


-- -----------------------------------------------------------------------------
-- trg_validar_precio_venta  +  ventas_validar_precio
-- Propósito: Trigger BEFORE INSERT en ventas_bajas que valida que el precio
-- final de venta no sea inferior al precio de adquisición de la variante.
-- Actúa como segunda línea de defensa además del CHECK en la tabla variantes,
-- porque precio_venta_final se negocia en tiempo de transacción y puede
-- divergir del precio_venta_etiqueta registrado estáticamente.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_validar_precio_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_precio_adquisicion DECIMAL(12,2);
  v_precio_etiqueta    DECIMAL(12,2);
BEGIN
  SELECT precio_adquisicion, precio_venta_etiqueta
  INTO   v_precio_adquisicion, v_precio_etiqueta
  FROM   variantes
  WHERE  id_variante = NEW.id_variante;

  IF NEW.precio_venta_final < v_precio_adquisicion THEN
    RAISE EXCEPTION
      'Precio de venta (%) no puede ser inferior al precio de adquisicion (%) para variante %',
      NEW.precio_venta_final, v_precio_adquisicion, NEW.id_variante;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER ventas_validar_precio
  BEFORE INSERT ON ventas_bajas
  FOR EACH ROW EXECUTE FUNCTION trg_validar_precio_venta();
