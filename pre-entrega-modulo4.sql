-- =====================================================================
-- Proyecto Retail · Pre-entrega Módulo 4
-- Consultas multicapa para análisis de negocio (JOINs, GROUP BY, HAVING)
-- Autor: Joaquín Camisasca Benítez
-- Motor: PostgreSQL · Base: retail_project
--
-- Requisito previo: haber ejecutado retail_project.sql (pre-entrega 2),
-- que crea y carga clientes, productos y ventas.
-- =====================================================================


-- =====================================================================
-- 0. PREPARACIÓN DEL ESQUEMA (ejecutar UNA sola vez)
-- La consigna pide unir ventas, productos y categorias, pero en el
-- módulo anterior la categoría era un texto dentro de productos. Acá se
-- normaliza: se crea la tabla categorias y productos pasa a apuntarle
-- con una FOREIGN KEY. También se suman datos para que las consultas
-- tengan casos interesantes: clientes que todavía no compraron y
-- clientes que repiten productos.
-- =====================================================================
CREATE TABLE IF NOT EXISTS categorias (
    id_categoria  SERIAL       PRIMARY KEY,
    nombre        VARCHAR(50)  NOT NULL UNIQUE
);

BEGIN;

-- 0.1 Cargar las categorías a partir de las que ya existen en productos
INSERT INTO categorias (nombre)
SELECT DISTINCT categoria FROM productos ORDER BY categoria
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO categorias (nombre) VALUES ('Deportes')
ON CONFLICT (nombre) DO NOTHING;

-- 0.2 Vincular productos con categorias mediante una FK
ALTER TABLE productos
    ADD COLUMN IF NOT EXISTS id_categoria INT REFERENCES categorias (id_categoria);

-- 0.3 Productos nuevos (id 6, 7 y 8)
INSERT INTO productos (nombre, categoria, precio, stock) VALUES
    ('Pelota de fútbol',  'Deportes', 32000.00, 40),
    ('Botella térmica',   'Deportes', 21000.00, 60),
    ('Juego de sábanas',  'Hogar',    38000.00, 20);

-- Completar la FK de todos los productos según su categoría en texto
UPDATE productos p
SET id_categoria = cat.id_categoria
FROM categorias cat
WHERE cat.nombre = p.categoria
  AND p.id_categoria IS NULL;

-- 0.4 Clientes nuevos (id 6, 7 y 8). El 7 y el 8 no van a tener compras.
INSERT INTO clientes (nombre, apellido, email, edad, ciudad, fecha_registro) VALUES
    ('Camila',    'Sánchez', 'camila.sanchez@mail.com', 27, 'CABA',          '2026-04-10'),
    ('Nicolás',   'Pereyra', 'nico.pereyra@mail.com',   38, 'Mar del Plata', '2026-05-02'),
    ('Florencia', 'Díaz',    'flor.diaz@mail.com',      45, 'Salta',         '2026-06-18');

-- 0.5 Ventas nuevas (al precio vigente de cada producto)
INSERT INTO ventas (id_cliente, id_producto, fecha_venta, cantidad, precio_unitario) VALUES
    (1, 2, '2026-05-03', 1, 20350.00),
    (1, 2, '2026-06-14', 1, 20350.00),
    (2, 3, '2026-05-10', 2, 15000.00),
    (2, 6, '2026-06-02', 1, 32000.00),
    (3, 8, '2026-05-20', 1, 38000.00),
    (3, 8, '2026-07-01', 1, 38000.00),
    (4, 6, '2026-05-15', 1, 32000.00),
    (4, 6, '2026-08-09', 2, 32000.00),
    (4, 7, '2026-08-09', 1, 21000.00),
    (5, 1, '2026-06-20', 1, 49500.00),
    (6, 7, '2026-07-12', 2, 21000.00),
    (6, 7, '2026-09-03', 1, 21000.00),
    (6, 6, '2026-09-03', 1, 32000.00);

COMMIT;


