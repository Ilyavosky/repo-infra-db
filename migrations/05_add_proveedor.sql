ALTER TABLE productos_maestros
  ADD COLUMN IF NOT EXISTS proveedor VARCHAR(150);

CREATE INDEX IF NOT EXISTS idx_productos_proveedor
  ON productos_maestros(proveedor);