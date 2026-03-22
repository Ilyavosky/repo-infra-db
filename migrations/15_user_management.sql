ALTER TABLE usuarios
    ADD COLUMN IF NOT EXISTS id_sucursal INTEGER REFERENCES sucursales(id_sucursal) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE usuarios
    ADD CONSTRAINT chk_gerente_sucursal
    CHECK (
        (rol = 'GERENTE' AND id_sucursal IS NOT NULL) OR
        (rol = 'ADMIN')
    );

CREATE OR REPLACE TRIGGER usuarios_updated_at
BEFORE UPDATE ON usuarios
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE OR REPLACE VIEW v_usuarios AS
SELECT
    u.id_usuario,
    u.nombre,
    u.email,
    u.rol,
    u.activo,
    u.id_sucursal,
    s.nombre_lugar AS sucursal_nombre,
    u.created_at,
    u.updated_at
FROM usuarios u
LEFT JOIN sucursales s ON s.id_sucursal = u.id_sucursal;
