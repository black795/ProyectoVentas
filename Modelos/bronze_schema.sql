CREATE SCHEMA bronze;
GO

-- ============================================================
-- CAPA BRONZE: Ingesta cruda. TODAS las columnas VARCHAR(MAX).
-- Una tabla _raw por cada fuente. Sin casteo ni limpieza.
-- ============================================================

-- 1. Ventas Sucursal La Paz (CSV)
CREATE TABLE bronze.ventas_lpz_raw (
    id_venta VARCHAR(MAX),
    fecha_venta VARCHAR(MAX),
    producto VARCHAR(MAX),
    cant VARCHAR(MAX),
    preciounit VARCHAR(MAX),
    sucursal VARCHAR(MAX),
    vendedor VARCHAR(MAX),
    nombre_cliente VARCHAR(MAX),
    email_cliente VARCHAR(MAX),
    metodopago VARCHAR(MAX)
);

-- 2. Ventas Sucursal Santa Cruz (CSV)
CREATE TABLE bronze.ventas_scz_raw (
    id_venta VARCHAR(MAX),
    fecha VARCHAR(MAX),
    producto VARCHAR(MAX),
    cantidad VARCHAR(MAX),
    precio_unitario VARCHAR(MAX),
    sucursal VARCHAR(MAX),
    vendedor VARCHAR(MAX),
    cliente_nombre VARCHAR(MAX),
    cliente_email VARCHAR(MAX),
    metodo_pago VARCHAR(MAX)
);

-- 3. Ventas Online (JSON, customer aplanado en la ingesta)
CREATE TABLE bronze.ventas_online_raw (
    order_id VARCHAR(MAX),
    timestamp VARCHAR(MAX),
    product VARCHAR(MAX),
    qty VARCHAR(MAX),
    unit_price VARCHAR(MAX),
    customer_name VARCHAR(MAX),
    customer_email VARCHAR(MAX),
    customer_city VARCHAR(MAX),
    payment_method VARCHAR(MAX),
    status VARCHAR(MAX),
    shipping_cost VARCHAR(MAX),
    channel VARCHAR(MAX)
);

-- 4. Inventario (Excel) -- CATÁLOGO de productos + snapshot de stock
CREATE TABLE bronze.inventario_raw (
    codigo_producto VARCHAR(MAX),
    nombre_producto VARCHAR(MAX),
    categoria VARCHAR(MAX),
    precio_venta VARCHAR(MAX),
    costo_adquisicion VARCHAR(MAX),
    stock_actual VARCHAR(MAX),
    stock_minimo VARCHAR(MAX),
    sucursal VARCHAR(MAX),
    proveedor VARCHAR(MAX),
    ultima_reposicion VARCHAR(MAX),
    activo VARCHAR(MAX)
);
