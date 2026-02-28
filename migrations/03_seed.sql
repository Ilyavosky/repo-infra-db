BEGIN;

-- Sucursales
INSERT INTO sucursales (nombre_lugar, ubicacion, activo) VALUES
('Tienda Centro', 'Av. Central 123, Tuxtla Gutiérrez', TRUE),
('Bodega Principal', 'Libramiento Sur, Bodega 4, Tuxtla Gutiérrez', TRUE),
('Tienda Plaza', 'Plaza Crystal Local 45, Tuxtla Gutiérrez', TRUE),
('Tienda Terán', 'Blvd. Ángel Albino Corzo 890, Tuxtla Gutiérrez', TRUE)
ON CONFLICT (nombre_lugar) DO NOTHING;

-- Motivos de transacción
INSERT INTO motivos_transaccion (descripcion) VALUES
('Venta directa al cliente'),
('Baja por merma / daño'),
('Ajuste de inventario (Sobrante)'),
('Ajuste de inventario (Faltante)'),
('Ingreso por adquisición / compra')
ON CONFLICT (descripcion) DO NOTHING;

-- Usuario administrador
INSERT INTO usuarios (nombre, email, password_hash, rol, activo) VALUES
(
  'Administrador',
  :'admin_email',
  crypt(:'admin_password', gen_salt('bf')),
  'ADMIN',
  TRUE
)
ON CONFLICT (email) DO NOTHING;

-- Usuario gerente de ejemplo
INSERT INTO usuarios (nombre, email, password_hash, rol, activo) VALUES
(
  'Gerente General',
  'gerente@glamstock.com',
  crypt('Gerente1234!', gen_salt('bf')),
  'GERENTE',
  TRUE
)
ON CONFLICT (email) DO NOTHING;

-- Productos maestros
INSERT INTO productos_maestros (sku, nombre) VALUES
('BOL-001', 'Bolsa Kelly'),
('BOL-002', 'Bolsa Birkin'),
('BOL-003', 'Bolsa Tote Canvas'),
('BOL-004', 'Bolsa Crossbody Mini'),
('BOL-005', 'Bolsa Shopper Grande'),
('CAR-001', 'Cartera Bifold'),
('CAR-002', 'Cartera Zip Around'),
('CAR-003', 'Cartera Slim'),
('MOC-001', 'Mochila Urbana'),
('MOC-002', 'Mochila Casual'),
('CIN-001', 'Cinturón Clásico Piel'),
('CIN-002', 'Cinturón Reversible'),
('MON-001', 'Monedero Redondo'),
('MON-002', 'Monedero Rectangular'),
('KIT-001', 'Kit Bolsa + Cartera')
ON CONFLICT (sku) DO NOTHING;

-- Variantes
INSERT INTO variantes (id_producto_maestro, sku_variante, codigo_barras, modelo, color, precio_adquisicion, precio_venta_etiqueta) VALUES
-- Bolsa Kelly
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-001'), 'BOL-001-NEG-25CM', 'CB-BOL001-001', '25cm', 'Negro', 1200.00, 2499.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-001'), 'BOL-001-CAM-25CM', 'CB-BOL001-002', '25cm', 'Camel', 1200.00, 2499.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-001'), 'BOL-001-NEG-32CM', 'CB-BOL001-003', '32cm', 'Negro', 1400.00, 2899.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-001'), 'BOL-001-VIN-32CM', 'CB-BOL001-004', '32cm', 'Vino', 1400.00, 2899.00),

-- Bolsa Birkin
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-002'), 'BOL-002-NEG-30CM', 'CB-BOL002-001', '30cm', 'Negro', 1500.00, 3199.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-002'), 'BOL-002-BEI-30CM', 'CB-BOL002-002', '30cm', 'Beige', 1500.00, 3199.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-002'), 'BOL-002-CAF-35CM', 'CB-BOL002-003', '35cm', 'Café', 1700.00, 3599.00),

-- Bolsa Tote Canvas
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-003'), 'BOL-003-NAT-ESTND', 'CB-BOL003-001', 'Estándar', 'Natural', 350.00, 799.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-003'), 'BOL-003-NEG-ESTND', 'CB-BOL003-002', 'Estándar', 'Negro', 350.00, 799.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-003'), 'BOL-003-NAT-GRAND', 'CB-BOL003-003', 'Grande', 'Natural', 420.00, 950.00),

