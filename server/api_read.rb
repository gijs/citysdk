class CitySDK_API < Sinatra::Base
  
  get '/' do
      kv8  = CitySDK_API::memcache_get('kv8daemon');
      divv = CitySDK_API::memcache_get('divvdaemon');
      @do_cache = false
      { :status => 'success', 
        :url => request.url, 
        "name" => "CitySDK Version 1.0",
        "description" => "live testing; preliminary documentation @ http://dev.citysdk.waag.org",
        "health" => {
          "kv8" => kv8 ? "alive, #{kv8}" : "dead",
          "divv" => divv ? "alive, last timestamp: #{divv}" : "dead",
        }
      }.to_json 
  end

  get '/get_session' do
    @do_cache = false
    st,sess = Owner.login(params[:e],params[:p])
    { :status => st,
      :results => [sess]
    }.to_json
  end

  get '/release_session' do
    @do_cache = false
    if Owner.validSession(request.env['HTTP_X_AUTH'])
      Owner.release_session(request.env['HTTP_X_AUTH'])
      { :status => 'success' }.to_json
    else
      CitySDK_API.do_abort(401,"Not Authorized")
    end
  end

  ###### Data URL handlers:

  get '/regions/?' do
    path_regions
  end
  
  get '/layers/reload__' do
    @do_cache = false
    Layer.getLayerHashes
    { :status => 'success' }.to_json
  end

  get '/layers/?' do
      params['count'] = ''
      pgn = Layer.dataset
        .name_search(params)
        .category_search(params)
        .layer_geosearch(params)
        .do_paginate(params)
        
      res = pgn.all.map { |l| l.serialize(params) }
      return CitySDK_API.json_results(res, params, pgn.get_pagination_data(params), request)
  end

  get '/nodes/?' do
    path_cdk_nodes
  end

  get '/routes/?' do
    path_cdk_nodes(1)
  end

  get '/ptstops/?' do
    path_cdk_nodes(2)
  end

  get '/ptlines/?' do
    path_cdk_nodes(3)
  end

  get '/layer/:name/?' do |name|
    layer_id = Layer.idFromText(name)
    CitySDK_API.do_abort(422,"Unknown layer or invalid layer spec: #{name}") if layer_id.nil? or layer_id.is_a? Array
    layer = Layer[layer_id]
    { :status => 'success', 
      :url => request.url,  
      :results => [ layer.serialize(params) ]
    }.to_json 
  end

  get '/:within/nodes/?' do
    path_cdk_nodes
  end

  get '/:within/routes/?' do
    path_cdk_nodes(1)
  end

  get '/:within/ptstops/?' do
    path_cdk_nodes(2)
  end

  get '/:within/ptlines/?' do
    path_cdk_nodes(3)
  end

  get '/:within/regions/?' do
    path_regions
  end

  
  get '/:cdk_id/select/:cmd/?' do
    n = Node.where(:cdk_id=>params[:cdk_id]).first    
    if n.nil?
      CitySDK_API.do_abort(422,"Node not found: #{params[:cdk_id]}")
    end
  
    code = 0, h = {}
    case n.node_type
      when 0 # nodes
        Nodes.processCommand(n,params,request)
      when 1 # routes        
        Routes.processCommand(n,params,request)
      when 2 # ptstops
        if( Nodes.processCommand?(n,params) ) 
          Nodes.processCommand(n,params,request)      
        else
          PublicTransport.processStop(n,params,request)
        end
      when 3 # ptlines
        if( Routes.processCommand?(n,params) ) 
          Routes.processCommand(n,params,request)    
        else
          PublicTransport.processLine(n,params,request)
        end
      else
        CitySDK_API.do_abort(422,"Unknown command for #{params[:cdk_id]} ")
    end
  end


  get '/:node/:layer/:dpoint/?' do
    if 0 == Node.where(:cdk_id=>params[:node]).count
      CitySDK_API.do_abort(422,"Node not found: '#{params[:node]}'")
    end
    if 0 == Layer.where(:name=>params[:layer]).count
      CitySDK_API.do_abort(422,"Layer not found: '#{params[:layer]}'")
    end
    n  = Node.where(:cdk_id=>params[:node]).first
    nd = NodeDatum.where(:layer_id => Layer.idFromText(params[:layer])).where(:node_id => n.id)
    if 0 == nd.count
      CitySDK_API.do_abort(422,"No #{params[:layer]} layer data for node '#{params[:node]}'")
    end
    { :status => 'success', 
      :url => request.url,
      :results => {params[:dpoint] => nd.first.data[params[:dpoint]]}
    }.to_json 
  end

  get '/:node/:layer/?' do
    if 0 == Node.where(:cdk_id=>params[:node]).count
      CitySDK_API.do_abort(422,"Node not found: '#{params[:node]}'")
    end
    if 0 == Layer.where(:name=>params[:layer]).count
      CitySDK_API.do_abort(422,"Layer not found: '#{params[:layer]}'")
    end
    n  = Node.where(:cdk_id=>params[:node]).first
    nd = NodeDatum.where(:layer_id => Layer.idFromText(params[:layer])).where(:node_id => n.id)
    { :status => 'success', 
      :url => request.url,
      :results => nd.all.map { |item| NodeDatum.serialize(params[:node],[item.values],params)}
    }.to_json 
  end


  get '/:node/?' do
    results = Node.where(:cdk_id=>params[:node])
      .node_layers(params)
      .nodes(params)
      .map { |item| Node.serialize(item,params) }

    if 0 == results.length
      CitySDK_API.do_abort(422,"Node not found: '#{params[:node]}'")
    end
    { :status => 'success', 
      :url => request.url,
      :results => results
    }.to_json 
  end

end