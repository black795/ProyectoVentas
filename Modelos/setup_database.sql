-- ============================================================================
-- ProyectoVentas - SCRIPT DE INSTALACIÓN COMPLETO (dw_ventas)
-- Ejecuta TODO en orden: esquemas + tablas Bronze/Silver/Gold + procedimientos.
-- Idempotente: se puede volver a ejecutar sin errores de "ya existe".
--
-- Recomendado: Azure Data Studio o SSMS (manejan 'GO' correctamente).
-- En el Editor de consultas del Portal, ejecútalo completo de una vez.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. ESQUEMAS
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze') EXEC('CREATE SCHEMA bronze');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver') EXEC('CREATE SCHEMA silver');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')   EXEC('CREATE SCHEMA gold');
GO

-- ----------------------------------------------------------------------------
-- 0.1 LIMPIEZA (drop en orden de dependencias para re-ejecución)
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS gold.sp_gold_fact_inventario;
DROP PROCEDURE IF EXISTS gold.sp_gold_fact_ventas;
DROP PROCEDURE IF EXISTS gold.sp_gold_dim_vendedor;
DROP PROCEDURE IF EXISTS gold.sp_gold_dim_sucursal;
DROP PROCEDURE IF EXISTS gold.sp_gold_dim_cliente;
DROP PROCEDURE IF EXISTS gold.sp_gold_dim_producto;
DROP PROCEDURE IF EXISTS silver.sp_bronze_to_silver;
DROP PROCEDURE IF EXISTS gold.sp_generate_dim_tiempo;

DROP TABLE IF EXISTS gold.fact_inventario;
DROP TABLE IF EXISTS gold.fact_ventas;
DROP TABLE IF EXISTS gold.dim_vendedor;
DROP TABLE IF EXISTS gold.dim_sucursal;
DROP TABLE IF EXISTS gold.dim_cliente;
DROP TABLE IF EXISTS gold.dim_producto;
DROP TABLE IF EXISTS gold.dim_tiempo;

DROP TABLE IF EXISTS silver.ventas_lpz;
DROP TABLE IF EXISTS silver.ventas_scz;
DROP TABLE IF EXISTS silver.ventas_online;
DROP TABLE IF EXISTS silver.inventario;

DROP TABLE IF EXISTS bronze.ventas_lpz_raw;
DROP TABLE IF EXISTS bronze.ventas_scz_raw;
DROP TABLE IF EXISTS bronze.ventas_online_raw;
DROP TABLE IF EXISTS bronze.inventario_raw;
GO

-- ============================================================================
-- 1. CAPA BRONZE  (todo VARCHAR(MAX), copia fiel de la fuente)
-- ============================================================================
CREATE TABLE bronze.ventas_lpz_raw (
    id_venta VARCHAR(MAX), fecha_venta VARCHAR(MAX), producto VARCHAR(MAX),
    cant VARCHAR(MAX), preciounit VARCHAR(MAX), sucursal VARCHAR(MAX),
    vendedor VARCHAR(MAX), nombre_cliente VARCHAR(MAX), email_cliente VARCHAR(MAX),
    metodopago VARCHAR(MAX)
);

CREATE TABLE bronze.ventas_scz_raw (
    id_venta VARCHAR(MAX), fecha VARCHAR(MAX), producto VARCHAR(MAX),
    cantidad VARCHAR(MAX), precio_unitario VARCHAR(MAX), sucursal VARCHAR(MAX),
    vendedor VARCHAR(MAX), cliente_nombre VARCHAR(MAX), cliente_email VARCHAR(MAX),
    metodo_pago VARCHAR(MAX)
);

CREATE TABLE bronze.ventas_online_raw (
    order_id VARCHAR(MAX), timestamp VARCHAR(MAX), product VARCHAR(MAX),
    qty VARCHAR(MAX), unit_price VARCHAR(MAX), customer_name VARCHAR(MAX),
    customer_email VARCHAR(MAX), customer_city VARCHAR(MAX), payment_method VARCHAR(MAX),
    status VARCHAR(MAX), shipping_cost VARCHAR(MAX), channel VARCHAR(MAX)
);

