#!/bin/bash

GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color

CWD="$(pwd)"

# ------------------------------------------------------------------------------
# Téléchargement, extraction, conversion et fusion des contours IRIS
# ------------------------------------------------------------------------------

iris_dir="data_src/Contours_IRIS_2024"
iris_csv="$iris_dir/iris_postgis.csv"

if [ -f "$iris_csv" ]; then
  echo -e "${YELLOW}✔️  Données IRIS déjà présentes (${iris_csv}), saut de l'étape.${NC}"
else
  echo -e "${CYAN}Téléchargement et préparation des contours IRIS...${NC}"

  declare -A urls=(
    ["France_metropolitaine"]="https://data.geopf.fr/telechargement/download/CONTOURS-IRIS/CONTOURS-IRIS_3-0__GPKG_LAMB93_FXX_2024-01-01/CONTOURS-IRIS_3-0__GPKG_LAMB93_FXX_2024-01-01.7z"
    ["Guadeloupe"]="https://data.geopf.fr/telechargement/download/CONTOURS-IRIS/CONTOURS-IRIS_3-0__GPKG_RGAF09UTM20_GLP_2024-01-01/CONTOURS-IRIS_3-0__GPKG_RGAF09UTM20_GLP_2024-01-01.7z"
    ["Martinique"]="https://data.geopf.fr/telechargement/download/CONTOURS-IRIS/CONTOURS-IRIS_3-0__GPKG_RGAF09UTM20_MTQ_2024-01-01/CONTOURS-IRIS_3-0__GPKG_RGAF09UTM20_MTQ_2024-01-01.7z"
    ["Guyane"]="https://data.geopf.fr/telechargement/download/CONTOURS-IRIS/CONTOURS-IRIS_3-0__GPKG_UTM22RGFG95_GUF_2024-01-01/CONTOURS-IRIS_3-0__GPKG_UTM22RGFG95_GUF_2024-01-01.7z"
    ["La_Reunion"]="https://data.geopf.fr/telechargement/download/CONTOURS-IRIS/CONTOURS-IRIS_3-0__GPKG_RGR92UTM40S_REU_2024-01-01/CONTOURS-IRIS_3-0__GPKG_RGR92UTM40S_REU_2024-01-01.7z"
    ["Saint_Pierre_et_Miquelon"]="https://data.geopf.fr/telechargement/download/CONTOURS-IRIS/CONTOURS-IRIS_3-0__GPKG_RGSPM06U21_SPM_2024-01-01/CONTOURS-IRIS_3-0__GPKG_RGSPM06U21_SPM_2024-01-01.7z"
    ["Mayotte"]="https://data.geopf.fr/telechargement/download/CONTOURS-IRIS/CONTOURS-IRIS_3-0__GPKG_RGM04UTM38S_MYT_2024-01-01/CONTOURS-IRIS_3-0__GPKG_RGM04UTM38S_MYT_2024-01-01.7z"
    ["Saint_Barthelemy"]="https://data.geopf.fr/telechargement/download/CONTOURS-IRIS/CONTOURS-IRIS_3-0__GPKG_RGAF09UTM20_BLM_2024-01-01/CONTOURS-IRIS_3-0__GPKG_RGAF09UTM20_BLM_2024-01-01.7z"
    ["Saint_Martin"]="https://data.geopf.fr/telechargement/download/CONTOURS-IRIS/CONTOURS-IRIS_3-0__GPKG_RGAF09UTM20_MAF_2024-01-01/CONTOURS-IRIS_3-0__GPKG_RGAF09UTM20_MAF_2024-01-01.7z"
  )

  mkdir -p "$iris_dir"
  cd "$iris_dir" || { echo -e "${RED}Erreur d'accès au dossier $iris_dir${NC}"; exit 1; }
  rm -f *.geojson all_iris.geojson iris_postgis.csv

  for region in "${!urls[@]}"; do
    echo -e "${CYAN}Traitement de la région : $region${NC}"
    mkdir -p "$region"
    cd "$region" || continue
    url="${urls[$region]}"
    filename=$(basename "$url")
    if [ ! -f "$filename" ]; then
      echo "Téléchargement de $filename..."
      curl -O "$url" || { echo -e "${RED}Échec du téléchargement de $filename${NC}"; cd "$CWD"; exit 1; }
    fi
    echo "Extraction de $filename..."
    7z x "$filename" > /dev/null || { echo -e "${RED}Échec de l'extraction de $filename${NC}"; cd "$CWD"; exit 1; }
    rm -f "$filename"
    gpkg_file=$(find . -type f -name "*.gpkg" | head -n 1)
    if [ -f "$gpkg_file" ]; then
      echo "Conversion en GeoJSON..."
      ogr2ogr -t_srs EPSG:4326 -f GeoJSON "../${region}.geojson" "$gpkg_file" || { echo -e "${RED}Échec de la conversion GeoJSON pour $region${NC}"; cd "$CWD"; exit 1; }
    else
      echo -e "${RED}Fichier .gpkg non trouvé dans $region${NC}"
    fi
    cd ..
  done

  echo "Fusion de tous les GeoJSON en un seul fichier..."
  ogrmerge.py -single -o all_iris.geojson *.geojson > /dev/null || { echo -e "${RED}Échec de la fusion GeoJSON${NC}"; cd "$CWD"; exit 1; }

  echo "Génération du CSV compatible PostGIS..."
  ogr2ogr -f CSV iris_postgis.csv all_iris.geojson -lco GEOMETRY=AS_WKT -select "code_insee,nom_commune,iris,code_iris,nom_iris" > /dev/null || { echo -e "${RED}Échec de la génération du CSV IRIS${NC}"; cd "$CWD"; exit 1; }

  echo -e "${GREEN}✔️  Données IRIS prêtes (${iris_csv})${NC}"
  cd "$CWD"
