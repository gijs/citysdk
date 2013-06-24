Sequel.migration do

  up do

    $stderr.puts("Creating functions...")

    # Create database functions
    
    # Returns index of item in array. Same as Array.index in Ruby.
    idx = <<-SQL
      DROP FUNCTION IF EXISTS idx(anyarray, anyelement);
      CREATE OR REPLACE FUNCTION idx(anyarray, anyelement)
        RETURNS int AS 
      $$
        SELECT i FROM (
           SELECT generate_series(array_lower($1,1),array_upper($1,1))
        ) g(i)
        WHERE $1[i] = $2
        LIMIT 1;
      $$ LANGUAGE sql IMMUTABLE;
    SQL

    run idx
    
    # In planet_osm_rels, members column is organised like this:
    # "{w8164451,inner,w6242601,outer}"
    # First item and every second item the first are OSM nodes,
    # other items are the nodes' role in the relation:
    #   http://wiki.openstreetmap.org/wiki/Relation#Roles
    #
    # osm_rel_members returns array with only OSM nodes.
    osm_rel_members = <<-SQL
      DROP FUNCTION IF EXISTS osm_rel_members(members text[]);
      CREATE OR REPLACE FUNCTION osm_rel_members(members text[]) 
      RETURNS text[]
      AS $$
      BEGIN
        RETURN array(SELECT members[i]
          FROM generate_series(array_lower(members, 1), array_upper(members, 1), 2) g(i));
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run osm_rel_members

    # Looks up the internal integer id used by the API from the nodes
    # table that matches the OSM id from the array.
    osm_rel_members_id = <<-SQL
      DROP FUNCTION IF EXISTS osm_rel_members_id(members text[]);
      CREATE OR REPLACE FUNCTION osm_rel_members_id(members text[]) 
      RETURNS bigint[]
      AS $$
      BEGIN
        RETURN array(
          SELECT id FROM nodes 
          JOIN (SELECT unnest(osm_rel_members(members)) AS cdk_id) n
          USING (cdk_id)        
        );
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run osm_rel_members_id

    derived_geometry = <<-SQL
      CREATE OR REPLACE FUNCTION derived_geometry(_geoms geometry[]) 
      RETURNS geometry
      AS $$
      DECLARE
        _gt text;
        _collection geometry;
        _points geometry;
        _lines geometry;
        _polygons geometry;        
      BEGIN
        _collection := ST_Collect(_geoms);
        
        _points := ST_CollectionExtract(_collection, 1);
        _lines := ST_CollectionExtract(_collection, 2);
        _polygons := ST_CollectionExtract(_collection, 3);
        
        IF ST_IsEmpty(_polygons) IS FALSE THEN
          RETURN ST_SetSRID(ST_Envelope(_collection), 4326); -- Of multipolygon from separate bboxes?
        ELSIF ST_IsEmpty(_lines) IS FALSE THEN -- lines (and maybe points)
          --SELECT ST_SetSRID(ST_MakeLine(array_agg(geom)), 4326) INTO _lines 
          --FROM ST_DumpPoints(_collection);  
          RETURN _lines; 
        ELSE -- only points
          RETURN ST_SetSRID(ST_Union(_geoms), 4326);
        END IF;
        
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL
      
    run derived_geometry

    route_geometry = <<-SQL
      CREATE OR REPLACE FUNCTION route_geometry(members bigint[]) 
      RETURNS geometry
      AS $$
      BEGIN
        RETURN derived_geometry(array_agg(geom)) FROM nodes JOIN 
          (SELECT unnest(members) AS id) i
        USING (id);
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run route_geometry

    # Returns internal ids from array of cdk_ids
    cdk_ids_to_internal = <<-SQL
      CREATE OR REPLACE FUNCTION cdk_ids_to_internal(cdk_ids text[]) 
      RETURNS bigint[]
      AS $$
      DECLARE
        _ids bigint[];
      BEGIN
        _ids = array(
          SELECT id FROM nodes 
          JOIN (SELECT unnest(cdk_ids) AS cdk_id) m
          ON m.cdk_id = nodes.cdk_id
        );
        IF array_length(cdk_ids, 1) != array_length(_ids, 1) THEN	
          FOR i IN array_lower(cdk_ids, 1) .. array_upper(cdk_ids, 1)
          LOOP
            IF cdk_id_to_internal(cdk_ids[i]) IS NULL THEN
              RAISE EXCEPTION 'Nonexistent cdk_id --> %', cdk_ids[i];
            END IF;
          END LOOP;			
        END IF;
        RETURN _ids;
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run cdk_ids_to_internal

    cdk_id_to_internal = <<-SQL
    CREATE OR REPLACE FUNCTION cdk_id_to_internal(_cdk_id text) 
      RETURNS bigint    
      AS $$
        DECLARE
          _id bigint;
        BEGIN        
          SELECT id INTO _id FROM nodes 
          WHERE _cdk_id = cdk_id;
          IF _id IS NULL THEN
            RAISE EXCEPTION 'Nonexistent cdk_id --> %', _cdk_id;
          END IF;
          RETURN _id;        
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run cdk_id_to_internal

    # Returns a GeometryCollection of all the geometries of the node's members
    # (for now, only one level deep.)
    # GeometryCollections cannot be used in ST_Contains etc...
    collect_member_geometries = <<-SQL
      CREATE OR REPLACE FUNCTION collect_member_geometries(members bigint[]) 
      RETURNS geometry
      AS $$
      BEGIN
        RETURN ST_Collect(geom) FROM nodes JOIN 
          (SELECT unnest(members) AS id) i
        USING (id);
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run collect_member_geometries
    
    # Returns all rows in nodes with node_type = 1 (route)
    # with all members contained by g
    contains_routes = <<-SQL
      CREATE OR REPLACE FUNCTION contains_routes(_geom geometry) 
      RETURNS SETOF nodes
      AS $$
      BEGIN
        RETURN QUERY
          SELECT * FROM nodes 
          WHERE cdk_id = ANY(
            SELECT m.cdk_id FROM (
              SELECT cdk_id, unnest(members) AS member_node_id
              FROM nodes
              WHERE node_type = 1 AND
              -- First filter out all routes that are outside 
              -- of g's bounding box   
              -- (fast because of index on collect_member_geometries(members))
              collect_member_geometries(members) @ _geom
            ) m
            JOIN nodes n ON member_node_id = n.id
            GROUP BY m.cdk_id
            HAVING every(ST_Intersects(_geom, geom))
          );        
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run contains_routes

    # Returns all member nodes of input cdk_id    
    member_nodes = <<-SQL
      CREATE OR REPLACE FUNCTION member_nodes(_cdk_id text) 
        RETURNS SETOF nodes
        AS $$
        BEGIN
          RETURN QUERY
            SELECT * FROM nodes WHERE (
              id = ANY(
                (
                  SELECT members 
                  FROM nodes 
                  WHERE cdk_id = _cdk_id       
                )
              ) 
            );
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run member_nodes

    # Returns all routes which have input node_id in members
    has_member = <<-SQL
      CREATE OR REPLACE FUNCTION has_member(_node_id bigint) 
      RETURNS SETOF nodes
      AS $$
      BEGIN
        RETURN QUERY
          SELECT DISTINCT nodes.* FROM nodes WHERE members @> ARRAY[_node_id];        
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run has_member

    get_members = <<-SQL
      CREATE OR REPLACE FUNCTION get_members(_cdk_id text) 
      RETURNS bigint[]
      AS $$
        BEGIN
          RETURN (
            SELECT members 
            FROM nodes 
            WHERE cdk_id = _cdk_id       
          );
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run get_members

    get_start_end = <<-SQL
      CREATE OR REPLACE FUNCTION get_start_end(_cdk_id text) 
      RETURNS bigint[]
      AS $$
        BEGIN
          RETURN (
            SELECT ARRAY[members[array_lower(members, 1)], members[array_upper(members, 1)]] 
            FROM nodes 
            WHERE cdk_id = _cdk_id       
          );
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run get_start_end

    # Returns all routes which share members with input node_id
    route_members_overlap = <<-SQL
      CREATE OR REPLACE FUNCTION route_members_overlap(_node_id bigint) 
      RETURNS SETOF nodes
      AS $$
      BEGIN
        RETURN QUERY
          SELECT DISTINCT nodes.* FROM nodes JOIN 
            (SELECT unnest(members) AS id FROM nodes WHERE id = _node_id) m 
          ON 
            members @> ARRAY[m.id];        
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run route_members_overlap
    
    # Returns all nodes with GeometryType = polygon that contain
    # input node
    containing_polygons = <<-SQL
      CREATE OR REPLACE FUNCTION containing_polygons(_node_id bigint) 
      RETURNS SETOF nodes
      AS $$
      BEGIN
        RETURN QUERY
          SELECT a.* FROM nodes a JOIN nodes b
            ON b.id = _node_id
            AND ST_Contains(a.geom, b.geom)
            AND GeometryType(a.geom) IN ('POLYGON', 'MULTIPOLYGON')
          ORDER BY ST_Area(a.geom);
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run containing_polygons

    # Returns all administrative regions (layer_id = 2) that contain 
    # input node, order by admn_level
    containing_admr_regions = <<-SQL
      CREATE OR REPLACE FUNCTION containing_admr_regions(_node_id bigint) 
      RETURNS SETOF nodes
      AS $$
      BEGIN
        RETURN QUERY
          SELECT a.* FROM nodes a 
          JOIN nodes b
            ON b.id = _node_id
              AND ST_Contains(a.geom, b.geom)
              AND a.layer_id = 2
          JOIN node_data nd
            ON a.id = nd.node_id
              AND nd.layer_id = 2
          ORDER BY (data -> 'admn_level')::int DESC;
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL
    
    run containing_admr_regions

    route_start_end = <<-SQL
      CREATE OR REPLACE FUNCTION route_start(members bigint[]) 
      RETURNS bigint
      AS $$
      BEGIN
        RETURN members[array_lower(members, 1)];
      END $$ LANGUAGE plpgsql IMMUTABLE;

      CREATE OR REPLACE FUNCTION route_end(members bigint[]) 
      RETURNS bigint
      AS $$
      BEGIN
        RETURN members[array_upper(members, 1)];
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL
    
    run route_start_end

    # Calculates average distance between all points of 
    # geometry a and geometry b
    #
    # avg_distance is asymmetrical!
    average_distance = <<-SQL
      CREATE OR REPLACE FUNCTION avg_distance(a geometry, b geometry) 
      RETURNS double precision AS $$          
      BEGIN
        RETURN (
          SELECT avg(ST_Distance((g.points).geom, b))
          FROM (SELECT ST_DumpPoints(a) AS points) AS g
        );
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run average_distance

    # Calculates standard deviation of distances between all points of 
    # geometry a and geometry b
    #
    # std_dev_distance is asymmetrical!
    std_dev_distance = <<-SQL
    CREATE OR REPLACE FUNCTION std_dev_distance(a geometry, b geometry) 
    RETURNS double precision AS $$          
    BEGIN
      RETURN (
        SELECT stddev(ST_Distance((g.points).geom, b))
        FROM (SELECT ST_DumpPoints(a) AS points) AS g
      );
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL
    
    run std_dev_distance  

    run <<-SQL
    drop function if exists update_layer_bounds(layer integer);
    create function update_layer_bounds(layer integer) returns void
    as $$
        declare ext1 geometry;
        declare ext2 geometry;
        begin

          ext1 := (select ST_SetSRID( ST_Extent(geom)::geometry, 4326) 
              from nodes join node_data 
              on 
              nodes.id = node_data.node_id 
              and 
              node_data.layer_id = layer);

          ext2 := (select ST_SetSRID( ST_Extent(geom)::geometry, 4326) 
              from nodes 
              where layer_id = layer);

          update layers set bbox = ST_Envelope( St_Collect(ext1,ext2) ) where id = layer;

        end;
    $$ language plpgsql;


    drop function if exists node_ulb() cascade;
    create function node_ulb() returns trigger
    as $$
        declare 
          lid integer := NEW.layer_id;
          box geometry := (select bbox from layers where id = NEW.layer_id);
        begin
          if box is NULL then
            update layers set bbox = ST_Envelope( st_buffer(ST_SetSRID(NEW.geom,4326), 0.0000001) ) where id = lid;
          else
            update layers set bbox = ST_Envelope( St_Collect(NEW.geom,box) ) where id = lid;
          end if;
          return NULL;
        end;
    $$ language plpgsql;

    drop function if exists nodedata_ulb() cascade;
    create function nodedata_ulb() returns trigger
    as $$
        declare 
          lid integer := NEW.layer_id;
          box geometry := (select bbox from layers where id = NEW.layer_id);
          geo geometry := (select geom from nodes where id = NEW.node_id);
        begin
          if box is NULL then
            update layers set bbox = ST_Envelope( st_buffer(ST_SetSRID(geo,4326), 0.0000001) ) where id = lid;
          else
            update layers set bbox = ST_Envelope( St_Collect(geo,box) ) where id = lid;
          end if;
          return NULL;
        end;
    $$ language plpgsql;

    create trigger node_lb_update
        after insert on nodes
        for each row execute procedure node_ulb();    

    create trigger nodedata_lb_update
        after insert on node_data
        for each row execute procedure nodedata_ulb();    
    SQL


  run <<-SQL
    drop function if exists keys_for_layer(layer integer) cascade;
    create function keys_for_layer(layer integer) returns text[]
    as $$
     begin
      return array_agg(distinct k)
      from (
          select skeys(data) as k
          from node_data where layer_id = layer
      ) as sq;
     end;
    $$ language plpgsql;
  SQL

  end

  down do
    
  end
  
end
