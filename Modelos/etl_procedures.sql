-- ============================================================
-- PROCEDIMIENTOS ETL - ProyectoVentas
-- Patrón idéntico al proyecto de referencia:
--   1) gold.sp_generate_dim_tiempo
--   2) silver.sp_bronze_to_silver  (TRUNCATE + INSERT + CAST por tabla)
--   3) gold.sp_gold_*  (un procedimiento por dimensión / hecho)
-- ============================================================

-- ------------------------------------------------------------
-- 1. PROCEDURE: Generar Dimensión de Tiempo  (idéntico al ejemplo)
-- ------------------------------------------------------------
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
                @FechaKey,
                @StartDate,
                YEAR(@StartDate),
                MONTH(@StartDate),
                DATENAME(MONTH, @StartDate),
                DATEPART(QUARTER, @StartDate),
                DATEPART(WEEKDAY, @StartDate),
                DATENAME(WEEKDAY, @StartDate)
            );
        END
        SET @StartDate = DATEADD(DAY, 1, @StartDate);
    END
END;
GO

-- ------------------------------------------------------------
-- 2. PROCEDURE: Bronze -> Silver (limpieza y casteo por cada tabla)
--    Aquí se resuelven los problemas de calidad detectados:
--      - precios con texto (Bs, Bs., BOB)  -> DECIMAL
--      - fechas en múltiples formatos       -> DATE (best-effort T-SQL)
--      - sucursales en 7 variantes          -> canónico
--      - categorías en 35 variantes         -> canónico
--      - activo (SI/NO/0/FALSE/sí...)        -> BIT
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE silver.sp_bronze_to_silver
AS
BEGIN
    SET NOCOUNT ON;

    -- ===== Ventas La Paz =====
    TRUNCATE TABLE silver.ventas_lpz;
    INSERT INTO silver.ventas_lpz
    SELECT
        id_venta,
        COALESCE(
            TRY_CONVERT(DATE, fecha_venta, 23),     -- 2024-09-02
            TRY_CONVERT(DATE, fecha_venta, 112),    -- 20240902
            TRY_CONVERT(DATE, fecha_venta, 107),    -- Sep 02, 2024
            TRY_CONVERT(DATE, fecha_venta, 106),    -- 02 Sep 2024
            TRY_CONVERT(DATE, fecha_venta, 103),    -- 02/09/2024
            TRY_CONVERT(DATE, fecha_venta, 101),    -- 09/02/2024
            TRY_CAST(fecha_venta AS DATE)
        ),
        LTRIM(RTRIM(producto)),
        TRY_CAST(TRY_CAST(cant AS DECIMAL(18,2)) AS INT),
        TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            LOWER(preciounit),'bob',''),'bs.',''),'bs',''),' ',''),',','') AS DECIMAL(18,2)),
        'La Paz',                                   -- sucursal canónica
        NULLIF(LTRIM(RTRIM(vendedor)), ''),
        LTRIM(RTRIM(nombre_cliente)),
        NULLIF(LTRIM(RTRIM(email_cliente)), ''),
        NULL,                                       -- cliente_ciudad (no existe en CSV)
        NULLIF(LTRIM(RTRIM(metodopago)), ''),
        NULL,                                       -- estado (no aplica)
        0,                                          -- shipping_cost
        'LPZ'                                       -- canal
    FROM bronze.ventas_lpz_raw
    WHERE id_venta IS NOT NULL;

    -- ===== Ventas Santa Cruz =====
    TRUNCATE TABLE silver.ventas_scz;
    INSERT INTO silver.ventas_scz
    SELECT
        id_venta,
        COALESCE(
            TRY_CONVERT(DATE, fecha, 23),
            TRY_CONVERT(DATE, fecha, 112),
            TRY_CONVERT(DATE, fecha, 111),          -- 2024/06/02
            TRY_CONVERT(DATE, fecha, 107),
            TRY_CONVERT(DATE, fecha, 106),
            TRY_CONVERT(DATE, fecha, 103),
            TRY_CAST(fecha AS DATE)
        ),
        LTRIM(RTRIM(producto)),
        TRY_CAST(TRY_CAST(cantidad AS DECIMAL(18,2)) AS INT),
        TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            LOWER(precio_unitario),'bob',''),'bs.',''),'bs',''),' ',''),',','') AS DECIMAL(18,2)),
        'Santa Cruz',
        NULLIF(LTRIM(RTRIM(vendedor)), ''),
        LTRIM(RTRIM(cliente_nombre)),
        NULLIF(LTRIM(RTRIM(cliente_email)), ''),
        NULL,
        NULLIF(LTRIM(RTRIM(metodo_pago)), ''),
        NULL,
        0,
        'SCZ'
    FROM bronze.ventas_scz_raw
    WHERE id_venta IS NOT NULL;

    -- ===== Ventas Online =====
    TRUNCATE TABLE silver.ventas_online;
    INSERT INTO silver.ventas_online
    SELECT
        order_id,
        COALESCE(
            TRY_CONVERT(DATE, LEFT(timestamp, 10), 23),   -- 2025-03-22T00:00:00
            TRY_CONVERT(DATE, timestamp, 111),            -- 2024/11/24
            TRY_CONVERT(DATE, timestamp, 103),            -- 21/03/2024
            TRY_CONVERT(DATE, timestamp, 107),
            TRY_CAST(timestamp AS DATE)
        ),
        LTRIM(RTRIM(product)),
        TRY_CAST(TRY_CAST(qty AS DECIMAL(18,2)) AS INT),
        TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            LOWER(unit_price),'bob',''),'bs.',''),'bs',''),' ',''),',','') AS DECIMAL(18,2)),
        'Online',
        NULL,                                       -- vendedor (no aplica online)
        NULLIF(LTRIM(RTRIM(customer_name)), ''),
        NULLIF(LTRIM(RTRIM(customer_email)), ''),
        NULLIF(LTRIM(RTRIM(customer_city)), ''),
        NULLIF(LTRIM(RTRIM(payment_method)), ''),
        NULLIF(LTRIM(RTRIM(status)), ''),
        TRY_CAST(shipping_cost AS DECIMAL(18,2)),
        'Online'
    FROM bronze.ventas_online_raw
    WHERE order_id IS NOT NULL;

    -- ===== Inventario =====
    TRUNCATE TABLE silver.inventario;
    INSERT INTO silver.inventario
    SELECT
        LTRIM(RTRIM(codigo_producto)),
        LTRIM(RTRIM(nombre_producto)),
        CASE                                        -- categoría canónica
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
        TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            LOWER(precio_venta),'bob',''),'bs.',''),'bs',''),' ',''),',','') AS DECIMAL(18,2)),
        TRY_CAST(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            LOWER(costo_adquisicion),'bob',''),'bs.',''),'bs',''),' ',''),',','') AS DECIMAL(18,2)),
        TRY_CAST(TRY_CAST(stock_actual AS DECIMAL(18,2)) AS INT),
        TRY_CAST(TRY_CAST(stock_minimo AS DECIMAL(18,2)) AS INT),
        CASE                                        -- sucursal canónica
            WHEN UPPER(REPLACE(sucursal,'.','')) LIKE '%PAZ%' OR UPPER(REPLACE(sucursal,'.','')) LIKE 'LP%' OR UPPER(REPLACE(sucursal,'.','')) LIKE '%LAPAZ%' THEN 'La Paz'
            WHEN UPPER(REPLACE(sucursal,'.','')) LIKE '%CRUZ%' OR UPPER(REPLACE(sucursal,'.','')) LIKE 'SC%' OR UPPER(REPLACE(sucursal,'.','')) LIKE 'SCZ%' THEN 'Santa Cruz'
            WHEN UPPER(sucursal) LIKE '%COCHA%' OR UPPER(sucursal) LIKE '%CBBA%' THEN 'Cochabamba'
            ELSE LTRIM(RTRIM(sucursal))
        END,
        LTRIM(RTRIM(proveedor)),
        COALESCE(
            TRY_CONVERT(DATE, ultima_reposicion, 23),
            TRY_CONVERT(DATE, ultima_reposicion, 111),
            TRY_CONVERT(DATE, ultima_reposicion, 110),   -- 02-28-2025 (mm-dd-yyyy)
            TRY_CONVERT(DATE, ultima_reposicion, 107),
            TRY_CONVERT(DATE, ultima_reposicion, 106),
            TRY_CAST(ultima_reposicion AS DATE)
        ),
        CASE
            WHEN UPPER(LTRIM(RTRIM(activo))) IN ('1','TRUE','SI','SÍ','S','YES','Y') THEN 1
            ELSE 0
        END
    FROM bronze.inventario_raw
    WHERE codigo_producto IS NOT NULL;
