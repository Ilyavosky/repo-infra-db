-- ============================================================
-- ROLLBACK DE PRUEBAS POSTMAN
-- Deja la BD en el estado previo a las pruebas
-- Estado base: 2 usuarios, 31 productos, 45 variantes,
--              2 sucursales, 45 inventario, 6 ventas, 5 motivos
-- ============================================================

BEGIN;

-- 1. Eliminar ventas generadas por pruebas (conservar las 6 originales)
DELETE FROM ventas_bajas WHERE id_transaccion > 6;

-- 2. Eliminar usuario de prueba Postman
DELETE FROM usuarios WHERE email = 'prueba.postman@glamstock.com';

-- 3. Eliminar sucursal de prueba Postman
DELETE FROM sucursales WHERE nombre_lugar = 'Sucursal Prueba Postman';

-- 4. Eliminar inventario de variantes de prueba
DELETE FROM inventario_sucursal
WHERE id_variante IN (
  SELECT v.id_variante FROM variantes v
  JOIN productos_maestros pm ON v.id_producto_maestro = pm.id_producto_maestro
  WHERE pm.sku = 'TEST-POSTMAN-001'
);

-- 5. Eliminar variantes de prueba directas
DELETE FROM variantes WHERE sku_variante = 'SKU-VAR-TEST-001';

-- 6. Eliminar variantes del producto de prueba
DELETE FROM variantes
WHERE id_producto_maestro IN (
  SELECT id_producto_maestro FROM productos_maestros WHERE sku = 'TEST-POSTMAN-001'
);

-- 7. Eliminar producto de prueba
DELETE FROM productos_maestros WHERE sku = 'TEST-POSTMAN-001';

-- 8. Reactivar sucursal si fue desactivada por el toggle
UPDATE sucursales SET activo = TRUE WHERE id_sucursal IN (1, 2);

-- 9. Verificar estado final
SELECT 'usuarios' AS tabla, COUNT(*) FROM usuarios
UNION ALL SELECT 'productos_maestros', COUNT(*) FROM productos_maestros
UNION ALL SELECT 'variantes', COUNT(*) FROM variantes
UNION ALL SELECT 'sucursales', COUNT(*) FROM sucursales
UNION ALL SELECT 'inventario_sucursal', COUNT(*) FROM inventario_sucursal
UNION ALL SELECT 'ventas_bajas', COUNT(*) FROM ventas_bajas
UNION ALL SELECT 'motivos_transaccion', COUNT(*) FROM motivos_transaccion;

COMMIT;