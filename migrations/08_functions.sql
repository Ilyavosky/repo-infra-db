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

CREATE OR REPLACE FUNCTION fn_variantes_por_sucursal(p_id_sucursal INTEGER)
RETURNS TABLE (
  id_variante INTEGER,
  nombre_producto VARCHAR,
  sku_variante VARCHAR,
  modelo VARCHAR,
  color VARCHAR,
  stock_actual INTEGER,
  precio_adquisicion   DECIMAL(12,2),
  precio_venta_etiqueta DECIMAL(12,2),
  margen_pct           DECIMAL(5,2)
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
  JOIN variantes v ON inv.id_variante = v.id_variante
  JOIN productos_maestros pm ON v.id_producto_maestro = pm.id_producto_maestro
  WHERE inv.id_sucursal = p_id_sucursal
    AND inv.stock_actual > 0
  ORDER BY pm.nombre, v.modelo, v.color;
END;
$$;