fi

# ------------------------------------------------------------------------------
# Téléchargement et extraction du fichier adresses-france.csv.gz
# ------------------------------------------------------------------------------

addr_dir="data_src/base_adresse_nationale"
addr_csv="$addr_dir/adresses-france.csv"

if [ -f "$addr_csv" ]; then
  echo -e "${YELLOW}✔️  Fichier adresses-france.csv déjà présent, saut de l'étape.${NC}"
else
  echo -e "${CYAN}Téléchargement des adresses nationales...${NC}"
  mkdir -p "$addr_dir"
  cd "$addr_dir" || { echo -e "${RED}Erreur d'accès au dossier $addr_dir${NC}"; exit 1; }
  url="https://adresse.data.gouv.fr/data/ban/adresses/latest/csv/adresses-france.csv.gz"
  filename="adresses-france.csv.gz"
  curl -O "$url" || { echo -e "${RED}Échec du téléchargement de $filename${NC}"; cd "$CWD"; exit 1; }
  echo "Extraction de ${filename}..."
  gunzip -f "$filename" || { echo -e "${RED}Échec de l'extraction de $filename${NC}"; cd "$CWD"; exit 1; }
  echo -e "${GREEN}✔️  Fichier extrait : ${addr_csv}${NC}"
  cd "$CWD"
fi

# ------------------------------------------------------------------------------
# Téléchargement du fichier CSV des communes
# ------------------------------------------------------------------------------

cities_dir="data_src/communes"
cities_csv="$cities_dir/v_commune_2025.csv"

if [ -f "$cities_csv" ]; then
  echo -e "${YELLOW}✔️  Fichier des communes déjà présent, saut de l'étape.${NC}"
else
  echo -e "${CYAN}Téléchargement des données des communes...${NC}"
  mkdir -p "$cities_dir"
  cd "$cities_dir" || { echo -e "${RED}Erreur d'accès au dossier $cities_dir${NC}"; exit 1; }
  url="https://www.data.gouv.fr/fr/datasets/r/91a95bee-c7c8-45f9-a8aa-f14cc4697545"
  filename="v_commune_2025.csv"
  curl -L -o "${filename}" "$url" || { echo -e "${RED}Échec du téléchargement de $filename${NC}"; cd "$CWD"; exit 1; }
  echo -e "${GREEN}✔️  Fichier téléchargé : ${cities_csv}${NC}"
  cd "$CWD"
fi

# ------------------------------------------------------------------------------
# Téléchargement du fichier CSV des codes postaux de La Poste
# ------------------------------------------------------------------------------

zip_dir="data_src/codes_postaux_laposte"
zip_csv="$zip_dir/base-officielle-codes-postaux.csv"

if [ -f "$zip_csv" ]; then
  echo -e "${YELLOW}✔️  Fichier codes postaux La Poste déjà présent, saut de l'étape.${NC}"
else
  echo -e "${CYAN}Téléchargement des codes postaux La Poste...${NC}"
  mkdir -p "$zip_dir"
  cd "$zip_dir" || { echo -e "${RED}Erreur d'accès au dossier $zip_dir${NC}"; exit 1; }
  url="https://datanova.laposte.fr/data-fair/api/v1/datasets/laposte-hexasmal/metadata-attachments/base-officielle-codes-postaux.csv"
  filename="base-officielle-codes-postaux.csv"
  curl -O "$url" || { echo -e "${RED}Échec du téléchargement de $filename${NC}"; cd "$CWD"; exit 1; }
  echo -e "${GREEN}✔️  Fichier téléchargé : ${zip_csv}${NC}"
  cd "$CWD"
fi

echo -e "${GREEN}🎉 Toutes les données sources sont prêtes à être utilisées !${NC}"
