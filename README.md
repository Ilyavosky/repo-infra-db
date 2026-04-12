# 🗄️ GlamStock · repo-infra-db

> **Infraestructura de Base de Datos** — Repositorio de configuración, esquema y migraciones PostgreSQL para el ecosistema GlamStock.

---

## Tabla de Contenidos

1. [Descripción General](#descripción-general)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Requisitos Previos](#requisitos-previos)
4. [Estructura del Repositorio](#estructura-del-repositorio)
5. [Esquema de la Base de Datos](#esquema-de-la-base-de-datos)
6. [Vistas y Objetos Avanzados](#vistas-y-objetos-avanzados)
7. [Configuración de Variables de Entorno](#configuración-de-variables-de-entorno)
8. [Inicialización y Despliegue](#inicialización-y-despliegue)
9. [Historial de Migraciones](#historial-de-migraciones)
10. [Mantenimiento](#mantenimiento)
11. [Relación con otros Repositorios](#relación-con-otros-repositorios)

---

## Descripción General

`repo-infra-db` es el repositorio de infraestructura de datos del sistema **GlamStock**, un sistema de gestión de inventario orientado a tiendas de moda multi-sucursal. Este repositorio centraliza:

- La **definición del esquema relacional** PostgreSQL 16.
- El conjunto completo de **migraciones incrementales** del DDL.
- **Vistas materializadas** para análisis de ventas y rankings de productos.
- **Procedimientos almacenados (stored procedures)** con lógica ACID transaccional.
- **Funciones y triggers** para auditoría automática de timestamps.
- La configuración de **Docker Compose** para levantar el servidor de base de datos en desarrollo local.

La base de datos se expone en el puerto `5433` del host (mapeado al `5432` interno del contenedor), para evitar conflictos con instalaciones locales de PostgreSQL.

---

## Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────┐
│                    GlamStock SOA                        │
│                                                         │
│  ┌────────────────┐      ┌────────────────────────┐     │
│  │ repo-web-client│ ───► │   repo-api-service     │     │
│  │  (Next.js 16)  │      │  (Express + TypeScript)│     │
│  └────────────────┘      └──────────┬─────────────┘     │
│                                     │ pg (port 5433)    │
│                          ┌──────────▼─────────────┐     │
│                          │    repo-infra-db       │     │
│                          │  (PostgreSQL 16 Docker)│     │
│                          └────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

---

## Requisitos Previos

| Herramienta    | Versión mínima | Notas                        |
| -------------- | -------------- | ---------------------------- |
| Docker Desktop | 24.x           | Incluye Docker Compose v2    |
| Docker Compose | v2.x           | `docker compose` (sin guión) |

> **No se necesita PostgreSQL instalado localmente.** La base de datos corre completamente dentro de Docker.

---

## Estructura del Repositorio

```
repo-infra-db/
├── .env                        # Variables de entorno locales (NO commitear)
├── .env.example                # Plantilla de variables de entorno (sí commitear)
├── .gitignore
├── docker-compose.yml          # Configuración del servicio postgres
└── migrations/
    ├── 00_db_objects.sql       # Referencia DDL consolidada (solo lectura, no ejecutar)
    ├── 00_ddl_complete.sql     # DDL completo alternativo (solo lectura, no ejecutar)
    ├── 01_schema.sql           # ★ Esquema base (tablas principales)
    ├── 02_index.sql            # Índices de rendimiento
    ├── 03_seed.sql             # Datos semilla iniciales
    ├── 04_views.sql            # Vistas y vistas materializadas
    ├── 05_add_proveedor.sql    # Migración: campo proveedor
    ├── 06_schema_updates.sql   # Actualizaciones de esquema
    ├── 07_procedures.sql       # Stored procedures (lógica ACID)
    ├── 08_functions.sql        # Funciones de base de datos
    ├── 09_triggers.sql         # Triggers de auditoría
    ├── 10_hypothesis_view.sql  # Vista para análisis estadístico
    ├── 11_analysis_queries.sql # Consultas de análisis avanzado
    ├── 12_drop_seed.sql        # Limpieza de datos semilla
    ├── 13_reseed_motivos.sql   # Re-siembra de motivos de transacción
    ├── 14_add_fecha_compra.sql # Migración: fecha de compra
    ├── 15_add_totp_fields.sql  # Migración: campos 2FA (TOTP)
    ├── 16_roles.sql            # Sistema de roles y permisos
    ├── 17_add_reset_token.sql  # Migración: token de recuperación
    └── 18_postman_rollback.sql # Rollback de pruebas Postman
```

> **Nota:** Las migraciones `01` a `05` se ejecutan **automáticamente** al crear el volumen por primera vez — están montadas en `/docker-entrypoint-initdb.d/` dentro del `docker-compose.yml` (`01_schema.sql`, `02_index.sql`, `03_seed.sql`, `04_views.sql`, `05_add_proveedor.sql`). Las migraciones `06` en adelante deben aplicarse **manualmente** usando los comandos de la sección [Aplicar migraciones posteriores al arranque](#aplicar-migraciones-posteriores-al-arranque).

---

## Esquema de la Base de Datos

### Diagrama Entidad-Relación

```
productos_maestros
  ├── id_producto_maestro (PK)
  ├── sku (UNIQUE)
  ├── nombre
  ├── proveedor
  └── created_at
        │ 1:N
        ▼
    variantes
      ├── id_variante (PK)
      ├── id_producto_maestro (FK)
      ├── sku_variante (UNIQUE)
      ├── codigo_barras (UNIQUE)
      ├── modelo
      ├── color
      ├── precio_adquisicion
      ├── precio_venta_etiqueta
      ├── etiqueta_generada
      ├── fecha_compra
      └── created_at
            │ 1:N                        │ 1:N
            ▼                            ▼
  inventario_sucursal           ventas_bajas
    ├── id_inventario (PK)         ├── id_transaccion (PK)
    ├── id_variante (FK)           ├── id_variante (FK)
    ├── id_sucursal (FK)           ├── id_sucursal (FK)
    ├── stock_actual               ├── id_motivo (FK)
    └── updated_at                 ├── id_usuario (FK)
           │                       ├── cantidad
           │                       ├── precio_venta_final
    sucursales                     └── fecha_hora
      ├── id_sucursal (PK)
      ├── nombre_lugar (UNIQUE)
      ├── ubicacion
      ├── activo
      └── created_at

usuarios                       motivos_transaccion
  ├── id_usuario (PK)            ├── id_motivo (PK)
  ├── nombre                     └── descripcion (UNIQUE)
  ├── email (UNIQUE)
  ├── password_hash
  ├── rol (ADMIN | GERENTE | VENDEDOR)
  ├── totp_secret
  ├── totp_enabled
  ├── reset_token
  ├── reset_token_expiry
  ├── activo
  └── created_at
```

### Descripción de Tablas

| Tabla                 | Propósito                                                                                           |
| --------------------- | --------------------------------------------------------------------------------------------------- |
| `productos_maestros`  | Catálogo maestro de productos (nivel marca/línea)                                                   |
| `variantes`           | Versiones específicas de productos (modelo + color + talla). Incluye precios de adquisición y venta |
| `sucursales`          | Puntos de venta / almacenes físicos del negocio                                                     |
| `inventario_sucursal` | Stock actual de cada variante en cada sucursal (relación N:M)                                       |
| `ventas_bajas`        | Registro inmutable de todas las transacciones de venta                                              |
| `motivos_transaccion` | Catálogo de razones de movimiento (Venta, Devolución, Ajuste, etc.)                                 |
| `usuarios`            | Cuentas de acceso al sistema con roles y soporte 2FA                                                |

### Restricciones de Integridad Clave

- `precio_venta_etiqueta >= precio_adquisicion` — Nunca vender por debajo del costo.
- `stock_actual >= 0` — El inventario no puede ser negativo.
- `cantidad > 0` en ventas — Las transacciones siempre son positivas.
- Roles de usuario: `ADMIN`, `GERENTE` o `VENDEDOR`.

---

## Vistas y Objetos Avanzados

### Vistas

| Vista                                  | Tipo                | Descripción                                                                        |
| -------------------------------------- | ------------------- | ---------------------------------------------------------------------------------- |
| `vista_ventas_detallada`               | Vista simple        | Ventas enriquecidas con datos de producto, variante, sucursal y utilidad calculada |
| `vista_resumen_ventas_por_sucursal`    | Vista simple        | KPIs de ventas agregados por sucursal (ingresos, costos, utilidad neta)            |
| `vista_ranking_productos_global`       | Vista materializada | Ranking global de variantes por unidades vendidas e ingresos                       |
| `vista_ranking_productos_por_sucursal` | Vista materializada | Ranking de variantes particionado por sucursal                                     |

> Las **vistas materializadas** requieren `REFRESH MATERIALIZED VIEW` después de actualizaciones masivas de datos.

### Stored Procedures

| Procedimiento                      | Descripción                                                                                                                      |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `sp_registrar_venta(...)`          | Registra una venta atómica: valida stock, verifica precio, descuenta inventario e inserta transacción en una sola operación ACID |
| `sp_transferir_stock(...)`         | Transfiere unidades entre sucursales de forma transaccional con bloqueo de filas (`FOR UPDATE`)                                  |
| `sp_ajustar_precios_producto(...)` | Aplica un incremento porcentual a todas las variantes de un producto usando cursores                                             |

### Triggers

| Trigger                 | Tabla                 | Descripción                                                          |
| ----------------------- | --------------------- | -------------------------------------------------------------------- |
| `inventario_updated_at` | `inventario_sucursal` | Actualiza `updated_at` automáticamente en cada modificación de stock |

---

## Configuración de Variables de Entorno

Copia `.env.example` a `.env` y ajusta los valores con tus credenciales reales:

```bash
cp .env.example .env
```

```env
# Credenciales del servidor PostgreSQL (usadas por Docker)
POSTGRES_USER=glamstock_user
POSTGRES_PASSWORD=cambia_esto_por_tu_password
POSTGRES_DB=glamstock_db

# Credenciales del usuario administrador inicial (usadas por el seed de la DB)
ADMIN_EMAIL=admin@tudominio.com
ADMIN_PASSWORD=cambia_esto_por_un_password_seguro
```

> ⚠️ **Nunca commitear el archivo `.env` real al repositorio.** El archivo `.env.example` ya está incluido como plantilla segura.

---

## Inicialización y Despliegue

### Primera vez (construcción desde cero)

```bash
# 1. Clonar el repositorio
git clone <URL_DEL_REPOSITORIO> repo-infra-db
cd repo-infra-db

# 2. Crear el archivo de variables de entorno a partir de la plantilla
cp .env.example .env
# Editar .env con tus credenciales reales (ver sección anterior)

# 3. Levantar el contenedor
docker compose up -d

# 4. Verificar que el contenedor está corriendo
docker ps | grep glamstock_db

# 5. Verificar conectividad
docker exec -it glamstock_db psql -U glamstock_user -d glamstock_db -c "\dt"
```

### Aplicar migraciones posteriores al arranque

Las migraciones `06` en adelante deben aplicarse manualmente una vez que el contenedor esté activo:

```bash
# Ejemplo: aplicar migración de roles
docker exec -i glamstock_db psql -U glamstock_user -d glamstock_db \
  < migrations/16_roles.sql

# Aplicar todas las migraciones adicionales en orden (06 en adelante)
for i in 06 07 08 09 10 11 12 13 14 15 16 17 18; do
  file=$(ls migrations/${i}_*.sql 2>/dev/null | head -n1)
  if [ -n "$file" ]; then
    echo "Aplicando $file..."
    docker exec -i glamstock_db psql -U glamstock_user -d glamstock_db < "$file"
  fi
done
```

### Detener y reiniciar

```bash
# Detener sin borrar datos
docker compose down

# Reiniciar (los datos persisten en el volumen postgres_data)
docker compose up -d

# Destruir TODO (incluyendo datos) y empezar de cero
docker compose down -v
docker compose up -d
```

### Conexión directa a la base de datos

```bash
# Desde terminal (requiere psql local)
psql -h localhost -p 5433 -U glamstock_user -d glamstock_db

# Desde dentro del contenedor
docker exec -it glamstock_db psql -U glamstock_user -d glamstock_db
```

**String de conexión para herramientas externas (DBeaver, TablePlus, etc.):**

```
Host:     localhost
Port:     5433
Database: glamstock_db
User:     glamstock_user
Password: <valor de POSTGRES_PASSWORD en tu .env>
```

---

## Historial de Migraciones

| #   | Archivo                   | Descripción                                                                                   |
| --- | ------------------------- | --------------------------------------------------------------------------------------------- |
| 01  | `01_schema.sql`           | Creación de tablas base con constraints e integridad referencial                              |
| 02  | `02_index.sql`            | Índices de rendimiento para consultas frecuentes                                              |
| 03  | `03_seed.sql`             | Datos semilla iniciales (sucursales, motivos, usuario admin)                                  |
| 04  | `04_views.sql`            | Vistas simples y materializadas para dashboard                                                |
| 05  | `05_add_proveedor.sql`    | Agrega columna `proveedor` a `productos_maestros`                                             |
| 06  | `06_schema_updates.sql`   | Ajustes varios al esquema base                                                                |
| 07  | `07_procedures.sql`       | Stored procedures: `sp_registrar_venta`, `sp_transferir_stock`, `sp_ajustar_precios_producto` |
| 08  | `08_functions.sql`        | Funciones auxiliares de base de datos                                                         |
| 09  | `09_triggers.sql`         | Triggers de auditoría de timestamps                                                           |
| 10  | `10_hypothesis_view.sql`  | Vista estadística para prueba de hipótesis académica                                          |
| 11  | `11_analysis_queries.sql` | Consultas analíticas avanzadas                                                                |
| 12  | `12_drop_seed.sql`        | Eliminación de datos de prueba                                                                |
| 13  | `13_reseed_motivos.sql`   | Re-población de catálogo de motivos de transacción                                            |
| 14  | `14_add_fecha_compra.sql` | Agrega `fecha_compra` a `variantes`                                                           |
| 15  | `15_add_totp_fields.sql`  | Agrega campos `totp_secret` y `totp_enabled` a `usuarios` (2FA)                               |
| 16  | `16_roles.sql`            | Sistema completo de roles de base de datos y permisos granulares                              |
| 17  | `17_add_reset_token.sql`  | Agrega `reset_token` y `reset_token_expiry` a `usuarios`                                      |
| 18  | `18_postman_rollback.sql` | ⚠️ Script de rollback para pruebas de integración con Postman. **Solo para entornos de desarrollo.** No ejecutar en producción. |

---

## Mantenimiento

### Refrescar vistas materializadas

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY vista_ranking_productos_global;
REFRESH MATERIALIZED VIEW CONCURRENTLY vista_ranking_productos_por_sucursal;
```

### Backup manual

```bash
docker exec glamstock_db pg_dump -U glamstock_user glamstock_db > backup_$(date +%Y%m%d).sql
```

### Restore de backup

```bash
docker exec -i glamstock_db psql -U glamstock_user -d glamstock_db < backup_20260101.sql
```

---

## Relación con otros Repositorios

| Repositorio                                | Relación                                                                                                   |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| [`repo-api-service`](../repo-api-service/) | El API se conecta a esta base de datos usando el driver `pg` vía `DATABASE_URL` apuntando al puerto `5433` |
| [`repo-web-client`](../repo-web-client/)   | El cliente web no se conecta directamente; consume datos a través del API Service                          |
