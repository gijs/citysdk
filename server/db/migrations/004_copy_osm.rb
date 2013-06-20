Sequel.migration do

  up do
    $stderr.puts("Copying OSM...")

    # Create sequences

    # Two node_id sequences are needed:
    #   - one when inserting nodes, 
    #   - and one when inserting node_data; then a link to the associated node is needed.
    # Since the two node_id sequences are incremented simultaneously,
    # the node_data's node_id will link to the correct id.
    sequences = <<-SQL
      DROP SEQUENCE IF EXISTS nodes1_id_seq; 
      CREATE SEQUENCE nodes1_id_seq START 1;   
    
      DROP SEQUENCE IF EXISTS nodes2_id_seq; 
      CREATE SEQUENCE nodes2_id_seq START 1;
    
      DROP SEQUENCE IF EXISTS node_data_id_seq;
      CREATE SEQUENCE node_data_id_seq START 1;
    SQL
    
    run sequences

    # Import OSM data from schema osm
    
    #### OSM nodes ############################################
    
    # We could also try to use Sequel:
    #
    # self[:nodes].insert(
    #   [
    #     :id,
    #     :cdk_id,
    #     :name,
    #     :layer_id, 
    #     :geom
    #   ], 
    #   self[:osm__planet_osm_point].select(
    #     nextval('nodes1_id_seq'),
    #     Sequel.join(['n', Sequel.lit(:osm_id).cast(:text)],
    #     :name,
    #     0,
    #     :way
    #   )
    # )

    point_nodes = <<-SQL
      INSERT INTO nodes (id, cdk_id, name, layer_id, geom)
        SELECT
          nextval('nodes1_id_seq'), -- id
          'n' || osm_id::text,      -- cdk_id
          name,                     -- name
          0,                        -- layer_id
          way                       -- geom
      FROM osm.planet_osm_point;
    SQL

    point_node_data = <<-SQL
      INSERT INTO node_data (id, node_id, layer_id, data)
        SELECT
          nextval('node_data_id_seq'), -- id
          nextval('nodes2_id_seq'),    -- node_id
          0,                           -- layer_id
          tags                         -- data
      FROM osm.planet_osm_point;
    SQL

    $stderr.puts("\tPoint nodes...")
    run point_nodes
    $stderr.puts("\tPoint node data...")
    run point_node_data

    #### OSM ways ############################################
    
    line_nodes = <<-SQL
      INSERT INTO nodes (id, cdk_id, name, layer_id, geom)
        SELECT
          nextval('nodes1_id_seq'), -- id
          'w' || osm_id::text,      -- cdk_id
          name,                     -- name
          0,                        -- layer_id
          way                       -- geom
      FROM osm.planet_osm_line
      WHERE osm_id > 0;
    SQL
    
    line_node_data = <<-SQL
      INSERT INTO node_data (id, node_id, layer_id, data)
        SELECT
          nextval('node_data_id_seq'), -- id
          nextval('nodes2_id_seq'),    -- node_id
          0,                           -- layer_id
          tags                         -- data
      FROM osm.planet_osm_line
      WHERE osm_id > 0;
    SQL
    
    $stderr.puts("\tLine nodes...")
    run line_nodes
    $stderr.puts("\tLine node data...")
    run line_node_data
    
    #### OSM polygons ############################################
    
    polygon_nodes = <<-SQL
      INSERT INTO nodes (id, cdk_id, name, layer_id, geom)
        SELECT
          nextval('nodes1_id_seq'), -- id
          'w' || osm_id::text,      -- cdk_id
          name,                     -- name
          0,                        -- layer_id
          way                       -- geom
      FROM osm.planet_osm_polygon
      WHERE osm_id > 0;
    SQL
    
    polygon_node_data = <<-SQL
      INSERT INTO node_data (id, node_id, layer_id, data)
        SELECT
          nextval('node_data_id_seq'), -- id
          nextval('nodes2_id_seq'),    -- node_id
          0,                           -- layer_id
          tags                         -- data
      FROM osm.planet_osm_polygon
      WHERE osm_id > 0;
    SQL
      
    $stderr.puts("\tPoly nodes...")
    run polygon_nodes
    $stderr.puts("\tPoly node data...")
    run polygon_node_data 
    
    #### OSM relations ############################################
    
    relation_nodes = <<-SQL
      INSERT INTO nodes (id, cdk_id, name, layer_id, geom)
        SELECT
          nextval('nodes1_id_seq'), -- id
          'r' || osm_id::text,      -- cdk_id
          hstore(tags) -> 'name',   -- name
          0,                        -- layer_id
          NULL                      -- geom
      FROM osm.planet_osm_rels;
    SQL
    
    relation_node_data = <<-SQL
      INSERT INTO node_data (id, node_id, layer_id, data)
        SELECT
          nextval('node_data_id_seq'), -- id
          nextval('nodes2_id_seq'),    -- node_id
          0,                           -- layer_id
          hstore(tags)                 -- data
      FROM osm.planet_osm_rels;
    SQL
    
  
    $stderr.puts("\tRelation nodes...")
    run relation_nodes
    $stderr.puts("\tRelation node data...")
    run relation_node_data

  end

  down do
    
  end end
