CREATE SCHEMA gold;
GO

-- ============================================================
-- CAPA GOLD: modelo estrella. Dimensiones aplanadas + hechos.
-- dim_tiempo usa fecha_key = CAST(CONVERT(VARCHAR(8),fecha,112) AS INT)
-- (formato YYYYMMDD), idéntico al proyecto de referencia.
-- ============================================================

-- DIMENSIONES -------------------------------------------------

-- 1. Dimensión Tiempo (generada por SP)
CREATE TABLE gold.dim_tiempo (
    fecha_key INT PRIMARY KEY,            -- YYYYMMDD
    fecha DATE NOT NULL,
    anio SMALLINT,
    mes TINYINT,
    nombre_mes VARCHAR(15),
    trimestre TINYINT,
    dia_semana TINYINT,
    nombre_dia VARCHAR(15)
);

-- 2. Dimensión Producto (APLANADA: producto + proveedor + categoría)
CREATE TABLE gold.dim_producto (
    producto_key INT IDENTITY(1,1) PRIMARY KEY,
    codigo_producto VARCHAR(50),
    nombre_producto VARCHAR(255),
    categoria VARCHAR(100),
    proveedor VARCHAR(100),          -- aplanado desde inventario
    precio_venta_ref DECIMAL(18,2),  -- precio de lista de referencia
    costo_adquisicion DECIMAL(18,2),
    activo BIT
);

-- 3. Dimensión Cliente
CREATE TABLE gold.dim_cliente (
    cliente_key INT IDENTITY(1,1) PRIMARY KEY,
    nombre_cliente VARCHAR(150),
    email_cliente VARCHAR(150),
    ciudad VARCHAR(100)              -- sólo disponible en ventas online
);

-- 4. Dimensión Sucursal / Canal
CREATE TABLE gold.dim_sucursal (
    sucursal_key INT IDENTITY(1,1) PRIMARY KEY,
    nombre_sucursal VARCHAR(50),
    tipo VARCHAR(20)                 -- 'Física' u 'Online'
);

-- 5. Dimensión Vendedor (sólo aplica a ventas en sucursal física)
CREATE TABLE gold.dim_vendedor (
    vendedor_key INT IDENTITY(1,1) PRIMARY KEY,
    nombre_vendedor VARCHAR(100)
);

-- TABLAS DE HECHOS (FACT TABLES) ------------------------------

-- 6. Hechos Ventas (grano: 1 línea de venta)
CREATE TABLE gold.fact_ventas (
    venta_key INT IDENTITY(1,1) PRIMARY KEY,
    fecha_key INT FOREIGN KEY REFERENCES gold.dim_tiempo(fecha_key),
    producto_key INT FOREIGN KEY REFERENCES gold.dim_producto(producto_key),
    cliente_key INT FOREIGN KEY REFERENCES gold.dim_cliente(cliente_key),
    sucursal_key INT FOREIGN KEY REFERENCES gold.dim_sucursal(sucursal_key),
    vendedor_key INT FOREIGN KEY REFERENCES gold.dim_vendedor(vendedor_key), -- NULL en online

    -- Métricas
    cantidad INT,
    precio_unitario DECIMAL(18,2),
    total_venta DECIMAL(18,2),       -- cantidad * precio_unitario
    shipping_cost DECIMAL(18,2),     -- 0 en sucursal física

    -- Atributos degenerados
    id_venta_origen VARCHAR(50),
    metodo_pago VARCHAR(50),
    estado VARCHAR(50),              -- estado del pedido online
    canal VARCHAR(20)
);

-- 7. Hechos Inventario (grano: producto × sucursal, snapshot)
CREATE TABLE gold.fact_inventario (
    inventario_key INT IDENTITY(1,1) PRIMARY KEY,
    producto_key INT FOREIGN KEY REFERENCES gold.dim_producto(producto_key),
    sucursal_key INT FOREIGN KEY REFERENCES gold.dim_sucursal(sucursal_key),
    fecha_reposicion_key INT FOREIGN KEY REFERENCES gold.dim_tiempo(fecha_key),

    -- Métricas
    stock_actual INT,
    stock_minimo INT,
    precio_venta DECIMAL(18,2),
    costo_adquisicion DECIMAL(18,2),
    margen_unitario DECIMAL(18,2)    -- precio_venta - costo_adquisicion
);
