Sequel.migration do

  up do
    
    $stderr.puts("Running enrichers...")

    # Find all members for all relations
    osm_relation_members = <<-SQL
      UPDATE nodes 
        SET members = osm_rel_members_id(rels.members)
        FROM osm.planet_osm_rels AS rels
      WHERE nodes.cdk_id = 'r' || rels.id::text
    SQL

    $stderr.puts("\tosm_relation_members...")
    run osm_relation_members

    # In planet_osm_polygon, polygons that are constructed from
    # OSM relations have a negative ID
    # TODO: type=boundary, type=multipolygon (, type=? , type=? find more types!!!)
    # Add geometry data from planet_osm_polygon met id = -rel_id to node
    osm_enrich_polygons = <<-SQL
      UPDATE nodes 
      SET geom = way FROM (
        SELECT m.cdk_id, way FROM osm.planet_osm_polygon p, (
          SELECT
            nodes.cdk_id, 
            -substring(nodes.cdk_id from 2 for length(nodes.cdk_id))::integer AS id 
          FROM node_data, nodes
          WHERE
            node_data.node_id = nodes.id AND 
            (data @> '"type"=>"boundary"'::hstore OR data @> '"type"=>"multipolygon"'::hstore)
        ) AS m
        WHERE m.id = p.osm_id
      ) AS n
      WHERE nodes.cdk_id = n.cdk_id
    SQL

    $stderr.puts("\tosm_enrich_polygons...")
    run osm_enrich_polygons

    ################################################################################################
    ####    OSM routes + modalities    #############################################################
    ################################################################################################

    # Convert all OSM nodes with type=route to routes
    osm_routes = <<-SQL
      UPDATE nodes
      SET node_type = 1 FROM (
        SELECT DISTINCT nodes.cdk_id FROM node_data, nodes
        WHERE
          node_data.node_id = nodes.id AND 
          data @> '"type"=>"route"'::hstore
      ) AS n
      WHERE nodes.cdk_id = n.cdk_id
    SQL

    $stderr.puts("\tosm_routes...")
    run osm_routes

    # OSM provides data about route modalities. We can use those to 
    # set the modality of the nodes we've just converted to routes.
    #
    # SQL to get all route types that occur in OSM db: 
    #
    # SELECT string_agg(route, ', ') FROM (
    #      SELECT data->'route' AS route
    #      FROM node_data WHERE data @> '"type"=>"route"'::hstore
    #      GROUP BY data->'route'
    #      ORDER BY COUNT(data->'route') DESC ) r
    #
    # Output (for NL, Manchester, Finland, Portugal, Greece):
    #
    # bicycle, bus, foot, hiking, road, piste, walking, train, mtb, horse, railway, ferry, detour, power, tram, junction, ski, subway, snowmobile, rail, retail_bus, light_rail, trolleybus, fairway, canal, pipeline, bicycle;foot, wheelchair, tourism, foot;bicycle;horse, disused_bus, inline_skates, tourist_train, historic, running, XXXbicycle, foot;bicycle, riding, bicycle;horse;foot, bicycle;foot;horse, abandoned:railway, canoe, tracks, bridleway, not_bus, construction:tram, deprecated_foot, roman_road, trail, narrow_gauge, abandoned, foot;horse, night bus, cycle, cruise, shuttle_train, Blessington to Hollywood Village, ring_road, multiaccess, disused_railway, track, orienteering, miniature_railway, tour, historic_railway, cycling, Running, path, guided bus, horse;foot, former bus route, maritime, whitewater
    #
    # CitySDK modalities (from 002_insert_constants.rb):
    # [0, 'Tram, Streetcar, Light rail'])
    # [1, 'Subway, Metro'])
    # [2, 'Rail'])
    # [3, 'Bus'])
    # [4, 'Ferry'])
    # [5, 'Cable car'])
    # [6, 'Gondola, Suspended cable car'])
    # [7, 'Funicular'])
    # [109, 'Airplane '])
    # [110, 'Foot, walking'])
    # [111, 'Bicycle'])
    # [112, 'Light motorbike, moped'])
    # [113, 'Motorbike'])
    # [114, 'Car'])
    # [115, 'Truck'])
    # [200, 'Any'])
    
    # Array to map most important modalities from OSM to CitySDK
    # Contains tuples [from OSM, to CitySDK]
    modalities = [
      [
        [ 
          'tracks',
          'walking',
          'foot',
          'hiking',
          'Running',
          'path'
        ],
        [110] # foot
      ],
      [
        [
          'foot;bicycle',
          'bridleway'
        ],
        [110,111] # foot, bike
      ],
      [
        [
          'bicycle',
          'XXXbicycle',
          'cycling',
          'mtb'
        ],
        [111] # bike
      ],
      [
        [
          'bus',
          'trolleybus',
          'night bus'
        ],
        [3] # bus
      ],
      [
        [
          'railway',
          'rail',
          'train'
        ],
        [2] # train
      ],
      [
        [
          'subway'
        ],
        [1] # subway
      ],
      [      
        [
          'light_rail',
          'tram'
        ],
        [0] # tram
      ],
      [
        [
          'ferry'
        ],
        [4] # ferry
      ],
      [
        [
          'road'
        ],
        [114] # car
      ]      
    ]
      
    set_nodes_modalities = <<-SQL
      UPDATE nodes SET modalities = %s 
      FROM node_data
       WHERE nodes.id = node_data.node_id AND (%s);
    SQL

    set_node_data_modalities = <<-SQL
      UPDATE node_data SET modalities = %s WHERE %s;
    SQL
      
    $stderr.puts("\tosm_modalities...")
   
    # Loop modalities array, run UPDATE for each entry
    modalities.each { |modality| 
      from = modality[0]
      to = modality[1]
  
      array = "ARRAY[%s]" % [to.join(",")]
      hstores = from.map { |type|    
        "data @> '\"route\"=>\"#{type}\"'::hstore"
      }.join(" OR ")
  
      run << set_nodes_modalities % [array, hstores]
      run << set_node_data_modalities % [array, hstores]
    }
    
    ################################################################################################
    ####    Routes need a geometry too!    #########################################################
    ################################################################################################
    
    $stderr.puts("\troute_geometries...")
    
    route_geometries = <<-SQL
      UPDATE nodes
      SET geom = route_geometry(members)
      WHERE members IS NOT NULL AND members != '{}' AND node_type IN (1, 3) AND geom IS NULL;
    SQL
    
    run << route_geometries

    ########################################################################################
    ########################################################################################
 
    run <<-SQL 
      UPDATE layers SET imported_at = now() WHERE name = 'osm'
    SQL
 
  end

  down do
    # Undo enrich operations
  end
end
