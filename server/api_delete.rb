class CitySDK_API < Sinatra::Base
  
  delete '/layer/:layer' do |layer|
    layer_id = Layer.idFromText(layer)
    CitySDK_API.do_abort(422,"Invalid layer spec: #{layer}") if layer_id.nil? or layer_id.is_a? Array
    Owner.validateSessionForLayer(request.env['HTTP_X_AUTH'],layer_id)   

    if(layer_id > 2)
      #delete node_data
      NodeDatum.where('layer_id = ?', layer_id).delete

      #delete nodes
      # if( params['delete_nodes'] == 'true' )
      nodes = Node.select(:id).where(:layer_id => layer_id)
      ndata = NodeDatum.select(:node_id).where(:node_id => nodes)
      Node.where(:layer_id => layer_id).exclude(:id => ndata).delete
      Node.where(:layer_id => layer_id).update(:layer_id => -1)

      if( params['delete_layer'] == 'true' )
        Layer.where(:id => layer_id).delete
        Layer.getLayerHashes
      end
      # end

      return 200, { 
        :status => 'success' 
      }.to_json
    end
    CitySDK_API.do_abort(422,"OSM, GTFS or ADMR layers cannot be deleted..")
  end

  delete '/:cdk_id/:layer' do |cdk_id, layer|
    layer_id = Layer.idFromText(layer)
    CitySDK_API.do_abort(422,"Invalid layer spec: #{layer}") if layer_id.nil? or layer_id.is_a? Array
    Owner.validateSessionForLayer(request.env['HTTP_X_AUTH'],layer_id)   
    node = Node.where(:cdk_id => cdk_id).first
    if(node)
      NodeDatum.where(:layer_id=>layer_id, :node_id => node.id).delete
      if( (node.layer_id == layer_id) and (params['delete_node'] == 'true') )
        if NodeDatum.select(:node_id).where(:node_id => node.id).all.length > 0
          node.update(:layer_id => -1)
        else
          node.delete
        end
      end
      return 200, { 
        :status => 'success' 
      }.to_json
    end
    CitySDK_API.do_abort(422,"Node '#{cdk_id}' not found." )
  end

end



