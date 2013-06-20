class NodeDatum < Sequel::Model
  
  module WebService   
    require 'faraday'
    require 'net/http'
    require 'uri'    


    #http://localhost:3000/admr.nl.stichtse_vecht_wijk_09_oudover_en_mijnden?layer=rain
    
    def self.memcache_key(layer_id, cdk_id)
      l = Layer.textFromId(layer_id)
      return "#{l}!!#{cdk_id}"
    end
    
    def self.load_from_ws(url,data)
      connection = Faraday.new(:url => url)
      response = connection.post('',data.to_json)
      if(response.status == 200) 
        begin
          r = JSON.parse(response.body)
          return r['data']
        rescue Exception => e
          puts e.message
        end
      else
        puts response.body
      end
      return nil
    end

    def self.load(layer_id, cdk_id, hstore)
      key = memcache_key(layer_id, cdk_id)
      data = CitySDK_API.memcache_get(key)      
      if data        
        return data
      else
        url = Layer.getWebserviceUrl(layer_id)
        data = load_from_ws(url,hstore)
        if(data)
          CitySDK_API.memcache_set(key, data, Layer.getDataTimeout(layer_id) )
          return data
        end
      end
      hstore
    end    


  end 
end