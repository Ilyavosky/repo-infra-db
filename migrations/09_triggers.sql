CREATE OR REPLACE FUNCTION trg_validar_precio_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_precio_adquisicion DECIMAL(12,2);
  v_precio_etiqueta DECIMAL(12,2);
BEGIN
  SELECT precio_adquisicion, precio_venta_etiqueta
  INTO v_precio_adquisicion, v_precio_etiqueta
  FROM variantes
  WHERE id_variante = NEW.id_variante;

  IF NEW.precio_venta_final < v_precio_adquisicion THEN
    RAISE EXCEPTION 'Precio de venta (%) no puede ser inferior al precio de adquisicion (%) para variante %',
      NEW.precio_venta_final, v_precio_adquisicion, NEW.id_variante;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER ventas_validar_precio
BEFORE INSERT ON ventas_bajas
FOR EACH ROW
EXECUTE FUNCTION trg_validar_precio_venta();
