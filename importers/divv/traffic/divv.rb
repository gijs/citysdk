require 'json'
require 'pg'
require 'net/http'
require 'faraday'
require 'active_support/core_ext'

local_ip = UDPSocket.open {|s| s.connect("123.123.123.123", 1); s.addr.last}
if(local_ip =~ /192\.168|10\.0\.135/)
  dbconf = JSON.parse(File.read('../../../server/database.json'))
  HOST = 'localhost'
  PORT = 3000
else
  dbconf = JSON.parse(File.read('/var/www/citysdk/current/database.json'))
  HOST = 'test-api.citysdk.waag.org'
  PORT = 80
end

$apiConn  = nil
$email = ARGV[0]
$password = ARGV[1] || ''

def authenticate  
  if HOST == 'localhost' 
    $apiConn = Faraday.new :url => "http://#{HOST}:#{PORT}" 
  else
    $apiConn = Faraday.new :url => "https://#{HOST}", :ssl => {:verify => false}
  end
  resp = $apiConn.get '/get_session', { :e => $email, :p => $password }
  if resp.status == 200
    resp = JSON.parse(resp.body)
    $apiConn = Faraday.new :url => "http://#{HOST}:#{PORT}"
    $apiConn.headers = {
       'X-Auth' => resp['results'][0], 
       'Content-Type' => 'application/json'
     } 
  else
    puts "Failed to get write session with api.. (#{resp.body})"
    exit -1;
  end
end

def do_match(h)
  response = $apiConn.post do |req|
    req.url '/util/match'
    req.headers['Content-Type'] = 'application/json'
    req.body = h.to_json
  
    req.options['timeout'] = 5 * 60
    req.options['open_timeout'] = 5 * 60
  end
  
  if response.status == 200 
    results = JSON.parse(response.body)

    nodes = results["nodes"]
    
    return nodes
  end
  nil
end


divv_url = 'http://www.trafficlink-online.nl/trafficlinkdata/wegdata/TrajectSensorsNH.GeoJSON'
divv_conn = Faraday.new(:url => divv_url)

db_conn = PGconn.new(dbconf['host'], '5432', nil, nil, dbconf['database'], dbconf['user'], dbconf['passwd'])

layer_name = 'divv.traffic'

# TODO: use API:
res = db_conn.exec("SELECT id FROM layers WHERE name = '#{layer_name}'");
layer_id = res[0]['id'].to_i if res.cmdtuples > 0
if(layer_id.nil?)
  $stderr.puts "No '#{layer_name}' layer found!"
  exit(-1)
end

###### Delete old data ######

# TODO: use API:
truncate = <<-SQL
  DELETE FROM nodes WHERE layer_id = #{layer_id};
  DELETE FROM node_data WHERE layer_id = #{layer_id};
SQL

db_conn.exec(truncate)

###### Download DIVV traffic data ######
puts 'Downloading DIVV data...'

response = divv_conn.get
response.body
result = JSON.parse(response.body)

allnodes = []
result['features'].each do |feature|
  properties = feature['properties']
  location = properties['LOCATION']
  object_type = properties['DSSObjectType'].downcase
  geojson = feature['geometry']
  
  allnodes << {
    :id => location,
    :name => location,
    :modalities => ["car"],
    :geom => geojson,
    :data => {
      :location => location,
      :object_type => object_type
     }
  }
end

authenticate

# osm_tags_bike = {
#   'highway' => ['unclassified', 'cycleway'],
#   'bicycle' => ['yes'],
#   'cycleway' => ['lane', 'track'],
#   'cycleway:left' => ['lane', 'track'],
#   'cycleway:right' => ['lane', 'track'],
#   'cycleway:both' => ['lane', 'track']  
# }

# osm_tags_foot = {
#   highway: footway
#   'highway' => ['path'],
#   'foot' => ['yes']
# }

###### Match with OSM ######
batch_size = 5
puts 'Match DIVV lines with OSM ways...'
i = 0
n = (allnodes.length / batch_size).ceil + 1
allnodes.in_groups_of(batch_size, false) do |batch|
  i += 1
  puts "  batch #{i}/#{n}"
  
  match = {
    :match => {
      :params => {
        :radius => 125,
        :srid => 28992,
        :debug => true,
        :match_type => :multiple,
        :geometry_type => :line,
        :ignore_oneway => false,
        :layers => {
          :osm => {
            "highway" => [  
              "unclassified", "road",
              "motorway", "motorway_link",
              "trunk", "trunk_link",
              "primary", "primary_link",
              "secondary", "secondary_link",
              "tertiary", "tertiary_link"
            ]
          }
        }
      }
    },
    :nodes => batch
  }
  
  results = do_match(match)

  if(results)
    create = {
      :create => {
        :params => {
          :srid => 28992,
          :create_type => "routes"
        }
      },
      :nodes => results
    }
  
    response = $apiConn.put "/nodes/#{layer_name}", create.to_json
    if response.status == 200 
      results = JSON.parse(response.body)
      puts "Gelukt!"
    else
      puts "Failed: (#{response.body})"
    end
    
  end
  
end


$apiConn.get '/release_session'

