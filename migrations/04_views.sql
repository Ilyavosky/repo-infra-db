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
  pm.nombre           AS nombre_producto,
  pm.sku,
  v.sku_variante,
  v.modelo,
  v.color,
  v.precio_adquisicion,
  v.codigo_barras,
  s.nombre_lugar      AS nombre_sucursal,
  mt.descripcion      AS motivo,
  u.nombre            AS nombre_usuario,
  ROUND((vb.precio_venta_final - v.precio_adquisicion) * vb.cantidad, 2) AS utilidad
FROM ventas_bajas        vb
JOIN variantes           v  ON vb.id_variante = v.id_variante
JOIN productos_maestros  pm ON v.id_producto_maestro = pm.id_producto_maestro
JOIN sucursales          s  ON vb.id_sucursal = s.id_sucursal
JOIN motivos_transaccion mt ON vb.id_motivo   = mt.id_motivo
JOIN usuarios            u  ON vb.id_usuario  = u.id_usuario;

DROP MATERIALIZED VIEW IF EXISTS vista_ranking_productos_global CASCADE;

CREATE MATERIALIZED VIEW vista_ranking_productos_global AS
SELECT
  pm.id_producto_maestro,
  pm.sku,
  pm.nombre                                                                     AS nombre_producto,
  v.id_variante,
  v.sku_variante,
  v.modelo,
  v.color,
  v.precio_adquisicion,
  v.precio_venta_etiqueta,
  COALESCE(SUM(vb.cantidad), 0)                                                 AS total_unidades_vendidas,
  COALESCE(ROUND(SUM(vb.precio_venta_final * vb.cantidad), 2), 0)              AS ingresos_totales,
  COALESCE(ROUND(SUM((vb.precio_venta_final - v.precio_adquisicion) * vb.cantidad), 2), 0)
                                                                                AS utilidad_total,
  RANK() OVER (
    ORDER BY COALESCE(SUM(vb.cantidad), 0) DESC
  )                                                                             AS ranking_mas_vendido,
  RANK() OVER (
    ORDER BY COALESCE(SUM(vb.cantidad), 0) ASC,
             pm.nombre ASC, v.modelo ASC, v.color ASC
  )                                                                             AS ranking_menos_vendido
FROM variantes v
JOIN productos_maestros pm ON v.id_producto_maestro = pm.id_producto_maestro
LEFT JOIN ventas_bajas  vb ON vb.id_variante = v.id_variante
WHERE EXISTS (SELECT 1 FROM inventario_sucursal i WHERE i.id_variante = v.id_variante AND i.stock_actual > 0)
GROUP BY
  pm.id_producto_maestro, pm.sku, pm.nombre,
  v.id_variante, v.sku_variante, v.modelo, v.color, v.precio_adquisicion, v.precio_venta_etiqueta
WITH DATA;

CREATE UNIQUE INDEX idx_ranking_global_variante
  ON vista_ranking_productos_global(id_variante);
CREATE INDEX idx_ranking_global_mas
  ON vista_ranking_productos_global(ranking_mas_vendido);
CREATE INDEX idx_ranking_global_menos
  ON vista_ranking_productos_global(ranking_menos_vendido);
CREATE INDEX idx_ranking_global_producto
  ON vista_ranking_productos_global(id_producto_maestro);

DROP MATERIALIZED VIEW IF EXISTS vista_ranking_productos_por_sucursal CASCADE;

CREATE MATERIALIZED VIEW vista_ranking_productos_por_sucursal AS
SELECT
  s.id_sucursal,
  s.nombre_lugar                                                                AS nombre_sucursal,
  pm.id_producto_maestro,
  pm.sku,
  pm.nombre                                                                     AS nombre_producto,
  v.id_variante,
  v.sku_variante,
  v.modelo,
  v.color,
  v.precio_adquisicion,
  v.precio_venta_etiqueta,
  COALESCE(SUM(vb.cantidad), 0)                                                 AS total_unidades_vendidas,
  COALESCE(ROUND(SUM(vb.precio_venta_final * vb.cantidad), 2), 0)              AS ingresos_sucursal,
  COALESCE(ROUND(SUM((vb.precio_venta_final - v.precio_adquisicion) * vb.cantidad), 2), 0)
                                                                                AS utilidad_sucursal,
  RANK() OVER (
    PARTITION BY s.id_sucursal
    ORDER BY COALESCE(SUM(vb.cantidad), 0) DESC,
             pm.nombre ASC, v.modelo ASC, v.color ASC
  )                                                                             AS ranking_mas_vendido,
  RANK() OVER (
    PARTITION BY s.id_sucursal
    ORDER BY COALESCE(SUM(vb.cantidad), 0) ASC,
             pm.nombre ASC, v.modelo ASC, v.color ASC
  )                                                                             AS ranking_menos_vendido
FROM sucursales s
CROSS JOIN variantes v
JOIN productos_maestros pm ON v.id_producto_maestro = pm.id_producto_maestro
LEFT JOIN ventas_bajas  vb ON vb.id_variante = v.id_variante
                           AND vb.id_sucursal = s.id_sucursal
WHERE s.activo = TRUE
AND EXISTS (
  SELECT 1 FROM inventario_sucursal i 
  WHERE i.id_variante = v.id_variante AND i.id_sucursal = s.id_sucursal AND i.stock_actual > 0
)
GROUP BY
  s.id_sucursal, s.nombre_lugar,
  pm.id_producto_maestro, pm.sku, pm.nombre,
  v.id_variante, v.sku_variante, v.modelo, v.color, v.precio_adquisicion, v.precio_venta_etiqueta
WITH DATA;

CREATE UNIQUE INDEX idx_ranking_suc_variante_suc
  ON vista_ranking_productos_por_sucursal(id_sucursal, id_variante);
CREATE INDEX idx_ranking_suc_mas
  ON vista_ranking_productos_por_sucursal(id_sucursal, ranking_mas_vendido);
CREATE INDEX idx_ranking_suc_menos
  ON vista_ranking_productos_por_sucursal(id_sucursal, ranking_menos_vendido);
CREATE INDEX idx_ranking_suc_producto
  ON vista_ranking_productos_por_sucursal(id_sucursal, id_producto_maestro);

DROP VIEW IF EXISTS vista_resumen_ventas_por_sucursal CASCADE;

CREATE OR REPLACE VIEW vista_resumen_ventas_por_sucursal AS
SELECT
  s.id_sucursal,
  s.nombre_lugar                                                                AS nombre_sucursal,
  COUNT(vb.id_transaccion)                                                      AS total_transacciones,
  COALESCE(SUM(vb.cantidad), 0)                                                 AS total_unidades_vendidas,
  COALESCE(ROUND(SUM(vb.precio_venta_final * vb.cantidad), 2), 0)              AS ingresos_brutos,
  COALESCE(ROUND(SUM(v.precio_adquisicion * vb.cantidad), 2), 0)               AS costo_total,
  COALESCE(ROUND(SUM((vb.precio_venta_final - v.precio_adquisicion) * vb.cantidad), 2), 0)
                                                                                AS utilidad_neta
FROM sucursales s
LEFT JOIN ventas_bajas  vb ON vb.id_sucursal = s.id_sucursal
LEFT JOIN variantes      v ON vb.id_variante  = v.id_variante
WHERE s.activo = TRUE
GROUP BY s.id_sucursal, s.nombre_lugar
ORDER BY s.nombre_lugar;
