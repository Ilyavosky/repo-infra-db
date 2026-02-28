-- Índices para optimización de JOINs y búsquedas frecuentes por campos
CREATE INDEX idx_variantes_producto ON variantes(id_producto_maestro);
CREATE INDEX idx_inventario_variante ON inventario_sucursal(id_variante);
CREATE INDEX idx_inventario_sucursal ON inventario_sucursal(id_sucursal);
CREATE INDEX idx_ventas_variante ON ventas_bajas(id_variante);
CREATE INDEX idx_ventas_sucursal ON ventas_bajas(id_sucursal);
CREATE INDEX idx_ventas_usuario ON ventas_bajas(id_usuario);
CREATE INDEX idx_ventas_motivo ON ventas_bajas(id_motivo);

-- Índices para búsquedas frecuentes y filtros
CREATE INDEX idx_ventas_fecha ON ventas_bajas(fecha_hora DESC);
CREATE INDEX idx_sucursales_activo ON sucursales(activo) WHERE activo = TRUE;
CREATE INDEX idx_usuarios_activo ON usuarios(activo) WHERE activo = TRUE;

-- Índice compuesto para reportes de ventas por fecha y sucursal
CREATE INDEX idx_ventas_fecha_sucursal ON ventas_bajas(fecha_hora DESC, id_sucursal);
