BEGIN;

--
-- Création des contours à partir d'enveloppes concaves des adresses pour les 
-- codes postaux manquants
--

-- Génère et stocke les enveloppes dans une table temporaire
DROP TABLE IF EXISTS tmp_addr_hulls;

CREATE TEMP TABLE tmp_addr_hulls AS WITH addr_data AS (
    SELECT DISTINCT adresses_france.code_postal,
        adresses_france.geom,
        communes_2025.reg AS region_code
    FROM communes_2025
        LEFT JOIN adresses_france ON communes_2025.com = adresses_france.code_insee
    WHERE NOT EXISTS (
            SELECT 1
            FROM contours
            WHERE contours.code_postal = adresses_france.code_postal
        )
        AND adresses_france.code_postal IS NOT NULL
),
addr_clusters AS (
    SELECT code_postal,
        geom,
        ST_ClusterDBSCAN(
            ST_Transform(geom, coalesce(projections.srid, 2154)),
            eps := 2000,
            minpoints := 5
        ) OVER (PARTITION BY code_postal) AS cid
    FROM addr_data
        LEFT JOIN projections ON addr_data.region_code = projections.region_code
)
SELECT code_postal,
    cid,
    ST_ConcaveHull(ST_Collect(geom), 0.8) AS geom
FROM addr_clusters
WHERE cid IS NOT NULL
GROUP BY code_postal,
    cid;

CREATE INDEX tmp_addr_hulls_code_postal_idx ON tmp_addr_hulls (code_postal);

-- Soustrait la géométrie des enveloppes fusionnées aux contours existants afin 
-- d'éviter les supperpositions
WITH overall_hull AS (
    SELECT ST_Union(geom) AS geom
    FROM tmp_addr_hulls
)
UPDATE contours
SET geom = ST_Difference(contours.geom, overall_hull.geom)
FROM overall_hull;

-- Insère les nouveaux contours générés
INSERT INTO contours (code_postal, geom)
SELECT code_postal,
    ST_Union(geom) AS geom
FROM tmp_addr_hulls
GROUP BY code_postal;

INSERT INTO contours (code_postal, geom)
SELECT code_postal,
    ST_Centroid(ST_Collect(geom::geometry)) AS geom
FROM codes_postaux
WHERE code_postal IS NOT NULL
    AND NOT EXISTS (
        SELECT 1
        FROM contours
        WHERE codes_postaux.code_postal = contours.code_postal
    )
GROUP BY code_postal;

COMMIT;