CREATE OR REPLACE VIEW vista_hipotesis AS
SELECT
  COUNT(*) AS total_transacciones,
  COUNT(*) FILTER (WHERE vb.precio_venta_final >= v.precio_venta_etiqueta) AS transacciones_sobre_etiqueta,
  ROUND(
    COUNT(*) FILTER (WHERE vb.precio_venta_final >= v.precio_venta_etiqueta)
    * 100.0 / NULLIF(COUNT(*), 0),
    2
  ) AS porcentaje_sobre_etiqueta,
  85.00 AS meta_hipotesis,
  CASE
    WHEN ROUND(
      COUNT(*) FILTER (WHERE vb.precio_venta_final >= v.precio_venta_etiqueta)
      * 100.0 / NULLIF(COUNT(*), 0),
      2
    ) >= 85.00
    THEN 'VALIDADA'
    ELSE 'NO VALIDADA'
  END AS estado_hipotesis
FROM ventas_bajas vb
JOIN variantes v ON vb.id_variante = v.id_variante;
