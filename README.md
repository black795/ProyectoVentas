# ProyectoVentas — Data Warehouse (Arquitectura Medallón)

Data Warehouse de ventas construido sobre Azure siguiendo la arquitectura
**Medallón (Bronze → Silver → Gold)**, replicando los patrones del proyecto
de referencia `dw-fuerzas-armadas`.

## Integrantes del grupo
- _(Nombre 1)_
- _(Nombre 2)_
- _(Nombre 3)_

> Usuario de Azure: **alan36755.yo@gmail.com** (debe quedar visible en todas las capturas).

---

## 1. Fuentes de datos

| Archivo | Formato | Filas | Naturaleza |
|---|---|---|---|
| `ventas_sucursal_lpz.csv` | CSV (ISO-8859-1) | 477 | Transaccional (ventas La Paz) |
| `ventas_sucursal_scz.csv` | CSV (UTF-8) | 540 | Transaccional (ventas Santa Cruz) |
| `ventas_online.json` | JSON anidado | 428 | Transaccional (ventas online) |
| `inventario.xlsx` | Excel | 94 | Catálogo de productos + snapshot de stock |

---

## 2. Arquitectura Medallón

- **BRONZE** — Ingesta cruda, copia fiel de la fuente. Todas las columnas `VARCHAR(MAX)`, tablas `*_raw`.
- **SILVER** — Datos limpios, estandarizados y validados (fechas, monedas, sucursales, categorías).
- **GOLD** — Modelo estrella: dimensiones aplanadas + tablas de hechos para consumo analítico.

### Modelo estrella (Gold)
**Dimensiones:** `dim_tiempo`, `dim_producto` (proveedor + categoría aplanados),
`dim_cliente`, `dim_sucursal`, `dim_vendedor`.
**Hechos:** `fact_ventas` (consolida las 3 fuentes) y `fact_inventario` (snapshot producto × sucursal).

`fecha_key = CAST(CONVERT(VARCHAR(8), fecha, 112) AS INT)` (formato `YYYYMMDD`).

---

## 3. Estructura del repositorio

```
ProyectoVentas/
├── Modelos/
│   ├── bronze_schema.sql        # 4 tablas _raw (VARCHAR(MAX))
│   ├── silver_schema.sql        # 3 ventas armonizadas + inventario (tipadas)
│   ├── gold_schema.sql          # 5 dimensiones + 2 hechos
│   └── etl_procedures.sql       # sp_generate_dim_tiempo, sp_bronze_to_silver, sp_gold_*
├── Terraform/
│   └── main.tf                  # RG + Storage Gen2 + Azure SQL + Firewall + ADF
├── linkedService/               # LS_DataLake_Ventas, LS_AzureSQL_Ventas
├── dataset/                     # 4 archivos origen + 4 bronze + 4 silver + 7 gold
├── dataflow/                    # df_silver_* (limpieza/estandarización)
├── pipeline/                    # bronze (Copy) + silver (Dataflow) + gold (SP) + pl_master_etl
├── trigger/                     # tr_diario_etl (programado diario)
└── factory/                     # definición de la Data Factory
```

---

## 4. Orden de despliegue

1. **Infraestructura (Terraform):**
   ```powershell
   cd Terraform
   terraform init
   terraform apply
   ```
   Crea: Resource Group, Storage Account Gen2 (contenedores `bronze`/`silver`),
   Azure SQL Server + DB `dw_ventas`, regla de firewall y la Data Factory.

2. **Subir los 4 archivos fuente** al contenedor `bronze` del Storage Account.

3. **Crear los esquemas SQL** (en `dw_ventas`, en este orden):
   `bronze_schema.sql` → `silver_schema.sql` → `gold_schema.sql` → `etl_procedures.sql`.

4. **Importar la Data Factory:** publicar/importar las carpetas
   `linkedService/`, `dataset/`, `dataflow/`, `pipeline/`, `trigger/`
   (o conectar el repositorio Git a ADF).

5. **Ejecutar `pl_master_etl`** (Debug o Trigger). Orquesta:
   `Limpiar_Base_Datos` → `Cargar_Bronze` (Copy) → 4 Silver (Dataflow) →
   5 Gold dimensiones (SP) → 2 Gold hechos (SP).

---

## 5. Transformaciones clave aplicadas en Silver

| Problema en la fuente | Solución |
|---|---|
| Precios `Bs.5252.67`, `BOB 5623.91`, `bs. 431.98` | Eliminar texto y `toDecimal` |
| Fechas en 6 formatos (incl. `07 de April de 2024`) | `coalesce(toDate(...))` con múltiples máscaras |
| Cantidades `5.0`, `-2.0` | `toInteger(toFloat(...))`, se conservan negativos (devoluciones) |
| Sucursal en 7 variantes (`LP`, `la paz`, `L.P.`…) | Normalización a `La Paz` / `Santa Cruz` / `Cochabamba` |
| Categorías en 35 variantes | Mapeo a ~10 categorías canónicas |
| `activo` (`SI`/`NO`/`0`/`FALSE`/`sí`) | Conversión a `boolean` |
| JSON `customer` anidado | Aplanado en la ingesta Bronze (Copy) a `customer_name/email/city` |

---

## 6. Evidencias para el informe PDF

Capturar **pantalla completa (sin recortes)** con el **usuario de Azure visible**:
1. Resource Group con todos los recursos creados.
2. Storage Account: contenedores `bronze`/`silver` con los archivos subidos.
3. Azure SQL: esquemas `bronze`/`silver`/`gold` con sus tablas.
4. Data Factory: Linked Services, Datasets, Dataflows, Pipelines y Trigger.
5. Ejecución exitosa de `pl_master_etl` (monitor con todas las actividades en verde).
6. Consultas de validación sobre `gold.fact_ventas` y `gold.fact_inventario`.
