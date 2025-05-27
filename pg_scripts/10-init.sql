BEGIN;

--
-- Création des tables pour les données géographiques et chargements via COPY
--

-- Création de la table iris sans typage direct de la géométrie
CREATE TEMP TABLE iris_2024_raw (
    WKT TEXT,
    code_insee TEXT,
    nom_commune TEXT,
    iris TEXT,
    code_iris TEXT,
    nom_iris TEXT
);

-- Import des données
COPY iris_2024_raw
FROM '/data_src/Contours_IRIS_2024/iris_postgis.csv' DELIMITER ',' CSV HEADER;

-- Création de la table finale avec géométrie
CREATE UNLOGGED TABLE iris_2024 AS
SELECT code_insee,
    nom_commune,
    iris,
    code_iris,
    nom_iris,
    ST_GeomFromText(wkt, 4326) AS geom
FROM iris_2024_raw;

-- Suppression de la table temporaire
DROP TABLE iris_2024_raw;

-- Creation de la table adresses_france
CREATE UNLOGGED TABLE adresses_france (
    id TEXT,
    id_fantoir TEXT,
    numero TEXT,
    rep TEXT,
    nom_voie TEXT,
    code_postal TEXT,
    code_insee TEXT,
    nom_commune TEXT,
    code_insee_ancienne_commune TEXT,
    nom_ancienne_commune TEXT,
    x DOUBLE PRECISION,
    y DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    lat DOUBLE PRECISION,
    type_position TEXT,
    alias TEXT,
    nom_ld TEXT,
    libelle_acheminement TEXT,
    nom_afnor TEXT,
    source_position TEXT,
    source_nom_voie TEXT,
    certification_commune TEXT,
    cad_parcelles TEXT
);

-- Import des données depuis le fichier CSV
COPY adresses_france
FROM '/data_src/base_adresse_nationale/adresses-france.csv' DELIMITER ';' CSV HEADER ENCODING 'UTF8';

-- Ajout d'une colonne géométrique pour les adresses
ALTER TABLE adresses_france
ADD COLUMN geom geometry(Point, 4326);

-- Mise à jour de la colonne géométrique avec les coordonnées longitude et latitude
UPDATE adresses_france
SET geom = ST_SetSRID(ST_MakePoint(lon, lat), 4326)
WHERE lon IS NOT NULL
    AND lat IS NOT NULL;

-- Creation de la table codes_postaux
CREATE UNLOGGED TABLE codes_postaux (
    code_commune_insee TEXT,
    nom_de_la_commune TEXT,
    code_postal TEXT,
    libelle_d_acheminement TEXT,
    ligne_5 TEXT,
    geopoint TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
);

-- Import des données depuis le fichier CSV
COPY codes_postaux
FROM '/data_src/codes_postaux_laposte/base-officielle-codes-postaux.csv' DELIMITER ',' CSV HEADER ENCODING 'UTF8';

-- Ajout d'une colonne géométrique pour les codes postaux
ALTER TABLE codes_postaux
ADD COLUMN geom geometry(Point, 4326);

-- Mise à jour de la colonne géométrique avec les coordonnées longitude et latitude
UPDATE codes_postaux
SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
WHERE longitude IS NOT NULL
    AND latitude IS NOT NULL;

CREATE UNLOGGED TABLE communes_2025 (
    typecom TEXT,
    com TEXT,
    reg TEXT,
    dep TEXT,
    ctcd TEXT,
    arr TEXT,
    tncc TEXT,
    ncc TEXT,
    nccenr TEXT,
    libelle TEXT,
    can TEXT,
    comparent TEXT
);

COPY communes_2025
FROM '/data_src/communes/v_commune_2025.csv' DELIMITER ',' CSV HEADER ENCODING 'UTF8';

--
-- Création des index
--

-- Index spatial pour accélérer ST_Contains
CREATE INDEX idx_adresses_france_geom ON adresses_france USING GIST (geom);

-- Index spatial sur iris_2024 si absent
CREATE INDEX idx_iris_2024_geom ON iris_2024 USING GIST (geom);

-- Index sur code_insee pour les jointures et mises à jour
CREATE INDEX idx_iris_2024_code_insee ON iris_2024 (code_insee);

-- Index sur code_commune_insee pour la table codes_postaux
CREATE INDEX idx_codes_postaux_code_commune_insee ON codes_postaux (code_commune_insee);

-- Index sur code_postal pour les group by et recherches
CREATE INDEX idx_adresses_france_code_postal ON adresses_france (code_postal);

CREATE INDEX idx_codes_postaux_code_postal ON codes_postaux (code_postal);

COMMIT;