CREATE SCHEMA gold;
GO

-- 1. Dimensión Tiempo
CREATE TABLE gold.dim_tiempo (
    id_tiempo INT PRIMARY KEY IDENTITY(1,1),
    fecha DATE UNIQUE,
    anio INT,
    mes INT,
    dia INT,
    nombre_mes VARCHAR(20),
    trimestre INT
);

-- 2. Dimensión Cliente
CREATE TABLE gold.dim_cliente (
    id_cliente INT PRIMARY KEY IDENTITY(1,1),
    nombre VARCHAR(100),
    email VARCHAR(150) UNIQUE
);

-- 3. Dimensión Producto
CREATE TABLE gold.dim_producto (
    id_producto INT PRIMARY KEY IDENTITY(1,1),
    codigo VARCHAR(50) UNIQUE,
    nombre VARCHAR(255),
    categoria VARCHAR(100)
);

-- 4. Dimensión Sucursal
CREATE TABLE gold.dim_sucursal (
    id_sucursal INT PRIMARY KEY IDENTITY(1,1),
    nombre VARCHAR(50) UNIQUE,
    tipo VARCHAR(20) -- Fí­sica u Online
);

-- 5. Hechos Ventas
CREATE TABLE gold.fact_ventas (
    id_fact INT PRIMARY KEY IDENTITY(1,1),
    id_venta_origen VARCHAR(50),
    id_tiempo INT FOREIGN KEY REFERENCES gold.dim_tiempo(id_tiempo),
    id_cliente INT FOREIGN KEY REFERENCES gold.dim_cliente(id_cliente),
    id_producto INT FOREIGN KEY REFERENCES gold.dim_producto(id_producto),
    id_sucursal INT FOREIGN KEY REFERENCES gold.dim_sucursal(id_sucursal),
    cantidad INT,
    precio_unitario DECIMAL(18,2),
    total_venta DECIMAL(18,2),
    metodo_pago VARCHAR(50),
    canal_venta VARCHAR(20)
);
