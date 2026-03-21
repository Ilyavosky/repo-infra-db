BEGIN;

INSERT INTO motivos_transaccion (descripcion) VALUES
('Venta directa al cliente'),
('Baja por merma / dano'),
('Ajuste de inventario (Sobrante)'),
('Ajuste de inventario (Faltante)'),
('Ingreso por adquisicion / compra');

COMMIT;