-- Bolsa Crossbody Mini
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-004'), 'BOL-004-ROS-MINI', 'CB-BOL004-001', 'Mini', 'Rosa', 480.00, 1099.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-004'), 'BOL-004-NEG-MINI', 'CB-BOL004-002', 'Mini', 'Negro', 480.00, 1099.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-004'), 'BOL-004-BLA-MINI', 'CB-BOL004-003', 'Mini', 'Blanco', 480.00, 1099.00),

-- Bolsa Shopper Grande
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-005'), 'BOL-005-CAM-ESTND', 'CB-BOL005-001', 'Estándar', 'Camel', 600.00, 1299.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='BOL-005'), 'BOL-005-NEG-ESTND', 'CB-BOL005-002', 'Estándar', 'Negro', 600.00, 1299.00),

-- Cartera Bifold
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CAR-001'), 'CAR-001-NEG-CLSIC', 'CB-CAR001-001', 'Clásica', 'Negro', 280.00, 599.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CAR-001'), 'CAR-001-CAF-CLSIC', 'CB-CAR001-002', 'Clásica', 'Café', 280.00, 599.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CAR-001'), 'CAR-001-VIN-CLSIC', 'CB-CAR001-003', 'Clásica', 'Vino', 280.00, 599.00),

-- Cartera Zip Around
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CAR-002'), 'CAR-002-NEG-ESTND', 'CB-CAR002-001', 'Estándar', 'Negro', 320.00, 699.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CAR-002'), 'CAR-002-ROS-ESTND', 'CB-CAR002-002', 'Estándar', 'Rosa', 320.00, 699.00),

-- Cartera Slim
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CAR-003'), 'CAR-003-NEG-SLIM', 'CB-CAR003-001', 'Slim', 'Negro', 220.00, 449.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CAR-003'), 'CAR-003-CAF-SLIM', 'CB-CAR003-002', 'Slim', 'Café', 220.00, 449.00),

-- Mochila Urbana
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='MOC-001'), 'MOC-001-NEG-MEDIA', 'CB-MOC001-001', 'Mediana', 'Negro', 700.00, 1499.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='MOC-001'), 'MOC-001-GRI-MEDIA', 'CB-MOC001-002', 'Mediana', 'Gris', 700.00, 1499.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='MOC-001'), 'MOC-001-NEG-GRAND', 'CB-MOC001-003', 'Grande', 'Negro', 850.00, 1799.00),

-- Mochila Casual
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='MOC-002'), 'MOC-002-ROS-ESTND', 'CB-MOC002-001', 'Estándar', 'Rosa', 450.00, 999.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='MOC-002'), 'MOC-002-NEG-ESTND', 'CB-MOC002-002', 'Estándar', 'Negro', 450.00, 999.00),

-- Cinturón Clásico Piel
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CIN-001'), 'CIN-001-NEG-TALLA', 'CB-CIN001-001', 'Talla S', 'Negro', 180.00, 399.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CIN-001'), 'CIN-001-NEG-TALLM', 'CB-CIN001-002', 'Talla M', 'Negro', 180.00, 399.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CIN-001'), 'CIN-001-NEG-TALLL', 'CB-CIN001-003', 'Talla L', 'Negro', 180.00, 399.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CIN-001'), 'CIN-001-CAF-TALLM', 'CB-CIN001-004', 'Talla M', 'Café', 180.00, 399.00),

-- Cinturón Reversible
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CIN-002'), 'CIN-002-NEG-TALLA', 'CB-CIN002-001', 'Talla S', 'Negro/Café', 200.00, 449.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CIN-002'), 'CIN-002-NEG-TALLM', 'CB-CIN002-002', 'Talla M', 'Negro/Café', 200.00, 449.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='CIN-002'), 'CIN-002-NEG-TALLL', 'CB-CIN002-003', 'Talla L', 'Negro/Café', 200.00, 449.00),

