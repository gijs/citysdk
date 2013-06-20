class CitySDK_API < Sinatra::Base

  module PointMatcher
    
    # Returns triple [n, d, f]:
    #  n. 
    #  d. hash with debug information
    #  f. boolean - match(es) found?
    def self.match(node, params)
      id = node["id"]
      name = node["name"] 
      
      CitySDK_API.do_abort(422, "Geometry encountered that is not a \"Point\".") if node["geom"]["type"] != "Point"
      
      point = node["geom"]["coordinates"]
      
      debug = false
      if params.has_key? 'debug'
        debug = params['debug']
      end
      
      params = {
        #"trigrams" => nil,
        "lat" => point[1],
        "lon" => point[0],
        "radius" => params["radius"],
        "srid" => params["srid"],
        "data_op" => "or",
        "per_page" => 8,
        "name" => name,
        "geom" => nil # Geometry needs also be included
      }.merge(params["layerdata_strings"])

      if node["within"]
        params["within"] = within
      end
    
      dataset_geo = Node.dataset
        .geo_bounds(params)       
        .nodedata(params)
        .node_layers(params)
        .include_distance(params)
        .do_paginate(params)

      dataset_all = Node.dataset
        .name_search(params)
        .geo_bounds(params)
        .nodedata(params)
        .node_layers(params)
        .include_distance(params)
        .do_paginate(params)
      
      matches_geo = dataset_geo.nodes(params).map { |item| Node.serialize(item,params) }
      matches_all = dataset_all.nodes(params).map { |item| Node.serialize(item,params) }

      matches = (matches_geo + matches_all).uniq

      matches = NodeCompare.filter_and_sort node, matches, params

      # matches.sort! { |a,b|
      #   -(NodeCompare.compare(node, b, params) <=> NodeCompare.compare(node, a, params))
      # }

      if matches.length > 0
        #puts "Match found: %s = %s" % [name, match[:name]]
        # TODO: add validity
        cdk_id = matches[0][:cdk_id]
        
        match = {
          "cdk_id" => cdk_id, 
          "data" => node["data"]
        }
        
        match_data = {
          :id => id,
          :cdk_id => cdk_id         
        }
        
        debug_data = nil
        if debug
          debug_data = {
            :found => true,
            :id => id,
            :cdk_id => cdk_id,
            :name => name, 
            :cdk_name => matches[0][:name]          
          }
        end        

        match["modalities"] = node["modalities"] if node["modalities"]        
        return match, match_data, debug_data, true   
      else
        #puts "No match found for #{name}"
        match_data = {:id => id}
        
        debug_data = {
          :found => false,
          :id => id,
          :name => name
        }

        return nil, match_data, debug_data, false
      end 

    end

  end
  
end