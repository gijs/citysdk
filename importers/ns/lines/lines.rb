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

lines = {}

# Download stations using NS API

  ns = JSON.parse(File.read('/var/www/citysdk/shared/config/nskey.json')) if File.exists?('/var/www/citysdk/shared/config/nskey.json')

  @ns = Faraday.new :url => "https://webservices.ns.nl", :ssl => {:verify => false}
  @ns.basic_auth(ns['usr'], ns['key'])
  xml = @ns.get "/ns-api-stations-v2"
  stations_all = Hash.from_xml(xml.body)['Stations']['Station']

  stations_code = {}
  stations_name = {}
  stations_all.each { |station|
    if station["Land"] == "NL" #and s['Code'] and s['Namen']['Lang']
      stations_code[station['Code']] = station['Namen']['Lang']
      stations_name[station['Namen']['Lang']] = station['Code']
    end
  }

# Download lines using NS API
if ARGV.length == 0

  termini = []
  CSV.foreach("termini.csv", {:headers => true, :col_sep => ";", :encoding => 'utf-8'}) do |row|
    termini << stations_name[row["naam"]]
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
    
        puts "#{i}/#{n}: #{stations_code[a]} to #{stations_code[b]}!"    
        xml = @ns.get "/ns-api-treinplanner", { :fromStation => a, :toStation => b, :dateTime => "2013-06-26T12:00" }   
        trips_all = Hash.from_xml(xml.body)
      
        if trips_all.has_key? "ReisMogelijkheden" and trips_all["ReisMogelijkheden"].has_key? "ReisMogelijkheid"
          trips = trips_all["ReisMogelijkheden"]["ReisMogelijkheid"].select {|trip|
            trip["AantalOverstappen"] == "0" #and trip["Optimaal"] == "true"
          }
      
          if trips.length > 0
            trips.each { |trip|
              type = trip["ReisDeel"]["VervoerType"].downcase
            
              stops = trip["ReisDeel"]["ReisStop"].map { |stop| 
                stations_name[stop["Naam"]]
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

# Write intermediate data to file:
File.open("lines.json", 'w') { |file| file.write(JSON.pretty_generate(lines)) }

lines.each do |type, stations|
  stations.each do |code1, trips|
    trips.each { |trip|
      trip.each_with_index { |code2, i|
        trip[i] = stations_code[code2]
      }
    }
  end
end

File.open("lines_debug.json", 'w') { |file| file.write(JSON.pretty_generate(lines)) }

puts JSON.pretty_generate(lines)