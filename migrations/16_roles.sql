-- ============================================================
-- PASO 0: Actualizar constraint y datos existentes
-- Idempotente: funciona tanto si 18_update_roles.sql se corrió
-- como si no se corrió
-- ============================================================
ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS usuarios_rol_check;

UPDATE usuarios SET rol = 'VENDEDOR' WHERE rol = 'GERENTE';

ALTER TABLE usuarios
  ADD CONSTRAINT usuarios_rol_check
  CHECK (rol IN ('ADMIN', 'VENDEDOR', 'AUDITOR'));


-- ============================================================
-- PASO 1: Roles sin LOGIN (grupos de permisos)
-- ============================================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'glamstock_admin') THEN
    CREATE ROLE glamstock_admin;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'glamstock_vendedor') THEN
    CREATE ROLE glamstock_vendedor;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'glamstock_auditor') THEN
    CREATE ROLE glamstock_auditor;
  END IF;
END $$;

COMMENT ON ROLE glamstock_admin    IS 'CRUD completo sobre todos los objetos de GlamStock';
COMMENT ON ROLE glamstock_vendedor IS 'Registro, actualización y reversión de ventas. Lectura de inventario.';
COMMENT ON ROLE glamstock_auditor  IS 'Solo lectura del estado del inventario. Sin acceso a ventas ni usuarios.';


-- ============================================================
-- PASO 2: Jerarquía de herencia
-- ============================================================
GRANT glamstock_auditor  TO glamstock_vendedor;
GRANT glamstock_vendedor TO glamstock_admin;


-- ============================================================
-- PASO 3: Nivel DATABASE
-- ============================================================
GRANT CONNECT ON DATABASE railway TO glamstock_auditor;
GRANT CONNECT ON DATABASE railway TO glamstock_vendedor;
GRANT CONNECT ON DATABASE railway TO glamstock_admin;


-- ============================================================
-- PASO 4: Nivel SCHEMA
-- ============================================================
GRANT USAGE ON SCHEMA public TO glamstock_auditor;
GRANT USAGE ON SCHEMA public TO glamstock_vendedor;
GRANT USAGE ON SCHEMA public TO glamstock_admin;


-- ============================================================
-- PASO 5: Nivel TABLE
-- ============================================================

-- AUDITOR: solo lectura de inventario
GRANT SELECT ON
  productos_maestros,
  variantes,
  sucursales,
  inventario_sucursal,
  motivos_transaccion
TO glamstock_auditor;

-- VENDEDOR: hereda SELECT de auditor + opera ventas
GRANT SELECT, INSERT, DELETE ON ventas_bajas TO glamstock_vendedor;

-- ADMIN: acceso completo
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO glamstock_admin;


-- ============================================================
-- PASO 6: Nivel SECUENCIAS
-- ============================================================
GRANT USAGE ON SEQUENCE ventas_bajas_id_transaccion_seq TO glamstock_vendedor;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public            TO glamstock_admin;


-- ============================================================
-- PASO 7: Nivel FUNCIÓN / PROCEDURE
-- Firmas verificadas contra 07_procedures.sql y 08_functions.sql
-- ============================================================

-- sp_registrar_venta(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, DECIMAL)
GRANT EXECUTE ON PROCEDURE sp_registrar_venta(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, DECIMAL)
  TO glamstock_vendedor;

-- sp_transferir_stock(INTEGER, INTEGER, INTEGER, INTEGER) — 4 parámetros
GRANT EXECUTE ON PROCEDURE sp_transferir_stock(INTEGER, INTEGER, INTEGER, INTEGER)
  TO glamstock_vendedor;

-- fn_margen_porcentaje solo para auditor (lectura de reportes)
GRANT EXECUTE ON FUNCTION fn_margen_porcentaje(DECIMAL, DECIMAL)
  TO glamstock_auditor;

-- fn_variantes_por_sucursal — acceso a auditor y vendedor
GRANT EXECUTE ON FUNCTION fn_variantes_por_sucursal(INTEGER)
  TO glamstock_auditor;

-- sp_ajustar_precios_producto solo ADMIN
GRANT EXECUTE ON PROCEDURE sp_ajustar_precios_producto(INTEGER, DECIMAL)
  TO glamstock_admin;

-- Admin hereda todo lo anterior + acceso completo
GRANT EXECUTE ON ALL FUNCTIONS  IN SCHEMA public TO glamstock_admin;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO glamstock_admin;


-- ============================================================
-- PASO 8: DEFAULT PRIVILEGES — cubre objetos futuros
-- ============================================================
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO glamstock_auditor;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, DELETE ON TABLES TO glamstock_vendedor;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL PRIVILEGES ON TABLES TO glamstock_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE ON SEQUENCES TO glamstock_vendedor;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE ON SEQUENCES TO glamstock_admin;


-- ============================================================
-- PASO 9: Row-Level Security (RLS)
-- La app hace SET LOCAL app.user_id = '<id>' por transacción
-- Nota: aplica cuando la conexión usa SET ROLE glamstock_*
-- El superuser de Railway ignora RLS salvo FORCE
-- ============================================================

-- ventas_bajas: AUDITOR no tiene política → 0 filas visibles
ALTER TABLE ventas_bajas ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas_bajas FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vendedor_ventas ON ventas_bajas;
DROP POLICY IF EXISTS admin_ventas    ON ventas_bajas;

CREATE POLICY vendedor_ventas
  ON ventas_bajas FOR ALL
  TO glamstock_vendedor
  USING (TRUE)
  WITH CHECK (TRUE);

CREATE POLICY admin_ventas
  ON ventas_bajas FOR ALL
  TO glamstock_admin
  USING (TRUE)
  WITH CHECK (TRUE);

-- usuarios: VENDEDOR solo ve su propio registro vía current_setting
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_usuarios             ON usuarios;
DROP POLICY IF EXISTS vendedor_su_propio_registro ON usuarios;

CREATE POLICY admin_usuarios
  ON usuarios FOR ALL
  TO glamstock_admin
  USING (TRUE)
  WITH CHECK (TRUE);

CREATE POLICY vendedor_su_propio_registro
  ON usuarios FOR SELECT
  TO glamstock_vendedor
  USING (
    id_usuario = NULLIF(current_setting('app.user_id', TRUE), '')::INTEGER
  );


-- ============================================================
-- PASO 10: Índice de soporte para política RLS
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_usuarios_id_rls ON usuarios(id_usuario);


-- ============================================================
-- VERIFICACIÓN
-- SELECT rolname FROM pg_roles WHERE rolname LIKE 'glamstock%';
-- SELECT tablename, policyname, cmd, roles, qual
--   FROM pg_policies WHERE schemaname = 'public';
-- SELECT tablename, rowsecurity, forcerowsecurity
--   FROM pg_tables WHERE schemaname = 'public';
-- ============================================================