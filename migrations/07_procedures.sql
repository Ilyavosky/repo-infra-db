CREATE OR REPLACE PROCEDURE sp_registrar_venta(
  p_id_variante       INTEGER,
  p_id_sucursal       INTEGER,
  p_id_motivo         INTEGER,
  p_id_usuario        INTEGER,
  p_cantidad          INTEGER,
  p_precio_venta_final DECIMAL(12,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_stock             INTEGER;
  v_precio_adquisicion DECIMAL(12,2);
BEGIN
  SELECT inv.stock_actual, v.precio_adquisicion
  INTO v_stock, v_precio_adquisicion
  FROM inventario_sucursal inv
  JOIN variantes v ON v.id_variante = inv.id_variante
  WHERE inv.id_variante = p_id_variante
    AND inv.id_sucursal = p_id_sucursal
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La variante % no existe en la sucursal %', p_id_variante, p_id_sucursal;
  END IF;

  IF v_stock < p_cantidad THEN
    RAISE EXCEPTION 'Stock insuficiente. Disponible: %, Solicitado: %', v_stock, p_cantidad;
  END IF;

  IF p_precio_venta_final < v_precio_adquisicion THEN
    RAISE EXCEPTION 'Precio de venta (%) inferior al precio de adquisicion (%)', p_precio_venta_final, v_precio_adquisicion;
  END IF;

  INSERT INTO ventas_bajas (id_variante, id_sucursal, id_motivo, id_usuario, cantidad, precio_venta_final)
  VALUES (p_id_variante, p_id_sucursal, p_id_motivo, p_id_usuario, p_cantidad, p_precio_venta_final);

  UPDATE inventario_sucursal
  SET stock_actual = stock_actual - p_cantidad
  WHERE id_variante = p_id_variante
    AND id_sucursal = p_id_sucursal;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_transferir_stock(
  p_id_variante    INTEGER,
  p_id_sucursal_origen  INTEGER,
  p_id_sucursal_destino INTEGER,
  p_cantidad       INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_stock_origen INTEGER;
BEGIN
  SELECT stock_actual INTO v_stock_origen
  FROM inventario_sucursal
  WHERE id_variante = p_id_variante
    AND id_sucursal = p_id_sucursal_origen
  FOR UPDATE;

  IF NOT FOUND THEN
    ROLLBACK;
    RAISE EXCEPTION 'La variante % no existe en la sucursal origen %', p_id_variante, p_id_sucursal_origen;
  END IF;

  IF v_stock_origen < p_cantidad THEN
    ROLLBACK;
    RAISE EXCEPTION 'Stock insuficiente en origen. Disponible: %, Solicitado: %', v_stock_origen, p_cantidad;
  END IF;

  UPDATE inventario_sucursal
  SET stock_actual = stock_actual - p_cantidad
  WHERE id_variante = p_id_variante
    AND id_sucursal = p_id_sucursal_origen;

  INSERT INTO inventario_sucursal (id_variante, id_sucursal, stock_actual)
  VALUES (p_id_variante, p_id_sucursal_destino, p_cantidad)
  ON CONFLICT (id_variante, id_sucursal)
  DO UPDATE SET stock_actual = inventario_sucursal.stock_actual + EXCLUDED.stock_actual;

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE EXCEPTION 'Transferencia fallida: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_ajustar_precios_producto(
  p_id_producto    INTEGER,
  p_incremento_pct DECIMAL(5,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
  cur_variantes CURSOR FOR
    SELECT id_variante, precio_adquisicion, precio_venta_etiqueta
    FROM variantes
    WHERE id_producto_maestro = p_id_producto;
  rec            RECORD;
  v_nuevo_precio DECIMAL(12,2);
BEGIN
  IF NOT EXISTS (SELECT 1 FROM productos_maestros WHERE id_producto_maestro = p_id_producto) THEN
    RAISE EXCEPTION 'El producto % no existe', p_id_producto;
  END IF;

  OPEN cur_variantes;
  LOOP
    FETCH cur_variantes INTO rec;
    EXIT WHEN NOT FOUND;

    v_nuevo_precio := ROUND(rec.precio_venta_etiqueta * (1 + p_incremento_pct / 100.0), 2);

    IF v_nuevo_precio >= rec.precio_adquisicion THEN
      UPDATE variantes
      SET precio_venta_etiqueta = v_nuevo_precio
      WHERE id_variante = rec.id_variante;
    END IF;
  END LOOP;
  CLOSE cur_variantes;
END;
$$;
