BEGIN;

INSERT INTO motivos_transaccion (descripcion) VALUES
('Venta directa al cliente'),
('Baja por merma / daño'),
('Ajuste de inventario (Sobrante)'),
('Ajuste de inventario (Faltante)'),
('Ingreso por adquisición / compra')
ON CONFLICT (descripcion) DO NOTHING;

INSERT INTO usuarios (nombre, email, password_hash, rol, activo) VALUES
(
  'Administrador',
  'admin@glamstock.com',
  crypt('Admin1234!', gen_salt('bf')),
  'ADMIN',
  TRUE
)
ON CONFLICT (email) DO NOTHING;

COMMIT;