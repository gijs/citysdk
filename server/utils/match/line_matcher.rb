class CitySDK_API < Sinatra::Base

  module LineMatcher

    require_relative './dijkstra_graph.rb'
    
    def self.match(node, params)
        
      debug = params["debug"]
      debug = false
      
      radius = params["radius"]
      layers = params["layers"]
      srid = params["srid"]
      ignore_oneway = params["ignore_oneway"]
      
      if not node.has_key? "geom"
        CitySDK_API.do_abort(422, "Parameter 'geom' missing for node with id=#{node["id"]}.")
      end
      
      if not layers.has_key? "osm"
        CitySDK_API.do_abort(422, "Line matching is (for now) only possible on 'osm' layer. Parameter 'layer' must have key 'osm' with some values.")
      end

      # TODO: check if input geom is not too big
      # SELECT ST_Area(Geography(ST_Extent(ST_SetSRID('geom'::geometry, 4326)))) / 1000 ^ 2 AS km2      
    
      cdk_ids, match_data, found = find_osm_ways_path(node["geom"], srid, layers["osm"], radius, ignore_oneway, debug)
            
      if found
        match_node = {
          "cdk_ids" => cdk_ids,
          "id" => node["id"],
          "name" => node["name"],
          "modalities" => node["modalities"],
          "data" => node["data"]
        }
        return match_node, match_data, true
      else
        return nil, match_data, false
      end
      
    end

    def self.find_osm_ways_path(geom, srid, osm_tags, radius, ignore_oneway, debug)

      # OSM tags, create SQL CLAUSE
      sql_data_in = ''
      if osm_tags.empty?
        sql_data_in = 'TRUE'
      else
        sql_data_in = osm_tags.collect { |k, v|
          # TODO: Check for SQL INJECTION!!!!!! Use Sequel?
          key = k.gsub /['"]/, ''
          values = v.collect {|v| v.gsub /['"]/, '' }.join("','")          
          ["data -> '%s' IN (%s)" % [k, "'" + values + "'"]]
        }.join(" OR ")
      end
      
      # Extra SELECT values
      select = ''
      if debug
        select = ', ST_AsGeoJSON(n.geom) AS geojson'
      end  

      rgeo_geom = RGeo::GeoJSON.decode(geom.to_json, :json_parser => :json)        
      wkb = CitySDK_API.wkb_generator.generate(rgeo_geom)      
      wkb_4326 = <<-SQL
        ST_Transform(ST_SetSRID('#{wkb}'::geometry, #{srid}), 4326)
      SQL
      
      # TODO: use Sequel?
      sql_osm_nodes = <<-SQL
        SELECT 
          n.cdk_id,          
          data -> 'oneway' AS oneway,     
          round(ST_Length(Geography(n.geom), false)) AS length,   
          ST_Distance(n.geom, ST_StartPoint(#{wkb_4326})) AS dst_start,
          ST_Distance(n.geom, ST_EndPoint(#{wkb_4326})) AS dst_end,          
          nodes
          #{select}
        FROM nodes n
        JOIN node_data ON (
          n.id = node_data.node_id AND
          node_data.layer_id = 0 AND (
            #{sql_data_in}
          ) AND 
          GeometryType(n.geom) = 'LINESTRING'
        ) 
        JOIN osm.planet_osm_ways w ON 
          w.id = substring(n.cdk_id FROM 2 FOR length(n.cdk_id) - 1)::bigint
        WHERE
          n.layer_id = 0 and
          ST_Intersects(
            ST_Transform(Geometry(ST_Buffer(Geography(#{wkb_4326}), #{radius})), 4326), 
            n.geom
          )
        LIMIT 1000;
      SQL
                  
      graph = Graph.new
      dsts = {}
      debug_data = debug ? {:nodes => [], :graph => {}} : nil
      
      database.fetch(sql_osm_nodes).all do |row|        
        
        cdk_id = row[:cdk_id]
        length = row[:length]
        nodes = row[:nodes]   
        oneway = (row[:oneway] == 'yes' or row[:oneway] == '1')
        
        if ignore_oneway
          oneway = false
        end

        dst_start = row[:dst_start].to_f
        dst_end = row[:dst_end].to_f

        if debug
          row[:geojson] = JSON.parse(row[:geojson])
          debug_data[:nodes] << row
        end

        if nodes.length >= 2
          dsts[cdk_id] = {
            :nodes => [nodes[0], nodes[-1]], :dst_start => dst_start, :dst_end => dst_end
          }
        else
          CitySDK_API.do_abort(500, "Encountered OSM way with less than two nodes.")
        end

        (0..(nodes.length - 2)).each do |i|                 
          start_node = nodes[i]
          end_node = nodes[i + 1]
          
          graph.connect(start_node, end_node, cdk_id, length / (nodes.length - 1), oneway)
        end
        
      end

      if dsts.length  > 0

        if debug    
          debug_graph = []
          graph.edges.each do |edge|
            debug_graph << {:source => edge.src, :target => edge.dst}
          end
          debug_data[:graph] = debug_graph
        end     

        start_options = dsts.sort_by { |cdk_id, data| data[:dst_start] }[0..1].collect { |k, v| v[:nodes]}.flatten
        end_options =  dsts.sort_by { |cdk_id, data| data[:dst_end] }[0..1].collect { |k, v| v[:nodes]}.flatten
        
        # TODO : Pak niet alle nodes, maar alleen begin- en eindpunt!
        paths = []
        
        start_options.each { |src| 
          end_options.each { |dst|
            path = graph.dijkstra(src, dst)
        
            if path != nil
              paths << path
            end
          }
        }     

        cdk_ids = nil
        found = false
        if paths.length > 0    
          # TODO: instead of shortest path use Hausdorff distance!    
          path = paths.sort_by { |t| t[1] }[0]    
          
          cdk_ids = path[0]
          found = true

          if debug            
            debug_data.collect { |node|              
              if cdk_ids.include? node[:cdk_id]
                node[:in_path] = true 
              else
                node[:in_path] = false
              end
              node
            }
          end
        end

      end

      # TODO: rename debug_data > match_data
      return cdk_ids, debug_data, nil, found
      
    end

  end

end