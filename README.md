# Retail Project – SQL (PostgreSQL)

Este es el esquema base de un proyecto retail con tres tablas: `clientes`, `productos` y `ventas`. Incluye restricciones de integridad y una carga inicial de datos hecha de forma segura.

**Autor:** Joaquín Camisasca Benítez
**Curso:** SQL con PostgreSQL · Pre-entrega 2

## Contenido

| Archivo | Descripción |
|---|---|
| `retail_project.sql` | **Pre-entrega 2.** Script completo, con DDL (tablas y restricciones) y DML (carga en transacción, UPDATE y DELETE) |
| `pre-entrega-modulo4.sql` | **Pre-entrega Módulo 4.** Consultas multicapa con JOINs, GROUP BY y HAVING (rentabilidad por categoría, clientes sin compras, top de compras por cliente) |

### Qué hace `retail_project.sql`
0. Crea la base `retail_project` y se conecta a ella.
1. **DDL:** crea `clientes`, `productos` y `ventas`, en ese orden porque `ventas` depende de las otras dos.
   - Todas las tablas usan `PRIMARY KEY` con `SERIAL`.
   - `clientes.email` es `UNIQUE` y `NOT NULL`.
   - `ventas` tiene dos `FOREIGN KEY`, una hacia `clientes` y otra hacia `productos`.
   - Tiene 5 restricciones `CHECK`: `edad >= 18`, `precio > 0`, `stock >= 0`, `cantidad > 0` y `precio_unitario > 0`.
   - Los tipos son `DECIMAL` para dinero, `VARCHAR` para texto y `DATE` para fechas.
2. **Carga inicial:** inserta 5 clientes, 5 productos y 6 ventas dentro de `BEGIN; ... COMMIT;`. La venta 6 es un registro de prueba.
3. **Mantenimiento:**
   - Un `UPDATE` sube un 10 % el precio de la categoría *Electrónica*, filtrando con `WHERE categoria = 'Electrónica'`.
   - Un `DELETE` elimina la venta de prueba con `WHERE id_venta = 6`.
   - Antes de cada uno corre un `SELECT` con el mismo `WHERE` para mostrar qué filas va a modificar.
4. **Verificación:** muestra el conteo de filas por tabla y un listado de ventas con `JOIN` a clientes y productos.
5. **Pruebas de restricciones:** son opcionales y están comentadas. Muestran cómo PostgreSQL rechaza datos inválidos.

## Cómo ejecutarlo

### Opción A: psql (todo de una vez)
```bash
psql -U postgres -f retail_project.sql
```

### Opción B: pgAdmin o DBeaver
1. Conectate a la base `postgres` y ejecutá solo esta línea:
   ```sql
   CREATE DATABASE retail_project;
   ```
2. Abrí un editor de consultas (Query Tool) conectado a **`retail_project`**.
3. Pegá el script **desde la sección 1 en adelante**, sin la línea `CREATE DATABASE` ni `\c retail_project`, que es un comando exclusivo de psql. Después ejecutalo completo.

Al final vas a ver 5 filas en cada tabla. Los productos de Electrónica quedan con el precio aumentado y la venta de prueba ya no aparece.

## Pre-entrega Módulo 4: `pre-entrega-modulo4.sql`

Este script se ejecuta **después** de `retail_project.sql`, conectado a la base `retail_project`.

0. **Preparación:** se corre una sola vez. Crea la tabla `categorias` y la vincula a `productos` con una `FOREIGN KEY`. También suma productos, clientes y ventas para tener casos de análisis: clientes que todavía no compraron y clientes que repiten productos.
1. **Rentabilidad por categoría:** une `ventas`, `productos` y `categorias`, y calcula unidades vendidas, ingreso total y ticket promedio. Con `HAVING` filtra las categorías que superan un umbral de $150.000.
2. **Clientes sin compras:** usa un `LEFT JOIN` de `clientes` con `ventas`, agrupa y filtra con `HAVING COUNT(v.id_venta) = 0`. `COALESCE` muestra 0 en lugar de NULL. Sirve para armar campañas de primera compra.
3. **Top de compras por cliente:** arma un ranking por total gastado. El producto más comprado sale de una subconsulta correlacionada (`COUNT(*)` + `LIMIT 1`) y la última compra, de `MAX(fecha_venta)`.
