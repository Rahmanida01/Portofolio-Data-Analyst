#. Profiling Data
SELECT
  COUNT(*) AS total_baris,
  COUNT(DISTINCT order_id) AS total_order,
  MIN(tanggal) AS tanggal_awal,
  MAX(tanggal) AS tanggal_akhir
FROM `data-analyst-seara-data.SearaData.Tranksaksi`;

#. Cek Missing Value dan Data Tidak Valid 
SELECT
  COUNTIF(tanggal IS NULL) AS tanggal_null,
  COUNTIF(order_id IS NULL) AS order_null,
  COUNTIF(qty IS NULL) AS qty_null,
  COUNTIF(harga_satuan IS NULL) AS harga_null,
  COUNTIF(qty <= 0) AS qty_tidak_valid
FROM `data-analyst-seara-data.SearaData.Tranksaksi`;

#Analisis Data
#1.Mencari Angka Total Gross Revenue 

SELECT
  SUM(qty * harga_satuan) AS total_gross_revenue
FROM `data-analyst-seara-data.SearaData.Tranksaksi`
WHERE tanggal >= DATE '2025-01-01'
  AND tanggal <= DATE '2025-12-31';

  #. Pecah Gross Revenue Per-Bulan 
SELECT
  DATE_TRUNC(tanggal, MONTH) AS bulan,
  SUM(qty * harga_satuan) AS gross_revenue
FROM `data-analyst-seara-data.SearaData.Tranksaksi`
WHERE tanggal >= DATE '2025-01-01'
  AND tanggal <= DATE '2025-12-31'
GROUP BY bulan
ORDER BY bulan;

#. Cek Kode Unik (Product_id)
SELECT
  COUNT(*) AS total_baris_produk,
  COUNT(DISTINCT produk_id) AS total_produk_unik
FROM `data-analyst-seara-data.SearaData.Produk`;

#. Cek Duplikasi Product_id 

SELECT
  produk_id,
  COUNT(*) AS jumlah
FROM `data-analyst-seara-data.SearaData.Produk`
GROUP BY produk_id
HAVING COUNT(*) > 1
ORDER BY jumlah DESC;

#. Join Data Transaksi dengan Produk 
SELECT
  t.order_id,
  t.tanggal,
  t.produk_id,
  t.qty,
  t.harga_satuan,
  p.harga_modal
FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t
INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
  ON t.produk_id = p.produk_id
WHERE t.tanggal >= DATE '2025-01-01'
  AND t.tanggal <= DATE '2025-12-31'
ORDER BY t.tanggal;

#. Hitung HPP Total 2025 

SELECT
  SUM(t.qty * p.harga_modal) AS total_hpp
FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t
INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
  ON t.produk_id = p.produk_id
WHERE t.tanggal >= DATE '2025-01-01'
  AND t.tanggal <= DATE '2025-12-31';

  #. Validasi Data After Join 
  SELECT
  COUNT(*) AS total_baris_setelah_join,
  COUNT(DISTINCT t.order_id) AS total_order_setelah_join,
  SUM(t.qty * t.harga_satuan) AS gross_revenue_setelah_join,
  SUM(t.qty * p.harga_modal) AS hpp_setelah_join
FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t
INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
  ON t.produk_id = p.produk_id
WHERE t.tanggal >= DATE '2025-01-01'
  AND t.tanggal <= DATE '2025-12-31';

#. Breakdown per bulan 

SELECT
  DATE_TRUNC(t.tanggal, MONTH) AS bulan,

  -- Gross Revenue
  SUM(t.qty * t.harga_satuan) AS gross_revenue,

  -- Net Revenue setelah diskon
  SUM(
    t.qty * t.harga_satuan
    * (1 - t.diskon_pct / 100)
  ) AS net_revenue,

  -- HPP
  SUM(t.qty * p.harga_modal) AS hpp,

  -- Gross Profit
  SUM(
    t.qty * t.harga_satuan
    * (1 - t.diskon_pct / 100)
  )
  - SUM(t.qty * p.harga_modal) AS gross_profit

FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
  ON t.produk_id = p.produk_id

WHERE t.tanggal >= DATE '2025-01-01'
  AND t.tanggal <= DATE '2025-12-31'

GROUP BY bulan
ORDER BY bulan;

# MoM Revenue 

