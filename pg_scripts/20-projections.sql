BEGIN;

--
-- Création de la table projections pour les régions d'outre-mer
-- Les projections sont utilisés pour les calcules de distances métriques
-- la nature sphérique de la Terre rend nécessaire l'utilisation de projections
-- spécifiques selon les régions
--

CREATE UNLOGGED TABLE IF NOT EXISTS projections (
    id SERIAL PRIMARY KEY,
    region_name TEXT NOT NULL,
    region_code TEXT,
    srid INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS projections_region_code_idx ON projections (region_code);

INSERT INTO projections (region_name, region_code, srid)
VALUES ('Guadeloupe', '1', 2970);

INSERT INTO projections (region_name, region_code, srid)
VALUES ('Martinique', '2', 2973);

INSERT INTO projections (region_name, region_code, srid)
VALUES ('Guyane', '3', 2972);

INSERT INTO projections (region_name, region_code, srid)
VALUES ('La Réunion', '4', 2975);

INSERT INTO projections (region_name, region_code, srid)
VALUES ('Mayotte', '6', 4471);

COMMIT;