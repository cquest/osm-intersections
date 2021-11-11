#! /bin/bash

DEP=$1

# export intersection noms de rues / routes d'un département

rm -f intersections-$DEP.json
    DEP_NAME=$(psql osm -tA -c "select replace(name,E'\x27','\x27') from osm_cog where insee='$DEP' and admin_level='6'")
    # recherche des communes du département
    for COM in $(psql osm -tA -c "select insee from osm_cog where insee like '$DEP%' and admin_level='8' order by 1")
    do
        psql osm -tA -c "
            select row_to_json(i) from (
                select
                    'inter' as type,
                    name, context, citycode, depcode,
                    round(st_x(geom)::numeric,6) as lon,
                    round(st_y(geom)::numeric,6) as lat
                from (
                    select
                        trim(format('%s %s',coalesce(l.name,''),coalesce(replace(l.ref,' ',''))))
                        ||' / '||
                        trim(format('%s %s',coalesce(l2.name,''),coalesce(replace(l2.ref,' ','')))) as name,
                        format(E'%s, $DEP_NAME',p.name) as context,
                        '$COM' as citycode,
                        '$DEP' as depcode,
                        St_Transform(st_centroid(st_collect(st_intersection(st_buffer(l.way,20),st_buffer(l2.way,20)))),4326) as geom
                    from
                        osm_cog p
                    join
                        planet_osm_line l on (l.way && p.way and st_intersects(p.way,st_centroid(l.way)))
                    join
                        planet_osm_line l2 on (l2.way && p.way and st_dwithin(l.way, l2.way, 20))
                    where
                        p.insee = '$COM' and p.admin_level='8' 
                        and l.highway is not null
                        and (l.name is not null or l.ref is not null)
                        and l2.highway is not null
                        and (l2.name is not null or l2.ref is not null)
                        and (l2.name != l.name or l2.ref != l.ref)
                        and l.osm_id < l2.osm_id
                    group by 1,2,3,4
                ) as i
            ) as i;
        " >> intersections-$DEP.json
    done
echo "$DEP $DEP_NAME: $(wc -l intersections-$DEP.json)"