CREATE TABLE bronze.inventario_raw (
    codigo_producto VARCHAR(MAX), nombre_producto VARCHAR(MAX), categoria VARCHAR(MAX),
    precio_venta VARCHAR(MAX), costo_adquisicion VARCHAR(MAX), stock_actual VARCHAR(MAX),
    stock_minimo VARCHAR(MAX), sucursal VARCHAR(MAX), proveedor VARCHAR(MAX),
    ultima_reposicion VARCHAR(MAX), activo VARCHAR(MAX)
);
GO

-- ============================================================================
-- 2. CAPA SILVER  (tipada y limpia)
-- ============================================================================
CREATE TABLE silver.ventas_lpz (
    id_venta VARCHAR(50) PRIMARY KEY, fecha DATE, producto VARCHAR(255),
    cantidad INT, precio_unitario DECIMAL(18,2), sucursal VARCHAR(50),
    vendedor VARCHAR(100), cliente_nombre VARCHAR(150), cliente_email VARCHAR(150),
    cliente_ciudad VARCHAR(100), metodo_pago VARCHAR(50), estado VARCHAR(50),
    shipping_cost DECIMAL(18,2), canal VARCHAR(20)
);

CREATE TABLE silver.ventas_scz (
    id_venta VARCHAR(50) PRIMARY KEY, fecha DATE, producto VARCHAR(255),
    cantidad INT, precio_unitario DECIMAL(18,2), sucursal VARCHAR(50),
    vendedor VARCHAR(100), cliente_nombre VARCHAR(150), cliente_email VARCHAR(150),
    cliente_ciudad VARCHAR(100), metodo_pago VARCHAR(50), estado VARCHAR(50),
    shipping_cost DECIMAL(18,2), canal VARCHAR(20)
);

CREATE TABLE silver.ventas_online (
    id_venta VARCHAR(50) PRIMARY KEY, fecha DATE, producto VARCHAR(255),
    cantidad INT, precio_unitario DECIMAL(18,2), sucursal VARCHAR(50),
    vendedor VARCHAR(100), cliente_nombre VARCHAR(150), cliente_email VARCHAR(150),
    cliente_ciudad VARCHAR(100), metodo_pago VARCHAR(50), estado VARCHAR(50),
    shipping_cost DECIMAL(18,2), canal VARCHAR(20)
);

CREATE TABLE silver.inventario (
    codigo_producto VARCHAR(50), nombre_producto VARCHAR(255), categoria VARCHAR(100),
    precio_venta DECIMAL(18,2), costo_adquisicion DECIMAL(18,2), stock_actual INT,
    stock_minimo INT, sucursal VARCHAR(50), proveedor VARCHAR(100),
    ultima_reposicion DATE, activo BIT
);
GO

-- ============================================================================
-- 3. CAPA GOLD  (modelo estrella)
-- ============================================================================
CREATE TABLE gold.dim_tiempo (
    fecha_key INT PRIMARY KEY, fecha DATE NOT NULL, anio SMALLINT, mes TINYINT,
    nombre_mes VARCHAR(15), trimestre TINYINT, dia_semana TINYINT, nombre_dia VARCHAR(15)
);

CREATE TABLE gold.dim_producto (
    producto_key INT IDENTITY(1,1) PRIMARY KEY, codigo_producto VARCHAR(50),
    nombre_producto VARCHAR(255), categoria VARCHAR(100), proveedor VARCHAR(100),
    precio_venta_ref DECIMAL(18,2), costo_adquisicion DECIMAL(18,2), activo BIT
);

CREATE TABLE gold.dim_cliente (
    cliente_key INT IDENTITY(1,1) PRIMARY KEY, nombre_cliente VARCHAR(150),
    email_cliente VARCHAR(150), ciudad VARCHAR(100)
);

