require 'faraday'
require 'socket'
require 'json'


# Module to help communicate with the CitySDK write api.
# Typical use is: authenticate -> get | put | post | delete -> release
# Authentication is not needed for get, get is added for completeness. 

class NilClass
    def empty?; true; end
end

class CitySDK_Exception < Exception
end

class CitySDK_API
  attr_reader :error
  attr_accessor :batch_size
  
  @@match_tpl = {:nodes => []}

  @@create_tpl =  {
    :create => {
      :params => {
        :create_type => "create"
      }
    },
    :nodes => []
  }
  
  def set_matchTemplate(mtpl) 
    mtpl[:nodes] = []
    @match = @@match_tpl = mtpl
  end

  def set_createTemplate(ctpl) 
    ctpl[:nodes] = []
    @create = @@create_tpl = ctpl
  end
  
  def initialize(email='',pw='')

    set_host('api.citysdk.waag.org')

    @error = '';
    @layer = '';
    @email = email;
    @passw = pw;
    @batch_size = 10;
    @updated = @created = 0;
  end
  
  def set_host(host,port=80)
    @host  = host
    @port  = port
    @connection = Faraday.new :url => "http://#{@host}:#{@port}"
    @connection.headers = {
      :user_agent => 'CitySDK_API RubyLib 1.0',
      :content_type => 'application/json'
    }
    begin 
      get('/')
    rescue
      raise CitySDK_Exception.new("Trouble connecting to api @ #{host}")
    end
    @create = @@create_tpl
    @match = @@match_tpl
  end
  
  def set_layer(l)
    @layer = l
  end
  
  def set_layer_status(status)
    put("/layer/#{@layer}/status",{:data => status})
  end
  
  
  def tally(res)
    if res['status'] == "success"
      # TODO: also tally debug data!
      @updated += res['create']['results']['totals']['updated']
      @created += res['create']['results']['totals']['created']
    end
  end
  
  
  def match_create_flush
    if @match[:nodes].length > 0
      resp = post('util/match',@match)
      if resp["nodes"].length > 0 
        @create[:nodes] = resp["nodes"]
        res = put("/nodes/#{@layer}",@create)
        tally(res)
        @create[:nodes] = []
      end
      @match[:nodes] = []
      res
    end
    nil
  end

  def match_flush
    if @match[:nodes].length > 0
      resp = post('util/match',@match)
      @match[:nodes] = []
      return resp
    end
  end
  
  
  def create_flush
    if @create[:nodes].length > 0
      tally put("/nodes/#{@layer}",@create)
      @create[:nodes] = []
    end
  end

  def match_node(n)
    @match[:nodes] << n
    return match_flush if @match[:nodes].length >= @batch_size
    return nil
  end


  def match_create_node(n)
    @match[:nodes] << n
    return match_create_flush if @match[:nodes].length >= @batch_size
  end
  

  def create_node(n)
    @create[:nodes] << n
    create_flush if @create[:nodes].length >= @batch_size
  end
  
  
  def authorized
    @connection.headers['X-Auth']
  end
  
  def authenticate
    if !( @host == 'api.dev' or @host == 'localhost' or @host == '127.0.0.1')
      auth_connection = Faraday.new :url => "https://#{@host}", :ssl => {:verify => false}
      # puts "trying: #{@host} with #{@email}, #{@passw}"
      resp = auth_connection.get '/get_session', { :e => @email, :p => @passw }
    else 
      resp = @connection.get '/get_session', { :e => @email, :p => @passw }
    end
    if resp.status == 200
      resp = JSON.parse(resp.body)
      @connection.headers['X-Auth'] = resp['results'][0]
      return true
    end
    @error = JSON.parse(resp.body)['message']
    return false
  end

  def release
    match_flush
    create_flush # send any remaining entries in the create buffer
    match_create_flush
    if authorized
      resp = @connection.get('/release_session')
      if resp.status == 200
        @connection.headers.delete('X-Auth')
      else
        @error = JSON.parse(resp.body)['message']
        raise CitySDK_Exception.new(@error)
      end
    end
    return [@updated, @created]
  end


  def get(path)
    resp = @connection.get(path)
    return JSON.parse(resp.body) if resp.status == 200
    @error = JSON.parse(resp.body)['message']
    raise CitySDK_Exception.new(@error)
  end
  
  def delete(path)
    if authorized 
      resp = @connection.delete(path)
      if resp.status == 200
        return JSON.parse(resp.body) 
      end
      @error = JSON.parse(resp.body)['message']
      raise CitySDK_Exception.new(@error)
    end
    raise CitySDK_Exception.new("DEL needs authorization.")
  end
  
  def post(path,data)
    if authorized 
      resp = @connection.post(path,data.to_json)
      return JSON.parse(resp.body) if resp.status == 200
      @error = JSON.parse(resp.body)['message']
      raise CitySDK_Exception.new(@error)
    end
    raise CitySDK_Exception.new("POST needs authorization.")
  end

  def put(path,data)
    if authorized 
      resp = @connection.put(path,data.to_json)
      return JSON.parse(resp.body) if resp.status == 200
      
      puts resp.body
      
      @error = JSON.parse(resp.body)['message']
      raise CitySDK_Exception.new(@error)
    end
    raise CitySDK_Exception.new("PUT needs authorization.")
  end
  
end
