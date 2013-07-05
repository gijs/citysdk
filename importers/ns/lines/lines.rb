require 'csv'
require 'active_support/core_ext'
require '/var/www/csdk_cms/current/utils/citysdk_api.rb'

# In totaal 405 stations in Nederland: 
#   405 * 405 = 170000
#   NS API: Max. 50.000 requests per dag...
# 
# Of alleen alle knooppunten en begin-/eindstations!
#   Bron: http://www.spoorkaart2013.nl/downloads/spoorkaart_2013_A4.pdf
# knooppunten.csv:
#   66 stations, 66 * 66 = 4356!
#   Dat is makkelijk!

ns_layer = "ns"

lines = {}
types = {
  "sprinter" => "Sprinter",
  "intercity" => "Intercity",
  "stoptrein" => "Stoptrein",
  "sneltrein" => "Sneltrein",
  "fyra" => "Fyra",
  "thalys" => "Thalys",
  "ice_international" => "ICE International"
}

# Download stations using NS API

ns = JSON.parse(File.read('/var/www/citysdk/shared/config/nskey.json')) if File.exists?('/var/www/citysdk/shared/config/nskey.json')

@ns = Faraday.new :url => "https://webservices.ns.nl", :ssl => {:verify => false}
@ns.basic_auth(ns['usr'], ns['key'])
xml = @ns.get "/ns-api-stations-v2"
stations_all = Hash.from_xml(xml.body)['Stations']['Station']

station_names = {}
station_codes = {}
stations_all.each { |station|
  if station["Land"] == "NL" #and s['Code'] and s['Namen']['Lang']
    station_names[station['Code']] = station['Namen']['Lang']
    station_codes[station['Namen']['Lang']] = station['Code']
  end
}

# Download lines using NS API
if ARGV.length == 0

  termini = []
  CSV.foreach("termini.csv", {:headers => true, :col_sep => ";", :encoding => 'utf-8'}) do |row|
    termini << station_codes[row["naam"]]
  end

  # Beter: gebruik alle stations uit termini.csv
  # roep http://webservices.ns.nl/ns-api-avt?station=ut aan
  # grijp voor alle verschillende eindbestemmingen de route?

  i = 0
  n = termini.length * termini.length - termini.length
  termini.each { |a|
    termini.each { |b|
      if a != b
        i += 1
    
        puts "#{i}/#{n}: #{station_names[a]} to #{station_names[b]}!"    
        xml = @ns.get "/ns-api-treinplanner", { :fromStation => a, :toStation => b, :dateTime => "2013-06-26T12:00" }   
        trips_all = Hash.from_xml(xml.body)
      
        if trips_all.has_key? "ReisMogelijkheden" and trips_all["ReisMogelijkheden"].has_key? "ReisMogelijkheid"
          trips = trips_all["ReisMogelijkheden"]["ReisMogelijkheid"].select {|trip|
            trip["AantalOverstappen"] == "0" #and trip["Optimaal"] == "true"
          }
      
          if trips.length > 0
            trips.each { |trip|
              type = trip["ReisDeel"]["VervoerType"].downcase.gsub(/\W+/, '_')
              # Add to global types hash:
              types[type] = trip["ReisDeel"]["VervoerType"]
            
              stops = trip["ReisDeel"]["ReisStop"].map { |stop| 
                station_codes[stop["Naam"]]
              }            
            
              if not lines.has_key? type
                lines[type] = {}
              end
            
              if not lines[type].has_key? a
                lines[type][a] = []
              end
            
              lines[type][a] << stops
            
              lines[type][a].uniq!
            }
          else
            puts "\t No trip possible without transfer."
          end
        else
          puts "\t No trip possible."
        end
    
      end
    }
  }

  # Write intermediate data to file:
  File.open("lines_all.json", 'w') { |file| file.write(JSON.pretty_generate(lines)) }
  
else
  # Read from file given in command line arguments
  lines = JSON.parse(IO.read(ARGV[0]))   
end

lines.each do |type, stations|
  stations.each do |code, trips|
    remove = []
    trips.each_with_index do |trip1, i|
      trips.each {|trip2| 
        if trip2.length > trip1.length and trip2[0..trip1.length-1] == trip1
          remove << i          
        end
      }
    end
    
    remove.uniq.each { |i|
      trips[i] = nil
    }   
    trips.compact!
  end
end


lines.each do |type, stations|
  stations.each do |code1, trips|
    trips.each { |trip|
      trip[1..-1].each_with_index { |code2, i|
        if stations.has_key? code2
          stations[code2].delete(trip[1+i..-1])
        end
      }
    }
  end
  # Remove empty arrays
  stations.each do |code, trips|
    if trips == []
      stations.delete(code)
    end
  end 
end  

lines.each do |type, stations|
  trips_new = []
  stations.each do |code, trips|
    trips.each { |trip|
      trips_new << trip
    }
  end
  lines[type] = trips_new
end


lines_debug = Marshal.load(Marshal.dump(lines))

lines_debug.each do |type, trips|
  trips.each { |trip|
    trip.each_with_index { |code, i|
      trip[i] = station_names[code]
    }
  }
end

# Write intermediate data to file:
File.open("lines.json", 'w') { |file| file.write(JSON.pretty_generate(lines)) }
File.open("lines_debug.json", 'w') { |file| file.write(JSON.pretty_generate(lines_debug)) }

# Write station data to file:
File.open("station_codes.json", 'w') { |file| file.write(JSON.pretty_generate(station_codes)) }
File.open("station_names.json", 'w') { |file| file.write(JSON.pretty_generate(station_names)) }

# Connect to CitySDK API

pw = JSON.parse(File.read('/var/www/citysdk/shared/config/cdkpw.json')) if File.exists?('/var/www/citysdk/shared/config/cdkpw.json')
$email = ARGV[1] || 'citysdk@waag.org'
$password = ARGV[2] || (pw ? pw[$email] : '')

@api = CitySDK_API.new($email, $password)
#@api.set_host("localhost", 3000)

create_tpl = {
  :create => {
    :params => {
      :create_type => "routes",
      :modalities => ["rail"]
    }
  }
}
@api.set_layer(ns_layer)
@api.set_createTemplate(create_tpl)

cdk_ids = {}
station_names.each { |code, name|
  qres = @api.get("/nodes?ns::code=#{code}")      
  if qres['status']=='success' and qres['results'] and qres['results'][0]
    cdk_id = qres['results'][0]['cdk_id']
    cdk_ids[code] = cdk_id
    puts "\t#{cdk_id} => #{code} (#{name})"
  end
}

# Write cdk_id mapping data to file:
File.open("cdk_ids.json", 'w') { |file| file.write(JSON.pretty_generate(cdk_ids)) }

if @api.authenticate == false 
  puts "Auth. failure with citysdk."
  exit!
end

ptlines = []
lines.each do |type, trips|
  trips.each { |trip|
    members = []
    trip.each { |code|
      members << cdk_ids[code] if cdk_ids[code]
    }

    ptline = {
      :id => "#{type}.#{trip[0]}.#{trip[-1]}".downcase,
      :name => "#{types[type]} #{station_names[trip[0]]} - #{station_names[trip[-1]]}",
      :cdk_ids => members,
      :modalities => ["rail"],
      :data => {
        :type => type
      }
    }
    @api.create_node(ptline)
    ptlines << ptline
  }
end

puts JSON.pretty_generate(ptlines)
@api.release