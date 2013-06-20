require 'csv'
require 'faraday'
require 'json'

server = "localhost:3000"

email = ARGV[0]
password = ARGV[1]

bridges = []

CSV.foreach("bridge.csv", {:headers => true, :col_sep => ";"}) do |row|   
  bridges << {
    :id => row['KEY'],
    :name => row['NAME'],
    :geom => {
       :type => "Point",
        :coordinates => [
          row['LONGITUDE'].gsub(',', '.').to_f,
          row['LATITUDE'].gsub(',', '.').to_f,
        ]
     },
     :data =>  {}     
  }  
end

CSV.foreach("bridge_state.csv", {:headers => true, :col_sep => ";"}) do |row|   
  bridge = bridges.select { |bridge| bridge[:id] == row['KEY']}
  bridge[0][:data][:state] = row['STATE'].downcase
end

match = {
  :match => {
    :params => {
      :radius => 150,
      :debug => true,
      :match_type => :multiple,
      :geometry_type => :point,
      :layers => {
        :osm => {
          :bridge => :yes
        }
      }
    }
  },
  :nodes => bridges
}

$apiConn = Faraday.new :url => "http://#{server}" 
resp = $apiConn.get '/get_session', { :e => email, :p => password }
if resp.status == 200
  resp = JSON.parse(resp.body)
  $apiConn = Faraday.new :url => "http://#{server}"
  $apiConn.headers = {
     'X-Auth' => resp['results'][0], 
     'Content-Type' => 'application/json'
   } 
else
  puts "Failed to get write session with api.. (#{resp.body})"
  exit -1;
end

response = $apiConn.post '/util/match', match.to_json
if response.status == 200 
  results = JSON.parse(response.body)

  create = {
    :create => {
      :params => {
        :create_type => "update"
      }
    },
    :nodes => results["nodes"]
  }
  
  response = $apiConn.put '/nodes/bridge', create.to_json
  if response.status == 200 
    results = JSON.parse(response.body)
    puts "Gelukt!"
  else
    puts "Failed: (#{response.body})"
  end
  
  $apiConn.get '/release_session'
else
  puts "Failed: (#{response.body})"
  exit -1
end