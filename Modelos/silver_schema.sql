CREATE SCHEMA silver;
GO

-- 1. Ventas Consolidadas y Limpias
CREATE TABLE silver.ventas_clean (
    id_venta VARCHAR(50),
    fecha DATE,
    producto_nombre VARCHAR(255),
    cantidad INT,
    precio_unitario DECIMAL(18,2),
    total_venta DECIMAL(18,2),
    sucursal VARCHAR(50),
    vendedor_nombre VARCHAR(100),
    cliente_nombre VARCHAR(100),
    cliente_email VARCHAR(150),
    metodo_pago VARCHAR(50),
    canal_venta VARCHAR(20), -- 'Online', 'SCZ', 'LPZ'
    processed_date DATETIME DEFAULT GETDATE()
);

-- 2. Inventario Limpio
CREATE TABLE silver.inventario_clean (
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
    activo BIT,
    processed_date DATETIME DEFAULT GETDATE()
);
