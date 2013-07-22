$LOAD_PATH.unshift File.dirname(__FILE__)

require 'sinatra'
require 'sinatra/sequel'
require 'sinatra/session'
require 'json'
require 'open-uri'
require 'citysdk'
require 'base64'

configure do | app |
  if defined?(PhusionPassenger)
      PhusionPassenger.on_event(:starting_worker_process) do |forked|
          if forked
              # We're in smart spawning mode.
              database.disconnect
          else
              # We're in direct spawning mode. We don't need to do anything.
          end
      end
  end

  dbconf = JSON.parse(File.read('./database.json')) 
  # set :database, "postgres://#{dbconf['user']}:#{dbconf['password']}@#{dbconf['host']}/#{dbconf['database']}"
  app.database = "postgres://#{dbconf['user']}:#{dbconf['password']}@#{dbconf['host']}/#{dbconf['database']}"
  app.database.extension :pg_array
  app.database.extension :pg_range


  #app.database.logger = Logger.new(STDOUT)

  Dir[File.dirname(__FILE__) + '/utils/*.rb'].each {|file| require file }
  Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file }

end

enable :sessions

class CSDK_CMS < Sinatra::Base
  
  set :views, Proc.new { File.join(root, "../views") }  

  # puts settings.root

  use Rack::MethodOverride
  register Sinatra::Session
  set :session_fail, '/login'
  set :session_secret, '09989dhlkjh7892%$#%2kljd'
  

  def self.do_abort(code,message)
    throw(:halt, [code, {'Content-Type' => 'text/plain'}, message])
  end

  before do

    case request.url
    when /cms\-test/
      @apiServer = 'test-api.citysdk.waag.org'
    when /cms\.citysdk/
      @apiServer = 'api.citysdk.waag.org'
    else
      @apiServer = 'api.dev'
    end

    @oid = session? ? session[:oid] : nil
    # puts "request: #{request.env['PATH_INFO']}"
  end
  
  after do
  end
  
  def getLayers
    @layerSelect = Layer.selectTag()
    @selected = params[:category] || 'administrative'
    if @selected != 'all'
      ds = Layer.where(Sequel.like(:category, "#{@selected}%"))
    else
      ds = Layer
    end
    if @oid and @oid != 0
      ds = ds.where(:owner_id => @oid)
    end
    @layers = ds.order(:name).all
  end

  get '/' do
    getLayers
    erb :layers, :layout => @nolayout ? false : true
  end
  
  
  get '/layers' do
    getLayers
    erb :layers, :layout => @nolayout ? false : true
  end


  get '/login' do
    if session?
      redirect '/'
    else
      erb :login
    end
  end
  
  
  get '/get_layer_keys/:layer' do |l|
    l = Layer.where(:name=>l).first
    if(l)
      return database.fetch("select keys_for_layer(#{l.id})").all.to_json
    else
      return '{}'
    end
  end
  
  get '/get_layer_stats/:layer' do |l|
    l = Layer.where(:name=>l).first
    @lstatus = l.import_status || '-'
    @ndata   = NodeDatum.where(:layer_id => l.id).count
    @ndataua = NodeDatum.select(:updated_at).where(:layer_id => l.id).order(:updated_at).reverse.limit(1).all
    @ndataua = ( @ndataua and @ndataua[0] ) ? @ndataua[0][:updated_at] : '-'
    @nodes   = Node.where(:layer_id => l.id).count
    @delcommand = "delUrl('/layer/" + l.id.to_s + "',null,$('#stats'))"
    erb :stats, :layout => false
  end
  
  get '/logout' do
    session_end!
    redirect '/'
  end
  
  post '/login' do
    oid,token = Owner.login(params[:email],params[:password])
    session_start!
    session[:auth_key] = token
    session[:oid] = oid
    
    session[:e] = params[:email]
    session[:p] = params[:password]
    
    redirect '/'
  end
  
  
  get '/owners' do 
    if Owner.validSession(session[:auth_key])
      if( @oid == 0)
        @owners = Owner.all
        erb :owners
      else
        @errorContext = "Not authorised!"
        erb :gen_error
        return
      end
    else
      redirect '/'
    end
  end

  post '/profile/create' do 
    if Owner.validSession(session[:auth_key]) and (@oid == 0)
      @owner = Owner.new
      @owner.email = params['email']
      @owner.name = params['email'].split('@')[0]
      @owner.www = params['www']
      @owner.organization = params['organization']
      @owner.domains = params['domains']
      if @owner.valid? and @owner.validatePW(params['password'],params['passwordc'])
        @owner.save
        @owner.createPW(params['password']) if (params['password'] && !params['password'].empty?)
      else
        erb :edit_profile
        return
      end
    else
      CSDK_CMS.do_abort(401,"not authorized")
    end
    redirect '/owners'
  end

  get '/profile/new' do 
    if Owner.validSession(session[:auth_key]) and (@oid == 0)
      @owner = Owner.new
    else
      CSDK_CMS.do_abort(401,"not authorized")
    end
    erb :edit_profile
  end

  get '/profile/:o_id' do |o|
    if Owner.validSession(session[:auth_key])
      if( @oid == 0 or (o.to_i == @oid))
        @owner = Owner[o]
        erb :edit_profile
      else
        CSDK_CMS.do_abort(401,"not authorized")
      end
    else
      redirect '/'
    end
  end
  
  post '/profile/:o_id' do |o|
    if Owner.validSession(session[:auth_key])
      if( @oid == 0 or (o.to_i == @oid))
        @owner = Owner[o]
        @owner.email = params['email']
        @owner.www = params['www']
        @owner.organization = params['organization']
        @owner.domains = params['domains']  if params['domains']
        if @owner.valid? and @owner.validatePW(params['password'],params['passwordc'])
          @owner.save
          @owner.createPW(params['password']) if (params['password'] && !params['password'].empty?)
          redirect '/'
        else
          erb :edit_profile
        end
      else
        CSDK_CMS.do_abort(401,"not authorized")
      end
    end
  end
  
  
  get '/layer/:layer_id/data' do |l|
    if Owner.validSession(session[:auth_key])
      @layer = Layer[l]
      if(@layer && (@oid == @layer.owner_id) or @oid==0)

        @period  = "<select name='period'> "
        @period += "<option selected='selected'>never</option>"
        @period += "<option>montly</option>"
        @period += "<option>weekly</option>"
        @period += "<option>daily</option>"
        @period += "</select>"
        if params[:nolayout]
          erb :layer_data, :layout => false
        else
          erb :layer_data
        end
      else
        CSDK_CMS.do_abort(401,"not authorized")
      end
    else
      redirect '/'
    end
  end
  
  get '/layer/:layer_id/edit' do |l|
    if Owner.validSession(session[:auth_key])
      @layer = Layer[l]
      if(@layer && (@oid == @layer.owner_id) or @oid==0)
        @layer.data_sources = [] if @layer.data_sources.nil?
        @categories = @layer.cat_select
        @webservice = @layer.webservice and @layer.webservice != ''
        erb :edit_layer
      else
        CSDK_CMS.do_abort(401,"not authorized")
      end
    else
      redirect '/'
    end
  end
  
  
  delete '/layer/:layer_id' do |l|
    sess = request.cookies['auth_key']
    if Owner.validSession(session[:auth_key])
      @layer = Layer[l]
      if(@layer && (@oid == @layer.owner_id) or @oid==0)
        url = "/layer/#{@layer.name}"
        par = []
        params.each_key do |k|
          par << "#{k}=#{params[k]}"
        end
        url += "?" + par.join("&") if par.length > 0
        begin
          api = CitySDK::API.new(@apiServer)
          api.authenticate(session[:e],session[:p]) do
            api.delete(url)
          end
        rescue Exception => e
          @errorContext = "delete layer #{@layer.name}:"
          @errorMessage = e.message
          puts "deleting content of #{@layer.name}, error: #{e.message}\n #{e.backtrace}"
          return "deleting content of #{@layer.name}, error: #{e.message}" + @errorMessage
        end
      end
    end
    getLayers
    params[:nolayout] = true
    redirect "/layer/#{@layer.id}/data?nolayout"
  end

  get '/layer/new' do
    if Owner.validSession(session[:auth_key])
      @owner = Owner[@oid]
      if @oid != 0 
        domains = @owner.domains.split(',')
        if( domains.length > 1 )
          @prefix  = "<select name='prefix'> "
          domains.uniq.each do |p|
            @prefix += "<option>#{p}</option>"
          end
          @prefix += "</select>"
        else
          @prefix = domains[0]
        end
      end
      @layer = Layer.new
      @layer.data_sources = []
      @layer.update_rate = 3600
      @layer.organization = @owner.organization
      @categories = @layer.cat_select
      @webservice = false
      erb :new_layer
    else
      CSDK_CMS.do_abort(401,"not authorized")
    end
  end
  # 
  # post '/layer/create' do
  #   if Owner.validSession(session[:auth_key])
  #     @layer = Layer.new
  #     @layer.owner_id = @oid
  # 
  #     if( params['prefix'] && params['prefix'] != '' )
  #       @layer.name = params['prefix'] + '.' + params['name']
  #     elsif (params['prefixc']  && params['prefixc'] != '' )
  #       @layer.name = params['prefixc'] + '.' + params['name']
  #     else
  #       @layer.name = params['name']
  #     end
  # 
  #     params['validity_from'] = Time.now.strftime('%Y-%m-%d') if params['validity_from'].nil?
  #     params['validity_to'] = Time.now.strftime('%Y-%m-%d') if params['validity_to'].nil?
  # 
  #     @layer.description = params['description']
  #     @layer.update_rate = params['update_rate'].to_i
  #     @layer.validity = "[#{params['validity_from']}, #{params['validity_to']}]"
  #     @layer.realtime = params['realtime'] ? true : false;
  #     @layer.data_sources = []
  #     @layer.data_sources << params["data_sources_x"] if params["data_sources_x"] && params["data_sources_x"] != ''
  #     @layer.organization = params['organization']
  #     @layer.category = params['catprefix'] + '.' + params['category']
  #     @layer.webservice = params['wsurl']
  #     @layer.update_rate = params['update_rate']
  # 
  #     if !@layer.valid? 
  #       @prefix = params['prefixc']
  #       @layer.name = params['name']
  #       @categories = @layer.cat_select
  #       erb :new_layer
  #     else
  #       api = CitySDK::API.new(@apiServer)
  #       api.authenticate(session[:e],session[:p]) do
  #         begin
  #           d = { :data => @layer.to_hash.to_json }
  #           puts JSON.pretty_generate(d)
  #           api.put('/layers',d)
  #         rescue => e
  #           puts e.message
  #         end
  #       end
  #       getLayers
  #       erb :layers
  #     end
  #   end
  # end
  
  
  post '/layer/create' do
    if Owner.validSession(session[:auth_key])
      @layer = {}
      @layer[:owner_id] = @oid

      if( params['prefix'] && params['prefix'] != '' )
        @layer[:name] = params['prefix'] + '.' + params['name']
      elsif (params['prefixc']  && params['prefixc'] != '' )
        @layer[:name] = params['prefixc'] + '.' + params['name']
      else
        @layer[:name] = params['name']
      end

      params['validity_from'] = Time.now.strftime('%Y-%m-%d') if params['validity_from'].nil?
      params['validity_to'] = Time.now.strftime('%Y-%m-%d') if params['validity_to'].nil?

      @layer[:description] = params['description']
      @layer[:update_rate] = params['update_rate'].to_i
      @layer[:validity] = "[#{params['validity_from']}, #{params['validity_to']}]"
      @layer[:realtime] = params['realtime'] ? true : false;
      @layer[:data_sources] = []
      @layer[:data_sources] << params["data_sources_x"] if params["data_sources_x"] && params["data_sources_x"] != ''
      @layer[:organization] = params['organization']
      @layer[:category] = params['catprefix'] + '.' + params['category']
      @layer[:webservice] = params['wsurl']
      @layer[:update_rate] = params['update_rate']

      api = CitySDK::API.new(@apiServer)
      api.authenticate(session[:e],session[:p]) do
        begin
          d = { :data => @layer }
          puts JSON.pretty_generate(d)
          api.put('/layers',d)
        rescue => e
          @prefix = params['prefixc']
          @layer.name = params['name']
          @categories = @layer.cat_select
          erb :new_layer
          return
        end
      end
      getLayers
      erb :layers
    end

  end
  
  post '/layer/edit/:layer_id' do |l|
    if Owner.validSession(session[:auth_key])
      @layer = Layer[l]
      if(@layer && (@oid == @layer.owner_id) or @oid==0)
        @layer.description = params['description']
        params['validity_from'] = Time.now.strftime('%Y-%m-%d') if params['validity_from'].nil?
        params['validity_to'] = Time.now.strftime('%Y-%m-%d') if params['validity_to'].nil?
        if( params['realtime'] )
          @layer.realtime = true;
          @layer.update_rate = params['update_rate'].to_i
        else
          @layer.realtime = false;
          @layer.validity = "[#{params['validity_from']}, #{params['validity_to']}]"
        end
        ds = []; i = 0;
        while params["data_sources"][i.to_s]
          if params["data_sources"][i.to_s] != ''
            ds << params["data_sources"][i.to_s] 
          end
          i += 1
        end if params["data_sources"]
        ds << params["data_sources_x"] if params["data_sources_x"] && params["data_sources_x"] != ''
        @layer.data_sources = ds
        @layer.organization = params['organization']
        @layer.category = params['catprefix'] + '.' + params['category']
        
        @layer.webservice = params['wsurl']
        @layer.update_rate = params['update_rate']
        
        @layer.sample_url = params['sample_url'] if params['sample_url'] and params['sample_url'] != ''
        
        
        if !@layer.valid? 
          @categories = @layer.cat_select
          erb :edit_layer
        else
          @layer.save
          api = CitySDK::API.new(@apiServer)
          api.get('/layers/reload__')
          redirect '/'
        end
      else
        CSDK_CMS.do_abort(401,"not authorized")
      end
    else
      redirect '/'
    end
  end
  
  post '/layer/:layer_id/webservice' do |l|
    if Owner.validSession(session[:auth_key])
      @layer = Layer[l]
      if(@layer && (@oid == @layer.owner_id) or @oid==0)
        @layer.webservice = params['wsurl']
        @layer.update_rate = params['update_rate']
        if !@layer.valid? 
          @categories = @layer.cat_select
          redirect "/layer/#{l}/data"
        else
          @layer.save
          redirect "/layer/#{l}/data"
        end
      end
    end
  end
  
  post '/layer/:layer_id/loadcsv' do |l|
    
    if Owner.validSession(session[:auth_key])
      @layer = Layer[l]
      if(@layer && (@oid == @layer.owner_id) or @oid==0)
        p = params['0'] || params['csv']
        @original_file = p[:filename]

        if p && p[:tempfile] 
          @layerSelect = Layer.selectTag()
          begin
            return parseCSV(p[:tempfile], @layer.name)
          rescue => e
            return [422,{},e.message]
          end
        end
      else
        CSDK_CMS.do_abort(401,"not authorized")
      end
    end
  end
  
  get '/fupl/:layer' do |layer|
    @layer = Layer[layer]
    erb :file_upl, :layout => false
  end
  
  
  post '/csvheader' do
    
    if params['add']
      params['email'] = session[:e]
      params['passw'] = session[:p]
      
      
      parameters = JSON.parse(Base64.decode64(params['parameters']))

      # puts "csvheader parameters: #{parameters}"
      #     
      # puts ""
      #     
      params.delete('parameters')

      # puts "csvheader params: #{params}"
      #     
      # puts ""
      #     
      parameters = parameters.merge(params)
      # 
      # puts "csvheader merged: #{parameters}"
      # 

      parameters.each do |k,v|
        parameters.delete(k) if v =~ /^<no\s+/
      end
      
      parameters[:host] = @apiServer

      system "ruby utils/import_file.rb '#{parameters.to_json}' >> log/import.log &"
      redirect "/get_layer_stats/#{parameters['layername']}"

    else
      puts JSON.pretty_generate(params)
      a = matchCSV(params)
      begin 
        a = JSON.pretty_generate(a)
      rescue
      end
      return [200,{},"<hr/><pre>" + a + "</pre>"]

    end
  end
  
end