CREATE TABLE gold.dim_sucursal (
    sucursal_key INT IDENTITY(1,1) PRIMARY KEY, nombre_sucursal VARCHAR(50), tipo VARCHAR(20)
);

CREATE TABLE gold.dim_vendedor (
    vendedor_key INT IDENTITY(1,1) PRIMARY KEY, nombre_vendedor VARCHAR(100)
);

CREATE TABLE gold.fact_ventas (
    venta_key INT IDENTITY(1,1) PRIMARY KEY,
    fecha_key INT FOREIGN KEY REFERENCES gold.dim_tiempo(fecha_key),
    producto_key INT FOREIGN KEY REFERENCES gold.dim_producto(producto_key),
    cliente_key INT FOREIGN KEY REFERENCES gold.dim_cliente(cliente_key),
    sucursal_key INT FOREIGN KEY REFERENCES gold.dim_sucursal(sucursal_key),
    vendedor_key INT FOREIGN KEY REFERENCES gold.dim_vendedor(vendedor_key),
    cantidad INT, precio_unitario DECIMAL(18,2), total_venta DECIMAL(18,2),
    shipping_cost DECIMAL(18,2), id_venta_origen VARCHAR(50), metodo_pago VARCHAR(50),
    estado VARCHAR(50), canal VARCHAR(20)
);

CREATE TABLE gold.fact_inventario (
    inventario_key INT IDENTITY(1,1) PRIMARY KEY,
    producto_key INT FOREIGN KEY REFERENCES gold.dim_producto(producto_key),
    sucursal_key INT FOREIGN KEY REFERENCES gold.dim_sucursal(sucursal_key),
    fecha_reposicion_key INT FOREIGN KEY REFERENCES gold.dim_tiempo(fecha_key),
    stock_actual INT, stock_minimo INT, precio_venta DECIMAL(18,2),
    costo_adquisicion DECIMAL(18,2), margen_unitario DECIMAL(18,2)
);
GO

-- ============================================================================
-- 4. PROCEDIMIENTOS ETL
-- ============================================================================
CREATE OR ALTER PROCEDURE gold.sp_generate_dim_tiempo
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartDate DATE = '2023-01-01';
    DECLARE @EndDate DATE = '2026-12-31';

    WHILE @StartDate <= @EndDate
    BEGIN
        DECLARE @FechaKey INT = CAST(CONVERT(VARCHAR(8), @StartDate, 112) AS INT);
        IF NOT EXISTS (SELECT 1 FROM gold.dim_tiempo WHERE fecha_key = @FechaKey)
        BEGIN
            INSERT INTO gold.dim_tiempo (fecha_key, fecha, anio, mes, nombre_mes, trimestre, dia_semana, nombre_dia)
            VALUES (
                @FechaKey, @StartDate, YEAR(@StartDate), MONTH(@StartDate),
                DATENAME(MONTH, @StartDate), DATEPART(QUARTER, @StartDate),
                DATEPART(WEEKDAY, @StartDate), DATENAME(WEEKDAY, @StartDate)
            );
        END
        SET @StartDate = DATEADD(DAY, 1, @StartDate);
    END
END;
GO