WITH per_bulan AS (
  SELECT
    DATE_TRUNC(t.tanggal, MONTH) AS bulan,

    SUM(t.qty * t.harga_satuan) AS gross_revenue,

    SUM(
      t.qty * t.harga_satuan
      * (1 - t.diskon_pct / 100)
    ) AS net_revenue,

    SUM(t.qty * p.harga_modal) AS hpp,

    SUM(
      t.qty * t.harga_satuan
      * (1 - t.diskon_pct / 100)
    ) - SUM(t.qty * p.harga_modal) AS gross_profit

  FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

  INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
    ON t.produk_id = p.produk_id

  WHERE t.tanggal >= DATE '2025-01-01'
    AND t.tanggal <= DATE '2025-12-31'

  GROUP BY bulan
)

SELECT
  bulan,
  gross_revenue,
  net_revenue,
  hpp,
  gross_profit,

  LAG(gross_revenue) OVER (
    ORDER BY bulan
  ) AS previous_gross_revenue,

  ROUND(
    SAFE_DIVIDE(
      gross_revenue
      - LAG(gross_revenue) OVER (ORDER BY bulan),
      LAG(gross_revenue) OVER (ORDER BY bulan)
    ) * 100,
    1
  ) AS mom_revenue_pct

FROM per_bulan

ORDER BY bulan;

#. MoM Gross Profit

WITH per_bulan AS (
  SELECT
    DATE_TRUNC(t.tanggal, MONTH) AS bulan,

    SUM(t.qty * t.harga_satuan) AS gross_revenue,

    SUM(
      t.qty * t.harga_satuan
      * (1 - t.diskon_pct / 100)
    ) AS net_revenue,

    SUM(t.qty * p.harga_modal) AS hpp,

    SUM(
      t.qty * t.harga_satuan
      * (1 - t.diskon_pct / 100)
    ) - SUM(t.qty * p.harga_modal) AS gross_profit

  FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

  INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
    ON t.produk_id = p.produk_id

  WHERE t.tanggal >= DATE '2025-01-01'
    AND t.tanggal <= DATE '2025-12-31'

  GROUP BY bulan
),

dengan_lag AS (
  SELECT
    *,
    LAG(gross_profit) OVER (
      ORDER BY bulan
    ) AS previous_gross_profit
  FROM per_bulan
)

SELECT
  bulan,
  gross_revenue,
  net_revenue,
  hpp,
  gross_profit,
  previous_gross_profit,

  ROUND(
    SAFE_DIVIDE(
      gross_profit - previous_gross_profit,
      previous_gross_profit
    ) * 100,
    1
  ) AS mom_profit_pct

FROM dengan_lag

ORDER BY bulan;

#. Gross Profit Per-Quarter 
SELECT
  CONCAT(
    'Q',
    CAST(EXTRACT(QUARTER FROM t.tanggal) AS STRING)
  ) AS quarter,

  SUM(
    t.qty * t.harga_satuan
    * (1 - t.diskon_pct / 100)
  ) AS net_revenue,

  SUM(t.qty * p.harga_modal) AS hpp,

  SUM(
    t.qty * t.harga_satuan
    * (1 - t.diskon_pct / 100)
  ) - SUM(t.qty * p.harga_modal) AS gross_profit

FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
  ON t.produk_id = p.produk_id

WHERE t.tanggal >= DATE '2025-01-01'
  AND t.tanggal <= DATE '2025-12-31'

GROUP BY quarter
ORDER BY quarter;

# % Gross Profit Per-Quarter 
WITH per_quarter AS (
  SELECT
    CONCAT(
      'Q',
      CAST(EXTRACT(QUARTER FROM t.tanggal) AS STRING)
    ) AS quarter,

    SUM(
      t.qty * t.harga_satuan
      * (1 - t.diskon_pct / 100)
    ) AS net_revenue,

    SUM(t.qty * p.harga_modal) AS hpp,

    SUM(
      t.qty * t.harga_satuan
      * (1 - t.diskon_pct / 100)
    ) - SUM(t.qty * p.harga_modal) AS gross_profit

  FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

  INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
    ON t.produk_id = p.produk_id

  WHERE t.tanggal >= DATE '2025-01-01'
    AND t.tanggal <= DATE '2025-12-31'

  GROUP BY quarter
),

dengan_lag AS (
  SELECT
    *,
    LAG(gross_profit) OVER (
      ORDER BY quarter
    ) AS previous_gross_profit
  FROM per_quarter
)