END;
GO

-- ------------------------------------------------------------
-- 3. PROCEDURES Silver -> Gold (uno por dimensión / hecho)
-- ------------------------------------------------------------

-- 3.1 Dimensión Producto (aplanada: producto + categoría + proveedor)
--     Dedup por codigo_producto (el inventario repite el producto por sucursal)
CREATE OR ALTER PROCEDURE gold.sp_gold_dim_producto
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM gold.dim_producto;
    INSERT INTO gold.dim_producto (codigo_producto, nombre_producto, categoria, proveedor, precio_venta_ref, costo_adquisicion, activo)
    SELECT
        codigo_producto,
        MAX(nombre_producto),
        MAX(categoria),
        MAX(proveedor),
        AVG(precio_venta),
        AVG(costo_adquisicion),
        MAX(CAST(activo AS INT))
    FROM silver.inventario
    GROUP BY codigo_producto;
END;
GO

-- 3.2 Dimensión Cliente (consolidada de las 3 fuentes, dedup por email/nombre)
CREATE OR ALTER PROCEDURE gold.sp_gold_dim_cliente
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM gold.dim_cliente;
    WITH clientes AS (
        SELECT cliente_nombre, cliente_email, cliente_ciudad FROM silver.ventas_lpz
        UNION ALL
        SELECT cliente_nombre, cliente_email, cliente_ciudad FROM silver.ventas_scz
        UNION ALL
        SELECT cliente_nombre, cliente_email, cliente_ciudad FROM silver.ventas_online
    )
    INSERT INTO gold.dim_cliente (nombre_cliente, email_cliente, ciudad)
    SELECT
        MAX(cliente_nombre),
        cliente_email,
        MAX(cliente_ciudad)
    FROM clientes
    WHERE cliente_nombre IS NOT NULL
    GROUP BY cliente_email, CASE WHEN cliente_email IS NULL THEN cliente_nombre ELSE NULL END;
