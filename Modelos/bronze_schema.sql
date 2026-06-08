CREATE SCHEMA bronze;
GO

-- 1. Ventas Online (Desde JSON)
CREATE TABLE bronze.ventas_online_raw (
    order_id VARCHAR(MAX),
    timestamp VARCHAR(MAX),
    product VARCHAR(MAX),
    qty INT,
    unit_price FLOAT,
    customer_name VARCHAR(MAX),
    customer_email VARCHAR(MAX),
    customer_city VARCHAR(MAX),
    payment_method VARCHAR(MAX),
    status VARCHAR(MAX),
    shipping_cost FLOAT,
    channel VARCHAR(MAX),
    ingestion_date DATETIME DEFAULT GETDATE()
);

-- 2. Ventas Sucursal Santa Cruz (Desde CSV)
CREATE TABLE bronze.ventas_scz_raw (
    id_venta VARCHAR(MAX),
    fecha VARCHAR(MAX),
    producto VARCHAR(MAX),
    cantidad FLOAT,
    precio_unitario VARCHAR(MAX),
    sucursal VARCHAR(MAX),
    vendedor VARCHAR(MAX),
    cliente_nombre VARCHAR(MAX),
    cliente_email VARCHAR(MAX),
    metodo_pago VARCHAR(MAX),
    ingestion_date DATETIME DEFAULT GETDATE()
);

-- 3. Ventas Sucursal La Paz (Desde CSV)
CREATE TABLE bronze.ventas_lpz_raw (
    id_venta VARCHAR(MAX),
    fecha_venta VARCHAR(MAX),
    producto VARCHAR(MAX),
    cant FLOAT,
    preciounit VARCHAR(MAX),
    sucursal VARCHAR(MAX),
    vendedor VARCHAR(MAX),
    nombre_cliente VARCHAR(MAX),
    email_cliente VARCHAR(MAX),
    metodopago VARCHAR(MAX),
    ingestion_date DATETIME DEFAULT GETDATE()
);

-- 4. Inventario (Desde Excel)
CREATE TABLE bronze.inventario_raw (
    codigo_producto VARCHAR(MAX),
    nombre_producto VARCHAR(MAX),
    categoria VARCHAR(MAX),
    precio_venta FLOAT,
    costo_adquisicion FLOAT,
    stock_actual INT,
    stock_minimo INT,
    sucursal VARCHAR(MAX),
    proveedor VARCHAR(MAX),
    ultima_reposicion VARCHAR(MAX),
    activo VARCHAR(MAX),
    ingestion_date DATETIME DEFAULT GETDATE()
);
