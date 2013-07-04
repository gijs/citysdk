require "../../rce/rijksmonumenten"
require 'active_support/core_ext'
require '/var/www/csdk_cms/current/utils/citysdk_api.rb'

pw = JSON.parse(File.read('/var/www/citysdk/shared/config/cdkpw.json')) if File.exists?('/var/www/citysdk/shared/config/cdkpw.json')
ns = JSON.parse(File.read('/var/www/citysdk/shared/config/nskey.json')) if File.exists?('/var/www/citysdk/shared/config/nskey.json')
$email = ARGV[0] || 'citysdk@waag.org'
$password = ARGV[1] || (pw ? pw[$email] : '')

@ns = Faraday.new :url => "https://webservices.ns.nl", :ssl => {:verify => false}
@ns.basic_auth(ns['usr'], ns['key'])
xml = @ns.get "/ns-api-stations"

# TODO: Use ns-api-stations-v2

stations = Hash.from_xml(xml.body)['stations']
stations = stations['station']

nodes = stations.map do |s|
  # TODO: Niet alleen Nederlandse stations??
  if s["country"] == "NL" and s['alias'] == 'false' and s['code']
    s.delete('alias')
    lat = s.delete('lat')
    lng = s.delete('long')
    {
      :id => s['code'],
      :name => s['name'],
      :geom => {
        :type => :Point,
        :coordinates => [
          lng.to_f,
          lat.to_f
        ]
      },
      :data => s
    }
  else
    nil
  end
end.compact

puts "Received #{nodes.length} stations.."
$stderr.puts "Received #{nodes.length} stations.."

$api = CitySDK_API.new($email, $password)
if $api.authenticate == false 
  puts "Auth failure with citysdk."
  exit!
end
$api.set_layer('ns')

$api.set_matchTemplate( {
  :match => {
    :params => {
      :radius => 350,
      :debug => true,
      :geometry_type => :point,
      :layers => {
        :osm => {
          :railway => :station
        }
      }
    }
  }
} )

$api.set_createTemplate( {
  :create => {
    :params => {
      :create_type => "create",
      :node_type => "ptstop"
    }
  }
} )


nodes.each do |n|
  $api.match_create_node(n)
end

u,c = $api.release
$stderr.puts("nodes updated: #{u}\n nodes created #{c}")
puts("nodes updated: #{u}\n nodes created #{c}")





# See what matches are made:
#   SELECT cdk_id, name, data -> 'naam_lang' AS title 
#   FROM nodes JOIN node_data ON nodes.id = node_data.node_id
#   WHERE nodes.layer_id = 0 AND node_data.layer_id = 12;
#
# And what venues could not be matched:
#   SELECT name, data -> 'code' AS code 
#   FROM nodes JOIN node_data ON nodes.id = node_data.node_id
#   WHERE nodes.layer_id = 12
