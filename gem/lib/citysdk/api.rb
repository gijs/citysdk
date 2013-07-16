require 'json'
require 'faraday'

module CitySDK
  
  class HostException < ::Exception
  end

  class API
    attr_reader :error
    attr_accessor :batch_size
  
    @@match_tpl = {
      :match => {
        :params => {}
      },
      :nodes => []
    }
    @@create_tpl =  {
      :create => {
        :params => {
          :create_type => "create"
        }
      },
      :nodes => []
    }

    def initialize(host, port=80)
      @error = '';
      @layer = '';
      @batch_size = 10;
      @updated = @created = 0;
      set_host(host,port)
    end
    
    def authenticate(e,p)
      @email = e;
      @passw = p;
      if !( @host == 'api.dev' or @host == 'localhost' or @host == '127.0.0.1')
        auth_connection = Faraday.new :url => "https://#{@host}", :ssl => {:verify => false}
        resp = auth_connection.get '/get_session', { :e => @email, :p => @passw }
      else 
        resp = @connection.get '/get_session', { :e => @email, :p => @passw }
      end
      if resp.status == 200 
        resp = CitySDK::parseJson(resp.body)
        if resp[:status] == 'success'
          @connection.headers['X-Auth'] = resp[:results][0]
        else
          raise Exception.new(resp[:message])
        end
      else
        raise Exception.new(resp.body)
      end
      
      if block_given?
        yield
        return self.release
      end
      true
    end

    def set_host(host,port=80)
      @host  = host
      @port  = port
      @connection = Faraday.new :url => "http://#{@host}:#{@port}"
      @connection.headers = {
        :user_agent => 'CitySDK_API GEM ' + CitySDK::VERSION,
        :content_type => 'application/json'
      }
      begin 
        get('/')
      rescue Exception => e
        raise CitySDK::Exception.new("Trouble connecting to api @ #{host}")
      end
      @create = @@create_tpl
      @match = @@match_tpl
    end

    def set_matchTemplate(mtpl) 
      mtpl[:nodes] = []
      @match = @@match_tpl = mtpl
    end

    def set_createTemplate(ctpl) 
      ctpl[:nodes] = []
      @create = @@create_tpl = ctpl
    end

    def set_layer(l)
      @layer = l
    end
  
    def set_layer_status(status)
      put("/layer/#{@layer}/status",{:data => status})
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
  
    def authorized?
      @connection.headers['X-Auth']
    end

    def release
      match_flush
      create_flush # send any remaining entries in the create buffer
      match_create_flush
      if authorized?
        resp = @connection.get('/release_session')
        if resp.status == 200
          @connection.headers.delete('X-Auth')
        else
          @error = CitySDK::parseJson(resp.body)[:message]
          raise HostException.new(@error)
        end
      end
      return [@updated, @created]
    end
  
    def delete(path)
      if authorized? 
        resp = @connection.delete(path)
        if resp.status == 200
          return CitySDK::parseJson(resp.body) 
        end
        @error = CitySDK::parseJson(resp.body)[:message]
        raise HostException.new(@error)
      end
      raise CitySDK::Exception.new("DEL needs authorization.")
    end
  
    def post(path,data)
      if authorized? 
        resp = @connection.post(path,data.to_json)
        return CitySDK::parseJson(resp.body) if resp.status == 200
        @error = CitySDK::parseJson(resp.body)[:message]
        raise HostException.new(@error)
      end
      raise CitySDK::Exception.new("POST needs authorization.")
    end

    def put(path,data)
      if authorized? 
        resp = @connection.put(path,data.to_json)
        return CitySDK::parseJson(resp.body) if resp.status == 200
        @error = CitySDK::parseJson(resp.body)[:message]
        raise HostException.new(@error)
      end
      raise CitySDK::Exception.new("PUT needs authorization.")
    end

    def get(path)
      resp = @connection.get(path)
      return CitySDK::parseJson(resp.body) if resp.status == 200
      @error = CitySDK::parseJson(resp.body)[:message]
      raise HostException.new(@error)
    end

    def match_create_flush
      
      if @match[:nodes].length > 0
        resp = post('util/match',@match)
        if resp[:nodes].length > 0 
          @create[:nodes] = resp[:nodes]
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

    def tally(res)
      if res[:status] == "success"
        # TODO: also tally debug data!
        @updated += res[:create][:results][:totals][:updated]
        @created += res[:create][:results][:totals][:created]
      end
    end
    
  end

end

