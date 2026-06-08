CREATE SCHEMA silver;
GO

-- ============================================================
-- CAPA SILVER: una tabla por cada fuente Bronze, tipada y limpia.
-- Las 3 fuentes de ventas comparten el MISMO esquema armonizado
-- para que Gold consolide con un simple UNION ALL.
-- (id_venta es VARCHAR porque las claves son alfanuméricas:
--  'LPZ-00033', 'SCZ-00230', 'ONL-00233' — no enteros como el ejemplo.)
-- ============================================================

-- 1. Ventas La Paz (limpia)
CREATE TABLE silver.ventas_lpz (
    id_venta VARCHAR(50) PRIMARY KEY,
    fecha DATE,
    producto VARCHAR(255),
    cantidad INT,
    precio_unitario DECIMAL(18,2),
    sucursal VARCHAR(50),
    vendedor VARCHAR(100),
    cliente_nombre VARCHAR(150),
    cliente_email VARCHAR(150),
    cliente_ciudad VARCHAR(100),
    metodo_pago VARCHAR(50),
    estado VARCHAR(50),
    shipping_cost DECIMAL(18,2),
    canal VARCHAR(20)
);

-- 2. Ventas Santa Cruz (limpia)
CREATE TABLE silver.ventas_scz (
    id_venta VARCHAR(50) PRIMARY KEY,
    fecha DATE,
    producto VARCHAR(255),
    cantidad INT,
    precio_unitario DECIMAL(18,2),
    sucursal VARCHAR(50),
    vendedor VARCHAR(100),
    cliente_nombre VARCHAR(150),
    cliente_email VARCHAR(150),
    cliente_ciudad VARCHAR(100),
    metodo_pago VARCHAR(50),
    estado VARCHAR(50),
    shipping_cost DECIMAL(18,2),
    canal VARCHAR(20)
);

-- 3. Ventas Online (limpia)
CREATE TABLE silver.ventas_online (
    id_venta VARCHAR(50) PRIMARY KEY,
    fecha DATE,
    producto VARCHAR(255),
    cantidad INT,
    precio_unitario DECIMAL(18,2),
    sucursal VARCHAR(50),
    vendedor VARCHAR(100),
    cliente_nombre VARCHAR(150),
    cliente_email VARCHAR(150),
    cliente_ciudad VARCHAR(100),
    metodo_pago VARCHAR(50),
    estado VARCHAR(50),
    shipping_cost DECIMAL(18,2),
    canal VARCHAR(20)
);

-- 4. Inventario (limpio) -- catálogo de productos + stock
CREATE TABLE silver.inventario (
    codigo_producto VARCHAR(50),
    nombre_producto VARCHAR(255),
    categoria VARCHAR(100),
    precio_venta DECIMAL(18,2),
    costo_adquisicion DECIMAL(18,2),
    stock_actual INT,
    stock_minimo INT,
    sucursal VARCHAR(50),
    proveedor VARCHAR(100),
    ultima_reposicion DATE,
    activo BIT
);