SELECT
  quarter,
  net_revenue,
  hpp,
  gross_profit,
  previous_gross_profit,

  ROUND(
    SAFE_DIVIDE(
      gross_profit - previous_gross_profit,
      previous_gross_profit
    ) * 100,
    1
  ) AS qoq_profit_pct

FROM dengan_lag

ORDER BY quarter;

#. Perbandingan Q3 vs Q4 
SELECT
  CONCAT(
    'Q',
    CAST(EXTRACT(QUARTER FROM t.tanggal) AS STRING)
  ) AS quarter,

  SUM(
    t.qty * t.harga_satuan
    * (1 - t.diskon_pct / 100)
  ) AS net_revenue,

  SUM(t.qty * p.harga_modal) AS hpp,

  SUM(
    t.qty * t.harga_satuan
    * (1 - t.diskon_pct / 100)
  ) - SUM(t.qty * p.harga_modal) AS gross_profit,

  ROUND(
    SAFE_DIVIDE(
      SUM(
        t.qty * t.harga_satuan
        * (1 - t.diskon_pct / 100)
      ) - SUM(t.qty * p.harga_modal),
      SUM(
        t.qty * t.harga_satuan
        * (1 - t.diskon_pct / 100)
      )
    ) * 100,
    1
  ) AS gross_margin_pct

FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
  ON t.produk_id = p.produk_id

WHERE t.tanggal >= DATE '2025-07-01'
  AND t.tanggal <= DATE '2025-12-31'

GROUP BY quarter
ORDER BY quarter;

#. Penyebab Profit, Turun 
# Breakdown Gross Profit Per-Kategori 
#. 1. Cek kolom Table Product 
SELECT
  column_name,
  data_type
