ALTER TABLE productos_maestros ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE variantes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE sucursales ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE ventas_bajas ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

CREATE OR REPLACE TRIGGER productos_maestros_updated_at
BEFORE UPDATE ON productos_maestros
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE OR REPLACE TRIGGER variantes_updated_at
BEFORE UPDATE ON variantes
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE OR REPLACE TRIGGER sucursales_updated_at
BEFORE UPDATE ON sucursales
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE OR REPLACE TRIGGER usuarios_updated_at
BEFORE UPDATE ON usuarios
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE OR REPLACE TRIGGER ventas_bajas_updated_at
BEFORE UPDATE ON ventas_bajas
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

ALTER TABLE variantes
  DROP CONSTRAINT IF EXISTS variantes_id_producto_maestro_fkey,
  ADD CONSTRAINT variantes_id_producto_maestro_fkey
    FOREIGN KEY (id_producto_maestro) REFERENCES productos_maestros(id_producto_maestro)
    ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE inventario_sucursal
  DROP CONSTRAINT IF EXISTS inventario_sucursal_id_variante_fkey,
  ADD CONSTRAINT inventario_sucursal_id_variante_fkey
    FOREIGN KEY (id_variante) REFERENCES variantes(id_variante)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  DROP CONSTRAINT IF EXISTS inventario_sucursal_id_sucursal_fkey,
  ADD CONSTRAINT inventario_sucursal_id_sucursal_fkey
    FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal)
    ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE ventas_bajas
  DROP CONSTRAINT IF EXISTS ventas_bajas_id_variante_fkey,
  ADD CONSTRAINT ventas_bajas_id_variante_fkey
    FOREIGN KEY (id_variante) REFERENCES variantes(id_variante)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  DROP CONSTRAINT IF EXISTS ventas_bajas_id_sucursal_fkey,
  ADD CONSTRAINT ventas_bajas_id_sucursal_fkey
    FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  DROP CONSTRAINT IF EXISTS ventas_bajas_id_motivo_fkey,
  ADD CONSTRAINT ventas_bajas_id_motivo_fkey
    FOREIGN KEY (id_motivo) REFERENCES motivos_transaccion(id_motivo)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  DROP CONSTRAINT IF EXISTS ventas_bajas_id_usuario_fkey,
  ADD CONSTRAINT ventas_bajas_id_usuario_fkey
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
    ON DELETE RESTRICT ON UPDATE RESTRICT;
