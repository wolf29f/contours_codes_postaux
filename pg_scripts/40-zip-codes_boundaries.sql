BEGIN;

--
-- Génération des premiers contours à partir des IRIS associés aux codes postaux
--

-- Création de la table contours pour stocker les géométries des codes postaux
CREATE UNLOGGED TABLE IF NOT EXISTS contours (
    code_postal VARCHAR(5) UNIQUE NOT NULL,
    geom geometry
);

CREATE INDEX IF NOT EXISTS contours_code_postal_idx ON contours (code_postal);

CREATE INDEX IF NOT EXISTS contours_geom_idx ON contours USING GIST (geom);

-- Les IRIS sont regroupés par code postal
-- et les géométries sont fusionnées pour créer un contour unique par code postal
WITH iris_code_postal AS (
    SELECT code_postal,
        ST_Union(ST_MakeValid(iris_2024.geom)) AS geom
    FROM iris_2024
    GROUP BY code_postal
)
INSERT INTO contours (code_postal, geom)
SELECT code_postal,
    geom
FROM iris_code_postal
WHERE code_postal IS NOT NULL;

COMMIT;