FROM `data-analyst-seara-data.SearaData.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'Produk'
ORDER BY ordinal_position;

#. Breakdown Gross Profit Per-Kategori 
WITH data_quarter AS (
  SELECT
    p.kategori,

    CASE
      WHEN t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-09-30'
        THEN 'Q3'
      WHEN t.tanggal BETWEEN DATE '2025-10-01' AND DATE '2025-12-31'
        THEN 'Q4'
    END AS quarter,

    SUM(
      t.qty * t.harga_satuan
      * (1 - t.diskon_pct / 100)
    ) AS net_revenue,

    SUM(
      t.qty * p.harga_modal
    ) AS hpp,

    SUM(
      t.qty * t.harga_satuan
      * (1 - t.diskon_pct / 100)
    )
    - SUM(
      t.qty * p.harga_modal
    ) AS gross_profit

  FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

  INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
    ON t.produk_id = p.produk_id

  WHERE t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-12-31'

  GROUP BY
    p.kategori,
    quarter
)

SELECT
  kategori,
  quarter,
  net_revenue,
  hpp,
  gross_profit

FROM data_quarter

ORDER BY
  kategori,
  quarter;

  #. Hitung Profit Change Q4-Q3
WITH data_quarter AS (
  SELECT
    p.kategori,

    CASE
      WHEN t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-09-30'
        THEN 'Q3'
      WHEN t.tanggal BETWEEN DATE '2025-10-01' AND DATE '2025-12-31'
        THEN 'Q4'
    END AS quarter,

    SUM(
      t.qty * t.harga_satuan
      * (1 - t.diskon_pct / 100)
    )
    - SUM(
      t.qty * p.harga_modal
    ) AS gross_profit

  FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

  INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
    ON t.produk_id = p.produk_id

  WHERE t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-12-31'

  GROUP BY
    p.kategori,
    quarter
),

pivot_profit AS (
  SELECT
    kategori,

    SUM(
      CASE
        WHEN quarter = 'Q3' THEN gross_profit
        ELSE 0
      END
    ) AS profit_q3,

    SUM(
      CASE
        WHEN quarter = 'Q4' THEN gross_profit
        ELSE 0
      END
    ) AS profit_q4

  FROM data_quarter

  GROUP BY kategori
)

SELECT
  kategori,
  profit_q3,
  profit_q4,

  profit_q4 - profit_q3 AS profit_change,

  ROUND(
    SAFE_DIVIDE(
      profit_q4 - profit_q3,
      profit_q3
    ) * 100,
    1
  ) AS profit_change_pct

FROM pivot_profit

ORDER BY profit_change ASC;

#. % Kontribusi Kategori terhadap Penurunan Profit Total 
WITH profit_kategori AS (
  SELECT
    p.kategori,

    SUM(
      CASE
        WHEN t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-09-30'
        THEN
          t.qty * t.harga_satuan
          * (1 - t.diskon_pct / 100)
          - t.qty * p.harga_modal
        ELSE 0
      END
    ) AS profit_q3,

    SUM(
      CASE
        WHEN t.tanggal BETWEEN DATE '2025-10-01' AND DATE '2025-12-31'
        THEN
          t.qty * t.harga_satuan
          * (1 - t.diskon_pct / 100)
          - t.qty * p.harga_modal
        ELSE 0
      END
    ) AS profit_q4

  FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

  INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
    ON t.produk_id = p.produk_id

  WHERE t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-12-31'

  GROUP BY p.kategori
),

perubahan AS (
  SELECT
    kategori,
    profit_q3,
    profit_q4,
    profit_q4 - profit_q3 AS profit_change
  FROM profit_kategori
),

total_penurunan AS (
  SELECT
    SUM(ABS(profit_change)) AS total_decline
  FROM perubahan
  WHERE profit_change < 0
)

SELECT
  perubahan.kategori,
  perubahan.profit_q3,
  perubahan.profit_q4,
  perubahan.profit_change,

  ROUND(
    SAFE_DIVIDE(
      ABS(perubahan.profit_change),
      total_penurunan.total_decline
    ) * 100,
    1
  ) AS contribution_pct

FROM perubahan
CROSS JOIN total_penurunan

WHERE perubahan.profit_change < 0

ORDER BY contribution_pct DESC;

#. Penyebab Sofa dan Lemari Turun Profitnya
SELECT
  p.kategori,

  CASE
    WHEN t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-09-30'
      THEN 'Q3'
    WHEN t.tanggal BETWEEN DATE '2025-10-01' AND DATE '2025-12-31'
      THEN 'Q4'
  END AS quarter,

  SUM(
    t.qty * t.harga_satuan
    * (1 - t.diskon_pct / 100)
  ) AS net_revenue,

  SUM(
    t.qty * p.harga_modal
  ) AS hpp,

  SUM(
    t.qty * t.harga_satuan
    * (1 - t.diskon_pct / 100)
  )
  - SUM(
    t.qty * p.harga_modal
  ) AS gross_profit,

  ROUND(
    SAFE_DIVIDE(
      SUM(
        t.qty * t.harga_satuan
        * (1 - t.diskon_pct / 100)
      )
      - SUM(
        t.qty * p.harga_modal
      ),
      SUM(
        t.qty * t.harga_satuan
        * (1 - t.diskon_pct / 100)
      )
    ) * 100,
    1
  ) AS gross_margin_pct,

  ROUND(AVG(t.diskon_pct), 1) AS avg_discount_pct

FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
  ON t.produk_id = p.produk_id

WHERE t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-12-31'
  AND p.kategori IN ('Sofa', 'Lemari')

GROUP BY
  p.kategori,
  quarter

ORDER BY
  p.kategori,
  quarter;

  #. Pengaruh Kenaikan Discount untuk Sofa & Lemari 

SELECT
  p.kategori,

  CASE
    WHEN t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-09-30'
      THEN 'Q3'
    WHEN t.tanggal BETWEEN DATE '2025-10-01' AND DATE '2025-12-31'
      THEN 'Q4'
  END AS quarter,

  SUM(
    t.qty * t.harga_satuan
  ) AS gross_revenue,

  SUM(
    t.qty * t.harga_satuan
    * (t.diskon_pct / 100)
  ) AS discount_amount,

  SUM(
    t.qty * t.harga_satuan
    * (1 - t.diskon_pct / 100)
  ) AS net_revenue

FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
  ON t.produk_id = p.produk_id

WHERE t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-12-31'
  AND p.kategori IN ('Sofa', 'Lemari')

GROUP BY
  p.kategori,
  quarter

ORDER BY
  p.kategori,
  quarter;

  #. Analisa Produk mana di dalam Sofa dan Lemari yang paling besar menyebabkan kenaikan HPP?
  SELECT
  p.kategori,
  p.produk_id,
  p.nama_produk,

  SUM(
    CASE
      WHEN t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-09-30'
      THEN t.qty
      ELSE 0
    END
  ) AS qty_q3,

  SUM(
    CASE
      WHEN t.tanggal BETWEEN DATE '2025-10-01' AND DATE '2025-12-31'
      THEN t.qty
      ELSE 0
    END
  ) AS qty_q4,

  SUM(
    CASE
      WHEN t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-09-30'
      THEN t.qty * p.harga_modal
      ELSE 0
    END
  ) AS hpp_q3,

  SUM(
    CASE
      WHEN t.tanggal BETWEEN DATE '2025-10-01' AND DATE '2025-12-31'
      THEN t.qty * p.harga_modal
      ELSE 0
    END
  ) AS hpp_q4

FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
  ON t.produk_id = p.produk_id

WHERE t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-12-31'
  AND p.kategori IN ('Sofa', 'Lemari')

GROUP BY
  p.kategori,
  p.produk_id,
  p.nama_produk

ORDER BY
  (hpp_q4 - hpp_q3) DESC;

  #. Product dengan kontribusi terbesar 
  WITH product_quarter AS (
  SELECT
    p.kategori,
    p.produk_id,
    p.nama_produk,

    SUM(
      CASE
        WHEN t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-09-30'
        THEN
          t.qty * t.harga_satuan
          * (1 - t.diskon_pct / 100)
        ELSE 0
      END
    ) AS net_revenue_q3,

    SUM(
      CASE
        WHEN t.tanggal BETWEEN DATE '2025-10-01' AND DATE '2025-12-31'
        THEN
          t.qty * t.harga_satuan
          * (1 - t.diskon_pct / 100)
        ELSE 0
      END
    ) AS net_revenue_q4,

    SUM(
      CASE
        WHEN t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-09-30'
        THEN t.qty * p.harga_modal
        ELSE 0
      END
    ) AS hpp_q3,

    SUM(
      CASE
        WHEN t.tanggal BETWEEN DATE '2025-10-01' AND DATE '2025-12-31'
        THEN t.qty * p.harga_modal
        ELSE 0
      END
    ) AS hpp_q4

  FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

  INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
    ON t.produk_id = p.produk_id

  WHERE t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-12-31'
    AND p.kategori IN ('Sofa', 'Lemari')

  GROUP BY
    p.kategori,
    p.produk_id,
    p.nama_produk
)

SELECT
  kategori,
  produk_id,
  nama_produk,

  net_revenue_q3,
  net_revenue_q4,

  hpp_q3,
  hpp_q4,

  net_revenue_q3 - hpp_q3 AS gross_profit_q3,

  net_revenue_q4 - hpp_q4 AS gross_profit_q4,

  (net_revenue_q4 - hpp_q4)
  - (net_revenue_q3 - hpp_q3) AS profit_change

FROM product_quarter

ORDER BY profit_change ASC;

#. Product mana yang turun dan naik 
WITH product_profit AS (
  SELECT
    p.kategori,
    p.produk_id,
    p.nama_produk,

    SUM(
      CASE
        WHEN t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-09-30'
        THEN
          t.qty * t.harga_satuan
          * (1 - t.diskon_pct / 100)
          - t.qty * p.harga_modal
        ELSE 0
      END
    ) AS profit_q3,

    SUM(
      CASE
        WHEN t.tanggal BETWEEN DATE '2025-10-01' AND DATE '2025-12-31'
        THEN
          t.qty * t.harga_satuan
          * (1 - t.diskon_pct / 100)
          - t.qty * p.harga_modal
        ELSE 0
      END
    ) AS profit_q4

  FROM `data-analyst-seara-data.SearaData.Tranksaksi` AS t

  INNER JOIN `data-analyst-seara-data.SearaData.Produk` AS p
    ON t.produk_id = p.produk_id

  WHERE t.tanggal BETWEEN DATE '2025-07-01' AND DATE '2025-12-31'
    AND p.kategori IN ('Sofa', 'Lemari')

  GROUP BY
    p.kategori,
    p.produk_id,
    p.nama_produk
)

SELECT
  kategori,

  CASE
    WHEN profit_q3 > 0 AND profit_q4 = 0
      THEN 'Hilang di Q4'

    WHEN profit_q3 > 0 AND profit_q4 < profit_q3
      THEN 'Profit Turun'

    WHEN profit_q3 = 0 AND profit_q4 > 0
      THEN 'Produk Baru'

    WHEN profit_q4 > profit_q3
      THEN 'Profit Naik'

    ELSE 'Stabil'
  END AS status_produk,

  COUNT(*) AS jumlah_produk,

  SUM(profit_q3) AS total_profit_q3,
  SUM(profit_q4) AS total_profit_q4,

  SUM(profit_q4 - profit_q3) AS profit_change

FROM product_profit

GROUP BY
  kategori,
  status_produk

ORDER BY
  kategori,
  profit_change ASC;