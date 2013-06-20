class Sequel::Model
  @@node_types = ['node','route','ptstop','ptline']  
end


class Node < Sequel::Model
  #plugin :validation_helpers
  one_to_many :node_data

  def getLayer(n)
    if n.is_a?(String)
      self.node_data.each do |nd|
        return nd if nd.layer.name == n
      end
    else
      self.node_data.each do |nd|
        return nd if nd.layer_id == n
      end
    end
    nil
  end

  def self.serialize(h,params)    
    h[:layers] = NodeDatum.serialize(h[:cdk_id], h[:node_data], params) if h[:node_data]

    # members not directly exposed, 
    # call ../ptstops form members of route, f.i.
    h.delete(:members)

    h[:layer] = Layer.textFromId(h[:layer_id])
    h[:name] = '' if h[:name].nil?
    if params.has_key? "geom"
      if h[:member_geometries] and h[:node_type] != 3
        h[:geom] = RGeo::GeoJSON.encode(CitySDK_API.rgeo_factory.parse_wkb(h[:member_geometries])) if h[:member_geometries]
      elsif h[:geom]
        h[:geom] = RGeo::GeoJSON.encode(CitySDK_API.rgeo_factory.parse_wkb(h[:geom])) if h[:geom]
      end
    else
      h.delete(:geom)
    end
    
    if h[:modalities]
      h[:modalities] = h[:modalities].map { |m| Modality.NameFromId(m) }
    else
      h.delete(:modalities)
    end

    h.delete(:related) if h[:related].nil?
    h.delete(:member_geometries)    
    #h.delete(:modalities) if (h[:modalities] == [] or h[:modalities].nil?)
    h[:node_type] = @@node_types[h[:node_type]]
    h.delete(:layer_id)
    h.delete(:id)
    h.delete(:node_data)
    h.delete(:created_at)
    h.delete(:updated_at)

    if h.has_key? :collect_member_geometries
      h.delete(:collect_member_geometries)
    end

    h
  end

end

