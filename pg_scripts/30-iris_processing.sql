BEGIN;

-- Ajoute d'une colonne pour associer les codes postaux aux IRIS
ALTER TABLE iris_2024
ADD COLUMN code_postal VARCHAR(5);

-- Associe le code postal si le code insee n'est associé qu'à un seul code postal
WITH agg AS (
    SELECT iris_2024.code_insee,
        array_agg(DISTINCT codes_postaux.code_postal) AS codes
    FROM iris_2024
        JOIN codes_postaux ON trim(
            LEADING '0'
            FROM codes_postaux.code_commune_insee
        ) = trim(
            LEADING '0'
            FROM iris_2024.code_insee
        )
    WHERE iris_2024.code_postal IS NULL
    GROUP BY iris_2024.code_insee
)
UPDATE iris_2024
SET code_postal = codes [1]
FROM agg
WHERE iris_2024.code_insee = agg.code_insee
    AND cardinality(codes) = 1;

-- Associe le code postal le plus fréquent pour les IRIS sans code postal
UPDATE iris_2024
SET code_postal = (
        SELECT code_postal
        FROM adresses_france
        WHERE ST_Contains(iris_2024.geom, adresses_france.geom)
        GROUP BY code_postal
        ORDER BY COUNT(*) DESC
        LIMIT 1
    )
WHERE code_postal IS NULL;

COMMIT;