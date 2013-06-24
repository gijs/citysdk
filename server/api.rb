$LOAD_PATH.unshift File.dirname(__FILE__)

require 'sinatra'
require 'json'
require 'csv'

configure do | sinatraApp |
  set :environment, :production

  if defined?(PhusionPassenger)
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      if forked
        # We're in smart spawning mode.
        CitySDK_API.memcache_new
        database.disconnect
      end
      # Else we're in direct spawning mode. We don't need to do anything.
    end
  end
    
  dbconf = JSON.parse(File.read('./database.json')) 
  sinatraApp.database = "postgres://#{dbconf['user']}:#{dbconf['password']}@#{dbconf['host']}/#{dbconf['database']}"

  # sinatraApp.database.logger = Logger.new(STDOUT)
  
  sinatraApp.database.extension :pg_array
  sinatraApp.database.extension :pg_range
  sinatraApp.database.extension :pg_hstore
  
  require File.dirname(__FILE__) + '/api_read.rb'
  require File.dirname(__FILE__) + '/api_write.rb'
  require File.dirname(__FILE__) + '/api_delete.rb'
    
  Dir[File.dirname(__FILE__) + '/utils/*.rb'].each {|file| require file }
  Dir[File.dirname(__FILE__) + '/utils/match/*.rb'].each {|file| require file }
  Dir[File.dirname(__FILE__) + '/utils/commands/*.rb'].each {|file| require file }
  Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file }
    
end

class CitySDK_API < Sinatra::Base
  Sequel::Model.plugin :json_serializer  
  Sequel.extension :pagination
  Sequel.extension :pg_hstore_ops
  Sequel.extension :pg_array_ops
  
  before do 
    content_type 'application/json'
    # @do_cache = (request.env['REQUEST_METHOD'] == 'GET')
    # @cache_time = 300
  end
  
  after do
    # if @do_cache and (request.url =~ /http:\/\/.+?(\/.*$)/)
    #   @@memcache.set($1,response.body[0], @cache_time, :raw => true)
    # end
    response.headers['Access-Control-Allow-Origin'] = '*'
  end

  # keep it dry
  def path_cdk_nodes(node_type=nil)
    begin
      pgn = 
        if node_type
          params["node_type"] = node_type
          Node.dataset
            .where(:node_type=>node_type)
            .geo_bounds(params)
            .name_search(params)
            .modality_search(params)
            .route_members(params)
            .nodedata(params)
            .node_layers(params)
            .do_paginate(params)
        else
          Node.dataset
            .geo_bounds(params)
            .name_search(params)
            .modality_search(params)
            .route_members(params)
            .nodedata(params)
            .node_layers(params)
            .do_paginate(params)
        end      
      
      CitySDK_API.json_nodes_results(pgn, params, request)
    rescue Exception => e
      CitySDK_API.do_abort(500,"Server error (#{e.message}, \n #{e.backtrace.join('\n')}.")
    end

  end
  
  def path_regions
    begin 
      pgn = Node.dataset.where(:nodes__layer_id=>2)
        .geo_bounds(params)
        .name_search(params)
        .nodedata(params)
        .node_layers(params)
        .do_paginate(params)

      CitySDK_API.json_nodes_results(pgn, params, request)
    rescue Exception => e
      CitySDK_API.do_abort(500,"Server error (#{e.message}, \n #{e.backtrace.join('\n')}.")
    end
  end

  ##########################################################################################
  # URL handlers are in api_read.rb and api_write.rb
  ##########################################################################################

end
