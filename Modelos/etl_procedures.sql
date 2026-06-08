-- Procedimientos para el pipeline de Azure Data Factory
CREATE OR ALTER PROCEDURE silver.sp_load_ventas_clean
AS
BEGIN
    TRUNCATE TABLE silver.ventas_clean;

    -- Insertar Ventas SCZ (Limpiando formatos de número y fecha)
    INSERT INTO silver.ventas_clean (id_venta, fecha, producto_nombre, cantidad, precio_unitario, total_venta, sucursal, vendedor_nombre, cliente_nombre, cliente_email, metodo_pago, canal_venta)
    SELECT 
        id_venta,
        TRY_CAST(fecha AS DATE),
        producto,
        TRY_CAST(cantidad AS INT),
        TRY_CAST(REPLACE(REPLACE(precio_unitario, 'bs.', ''), ',', '') AS DECIMAL(18,2)),
        (TRY_CAST(cantidad AS INT) * TRY_CAST(REPLACE(REPLACE(precio_unitario, 'bs.', ''), ',', '') AS DECIMAL(18,2))),
        'Santa Cruz',
        vendedor,
        cliente_nombre,
        cliente_email,
        metodo_pago,
        'Tienda Fí­sica'
    FROM bronze.ventas_scz_raw
    WHERE TRY_CAST(cantidad AS INT) > 0; -- Filtro de calidad simple

    -- Insertar Ventas LPZ
    INSERT INTO silver.ventas_clean (id_venta, fecha, producto_nombre, cantidad, precio_unitario, total_venta, sucursal, vendedor_nombre, cliente_nombre, cliente_email, metodo_pago, canal_venta)
    SELECT 
        id_venta,
        TRY_CAST(fecha_venta AS DATE),
        producto,
        TRY_CAST(cant AS INT),
        TRY_CAST(REPLACE(REPLACE(preciounit, 'Bs.', ''), ',', '') AS DECIMAL(18,2)),
        (TRY_CAST(cant AS INT) * TRY_CAST(REPLACE(REPLACE(preciounit, 'Bs.', ''), ',', '') AS DECIMAL(18,2))),
        'La Paz',
        vendedor,
        nombre_cliente,
        email_cliente,
        metodopago,
        'Tienda Fí­sica'
    FROM bronze.ventas_lpz_raw
    WHERE TRY_CAST(cant AS INT) > 0;

    -- Insertar Ventas Online
    INSERT INTO silver.ventas_clean (id_venta, fecha, producto_nombre, cantidad, precio_unitario, total_venta, sucursal, vendedor_nombre, cliente_nombre, cliente_email, metodo_pago, canal_venta)
    SELECT 
        order_id,
        TRY_CAST(LEFT(timestamp, 10) AS DATE),
        product,
        qty,
        unit_price,
        (qty * unit_price),
        'Online',
        'Bot E-commerce',
        customer_name,
        customer_email,
        payment_method,
        'Online'
    FROM bronze.ventas_online_raw;
END;
GO

CREATE OR ALTER PROCEDURE gold.sp_load_fact_ventas
AS
BEGIN
    TRUNCATE TABLE gold.fact_ventas;

    -- Aquí irí­a la lógica de búsqueda de las Dimensiones e Inserción en la tabla de Hechos.
    INSERT INTO gold.fact_ventas (id_venta_origen, id_tiempo, id_cliente, id_producto, id_sucursal, cantidad, precio_unitario, total_venta, metodo_pago, canal_venta)
    SELECT 
        v.id_venta,
        t.id_tiempo,
        c.id_cliente,
        p.id_producto,
        s.id_sucursal,
        v.cantidad,
        v.precio_unitario,
        v.total_venta,
        v.metodo_pago,
        v.canal_venta
    FROM silver.ventas_clean v
    LEFT JOIN gold.dim_tiempo t ON v.fecha = t.fecha
    LEFT JOIN gold.dim_cliente c ON v.cliente_email = c.email
    LEFT JOIN gold.dim_sucursal s ON v.sucursal = s.nombre
    -- JOIN Producto por coincidencia aproximada o si existe tabla mapeo
    LEFT JOIN gold.dim_producto p ON v.producto_nombre = p.nombre;
END;
GO