CREATE OR ALTER PROCEDURE silver.sp_bronze_to_silver
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE silver.ventas_lpz;
    INSERT INTO silver.ventas_lpz
    SELECT
        id_venta,
        COALESCE(
            TRY_CONVERT(DATE, fecha_venta, 23), TRY_CONVERT(DATE, fecha_venta, 112),
            TRY_CONVERT(DATE, fecha_venta, 107), TRY_CONVERT(DATE, fecha_venta, 106),
            TRY_CONVERT(DATE, fecha_venta, 103), TRY_CONVERT(DATE, fecha_venta, 101),
            TRY_CAST(fecha_venta AS DATE)),
        LTRIM(RTRIM(producto)),
        TRY_CAST(TRY_CAST(cant AS DECIMAL(18,2)) AS INT),
        TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(preciounit),'bob',''),'bs.',''),'bs',''),' ',''),',','') AS DECIMAL(18,2)),
        'La Paz',
        NULLIF(LTRIM(RTRIM(vendedor)), ''),
        LTRIM(RTRIM(nombre_cliente)),
        NULLIF(LTRIM(RTRIM(email_cliente)), ''),
        NULL,
        NULLIF(LTRIM(RTRIM(metodopago)), ''),
        NULL, 0, 'LPZ'
    FROM bronze.ventas_lpz_raw
    WHERE id_venta IS NOT NULL;

    TRUNCATE TABLE silver.ventas_scz;
    INSERT INTO silver.ventas_scz
    SELECT
        id_venta,
        COALESCE(
            TRY_CONVERT(DATE, fecha, 23), TRY_CONVERT(DATE, fecha, 112),
            TRY_CONVERT(DATE, fecha, 111), TRY_CONVERT(DATE, fecha, 107),
            TRY_CONVERT(DATE, fecha, 106), TRY_CONVERT(DATE, fecha, 103),
            TRY_CAST(fecha AS DATE)),
        LTRIM(RTRIM(producto)),
        TRY_CAST(TRY_CAST(cantidad AS DECIMAL(18,2)) AS INT),
        TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(precio_unitario),'bob',''),'bs.',''),'bs',''),' ',''),',','') AS DECIMAL(18,2)),
        'Santa Cruz',
        NULLIF(LTRIM(RTRIM(vendedor)), ''),
        LTRIM(RTRIM(cliente_nombre)),
        NULLIF(LTRIM(RTRIM(cliente_email)), ''),
        NULL,
        NULLIF(LTRIM(RTRIM(metodo_pago)), ''),
        NULL, 0, 'SCZ'
    FROM bronze.ventas_scz_raw
    WHERE id_venta IS NOT NULL;

    TRUNCATE TABLE silver.ventas_online;
    INSERT INTO silver.ventas_online
    SELECT
        order_id,
        COALESCE(
            TRY_CONVERT(DATE, LEFT(timestamp, 10), 23), TRY_CONVERT(DATE, timestamp, 111),
            TRY_CONVERT(DATE, timestamp, 103), TRY_CONVERT(DATE, timestamp, 107),
            TRY_CAST(timestamp AS DATE)),
        LTRIM(RTRIM(product)),
        TRY_CAST(TRY_CAST(qty AS DECIMAL(18,2)) AS INT),
        TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(unit_price),'bob',''),'bs.',''),'bs',''),' ',''),',','') AS DECIMAL(18,2)),
        'Online',
        NULL,
        NULLIF(LTRIM(RTRIM(customer_name)), ''),
        NULLIF(LTRIM(RTRIM(customer_email)), ''),
        NULLIF(LTRIM(RTRIM(customer_city)), ''),
        NULLIF(LTRIM(RTRIM(payment_method)), ''),
        NULLIF(LTRIM(RTRIM(status)), ''),
        TRY_CAST(shipping_cost AS DECIMAL(18,2)),
        'Online'
    FROM bronze.ventas_online_raw
    WHERE order_id IS NOT NULL;

    TRUNCATE TABLE silver.inventario;
    INSERT INTO silver.inventario
    SELECT
        LTRIM(RTRIM(codigo_producto)),
        LTRIM(RTRIM(nombre_producto)),
        CASE
            WHEN UPPER(categoria) LIKE '%PERIF%'                         THEN 'Periféricos'
            WHEN UPPER(categoria) LIKE 'ACC%'                            THEN 'Accesorios'
            WHEN UPPER(categoria) LIKE '%ALMACEN%' OR UPPER(categoria) LIKE '%STORAGE%' THEN 'Almacenamiento'
            WHEN UPPER(categoria) LIKE '%AUDIO%'  OR UPPER(categoria) LIKE '%SONIDO%'   THEN 'Audio'
            WHEN UPPER(categoria) LIKE '%IMPRES%' OR UPPER(categoria) LIKE '%PRINTER%'  THEN 'Impresoras'
            WHEN UPPER(categoria) LIKE '%MONITOR%' OR UPPER(categoria) LIKE '%PANTALLA%' THEN 'Monitores'
            WHEN UPPER(categoria) LIKE 'PC%' OR UPPER(categoria) LIKE '%COMPUTAD%'      THEN 'Computadoras'
            WHEN UPPER(categoria) LIKE '%TABLET%'                        THEN 'Tablets'
            WHEN UPPER(categoria) LIKE '%RED%'                           THEN 'Redes'
            WHEN UPPER(categoria) LIKE '%HARDWARE%' OR UPPER(categoria) LIKE '%COMPONENT%' THEN 'Componentes'
            ELSE LTRIM(RTRIM(categoria))
        END,
        TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(precio_venta),'bob',''),'bs.',''),'bs',''),' ',''),',','') AS DECIMAL(18,2)),
        TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(costo_adquisicion),'bob',''),'bs.',''),'bs',''),' ',''),',','') AS DECIMAL(18,2)),
        TRY_CAST(TRY_CAST(stock_actual AS DECIMAL(18,2)) AS INT),
        TRY_CAST(TRY_CAST(stock_minimo AS DECIMAL(18,2)) AS INT),
        CASE
            WHEN UPPER(REPLACE(sucursal,'.','')) LIKE '%PAZ%' OR UPPER(REPLACE(sucursal,'.','')) LIKE 'LP%' OR UPPER(REPLACE(sucursal,'.','')) LIKE '%LAPAZ%' THEN 'La Paz'
            WHEN UPPER(REPLACE(sucursal,'.','')) LIKE '%CRUZ%' OR UPPER(REPLACE(sucursal,'.','')) LIKE 'SC%' OR UPPER(REPLACE(sucursal,'.','')) LIKE 'SCZ%' THEN 'Santa Cruz'
            WHEN UPPER(sucursal) LIKE '%COCHA%' OR UPPER(sucursal) LIKE '%CBBA%' THEN 'Cochabamba'
            ELSE LTRIM(RTRIM(sucursal))
        END,
        LTRIM(RTRIM(proveedor)),
        COALESCE(
            TRY_CONVERT(DATE, ultima_reposicion, 23), TRY_CONVERT(DATE, ultima_reposicion, 111),
            TRY_CONVERT(DATE, ultima_reposicion, 110), TRY_CONVERT(DATE, ultima_reposicion, 107),
            TRY_CONVERT(DATE, ultima_reposicion, 106), TRY_CAST(ultima_reposicion AS DATE)),
        CASE
            WHEN UPPER(LTRIM(RTRIM(activo))) IN ('1','TRUE','SI','SÍ','S','YES','Y') THEN 1
            ELSE 0
        END
    FROM bronze.inventario_raw
    WHERE codigo_producto IS NOT NULL;
