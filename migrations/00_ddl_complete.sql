CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP TABLE IF EXISTS ventas_bajas CASCADE;
DROP TABLE IF EXISTS inventario_sucursal CASCADE;
DROP TABLE IF EXISTS variantes CASCADE;
DROP TABLE IF EXISTS productos_maestros CASCADE;
DROP TABLE IF EXISTS sucursales CASCADE;
DROP TABLE IF EXISTS motivos_transaccion CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;
DROP FUNCTION IF EXISTS update_timestamp() CASCADE;

CREATE TABLE productos_maestros (
    id_producto_maestro SERIAL          PRIMARY KEY,
    sku                 VARCHAR(50)     NOT NULL UNIQUE,
    nombre              VARCHAR(150)    NOT NULL,
    proveedor           VARCHAR(150),
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sucursales (
    id_sucursal     SERIAL          PRIMARY KEY,
    nombre_lugar    VARCHAR(100)    NOT NULL UNIQUE,
    ubicacion       VARCHAR(255),
    activo          BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE motivos_transaccion (
    id_motivo   SERIAL          PRIMARY KEY,
    descripcion VARCHAR(100)    NOT NULL UNIQUE
);

CREATE TABLE usuarios (
    id_usuario      SERIAL          PRIMARY KEY,
    nombre          VARCHAR(100)    NOT NULL,
    email           VARCHAR(150)    NOT NULL UNIQUE,
    password_hash   VARCHAR(255)    NOT NULL,
    rol             VARCHAR(50)     NOT NULL CHECK (rol IN ('ADMIN', 'GERENTE')),
    activo          BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE variantes (
    id_variante             SERIAL          PRIMARY KEY,
    id_producto_maestro     INTEGER         NOT NULL,
    sku_variante            VARCHAR(100)    NOT NULL UNIQUE,
    codigo_barras           VARCHAR(100)    NOT NULL UNIQUE,
    modelo                  VARCHAR(100),
    color                   VARCHAR(50),
    precio_adquisicion      DECIMAL(12,2)   NOT NULL CHECK (precio_adquisicion >= 0),
    precio_venta_etiqueta   DECIMAL(12,2)   NOT NULL CHECK (precio_venta_etiqueta >= 0),
    etiqueta_generada       BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT variantes_precio_check
        CHECK (precio_venta_etiqueta >= precio_adquisicion),
    CONSTRAINT variantes_id_producto_maestro_fkey
        FOREIGN KEY (id_producto_maestro)
        REFERENCES productos_maestros (id_producto_maestro)
        ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE TABLE inventario_sucursal (
    id_inventario   SERIAL      PRIMARY KEY,
    id_variante     INTEGER     NOT NULL,
    id_sucursal     INTEGER     NOT NULL,
    stock_actual    INTEGER     NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
    updated_at      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT inventario_sucursal_unique
        UNIQUE (id_variante, id_sucursal),
    CONSTRAINT inventario_sucursal_id_variante_fkey
        FOREIGN KEY (id_variante)
        REFERENCES variantes (id_variante)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT inventario_sucursal_id_sucursal_fkey
        FOREIGN KEY (id_sucursal)
        REFERENCES sucursales (id_sucursal)
        ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE TABLE ventas_bajas (
    id_transaccion      SERIAL          PRIMARY KEY,
    id_variante         INTEGER         NOT NULL,
    id_sucursal         INTEGER         NOT NULL,
    id_motivo           INTEGER         NOT NULL,
    id_usuario          INTEGER         NOT NULL,
    cantidad            INTEGER         NOT NULL CHECK (cantidad > 0),
    precio_venta_final  DECIMAL(12,2)   NOT NULL CHECK (precio_venta_final >= 0),
    fecha_hora          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ventas_bajas_id_variante_fkey
        FOREIGN KEY (id_variante)
        REFERENCES variantes (id_variante)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ventas_bajas_id_sucursal_fkey
        FOREIGN KEY (id_sucursal)
        REFERENCES sucursales (id_sucursal)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ventas_bajas_id_motivo_fkey
        FOREIGN KEY (id_motivo)
        REFERENCES motivos_transaccion (id_motivo)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ventas_bajas_id_usuario_fkey
        FOREIGN KEY (id_usuario)
        REFERENCES usuarios (id_usuario)
        ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER productos_maestros_updated_at
    BEFORE UPDATE ON productos_maestros
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER sucursales_updated_at
    BEFORE UPDATE ON sucursales
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER usuarios_updated_at
    BEFORE UPDATE ON usuarios
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER variantes_updated_at
    BEFORE UPDATE ON variantes
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER inventario_sucursal_updated_at
    BEFORE UPDATE ON inventario_sucursal
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER ventas_bajas_updated_at
    BEFORE UPDATE ON ventas_bajas
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();
