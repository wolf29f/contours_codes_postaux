-- Ecrit le résultat de la requête au format CSV sur la sortie standard
-- La sortie est utilisé par le script appelant pour stocker dans un fichier
COPY (
    SELECT code_postal,
        ST_AsText(geom) AS wkt_geom
    FROM contours
) TO STDOUT WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');