END;
GO

CREATE OR ALTER PROCEDURE gold.sp_gold_dim_producto
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM gold.dim_producto;
    INSERT INTO gold.dim_producto (codigo_producto, nombre_producto, categoria, proveedor, precio_venta_ref, costo_adquisicion, activo)
    SELECT codigo_producto, MAX(nombre_producto), MAX(categoria), MAX(proveedor),
           AVG(precio_venta), AVG(costo_adquisicion), MAX(CAST(activo AS INT))
    FROM silver.inventario
    GROUP BY codigo_producto;
END;
GO

CREATE OR ALTER PROCEDURE gold.sp_gold_dim_cliente
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM gold.dim_cliente;
    WITH clientes AS (
        SELECT cliente_nombre, cliente_email, cliente_ciudad FROM silver.ventas_lpz
        UNION ALL SELECT cliente_nombre, cliente_email, cliente_ciudad FROM silver.ventas_scz
        UNION ALL SELECT cliente_nombre, cliente_email, cliente_ciudad FROM silver.ventas_online
    )
    INSERT INTO gold.dim_cliente (nombre_cliente, email_cliente, ciudad)
    SELECT MAX(cliente_nombre), cliente_email, MAX(cliente_ciudad)
    FROM clientes
    WHERE cliente_nombre IS NOT NULL
    GROUP BY cliente_email, CASE WHEN cliente_email IS NULL THEN cliente_nombre ELSE NULL END;
