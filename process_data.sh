#!/bin/bash

GREEN='\033[1;32m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m' # No Color

set -e

error_exit() {
    echo -e "${RED}❌ Une erreur est survenue à l'étape : $1${NC}"
    docker compose down
    exit 1
}

trap 'error_exit "$BASH_COMMAND"' ERR

echo -e "${CYAN}Démarrage des conteneurs Docker...${NC}"
docker compose up --wait

echo -e "${GREEN}✔️  Docker est prêt !${NC}"

docker compose exec postgis psql -U postgres -d gis -f /pg_scripts/10-init.sql
echo -e "${GREEN}✔️  Initialisation des données chargée avec succès.${NC}"

docker compose exec postgis psql -U postgres -d gis -f /pg_scripts/20-projections.sql
echo -e "${GREEN}✔️  Projections chargées avec succès.${NC}"

docker compose exec postgis psql -U postgres -d gis -f /pg_scripts/30-iris_processing.sql
echo -e "${GREEN}✔️  Traitement IRIS terminé.${NC}"

docker compose exec postgis psql -U postgres -d gis -f /pg_scripts/40-zip-codes_boundaries.sql
echo -e "${GREEN}✔️  Contours codes postaux générés.${NC}"

docker compose exec postgis psql -U postgres -d gis -f /pg_scripts/50-cluster-based_boundaries.sql
echo -e "${GREEN}✔️  Contours clusterisés générés.${NC}"

echo -e "${CYAN}Export des résultats vers contours.csv en cours...${NC}"
mkdir -p ./data_dst
docker compose exec postgis psql -U postgres -d gis -f /pg_scripts/90-export_result.sql > ./data_dst/contours.csv

echo -e "${CYAN}Export des résultats vers contours.geojson en cours...${NC}"
docker compose exec postgis psql --no-align --quiet --tuples-only -U postgres -d gis -f /pg_scripts/100-raw_geojson.sql > ./data_dst/contours.geojson

echo -e "${CYAN}Création de l'archive des résultats...${NC}"
7z a -t7z ./data_dst/contours_csv.7z ./data_dst/contours.csv
7z a -t7z ./data_dst/contours_geojson.7z ./data_dst/contours.geojson
echo -e "${GREEN}✔️  Archive des résultats créée avec succès.${NC}"

echo -e "${GREEN}✔️  Export des résultats terminé.${NC}"

docker compose down
echo -e "${CYAN}Arrêt des conteneurs Docker. À bientôt.${NC}"
