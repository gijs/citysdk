module Sequel

  class Dataset   
    
    def include_distance(params)      
      if (params.has_key? "lat" and params.has_key? "lon" ) or (params.has_key? "y" and params.has_key? "x" )
        lon = params["lon"] || params['x']
        lat = params["lat"] || params['y']
        
        distance = Sequel.function(:ST_Distance,
          Sequel.function(:Geography, 
            :geom
          ),
          Sequel.function(:Geography,            
            Sequel.function(:ST_Transform,
              Sequel.function(:ST_SetSRID,
                Sequel.function(:ST_MakePoint,
                lon, lat),
                params['srid'] || 4326
              ),
              4326
            )
          )
        )
        #"ST_Distance(Geography(geom), Geography(ST_SetSRID(ST_MakePoint(%s, %s), 4326)))" % [lon, lat]
      
        if params.has_key? 'layer' or params.has_key? "nodedata_layer_ids"
          return self.add_graph_aliases(:distance=>[
              :nodes, :distance,
              distance
            ])
        else
          return self.select_append(distance.as(:distance))
        end
      end
    end

  end

end