END;
GO

CREATE OR ALTER PROCEDURE gold.sp_gold_dim_sucursal
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM gold.dim_sucursal;
    WITH sucursales AS (
        SELECT sucursal FROM silver.ventas_lpz
        UNION SELECT sucursal FROM silver.ventas_scz
        UNION SELECT sucursal FROM silver.ventas_online
        UNION SELECT sucursal FROM silver.inventario
    )
    INSERT INTO gold.dim_sucursal (nombre_sucursal, tipo)
    SELECT DISTINCT sucursal, CASE WHEN sucursal = 'Online' THEN 'Online' ELSE 'Física' END
    FROM sucursales
    WHERE sucursal IS NOT NULL;
END;
GO

CREATE OR ALTER PROCEDURE gold.sp_gold_dim_vendedor
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM gold.dim_vendedor;
    WITH vendedores AS (
        SELECT vendedor FROM silver.ventas_lpz
        UNION SELECT vendedor FROM silver.ventas_scz
    )
    INSERT INTO gold.dim_vendedor (nombre_vendedor)
    SELECT DISTINCT vendedor FROM vendedores WHERE vendedor IS NOT NULL;
END;
GO

CREATE OR ALTER PROCEDURE gold.sp_gold_fact_ventas
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM gold.fact_ventas;
    WITH ventas AS (
        SELECT * FROM silver.ventas_lpz
        UNION ALL SELECT * FROM silver.ventas_scz
        UNION ALL SELECT * FROM silver.ventas_online
    )
    INSERT INTO gold.fact_ventas (
        fecha_key, producto_key, cliente_key, sucursal_key, vendedor_key,
        cantidad, precio_unitario, total_venta, shipping_cost,
        id_venta_origen, metodo_pago, estado, canal
    )
    SELECT
        CAST(CONVERT(VARCHAR(8), v.fecha, 112) AS INT),
        dp.producto_key, dc.cliente_key, ds.sucursal_key, dv.vendedor_key,
        v.cantidad, v.precio_unitario, v.cantidad * v.precio_unitario, v.shipping_cost,
        v.id_venta, v.metodo_pago, v.estado, v.canal
    FROM ventas v
    LEFT JOIN gold.dim_producto dp ON LOWER(LTRIM(RTRIM(v.producto))) = LOWER(LTRIM(RTRIM(dp.nombre_producto)))
    LEFT JOIN gold.dim_cliente dc ON v.cliente_email = dc.email_cliente
        OR (v.cliente_email IS NULL AND v.cliente_nombre = dc.nombre_cliente)
    LEFT JOIN gold.dim_sucursal ds ON v.sucursal = ds.nombre_sucursal
    LEFT JOIN gold.dim_vendedor dv ON v.vendedor = dv.nombre_vendedor;
END;
GO

CREATE OR ALTER PROCEDURE gold.sp_gold_fact_inventario
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM gold.fact_inventario;
    INSERT INTO gold.fact_inventario (
        producto_key, sucursal_key, fecha_reposicion_key,
        stock_actual, stock_minimo, precio_venta, costo_adquisicion, margen_unitario
    )
    SELECT
        dp.producto_key, ds.sucursal_key,
        CAST(CONVERT(VARCHAR(8), i.ultima_reposicion, 112) AS INT),
        i.stock_actual, i.stock_minimo, i.precio_venta, i.costo_adquisicion,
        i.precio_venta - i.costo_adquisicion
    FROM silver.inventario i
    LEFT JOIN gold.dim_producto dp ON i.codigo_producto = dp.codigo_producto
    LEFT JOIN gold.dim_sucursal ds ON i.sucursal = ds.nombre_sucursal;
END;
GO

PRINT 'Instalacion completa: esquemas, tablas y procedimientos creados.';