END;
GO

-- 3.3 Dimensión Sucursal / Canal
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
    SELECT DISTINCT
        sucursal,
        CASE WHEN sucursal = 'Online' THEN 'Online' ELSE 'Física' END
    FROM sucursales
    WHERE sucursal IS NOT NULL;
END;
GO

-- 3.4 Dimensión Vendedor (sólo ventas físicas)
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

-- 3.5 Hechos Ventas (consolida las 3 fuentes con UNION ALL)
CREATE OR ALTER PROCEDURE gold.sp_gold_fact_ventas
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM gold.fact_ventas;

    WITH ventas AS (
        SELECT * FROM silver.ventas_lpz
        UNION ALL
        SELECT * FROM silver.ventas_scz
        UNION ALL
        SELECT * FROM silver.ventas_online
    )
    INSERT INTO gold.fact_ventas (
        fecha_key, producto_key, cliente_key, sucursal_key, vendedor_key,
        cantidad, precio_unitario, total_venta, shipping_cost,
        id_venta_origen, metodo_pago, estado, canal
    )
    SELECT
        CAST(CONVERT(VARCHAR(8), v.fecha, 112) AS INT),
        dp.producto_key,
        dc.cliente_key,
        ds.sucursal_key,
        dv.vendedor_key,
        v.cantidad,
        v.precio_unitario,
        v.cantidad * v.precio_unitario,
        v.shipping_cost,
        v.id_venta,
        v.metodo_pago,
        v.estado,
        v.canal
    FROM ventas v
    LEFT JOIN gold.dim_producto dp
        ON LOWER(LTRIM(RTRIM(v.producto))) = LOWER(LTRIM(RTRIM(dp.nombre_producto)))
    LEFT JOIN gold.dim_cliente dc
        ON v.cliente_email = dc.email_cliente
        OR (v.cliente_email IS NULL AND v.cliente_nombre = dc.nombre_cliente)
    LEFT JOIN gold.dim_sucursal ds ON v.sucursal = ds.nombre_sucursal
    LEFT JOIN gold.dim_vendedor dv ON v.vendedor = dv.nombre_vendedor;
END;
GO

-- 3.6 Hechos Inventario (grano: producto × sucursal)
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
        dp.producto_key,
        ds.sucursal_key,
        CAST(CONVERT(VARCHAR(8), i.ultima_reposicion, 112) AS INT),
        i.stock_actual,
        i.stock_minimo,
        i.precio_venta,
        i.costo_adquisicion,
        i.precio_venta - i.costo_adquisicion
    FROM silver.inventario i
    LEFT JOIN gold.dim_producto dp ON i.codigo_producto = dp.codigo_producto
    LEFT JOIN gold.dim_sucursal ds ON i.sucursal = ds.nombre_sucursal;
END;
GO
