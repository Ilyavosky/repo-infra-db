-- Q1: Metrica directa de hipotesis por sucursal
-- Mide el porcentaje de ventas al precio de etiqueta o superior, segmentado por sucursal
SELECT
  s.nombre_lugar AS sucursal,
  COUNT(*) AS total_ventas,
  COUNT(*) FILTER (WHERE vb.precio_venta_final >= v.precio_venta_etiqueta) AS ventas_sobre_etiqueta,
  ROUND(
    COUNT(*) FILTER (WHERE vb.precio_venta_final >= v.precio_venta_etiqueta)
    * 100.0 / NULLIF(COUNT(*), 0),
    2
  ) AS pct_sobre_etiqueta,
  85.00 AS meta,
  CASE
    WHEN ROUND(
      COUNT(*) FILTER (WHERE vb.precio_venta_final >= v.precio_venta_etiqueta)
      * 100.0 / NULLIF(COUNT(*), 0), 2
    ) >= 85.00 THEN 'CUMPLE'
    ELSE 'NO CUMPLE'
  END AS estado
FROM ventas_bajas vb
JOIN variantes v    ON vb.id_variante  = v.id_variante
JOIN sucursales s   ON vb.id_sucursal  = s.id_sucursal
GROUP BY s.id_sucursal, s.nombre_lugar
ORDER BY pct_sobre_etiqueta DESC;

-- Q2: Productos con mayor volumen de ventas (solo los que superan 5 unidades vendidas)
-- Demuestra: JOINs multiples, SUM, COUNT, GROUP BY, HAVING
SELECT
  pm.sku,
  pm.nombre AS producto,
  v.modelo,
  v.color,
  SUM(vb.cantidad) AS unidades_vendidas,
  ROUND(SUM(vb.precio_venta_final * vb.cantidad), 2) AS ingresos_totales,
  ROUND(SUM((vb.precio_venta_final - v.precio_adquisicion) * vb.cantidad), 2) AS utilidad_total,
  COUNT(DISTINCT vb.id_sucursal) AS sucursales_con_ventas
FROM ventas_bajas vb
JOIN variantes v ON vb.id_variante = v.id_variante
JOIN productos_maestros pm ON v.id_producto_maestro = pm.id_producto_maestro
GROUP BY pm.id_producto_maestro, pm.sku, pm.nombre, v.id_variante, v.modelo, v.color
HAVING SUM(vb.cantidad) > 5
ORDER BY unidades_vendidas DESC;

-- Q3: Clasificacion de transacciones por nivel de margen obtenido
-- Demuestra: CASE, COALESCE, campos calculados, subconsulta en SELECT
SELECT
  vb.id_transaccion,
  vb.fecha_hora,
  s.nombre_lugar AS sucursal,
  pm.nombre AS producto,
  v.modelo,
  v.color,
  vb.precio_venta_final,
  v.precio_venta_etiqueta,
  v.precio_adquisicion,
  fn_margen_porcentaje(v.precio_adquisicion, vb.precio_venta_final) AS margen_real_pct,
  CASE
    WHEN vb.precio_venta_final < v.precio_venta_etiqueta THEN 'DESCUENTO'
    WHEN vb.precio_venta_final = v.precio_venta_etiqueta THEN 'PRECIO ETIQUETA'
    ELSE 'SOBRE ETIQUETA'
  END AS categoria_precio,
  COALESCE(u.nombre, 'Sin usuario') AS vendedor
FROM ventas_bajas vb
JOIN variantes v ON vb.id_variante = v.id_variante
JOIN productos_maestros pm ON v.id_producto_maestro = pm.id_producto_maestro
JOIN sucursales s ON vb.id_sucursal = s.id_sucursal
JOIN usuarios u ON vb.id_usuario = u.id_usuario
ORDER BY vb.fecha_hora DESC;

-- Q4: Rentabilidad por sucursal comparada contra el promedio global (CTE + subconsulta)
-- Demuestra: CTE (WITH), subconsulta en WHERE, AVG, operaciones aritmeticas
WITH utilidad_por_sucursal AS (
  SELECT
    s.id_sucursal,
    s.nombre_lugar AS sucursal,
    ROUND(SUM((vb.precio_venta_final - v.precio_adquisicion) * vb.cantidad), 2) AS utilidad_total,
    COUNT(vb.id_transaccion) AS total_transacciones,
    ROUND(AVG(vb.precio_venta_final), 2) AS ticket_promedio
  FROM sucursales s
  JOIN ventas_bajas vb ON vb.id_sucursal = s.id_sucursal
  JOIN variantes v ON vb.id_variante = v.id_variante
  GROUP BY s.id_sucursal, s.nombre_lugar
)
SELECT
  ups.sucursal,
  ups.utilidad_total,
  ups.total_transacciones,
  ups.ticket_promedio,
  (SELECT ROUND(AVG(utilidad_total), 2) FROM utilidad_por_sucursal) AS promedio_global,
  CASE
    WHEN ups.utilidad_total >= (SELECT AVG(utilidad_total) FROM utilidad_por_sucursal)
    THEN 'SOBRE PROMEDIO'
    ELSE 'BAJO PROMEDIO'
  END AS rendimiento
FROM utilidad_por_sucursal ups
ORDER BY ups.utilidad_total DESC;

-- Q5: Variantes en stock que nunca han sido vendidas (subconsulta en WHERE con NOT EXISTS)
-- Demuestra: subconsulta correlacionada, LEFT JOIN, COALESCE, GROUP BY, HAVING
SELECT
  pm.sku,
  pm.nombre AS producto,
  v.sku_variante,
  v.modelo,
  v.color,
  v.precio_venta_etiqueta,
  SUM(inv.stock_actual) AS stock_total_sistema,
  COUNT(DISTINCT inv.id_sucursal) AS sucursales_con_stock
FROM variantes v
JOIN productos_maestros pm ON v.id_producto_maestro = pm.id_producto_maestro
JOIN inventario_sucursal inv ON inv.id_variante = v.id_variante
WHERE NOT EXISTS (
  SELECT 1 FROM ventas_bajas vb WHERE vb.id_variante = v.id_variante
)
GROUP BY pm.sku, pm.nombre, v.id_variante, v.sku_variante, v.modelo, v.color, v.precio_venta_etiqueta
HAVING SUM(inv.stock_actual) > 0
ORDER BY stock_total_sistema DESC;