-- =====================================================================
-- CONSULTA 1 · RENTABILIDAD POR CATEGORÍA
-- Problema de negocio: saber qué categorías realmente sostienen la
-- facturación, para decidir dónde poner stock, promociones y espacio de
-- vidriera, y cuáles hay que revisar porque venden poco.
--
-- Umbral definido en $150.000 porque el ingreso promedio por categoría
-- ronda los $180.000: una categoría que no llega a 150.000 queda claramente
-- por debajo del promedio y conviene revisarla (precio, surtido o
-- visibilidad). Las que lo superan son las que "rinden".
--
-- Lógica: se unen 3 tablas (ventas → productos → categorias). Se agrupa
-- por categoría y el filtro va en HAVING porque se aplica sobre un
-- resultado agregado (SUM): en WHERE daría error.
-- =====================================================================
SELECT
    cat.nombre                                     AS categoria,
    COUNT(v.id_venta)                              AS cantidad_ventas,
    SUM(v.cantidad)                                AS unidades_vendidas,
    SUM(v.cantidad * v.precio_unitario)            AS ingreso_total,
    ROUND(AVG(v.cantidad * v.precio_unitario), 2)  AS ticket_promedio
FROM ventas v
JOIN productos  p   ON p.id_producto    = v.id_producto
JOIN categorias cat ON cat.id_categoria = p.id_categoria
GROUP BY cat.nombre
HAVING SUM(v.cantidad * v.precio_unitario) > 150000
ORDER BY ingreso_total DESC;


-- =====================================================================
-- CONSULTA 2 · CLIENTES SIN COMPRAS ("clientes escurridizos")
-- Problema de negocio: detectar personas que se registraron pero nunca
-- compraron, para armarles una campaña de primera compra (cupón de
-- bienvenida, mail de recordatorio). Cuantos más días pasaron desde el
-- registro, más urgente es contactarlas.
--
-- Lógica: LEFT JOIN conserva a TODOS los clientes, tengan o no ventas.
-- Para quien no compró, las columnas de ventas vienen en NULL:
-- COUNT(v.id_venta) da 0 y COALESCE convierte el total NULL en 0.
-- El filtro "sin compras" es sobre un agregado, por eso va en HAVING.
-- =====================================================================
SELECT
    c.id_cliente,
    c.nombre || ' ' || c.apellido                       AS cliente,
    c.email,
    c.fecha_registro,
    CURRENT_DATE - c.fecha_registro                     AS dias_desde_registro,
    COUNT(v.id_venta)                                   AS cantidad_compras,
    COALESCE(SUM(v.cantidad * v.precio_unitario), 0)    AS total_gastado
FROM clientes c
LEFT JOIN ventas v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre, c.apellido, c.email, c.fecha_registro
HAVING COUNT(v.id_venta) = 0
ORDER BY dias_desde_registro DESC;


-- =====================================================================
-- CONSULTA 3 · TOP DE COMPRAS POR CLIENTE
-- Problema de negocio: conocer a los mejores clientes. Para cada uno se
-- ve cuánto gastó (para rankearlo), qué producto compra más seguido
-- (para recomendaciones o promos personalizadas) y cuándo fue su última
-- compra (para detectar si se está enfriando).
--
-- Lógica:
--  · La consulta principal une clientes y ventas, agrupa por cliente y
--    calcula compras, total gastado y MAX(fecha_venta) = última compra.
--  · El producto favorito sale de una SUBCONSULTA CORRELACIONADA en el
--    SELECT: para cada cliente (c.id_cliente) une ventas con productos,
--    agrupa por producto, ordena por cantidad de compras (COUNT(*)) de
--    mayor a menor y se queda con el primero (LIMIT 1).
--    Desempate: si dos productos se compraron las mismas veces, gana el
--    de más unidades y, si sigue el empate, el orden alfabético.
--  · El ranking se arma ordenando por total gastado.
-- =====================================================================
SELECT
    c.nombre || ' ' || c.apellido              AS cliente,
    COUNT(v.id_venta)                          AS cantidad_compras,
    SUM(v.cantidad * v.precio_unitario)        AS total_gastado,
    (
        SELECT p.nombre
        FROM ventas v2
        JOIN productos p ON p.id_producto = v2.id_producto
        WHERE v2.id_cliente = c.id_cliente          -- correlación con el cliente de afuera
        GROUP BY p.id_producto, p.nombre
        ORDER BY COUNT(*) DESC, SUM(v2.cantidad) DESC, p.nombre
        LIMIT 1
    )                                          AS producto_mas_comprado,
    MAX(v.fecha_venta)                         AS ultima_compra
FROM clientes c
JOIN ventas v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY total_gastado DESC;