-- Monedero Redondo
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='MON-001'), 'MON-001-NEG-ESTND', 'CB-MON001-001', 'Estándar', 'Negro', 120.00, 279.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='MON-001'), 'MON-001-ROS-ESTND', 'CB-MON001-002', 'Estándar', 'Rosa', 120.00, 279.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='MON-001'), 'MON-001-VIN-ESTND', 'CB-MON001-003', 'Estándar', 'Vino', 120.00, 279.00),

-- Monedero Rectangular
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='MON-002'), 'MON-002-NEG-ESTND', 'CB-MON002-001', 'Estándar', 'Negro', 130.00, 299.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='MON-002'), 'MON-002-CAF-ESTND', 'CB-MON002-002', 'Estándar', 'Café', 130.00, 299.00),

-- Kit Bolsa + Cartera
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='KIT-001'), 'KIT-001-NEG-SETBS', 'CB-KIT001-001', 'Set Básico', 'Negro', 900.00, 1899.00),
((SELECT id_producto_maestro FROM productos_maestros WHERE sku='KIT-001'), 'KIT-001-CAM-SETBS', 'CB-KIT001-002', 'Set Básico', 'Camel', 900.00, 1899.00)
ON CONFLICT (codigo_barras) DO NOTHING;

-- Inventario por sucursal (Tienda Centro)
INSERT INTO inventario_sucursal (id_variante, id_sucursal, stock_actual)
SELECT v.id_variante, s.id_sucursal,
  CASE
    WHEN v.precio_venta_etiqueta > 2000 THEN 3
    WHEN v.precio_venta_etiqueta > 1000 THEN 5
    ELSE 8
  END
FROM variantes v
CROSS JOIN sucursales s
WHERE s.nombre_lugar = 'Tienda Centro'
ON CONFLICT (id_variante, id_sucursal) DO NOTHING;

-- Inventario por sucursal (Tienda Plaza)
INSERT INTO inventario_sucursal (id_variante, id_sucursal, stock_actual)
SELECT v.id_variante, s.id_sucursal,
  CASE
    WHEN v.precio_venta_etiqueta > 2000 THEN 2
    WHEN v.precio_venta_etiqueta > 1000 THEN 4
    ELSE 6
  END
FROM variantes v
CROSS JOIN sucursales s
WHERE s.nombre_lugar = 'Tienda Plaza'
ON CONFLICT (id_variante, id_sucursal) DO NOTHING;

-- Inventario por sucursal (Tienda Terán)
INSERT INTO inventario_sucursal (id_variante, id_sucursal, stock_actual)
SELECT v.id_variante, s.id_sucursal,
  CASE
    WHEN v.precio_venta_etiqueta > 2000 THEN 2
    WHEN v.precio_venta_etiqueta > 1000 THEN 3
    ELSE 5
  END
FROM variantes v
CROSS JOIN sucursales s
WHERE s.nombre_lugar = 'Tienda Terán'
ON CONFLICT (id_variante, id_sucursal) DO NOTHING;

-- Inventario por sucursal (Bodega Principal - mayor stock)
INSERT INTO inventario_sucursal (id_variante, id_sucursal, stock_actual)
SELECT v.id_variante, s.id_sucursal,
  CASE
    WHEN v.precio_venta_etiqueta > 2000 THEN 10
    WHEN v.precio_venta_etiqueta > 1000 THEN 15
    ELSE 20
  END
FROM variantes v
CROSS JOIN sucursales s
WHERE s.nombre_lugar = 'Bodega Principal'
ON CONFLICT (id_variante, id_sucursal) DO NOTHING;

-- Historial de ventas
INSERT INTO ventas_bajas (id_variante, id_sucursal, id_motivo, id_usuario, cantidad, precio_venta_final, fecha_hora)
SELECT
  v.id_variante,
  s.id_sucursal,
  1,
  u.id_usuario,
  (floor(random() * 3 + 1))::int,
  v.precio_venta_etiqueta,
  NOW() - (INTERVAL '1 day' * gs.n)
FROM variantes v
CROSS JOIN sucursales s
CROSS JOIN (SELECT generate_series(1, 25) AS n) gs
JOIN usuarios u ON u.rol = 'ADMIN'
WHERE s.activo = TRUE AND random() > 0.6
ORDER BY random()
LIMIT 400;

COMMIT;