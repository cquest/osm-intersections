#! /bin/bash

mv intersections.json.gz intersections-$(date -I -r intersections.json.gz).json.gz

psql osm -c "
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE TABLE IF NOT EXISTS osm_cog AS SELECT name, tags->'ref:INSEE' as insee, admin_level, way from planet_osm_polygon where tags ? 'ref:INSEE';
INSERT INTO osm_cog SELECT 'Rhône', '69', '6', ST_UnaryUnion(ST_Collect(way)) FROM osm_cog WHERE insee like '69%' and admin_level='6';
CREATE INDEX IF NOT EXISTS osm_cog_insee ON osm_cog (admin_level,insee);
CREATE INDEX IF NOT EXISTS osm_cog_geom ON osm_cog USING GIST (way);
"
psql osm -tA -c "select insee from osm_cog where admin_level='6' order by 1" | parallel ./intersections_dep.sh {}

cat intersections-*.json | gzip -9 > intersections.json.gz
rm *.json

find . -name '*.geojson.gz' -size -10240c -delete

mkdir -p intersections-geojson
mv *.geojson.gz intersections-geojson

rsync intersections*.gz osm13.openstreetmap.fr:/home/cquest/public_html/osm_poi/ -av
rsync intersections-geojson osm13.openstreetmap.fr:/home/cquest/public_html/osm_poi/ -av
