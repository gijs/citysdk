class CitySDK_API < Sinatra::Base
  
  GEOMETRY_TYPE_POINT   = 'point' 
  GEOMETRY_TYPE_LINE    = 'line'
  GEOMETRY_TYPE_POLYGON = 'polygon'
  GEOMETRY_TYPES = [GEOMETRY_TYPE_POINT, GEOMETRY_TYPE_LINE, GEOMETRY_TYPE_POLYGON]
  
  CREATE_TYPE_UPDATE = 'update' 
  CREATE_TYPE_ROUTES = 'routes'
  CREATE_TYPE_CREATE = 'create'
  CREATE_TYPES = [CREATE_TYPE_UPDATE, CREATE_TYPE_ROUTES, CREATE_TYPE_CREATE]

  DEFAULT_RADIUS = 250

  post '/util/match' do 
    
    if not Owner.validSession(request.env['HTTP_X_AUTH'])
      CitySDK_API.do_abort(401,"Not Authorized")
    end
    
    json = CitySDK_API.parse_request_json(request)
    
    # Moet name + id in de node? of in de data?? Want nu soms dubbel met andere naam?
    # (als in data, dan moet in parameters een mapping naar name/id voor node)
    
    CitySDK_API.do_abort(422, "No 'match/params' object supplied") if not json.has_key? "match" and not json["match"].has_key? "params"
    match_params = json["match"]["params"]
      
    # Abort if JSON data contains duplicate IDs
    ids = []
    json["nodes"].each { |node|
      if not node.has_key? "id" or not node["id"]
        CitySDK_API.do_abort(422, "Node without ID encountered in JSON")
      end
      id = node["id"]

      if ids.include? id
        CitySDK_API.do_abort(422, "Duplicate ID encountered in JSON: \"#{id}\"")
      end
      ids << id
    }
    
    known = {}
    if json["match"].has_key? 'known'
      known = json["match"]["known"]
      
      # All cdk_ids specified in the known object MUST exist in CitySDK.
      # We need to check this first. SQL:
      #    SELECT * FROM unnest(known.values) AS cdk_id 
      #    WHERE cdk_id NOT IN (
      #      SELECT cdk_id FROM nodes WHERE cdk_id IN known.values
      #    )
      
      all_known_cdk_ids = Sequel.function(:unnest, known.values.pg_array).as(:cdk_id)
      existing_known_cdk_ids = Node.dataset.select(:cdk_id).where(:cdk_id => known.values)      
      not_known_cdk_ids = database[all_known_cdk_ids].where(Sequel.negate(:cdk_id => existing_known_cdk_ids)).all
      
      if not_known_cdk_ids.length > 0        
        CitySDK_API.do_abort(422, "'known' object specifies cdk_ids that do not exist in CitySDK: #{not_known_cdk_ids.map{|row| row[:cdk_id]}.join(", ")}")        
      end
      
    end
    
    debug = false
    if match_params.has_key? 'debug'
      debug = match_params['debug']
    end
    
    radius = DEFAULT_RADIUS
    if match_params.has_key? 'radius'
      radius = match_params['radius'].to_i
      if not radius > 0
        CitySDK_API.do_abort(422, "Wrong value for parameter 'radius': must be integer and larger than 0.")
      end
    end
    match_params["radius"] = radius
    
    srid = 4326
    if match_params.has_key? 'srid'
      srid = match_params['srid'].to_i
      if srid <= 0
        CitySDK_API.do_abort(422, "Invalid 'srid' parameter supplied. (#{match_params['srid']})")
      end
    end
    match_params["srid"] = srid
        
    layerdata_strings = {}
    if match_params.has_key? "layers" and match_params["layers"].is_a? Hash
      match_params["layers"].each { |layer, kvs|
        kvs.each { |k, v| 
          if v.is_a? Array
            v = v.join "|"
          end
          layerdata_strings.merge! ({"#{layer}::#{k}" => v})
        }        
      }
    end
    CitySDK_API.do_abort(422, "No 'layers' object supplied") if layerdata_strings.length == 0
      
    results = {
      :status => 'success', 
      :match => {
        :params => match_params.clone,
        :results => {
          :found => [],
          :not_found => [],
          :totals => {
            :found => 0,
            :not_found => 0            
          }
        }
      }, 
      :nodes => []
    } 
    
    if debug
      results[:match][:results][:debug] = []
    end 
    
    found_count = 0
    
    geometry_type = match_params["geometry_type"]    
    CitySDK_API.do_abort(422, "Invalid geometry_type specified: #{geometry_type}. Must be one of #{GEOMETRY_TYPES.join(', ')}") if not GEOMETRY_TYPES.include? geometry_type

    match_params["layerdata_strings"] = layerdata_strings
    json["nodes"].each { |node|
      id = node["id"]

      match_node = nil
      match_data = nil
      debug_data = nil 
      found = false
      
      if known.has_key? id
        cdk_id = known[id]
        found = true
        
        match_node = {
          "cdk_id" => cdk_id, 
          "data" => node["data"]
        }
        match_node["modalities"] = node["modalities"] if node["modalities"]
        
        match_data = {
          :id => id,
          :cdk_id => cdk_id
        }

        debug_data = {
          :found => true,
          :id => id,
          :cdk_id => cdk_id,
          :name => node["name"],
          :known => true
        }
      else
        # TODO: add option to exclude cdk_ids already found in previous matches
        # Matching should occur on one object for one cdk_id per layer per request.
        match_node, match_data, debug_data, found = case geometry_type
          when GEOMETRY_TYPE_POINT
            PointMatcher.match(node, match_params)
          when GEOMETRY_TYPE_LINE
            LineMatcher.match(node, match_params)        
          when GEOMETRY_TYPE_POLYGON
            PolygonMatcher.match(node, match_params)
        end
      end
      
      # TODO: check if match_node does not match againts the same cdk_id twice
      # Keep list of matched cdk_ids, reject if not uniq
      if found
        results[:nodes] << match_node
        results[:match][:results][:found] << match_data if match_data
        found_count += 1
      else # not found
        # If no match is found, add new node itself to result nodes,
        # create API can use this node in same hash to create new node.
        results[:match][:results][:not_found] << match_data if match_data
        results[:nodes] << node
      end
      
      if debug and debug_data
        results[:match][:results][:debug] << debug_data
      end
      
    }
    
    results[:match][:results][:totals][:found]     = found_count
    results[:match][:results][:totals][:not_found] = json["nodes"].length - found_count

    return results.to_json   
  end

  # Bulk API: add/update multiple nodes and node_data
  put '/nodes/:layer' do |layer|
    
    # TODO: Refactor! Refactor! Refactor! Refactor! Refactor! Refactor! Refactor! Refactor! Refactor! Refactor!
    # TODO: create class to check parameters. Here and in other functions!
    
    begin
    
      layer_id = Layer.idFromText(layer)
      CitySDK_API.do_abort(422,"Invalid layer spec: #{layer}") if layer_id.nil? or layer_id.is_a? Array
      
      Owner.validateSessionForLayer(request.env['HTTP_X_AUTH'],layer_id)   
                
      json = CitySDK_API.parse_request_json(request)

      CitySDK_API.do_abort(422,"No 'nodes' object supplied - nothing to do") if not json.has_key? "nodes"
      nodes = json["nodes"]

      CitySDK_API.do_abort(422,"No 'create/params' object supplied") if not json.has_key? "create" and not json["create"].has_key? "params"
      create_params = json["create"]["params"]

      create_type = create_params["create_type"]
      node_type = create_params["node_type"]

      results = {
        :status => 'success', 
        :create => {
          :params => create_params,
          :results => {
            :created => [],
            :updated => [],
            :totals => {
              :created => 0,
              :updated => 0            
            }
          }
        }
      }
    
      srid = 4326
      if create_params.has_key? 'srid'
        srid = create_params['srid'].to_i
        if not srid > 0
          CitySDK_API.do_abort(422, "Invalid 'srid' parameter supplied. (#{create_params['srid']}).")
        end
      end
    
      node_modalities = nil
      if create_params.has_key? 'modalities'
        if not create_params['modalities'].kind_of?(Array)
          CitySDK_API.do_abort(422, "'modalities' parameter must be an array.")
        end

        node_modalities = create_params['modalities'].map{|modality| Modality.idFromText(modality)}        
        node_modalities.each_with_index { |modality, index|
          CitySDK_API.do_abort(422,"Incorrect modality encountered in root modalities: \"#{create_params['modalities'][index]}\"") if modality.nil?
        }
      end
          
    
      # Abort if nodes from JSON data contains duplicate IDs or cdk_ids
      # ids = []
      # json["nodes"].each { |node|
      #   id = nil
      #   if node.has_key? "id" and node["id"]
      #     id = {
      #       :type => :id,
      #       :id => node["id"]
      #     }
      #   elsif node.has_key? "cdk_id" and node["cdk_id"]
      #     id = {
      #       :type => :cdk_id,
      #       :id => node["cdk_id"]
      #     }
      #   elsif node.has_key? "cdk_ids" and node["cdk_ids"]
      #     id = {
      #       :type => :cdk_ids,
      #       :id => node["cdk_ids"]
      #     }        
      #   else
      #     CitySDK_API.do_abort(422, "Node without id, cdk_id or cdk_ids field encountered in JSON")
      #   end
      #   
      #   if ids.include? id
      #     CitySDK_API.do_abort(422, "Duplicate id, cdk_id or cdk_ids encountered in JSON: #{id[:id]}")
      #   end
      #   ids << id
      # }     
    
      new_nodes = []
      updated_nodes = []
      node_data = []
      node_data_cdk_ids = []
        
      nodes.each do |node|      

        cdk_id = node["cdk_id"]
      
        cdk_ids = node["cdk_ids"]
        members = nil
      
        id = node["id"]
        name = node["name"]
      
       if cdk_id and cdk_ids
          CitySDK_API.do_abort(422,"Node with both cdk_id and cdk_ids fields encountered.")
        elsif cdk_ids
          if cdk_ids.is_a? Array and cdk_ids.length > 0
            if cdk_ids.length == 1
              cdk_id = cdk_ids[0]
            elsif cdk_ids.length > 1
              # Node to be added is a route
              members = cdk_ids.map { |cdk_id|
                Sequel.function(:cdk_id_to_internal, cdk_id)
              }.pg_array 
            end
          else
            CitySDK_API.do_abort(422,"Invalid cdk_ids field encountered. Must be array.")
          end
        end      

        if not id and not cdk_id and not cdk_ids
          CitySDK_API.do_abort(422,"Node without id, cdk_id or cdk_ids field encountered.")
        end
      
        geom = nil
        if node["geom"] and not cdk_id
          # geom must be present if a new node is created,
          # (e.g. when cdk_id and cdk_ids is empty)
          # and must be empty when either of cdk_id or cdk_ids is provided
      
          # PostGIS can convert GeoJSON to geometry with ST_GeomFromGeoJSON function:
          #   geom = Sequel.function(:ST_Transform, Sequel.function(:ST_SetSRID, Sequel.function(:ST_GeomFromGeoJSON, node["geom"].to_json), srid), 4326)
          # But on server this does not work:
          #   ERROR:  You need JSON-C for ST_GeomFromGeoJSON
          # TODO: find out why, and maybe update PostgreSQL/PostGIS...
        
          if node["geom"]['type'] != 'wkb'
            rgeo_geom = RGeo::GeoJSON.decode(node["geom"].to_json, :json_parser => :json)   
            wkb = CitySDK_API.wkb_generator.generate(rgeo_geom)
            geom = Sequel.function(:ST_Transform, Sequel.function(:ST_SetSRID, Sequel.lit("'#{wkb}'").cast(:geometry), srid), 4326)
          else
            # geom is already in wkb format; with correct srid..
            wkb = node["geom"]['wkb']
            geom = Sequel.function(:ST_Transform, Sequel.lit("'#{wkb}'").cast(:geometry), 4326)
          end
        elsif members
          # Compute derived geometry from the geometry of members
          geom = Sequel.function(:route_geometry, members)
        end
      
        # TODO: check if data is one-dimensional and unnested 
        data = nil
        if node["data"]
          data = node["data"].hstore
        else
          CitySDK_API.do_abort(422,"Node without data encountered.")
        end
      
        modalities = nil
        if node["modalities"]
          
          if not node['modalities'].kind_of?(Array)
            CitySDK_API.do_abort(422, "'modalities' parameter must be an array.")
          end
          
          modalities = node["modalities"].map{|modality| Modality.idFromText(modality)}
          modalities.each_with_index { |modality, index|
            CitySDK_API.do_abort(422,"Incorrect modality encountered in object with cdk_id=#{cdk_id}: \"#{node["modalities"][index]}\"") if modality.nil?
          }
        end

        validity = nil
        if node["validity"]
          if node["validity"].is_a? Array and node["validity"].length == 2
            begin
              lower_bound = DateTime.parse node["validity"][0]
              upper_bound = DateTime.parse node["validity"][1]
              if lower_bound < upper_bound
                validity = (lower_bound..upper_bound).pg_range(:tstzrange)
              end
            rescue
            end
          end
          CitySDK_API.do_abort(422,"Object with cdk_id=#{cdk_id} submitted with incorrect validity field, must be array with two datetime values, with value 1 < value 2") if validity.nil?
        end
         
        # Create new node and add data when:
        #   - create_type = create
        #   - cdk_id and cdk_ids is empty
        #   - geom is not empty
        # Or when:
        #   - create_type = routes (or create_type = create)
        #   - cdk_id is empty
        #   - cdk_ids is not empty
        #
        # Otherwise, do not create new node, only add data

        if data and
          (not cdk_id and not cdk_ids and geom and create_type == "create") or
          (not cdk_id and cdk_ids and (create_type == "routes" or create_type == "create"))

          # TODO: only create new route when node with same members does not exist!

          # Make new node, first generate cdk_id
          # TODO: option in create_params: how to construct cdk_id
          if not cdk_id
            if id
              cdk_id = CitySDK_API.generate_cdk_id_from_text(layer, id)
            elsif name
              cdk_id = CitySDK_API.generate_cdk_id_from_text(layer, name)
            elsif cdk_ids
              cdk_id = CitySDK_API.generate_route_cdk_id(cdk_ids)
            else
              CitySDK_API.do_abort(422,"No id, name or cdk_ids to generate new cdk_id from.") 
            end
          end
          
        end
     
        # TODO: node_type per node, not per request.
        # TODO: ptline when ptstop and members
        # TODO: not documented - for now.
        if 0 == Node.where(:cdk_id=>cdk_id).count
          # TODO validate node_type when given..
          # Set node_type to route (3) if node has members. Otherwise 0.
          node_type_id = 0
          if node_type
            case node_type
            when 'route'
              node_type_id = 1
            when 'ptstop'
              node_type_id = 2
            when 'ptline'
              node_type_id = 3
            end
          else
            node_type_id = members ? 1 : 0
          end
             

          new_nodes << {
            :cdk_id => cdk_id,
            :name => name,
            :members => members,
            :layer_id => layer_id,
            :node_type => node_type_id,
            :modalities => node_modalities ? node_modalities.pg_array : nil,
            :geom => geom
          }
          
          results[:create][:results][:totals][:created] += 1          
          
          # TODO: also update :updated and :totals
          results[:create][:results][:created] << {
            :cdk_id => cdk_id
          }
        
        else        
          # node with cdk_id already exist.
          # TODO: update geom/name/members/node_type of existing node!
        
          # cdk_id is available, data is added to existing node.
          # If existing node has node_type 'node' and new node is 'ptstop'
          # convert node to ptstop:
          if node_type == 'ptstop'
            updated_nodes << cdk_id
          end
        end      

        # See if there is node_data to add/update. Otherwise: skip
        if cdk_id and data
          node_data << {
            :node_id => Sequel.function(:cdk_id_to_internal, cdk_id), 
            :layer_id => layer_id,
            :data => data,
            :modalities => modalities ? modalities.pg_array : nil,
            :validity => validity
          }                  
          node_data_cdk_ids << cdk_id
          results[:create][:results][:totals][:updated] += 1
        end     
      
      end
      
      results[:create][:results][:totals][:updated] -= results[:create][:results][:totals][:created]

      database.transaction do 
        database[:nodes].multi_insert(new_nodes)

        if updated_nodes.length > 0
          Node.where(:cdk_id => updated_nodes).update(:node_type => 2)
        end
      
        if node_data_cdk_ids.length > 0
          NodeDatum.where(:node_id => Sequel.function(:any, Sequel.function(:cdk_ids_to_internal, node_data_cdk_ids.pg_array))).where(:layer_id => layer_id).delete      
        end
      
        database[:node_data].multi_insert(node_data)
      end
    
    rescue Exception => e
      CitySDK_API.do_abort(501,"Error: #{e.message}")
    end
    
    return results.to_json
  end
   
  # curl -X PUT -d '{"data": {"aap": "noot"}}' http://localhost:3000/admr.nl.amsterdam/cbs.plop
  put '/:cdk_id/:layer' do |cdk_id, layer|

    layer_id = Layer.idFromText(layer)
    CitySDK_API.do_abort(422,"Invalid layer spec: #{layer}") if layer_id.nil? or layer_id.is_a? Array
    
    Owner.validateSessionForLayer(request.env['HTTP_X_AUTH'],layer_id)   
    
    node = Node.where(:cdk_id => cdk_id).first
    if(node)
      json = CitySDK_API.parse_request_json(request)
      
      if(json)
        CitySDK_API.do_abort(422,"No 'data' found in post." ) if not json['data']
        nd = NodeDatum.where(:layer_id=>layer_id, :node_id => node.id).first
        if(nd)
          if(json['modalities'])
            nd.modalities = [] if nd.modalities.nil?
            nd.modalities << json['modalities'].map{ |m| Modality.idFromText(m)}
            nd.modalities.flatten!.uniq!
          end
          nd.data.merge!(json['data'])
          nd.save
        else
          h = {
            :layer_id=>layer_id,
            :node_id => node.id,
            :data => Sequel.hstore(json['data']),
            :node_data_type => 0,
            :modalities => json['modalities'] ? Sequel.pg_array(json['modalities'].map{ |m| Modality.idFromText(m)} ) : []
          }
          id = NodeDatum.insert h
        end
      end
      return 200, { 
        :status => 'success'
      }.to_json
    else
      CitySDK_API.do_abort(422,"Node '#{cdk_id}' not found." )
    end
  end
  



  put '/layer/:layer/status' do |layer|
  
    layer_id = Layer.idFromText(layer)
    CitySDK_API.do_abort(422,"Invalid layer spec: #{layer}") if layer_id.nil? or layer_id.is_a? Array
    Owner.validateSessionForLayer(request.env['HTTP_X_AUTH'],layer_id)   
    json = CitySDK_API.parse_request_json(request)
    if json['data']
      l = Layer[layer_id]
      l.import_status = json['data']
      l.save
      return 200, { 
        :status => 'success' 
      }.to_json
    end
    CitySDK_API.do_abort(422,"Data missing..")
  end



  put '/layers' do
    json = CitySDK_API.parse_request_json(request)
    if json['data']
      if Owner.domains(request.env['HTTP_X_AUTH']).include?(json['data']['name'].split('.')[0])
        l = Layer.new(json['data'])
        if l.valid?
          l.owner_id = Owner.get_id(request.env['HTTP_X_AUTH'])
          l.save
          Layer.getLayerHashes
        else
          CitySDK_API.do_abort(422,l.errors)
        end
      else
        CitySDK_API.do_abort(401,"Not authorized for domain #{json['data']['name'].split('.')[0]}.")
      end
      return 200, { 
        :status => 'success' 
      }.to_json
    end
    CitySDK_API.do_abort(422,"Data missing..")
  end


end




