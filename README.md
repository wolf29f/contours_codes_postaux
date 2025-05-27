# Contours par codes postaux

Ce dépôt fournit des contours géographiques pour les codes postaux français (France métropolitaine et DROM), générés à partir de sources ouvertes et d’une méthodologie reproductible.

> [!Important]
> Certains territoires d'outre-mer sont inclus, mais n'ont pas de contours (ex. : Nouvelle-Calédonie).

---

## Sommaire

- [Contours par codes postaux](#contours-par-codes-postaux)
  - [Sommaire](#sommaire)
  - [Contexte](#contexte)
  - [Prérequis](#prérequis)
    - [Installation des dépendances sur Ubuntu](#installation-des-dépendances-sur-ubuntu)
  - [Installation](#installation)
  - [Détail de la solution](#détail-de-la-solution)
  - [Utilisation](#utilisation)
    - [Traitement complet](#traitement-complet)
    - [Exécution étape par étape](#exécution-étape-par-étape)
  - [Structure du projet](#structure-du-projet)
  - [Résultats](#résultats)
  - [Sources de données](#sources-de-données)
  - [Liens utiles](#liens-utiles)
  - [Licence](#licence)
  - [Contribuer](#contribuer)

---

## Contexte

Les codes postaux sont largement utilisés pour localiser des zones géographiques, mais ils ne correspondent pas à des limites administratives fixes. Leur définition évolue et peut être ambiguë. Ce projet vise à générer des contours fiables pour chaque code postal, utilisables pour la cartographie, l’analyse spatiale ou la prospection.

---

## Prérequis

- [Docker](https://www.docker.com/)
- [docker-compose](https://docs.docker.com/compose/)
- [7z (p7zip)](https://p7zip.sourceforge.net/)
- [GDAL/ogr2ogr](https://gdal.org/)
- `curl`, `gunzip`, `bash`, `find`

### Installation des dépendances sur Ubuntu

```bash
sudo apt update
sudo apt install -y docker.io docker-compose p7zip-full gdal-bin curl
```

---

## Installation

1. **Clonez le dépôt :**
   ```bash
   git clone https://github.com/wolf29f/contours_codes_postaux.git
   cd contours_codes_postaux
   ```

2. **Téléchargez et préparez les données sources :**
   ```bash
   bash load_dataset.sh
   ```

---

## Détail de la solution

Le traitement s’appuie sur plusieurs sources et combine différentes stratégies pour obtenir des contours pertinents pour chaque code postal. Voici les grandes étapes, fidèles à la logique du projet :

1. **Téléchargement et préparation des données sources**
   - Contours IRIS (IGN)
   - Base Adresse Nationale (adresses)
   - Codes postaux officiels (La Poste)
   - Communes (data.gouv.fr)

2. **Import et préparation dans PostgreSQL/PostGIS**
   - Les données sont importées dans une base PostGIS via Docker.

3. **Association des codes postaux aux IRIS via les codes INSEE**
   - Les adresses sont croisées avec les IRIS à l’aide du code INSEE de la commune.
   - Pour chaque IRIS, si le code INSEE n'est associé qu'à un unique code postal, l'IRIS est associé à ce code.

4. **Association des codes postaux aux IRIS via les adresses**
   - Pour chaque IRIS sans code postal, on regroupe les adresses situées dans la zone de l'IRIS par code postal.
   - Le code postal ayant le plus d'adresses est retenu.

5. **Fusion des codes IRIS**
   - On fusionne les IRIS regroupés par code postal et on enregistre le résultat en base de données.

6. **Traitement par cluster d'adresses**
   - Pour les codes postaux non couverts par les IRIS, les adresses sont regroupées par code postal et clusterisées (DBSCAN) pour générer des polygones concaves.
   - Les projections métriques adaptées sont appliquées selon la région.
   - Les enveloppes sont soustraites aux contours déjà calculés à partir des IRIS pour éviter tout recouvrement.
   - Les enveloppes sont enregistrées et associées à leur code postal.

7. **Gestion des cas particuliers**
   - Pour les codes postaux sans adresse ou sans cluster, le centroïde de la commune ou une position connue est utilisé.

8. **Export des résultats**
   - Les contours sont exportés au format CSV (WKT) et GeoJSON, prêts à être utilisés.

> [!Warning]
> Si le résultat est globalement satisfaisant, la dernière étape, basée sur le clustering d'adresses, peut produire des contours parfois chaotiques et peut "trouer" des contours IRIS à cause d'adresses mélangées dans une zone réduite.  
> Malgré tout, cette étape est obligatoire, car certains codes postaux seraient absorbés par des zones IRIS ayant un autre code majoritaire.

---

## Utilisation

### Traitement complet

Pour lancer l'ensemble du traitement et générer les fichiers de résultats :

```bash
bash process_data.sh
```

Les résultats seront disponibles dans le dossier `data_dst/`.

> [!Note]
> Le dossier `config` contient une configuration Postgres optimisée pour le traitement sur mon ordinateur. Il peut être nécessaire de l'adapter selon vos spécifications.

### Exécution étape par étape

Vous pouvez aussi exécuter les scripts SQL un par un via Docker Compose :

```bash
docker compose exec postgis psql -U postgres -d gis -f /pg_scripts/10-init.sql
# ... puis les autres scripts dans l'ordre ...
```

---

## Structure du projet

- `data_src/` : Données sources téléchargées (IRIS, adresses, codes postaux, communes)
- `data_dst/` : Résultats générés (`contours.csv`, `contours.geojson`)
- `pg_scripts/` : Scripts SQL pour le traitement des données
- `load_dataset.sh` : Script de téléchargement et de préparation des données sources
- `process_data.sh` : Script principal d'exécution du traitement

---

## Résultats

- **contours.csv** : Fichier CSV contenant pour chaque code postal le contour au format WKT.
- **contours.geojson** : Fichier GeoJSON contenant tous les contours, chaque entité ayant le code postal dans ses propriétés.

Exemple d'utilisation :  
Vous pouvez visualiser le fichier GeoJSON dans [geojson.io](https://geojson.io/) ou l'importer dans [QGIS](https://qgis.org/).

> [!Warning]
> Le fichier GeoJSON est volumineux et peux être difficile à afficher sur certaines machines.

---

## Sources de données

- [Contours IRIS - IGN](https://geoservices.ign.fr/contoursiris)
- [Base Adresse Nationale](https://adresse.data.gouv.fr/data/ban/adresses/latest)
- [Codes postaux officiels La Poste](https://www.data.gouv.fr/fr/datasets/base-officielle-des-codes-postaux/)
- [Communes - data.gouv.fr](https://www.data.gouv.fr/fr/datasets/code-officiel-geographique-cog/)

---

## Liens utiles

- [Documentation PostGIS](https://postgis.net/documentation/)
- [Documentation GDAL/ogr2ogr](https://gdal.org/programs/ogr2ogr.html)
- [DBSCAN (PostGIS)](https://postgis.net/docs/ST_ClusterDBSCAN.html)
- [GeoJSON format](https://geojson.org/)
- [QGIS - SIG libre](https://qgis.org/)

---

## Licence

Ce projet est sous licence GPL-3.0. Voir le fichier [LICENSE](LICENSE) pour plus d'informations.

---

## Contribuer

Les contributions sont les bienvenues !  
N'hésitez pas à ouvrir une issue ou une pull request pour proposer des améliorations, corriger des bugs ou ajouter de nouvelles fonctionnalités.