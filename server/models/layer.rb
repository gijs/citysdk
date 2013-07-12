
#custom model for intelligence, because sequel model 
#doesn't allow custom insert statements easily
require "sequel/model"

class Layer < Sequel::Model
  many_to_one :owner
  one_to_many :node_data, :class => :NodeDatum
  
	plugin :validation_helpers
  plugin :json_serializer
  
  def validate
    super
    validates_presence [:name, :description, :organization, :category]
    validates_unique :name
    validates_format /^\w+(\.\w+)*$/, :name
    validates_format /^\w+\.\w+$/, :category
    
    cname = self.category.split('.')[0]
    if Category.where(:name => cname).first == nil
      errors.add(:category,"Cannot be '#{cname}'")
    end
    
  end
  
  
  
  @@layerIdHash = {};
  @@layerTextHash = {};

  # TODO: lelijk! maak functies of hoe dan ook!
  @@layerIsRealtime = {};
  @@layerIsWebservice = {};
  @@layerWebserviceUrl = {};

  @@LayerValidity = {};
	@@LayerUpdateRate = {};
  
  # def validate
  #   super
  #   validates_presence [:body, :latitude, :longitude]
  # end
    
  def self.get_validity(id) 
    if @@layerIsRealtime[id]
      return true, @@LayerUpdateRate[id]
    else
      return false, @@LayerValidity[id]
    end
  end

  def serialize(params)
    h = {
      :name => name,
      :category => category,
      :organization => organization,
      :owner => owner.email,
      :description => description,
      :data_sources => data_sources ? data_sources.map { |s| s.index('=') ? s[s.index('=')+1..-1] : s } : [],
      :imported_at => imported_at
      }
      if realtime 
        h[:update_rate] = update_rate
      else
        h[:validity] = [validity.begin, validity.end] if validity
      end
      
      if !bbox.nil? and params.has_key? 'geom'
         h[:bbox] = RGeo::GeoJSON.encode(CitySDK_API.rgeo_factory.parse_wkb(bbox))
      end
      h
  end

  def self.idFromText(p)
    # Accepts full layer names and layer names
    # with wildcards after dot layer separators:
    #    cbs.*
    case p
    when Array
      return p.map do |name| self.idFromText(name) end.flatten.uniq
    when String        
      if p.include? "*"
        # wildcards can only be used once, on the end of layer specifier after "." separator
        if p.length >= 3 and p.scan("*").size == 1 and p.scan(".*").size == 1 and p[-2,2] == ".*"
          prefix = p[0..(p.index("*") - 1)]
          return @@layerIdHash.select{|k,v| k.start_with? prefix}.values
        else
          CitySDK_API.do_abort(422,"You can only use wildcards in layer names directly after a name separator (e.g. osm.*)")
        end
      else
        return @@layerIdHash[p]
      end
    end
  end
 
  def self.textFromId(id)
    @@layerTextHash[id]
  end

  ##########################################################################################
  # Real-time/web service layers:
  ##########################################################################################

  def self.isRealtime?(id)    
    @@layerIsRealtime[id]
  end

  def self.isWebservice?(id)
    @@layerIsWebservice[id]
  end

  def self.getWebserviceUrl(id)
    if @@layerWebserviceUrl.has_key? id
      @@layerWebserviceUrl[id]
    end
  end

  def self.getData(id, node_id, data)
    WebService.load(id, node_id, data)
  end
  
  def self.getDataTimeout(id)
    @@LayerUpdateRate[id] || 3000
  end


  ##########################################################################################
  # Initialize layers hash:
  ##########################################################################################
  
  def self.getLayerHashes
    @@layerIdHash = {};
    @@layerTextHash = {};
    @@layerIsRealtime = {};
    @@layerIsWebservice = {};
    @@layerWebserviceUrl = {};
    @@LayerValidity = {};
  	@@LayerUpdateRate = {};

    Layer.all.each do |l|
      id = l[:id]
      
      @@layerIdHash[l[:name]] = id
      @@layerTextHash[id] = l[:name]
      
      @@layerIsRealtime[id] = l[:realtime]      
      @@LayerValidity[id] = l[:validity]
    	@@LayerUpdateRate[id] = l[:update_rate]
      
      webservice = l[:webservice]
      #TODO find generic way 
      if webservice and webservice.length > 0
        @@layerIsWebservice[id] = (l.name != 'ns')
        @@layerWebserviceUrl[id] = l[:webservice]
      else
        @@layerIsWebservice[id] = false
      end
    end
  end  
  
end

Layer.getLayerHashes




