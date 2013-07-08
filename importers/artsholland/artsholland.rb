require 'date'
require '/var/www/csdk_cms/current/utils/citysdk_api.rb'

pw = JSON.parse(File.read('/var/www/citysdk/shared/config/cdkpw.json')) if File.exists?('/var/www/citysdk/shared/config/cdkpw.json')
$email = ARGV[0] || 'citysdk@waag.org'
$password = ARGV[1] || (pw ? pw[$email] : '')


$ahApiKey = '91f8cb2755d2683eb442b3837dbe6274'

# Read SPARQL from file:
sparql = File.open('artsholland.sparql','r').read
# Get current datetime to use in SPARQL:
now = DateTime.now.strftime()

$ahPostData = {
  :output => :json,
  :query => sparql % [now]
}

$ahConn = Faraday.new :url => "http://api.artsholland.com" 

puts "Downloading Arts Holland venues..."
response = $ahConn.post do |req|
  req.url '/sparql'
  req.headers = {
   'Content-Type' => 'application/x-www-form-urlencoded',
   'Accept' => 'application/sparql-results+json'
  }
  req.params['api_key'] = $ahApiKey
  req.body = $ahPostData
end

venues = {}
if response.status == 200 
  results = JSON.parse(response.body)
      
  results["results"]["bindings"].each { |venue|
    
    data = {
      :title => venue["title"]["value"],
      :uri => venue["v"]["value"],
      :"street-address" => venue["streetaddress"]["value"],
      :"postal-code" => venue["postalcode"]["value"],
      :locality => venue["locality"]["value"]
    }
    
    if venue.has_key? "telephone"
      data[:telephone] = venue["telephone"]["value"]
    end 

    if venue.has_key? "homepage"
      data[:website] = venue["homepage"]["value"]
    end

    venues[venue["cidn"]["value"]] = {
      :id => venue["cidn"]["value"],
      :name => venue["title"]["value"],
      :geom => {
        :type => :Point,
        :coordinates => [
          venue["lon"]["value"].to_f,
          venue["lat"]["value"].to_f
        ]
      },
      :data => data
    }
  }
   
end
puts "\tDownloaded #{venues.length} venues"

# TODO: many Arts Holland venues have a website. Searching 
# on osm::website could help!
# Make mapping array for Match API to link AH website and OSM website

match = {
  :match => {
    :params => {
      :radius => 250,
      :debug => true,
      :geometry_type => :point,
      :data_op => "or",
      :layers => {
        :osm => {
          :tourism => [
            "museum",          
            "botanical_garden",
            "attraction",
            "zoo",
            "botanical_garden",
            "theme_park",
            "hotel"
          ],
          :amenity => [
            "nightclub",
            "theatre",
            "place_of_worship",
            "pub",
            "cafe",
            "cinema",
            "school",
            "library",
            "university",
            "college",
            "townhall"
          ],
          :leisure => [
            "stadium"
          ],
          :garden => [
            "botanical"
          ],
          :historic => [
            "monument",
            "castle"
          ],
          :shop => [
            "books"
          ],
          :building => [
            "church"
          ]
        }
      }
    },
    :known => JSON.parse(File.read('./known_matches.json')) 
  }
}

$api = CitySDK_API.new($email, $password)
if $api.authenticate == false 
  puts "Auth failure with citysdk."
  exit!
end
$api.set_layer('artsholland')
$api.set_matchTemplate( match )
venues.each_key do |k|
  $api.match_create_node(venues[k])
end

u,c = $api.release
$stderr.puts("nodes updated: #{u}\n nodes created #{c}")
puts("nodes updated: #{u}\n nodes created #{c}")


# TODO: Add to known_matches.json:
# Current old version of OSM DB does not include Gemeentemuseum Den Haag:
# "c74624f4-48ea-43c3-a8b2-8554610c746c": "w58578390",

# See what matches are made:
#   SELECT cdk_id, name, data -> 'title' AS title 
#   FROM nodes JOIN node_data ON nodes.id = node_data.node_id
#   WHERE nodes.layer_id = 0 AND node_data.layer_id = 8;
#
# And what venues could not be matched:
#   SELECT name, data -> 'uri' AS uri 
#   FROM nodes JOIN node_data ON nodes.id = node_data.node_id
#   WHERE nodes.layer_id = 8;




