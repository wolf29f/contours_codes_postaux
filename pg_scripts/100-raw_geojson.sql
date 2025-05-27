-- Extrait l'ensemble des contours au format geojson
SELECT json_build_object(
        'type',
        'FeatureCollection',
        'features',
        array_agg(
            json_build_object(
                'type',
                'Feature',
                'geometry',
                ST_AsGeoJSON(geom)::json,
                'properties',
                json_build_object(
                    'code_postal',
                    code_postal
                )
            )
        )
    )
FROM contours;