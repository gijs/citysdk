require 'amatch'

class CitySDK_API < Sinatra::Base
  
  # TODO: move to Node class??
  module NodeCompare
  
    NAME_DISTANCE_THRESHOLD = 0.4
    DATA_DISTANCE_THRESHOLD = 0
    
    THRESHOLD = 1.5
    
    SUBSTRING_MATCH_THRESHOLD = 10
    
    def self.filter_and_sort(node, matches, params) 
      
      # if matches.length > 0
      #   puts "%s: %s" % [node["name"], matches.map { |match| match[:name] }.join(", ")]
      # else
      #   puts "%s: NOTHING FOUND" % [node["name"]]
      # end
      # 
      # puts matches.map { |match| 
      #   [NodeCompare.compare(node, match, params), match] 
      # }.sort { |a, b|
      #   (a[0] <=> b[0]) 
      # }.select { |a|
      #   a[0] < THRESHOLD
      # }.map { |a|
      #   a[1]
      # }.inspect
      
      matches.map { |match| 
        [NodeCompare.compare(node, match, params), match] 
      }.sort { |a, b|
        (a[0] <=> b[0]) 
      }.select { |a|
        a[0] < THRESHOLD
      }.map { |a|
        a[1]
      }      
    end
    
    def self.compare(node, match, params)      
      # Als afstand klein en data komt overeen maar naam niet: toch hoge score
      
      name_distance = self.compare_name(node["name"], match[:name], params)
      data_distance = self.compare_data(node["data"], match[:data], params)
      
      meters = match[:distance]
      radius = params["radius"]
      
      geom_distance = (1.3 ** ((meters - radius + 200) / 20) + meters / 10) / 25

      return name_distance + geom_distance + data_distance
    end
    
    def self.compare_data(a, b, params)
      return 0
    end
          
    def self.compare_name(a, b, params)
      c = 0
      if a and b and a.strip.length > 0 and b.strip.length > 0
        if a == b
          c = 1
        elsif (a.downcase.include? b.downcase and b.length >= SUBSTRING_MATCH_THRESHOLD) or
          (b.downcase.include? a.downcase and a.length >= SUBSTRING_MATCH_THRESHOLD)
          # If a is completely contained by b, or the other way around
          # (and they don't differ too much in length)
          # Example: "Stedelijk Museum" = "Stedelijk Museum Amsterdam"
          # Example: "Carré" = "Koninklijk Theater Carré"          
          c = 0.7
        else
          c = a.pair_distance_similar(b)
        end      
      end
      #puts [a, b].inspect 
      return 4 * (1 - c) ** 2
    end
    
  end
  
end