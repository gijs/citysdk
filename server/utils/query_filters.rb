module Sequel

  class Dataset
    
    MAX_PER_PAGE = 1000
    
    def do_paginate(params)
      if not params.has_key? "subselect_pagination"
        page = 1
        per_page = 10
      
        if params.has_key? 'page'
          page = [1,params['page'].to_i].max
        end
        if params.has_key? 'per_page'
          per_page = [params['per_page'].to_i, MAX_PER_PAGE].min
        end
      
        per_page = 10 if per_page <= 0
      
        if params.has_key? 'count'
          return self.paginate(page, per_page)
        else 
          return self.paginate(page, per_page, 900000000)
        end
      else
        return self
      end
    end    
    
    # If eager_graph is used, multiple nodedata object 
    # can be found for single node. PAGINATION should occur
    # on distinct nodes, not on number of nodedata returned.
    #
    # node_layers function uses subselect dataset to find nodes,
    # pagination should occur on this dataset.
    def get_pagination_data(params)
      if params.has_key? "subselect_pagination"
        return {
          :current_page => params["subselect_pagination"][:current_page],
          :page_count => params["subselect_pagination"][:page_count],
          :page_size => params["subselect_pagination"][:page_size],
          :pagination_record_count => params["subselect_pagination"][:pagination_record_count],
          :next_page => params["subselect_pagination"][:current_page] < params["subselect_pagination"][:page_count] ? params["subselect_pagination"][:current_page] + 1 : nil
        }
      elsif self.respond_to? 'current_page'
        return {
          :current_page => self.current_page,
          :page_count => self.page_count,
          :page_size => self.page_size,
          :pagination_record_count => self.pagination_record_count,
          :next_page => self.current_page < self.page_count ? self.current_page + 1 : nil
        }
      else
        return nil
      end
    end

    ##########################################################################################
    # Dataset/query functions:
    ##########################################################################################

    # If nodes with data on multiple layer_ids are requested,
    # layer=layer1|layer2|layer3, for performance reasons 
    # a UNION query is performed instead of JOIN with OR clause
    # for each layer_id.
    #
    # For such queries, the node_layers function puts layer_ids
    # in the params variable: params[:layer_ids_for_union] = layer_ids
    
    def nodes(params) 
      # Removed order, to make queries on other node_types than node_type=0 faster.
      # With order
      #
      #   SELECT * FROM nodes n JOIN node_data nd ON n.id = nd.node_id 
      #   WHERE node_type = 3 AND nd.layer_id IN (0, 1, 2)
      #   ORDER BY n.id
      #   LIMIT 10
      #
      # is very slow, while
      #
      #   SELECT * FROM nodes n JOIN node_data nd ON n.id = nd.node_id 
      #   WHERE node_type = 0 AND nd.layer_id IN (0, 1, 2)
      #   ORDER BY n.id
      #   LIMIT 10
      #
      # is very fast (different node_type)
      #
      # Find out why and how to solve!
      #
      # (Temporary) solution: removed ORDER BY.
      
      if params.has_key? 'layer' or params.has_key? "nodedata_layer_ids"
        return self.all.map { |a| a.values.merge(:node_data=>a.node_data.map{|al| al.values}) }
      end
      
      return self.all.map { |a| a.values }
      
    end
  
    LAYER_OR_SEPARATOR  = "|"
    LAYER_AND_SEPARATOR = ","
    def node_layers(params)      
      # don't select nodes without any data on the specified layers
      if params.has_key? 'layer' or params.has_key? "nodedata_layer_ids"
        # Look for separators, determine if query is OR or AND query

        layer_ids = []
        op = :| # default operator is OR
        
        if params.has_key? 'layer'
          is_or_query  = params['layer'].include? LAYER_OR_SEPARATOR
          is_and_query = params['layer'].include? LAYER_AND_SEPARATOR        
        
          if is_or_query and is_and_query
            CitySDK_API.do_abort(422,"Layer parameter cannot contain a combination of '#{LAYER_OR_SEPARATOR}' and '#{LAYER_AND_SEPARATOR}' characters. Use '#{LAYER_OR_SEPARATOR}' to request nodes with data on any of the specified layers, use '#{LAYER_AND_SEPARATOR}' for nodes with data on all of the specified layers.")
          elsif is_or_query
            op = :| # boolean AND operator
            layer_ids = Layer.idFromText(params['layer'].split(LAYER_OR_SEPARATOR))
          elsif is_and_query
            op = :& # boolean AND operator
            layer_ids = Layer.idFromText(params['layer'].split(LAYER_AND_SEPARATOR))
          else # just one layer
            layer_ids = [Layer.idFromText(params['layer'])]
          end
        end
        
        # Also add layers needed for by nodedata function
        if params.has_key? "nodedata_layer_ids" and params["nodedata_layer_ids"].is_a? String          
          nodedata_layer_ids = params["nodedata_layer_ids"].split(",")
          layer_ids << nodedata_layer_ids.map{|layer_id| layer_id.to_i}          
        end
                
        layer_ids.flatten!
        layer_ids.uniq!
                       
        where = true 
        
        if layer_ids.length > 0        
          if op == :&          
          
            cdk_ids = Node.select(:cdk_id)
            layer_ids.each { |layer_id|
              cdk_ids = cdk_ids.join_table(:inner, :node_data, {:layer_id => layer_id, :node_id => :nodes__id}, {:table_alias=>"nd#{layer_id}"})
            }  
            # Set params["subselect_pagination"];
            # paginiation on this dataset no longer necessary, 
            # pagination now occurs on subselect 
            # But NOT when single cdk_id is requested
            # (in that case, params[:node] is not nil)
            if not (params[:node] or params[:within])
              cdk_ids = cdk_ids.do_paginate(params)
              params["subselect_pagination"] = {
                :current_page => cdk_ids.current_page,
                :page_count => cdk_ids.page_count,
                :page_size => cdk_ids.page_size,
                :pagination_record_count => cdk_ids.pagination_record_count
              }            
            end
            where = Sequel.expr(:node_data__layer_id => layer_ids) & Sequel.expr(:cdk_id => cdk_ids)
          else
            # if @layer_ids_for_union has elements, take current dataset (self)
            # and compute UNION with itself for different node_data.layer_ids
            #if params["layer_ids_for_union"] and params["layer_ids_for_union"].length > 0        
            # dataset = self
            # layer_id = params["layer_ids_for_union"][0]
            # dataset = self.where(:node_data__layer_id => layer_id)
            # params["layer_ids_for_union"].drop(1).each { |layer_id|
            #   dataset = dataset.union(self.where(:node_data__layer_id => layer_id))
            # }        
            # return dataset
            database << "SET enable_mergejoin TO false;"
            where = Sequel.expr(:node_data__layer_id => layer_ids)          
          end
        else
          # layer_ids is empty..
          # if layer parameter is supplied, but no existing layers (including wildcards)
          # are found. Return empty results.
          where = false
        end

        # Only retrieve geometry from database if requested
        if not params.has_key? "geom"
          columns = (Node.dataset.columns - [:geom]).map { |column| "nodes__#{column}".to_sym }
          return self.select{columns}.eager_graph(:node_data).where(where)
        else
          return self.eager_graph(:node_data).where(where)
            .add_graph_aliases(:member_geometries=>[
              :nodes, :member_geometries, 
              Sequel.function(:collect_member_geometries, :members) 
            ])
        end
      else 
        # if no layer specified, return NO layer info at all!!
        
        # Only retrieve geometry from database if requested
        if not params.has_key? "geom"
          columns = (Node.dataset.columns - [:geom]).map { |column| "nodes__#{column}".to_sym }
          return self.select{columns}
        else
          self.select_append(Sequel.function(:collect_member_geometries, :members).as(:member_geometries))
        end
      end
    end
    
    def route_members(params)
      # The starts_in, ends_in and contains parameters are used to
      # filter on routes starting, ending and containing certain 
      # cdk_ids as members. The order of the cdk_ids in the contains
      # parameter are always respected.
      # The contains parameter is of form:
      # <cdk_id>[,<cdk_id>]
      
      dataset = self

      if params.has_key? "starts_in"
        starts_in = params["starts_in"]
        dataset = dataset.where(Sequel.function(:cdk_id_to_internal, starts_in) => Sequel.pg_array(:members)[Sequel.function(:array_lower, :members, 1)])
      end

      if params.has_key? "ends_in"
        ends_in = params["ends_in"]
        dataset = dataset.where(Sequel.function(:cdk_id_to_internal, ends_in) => Sequel.pg_array(:members)[Sequel.function(:array_upper, :members, 1)])
      end
      
      if params.has_key? "contains"
        cdk_ids = params["contains"].split(",")
        if cdk_ids.length > 0
          # members @> ARRAY[cdk_id_to_internal('n712651044'), cdk_id_to_internal('w6637691')]          
          ids = cdk_ids.map { |cdk_id| 
            Sequel.function(:cdk_id_to_internal, cdk_id) 
          }
          dataset = dataset.where(Sequel.pg_array(:members).contains(ids))
          
          if cdk_ids.length > 1
            # Just check if route contains cdk_ids is not enough:
            # order should be checked as well.
            # TODO: this approach is not the most efficient,
            # cdk_id_to_internal and idx are called twice for each cdk_id...
            
            for i in 0..(cdk_ids.length - 2)
              cdk_id1 = cdk_ids[i]
              cdk_id2 = cdk_ids[i + 1]
              
              idx1 = Sequel.function(:idx, :members, Sequel.function(:cdk_id_to_internal, cdk_id1))  
              idx2 = Sequel.function(:idx, :members, Sequel.function(:cdk_id_to_internal, cdk_id2))
              
              dataset = dataset.where(idx1 < idx2)
            end            
          end
        end
      end

      return dataset
    end
    
    def category_search(params)
      if params.has_key? "category"
        return self.where(Sequel.expr(:category).ilike("%#{params['category']}%"))        
          .order(Sequel.desc(Sequel.function(:similarity, :name, params['category'])))          
      end
      self
    end


    # layers?per_page=15&lat=53.4962&lon=-1.3348
    # layers?per_page=150&where=admr.nl.haarlem
    def layer_geosearch(params)
      if params.has_key? 'lat' and params.has_key? 'lon'
        return self.where("ST_Intersects(ST_SetSRID(ST_Point(%s, %s), 4326),bbox)" % [params["lon"], params["lat"]] )
      elsif params.has_key? 'where'
        loc = Node.where(:cdk_id => params['where']).first
        if(loc)
          return self.where("ST_Intersects('%s',bbox)" % loc.geom)
        end
      end
      self
    end

    def modality_search(params)
      # TODO: zoeken op meerdere modalities?
      if params.has_key? "modality"
        mod = Modality.idFromText(params['modality'])
        return self.where(mod => :nodes__modalities.pg_array.any)        
      end
      self
    end
    

    def name_search(params)
      if params.has_key? "name"
        if params.has_key? "trigrams"
          return self.where('name % ?'.lit(Sequel.expr(params['name'])))
            .order(Sequel.desc(Sequel.function(:similarity, :name, params['name'])))
        else
          return self.where(Sequel.expr(:name).ilike("%#{params['name']}%"))        
            #.order(Sequel.desc(Sequel.function(:similarity, :name, params['name'])))          
        end
      end
      self
    end
    
    def geo_bounds(params)
      dataset = self
      if params.has_key? "within"
        container = Node.where(:cdk_id => params[:within]).first
        if container

          # Find nodes contained by within node.
          # We want routes and lines through the node to match, even though they are not contained.
          # But we do not want nodes to match that contain the container.
          # So intersect and then subtract those last
          # The ST_Buffer is used to filter out unwanted neighbours where borders intersect a bit.
          
          contains = Sequel.function(:ST_Intersects, Sequel.function(:ST_Buffer, container.geom, -0.00002), :geom)
          dataset = dataset.where(contains).exclude(Sequel.function(:ST_Contains, :geom, container.geom ))
        else
          CitySDK_API.do_abort(422,"Containing node not found: #{params[:within]}")
        end
      end
      
      if (params.has_key? "lat" and params.has_key? "lon" ) or (params.has_key? "y" and params.has_key? "x" )
        # Example:
        #   lat=52.375046&lon=4.899422

        lon = params["lon"] || params["x"]
        lat = params["lat"] || params["y"]
        
        srid = 4326
        if (params.has_key? "srid" and params["srid"].to_i > 0)
          srid = params["srid"].to_i
        end

        order = 'geom <-> ST_SetSRID(ST_MakePoint(%s, %s), %d)' % [lon, lat, srid]
        
        # If radius parameter is included, search for nodes inside circle from lat,lon with radius
        # Otherwise (without radius parameter), search for closest items (limited by per_page)
        if params.has_key? "radius" 
          radius = params["radius"]
          
          # Create point on lat, lon, convert to Geography, use ST_Buffer to create circle around
          # point with radius in meters and convert back to 4326.
          area = 'ST_Transform(Geometry(ST_Buffer(Geography(ST_Transform(ST_SetSRID(ST_Point(%s, %s), %d), 4326)), %s)), 4326)' %  [lon, lat, srid, radius]
          # Add ST_Intersects to see if node is within circle.          
          contains = 'ST_Intersects(%s, geom)' % area
          
          dataset = dataset.where(contains)
        end
        dataset = dataset.order(Sequel.lit(order))
      end 

      if params.has_key? "bbox"   
        # Example:
        #   bbox=52.38901,4.79519,52.35191,5.01135
        coordinates = params["bbox"].scan(/-?\d+(?:\.\d+)?/)
        contains = 'ST_Contains(ST_SetSRID(ST_MakeBox2D(ST_Point(%s, %s), ST_Point(%s, %s)), 4326), geom)' % [coordinates[1], coordinates[0], coordinates[3], coordinates[2]]    
        dataset = dataset.where(contains)
        
      end
      
      dataset
    end
    
    
    # Add WHERE clause to filter on node_data hstore keys/values
    def nodedata(params)
      joined = []
      layer_ids = []
      dt = self
      
      op = :&
      values_separator = LAYER_AND_SEPARATOR
      if params.has_key? "data_op" and params["data_op"].downcase == "or"
        op = :|
        values_separator = LAYER_OR_SEPARATOR
      end
      data_conditions = []
      
      params.each_pair do |param, values|
        match = /(?<layer>[\w\.]+)::(?<key>.+)/.match(param)  
        if match != nil
          layer = match[:layer]
          layer_id = Layer.idFromText(layer)
          layer_ids << layer_id
          key = match[:key]
        
          if (op == :& and values and values.include?(LAYER_OR_SEPARATOR)) or
            (op == :| and values and values.include?(LAYER_AND_SEPARATOR))
            CitySDK_API.do_abort(422,"'data_op=or' can only be used in combination with 'layer::key=a|b|c', 'data_op=and' can only be used in combination with 'layer::key=a,b,c'. Default is 'and'.")
          end
        
          if not joined.include? layer    
            dt = dt.join_table(:inner, :node_data, {:layer_id => layer_id, :node_id => :id}, {:table_alias=>layer})
            dt = dt.select_all(:nodes)
            # distinct('cdk_id'), maar dan enorm langzaam...
            joined << layer
          end

          # Uses hstore ops extension: 
          #   Sequel.extension :pg_hstore_ops
          #   http://sequel.rubyforge.org/rdoc-plugins/classes/Sequel.html
          if values
            values.split(values_separator).each { |value| 
              data_conditions << Sequel.expr(:data).qualify(layer).hstore.contains({key => value}.hstore)  
            }
          else              
             data_conditions << Sequel.expr(:data).qualify(layer).hstore.has_key?(key)
          end
        end        
      end  

      if data_conditions.length > 0
        dt = dt.where(data_conditions.reduce(op))        
      end       
      
      # Add layers on which node_data search is performed 
      # to params['nodedata_layer'], so that node_layers function
      # can also retrieve node_data from those layers.
      #
      # NOTE: call nodedata(params) BEFORE node_layers(params)
      if layer_ids.length > 0
        params["nodedata_layer_ids"] = layer_ids.uniq.join(",")
      end    
      dt
    end    
  end
end
