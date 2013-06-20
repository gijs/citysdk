require '/var/www/csdk_cms/current/utils/citysdk_api.rb'

pw = JSON.parse(File.read('/var/www/citysdk/shared/config/cdkpw.json')) if File.exists?('/var/www/citysdk/shared/config/cdkpw.json')
$email = ARGV[0] || 'citysdk@waag.org'
$password = ARGV[1] || pw ? pw[$email] : ''


locations = JSON.parse(File.open('./locaties.json', 'r:UTF-8').read) 
locations = locations["parkeerlocaties"].map {|wrapper|
  location = wrapper["parkeerlocatie"]
  {
    :id => location["title"],
    :name => location["title"],
    :geom => location["Locatie"],
    :modalities => ["car"],
    :data => {
      :title => location["title"],
      :type => location["type"],
      :url => location["url"],
      :adres => location["adres"],
      :postcode => location["postcode"],
      :woonplaats => location["woonplaats"]
    }.delete_if {|k,v| v.nil? }
  }
}



$api = CitySDK_API.new($email, $password)
if $api.authenticate == false 
  puts "Auth failure with citysdk."
  exit!
end

match_parking = {
  :match => {
    :params => {
      :radius => 150,
      :debug => true,
      :match_type => :single,
      :geometry_type => :point,
      :layers => {
        :osm => {
          :amenity => "parking"
        }
      }
    }
  }
}

match_taxi = {
  :match => {
    :params => {
      :radius => 150,
      :debug => true,
      :match_type => :single,
      :geometry_type => :point,
      :layers => {
        :osm => {
          :amenity => "taxi"
        }
      }
    }
  }
}


$api.set_layer('divv.parking')
$api.set_matchTemplate( match_parking )
locations.map do |node| 
  if ["Parkeergarage", "P+R"].include?(node[:data][:type])
    $api.match_create_node(node)
  end
end

$api.set_layer('divv.taxi')
$api.set_matchTemplate( match_taxi )
locations.map do |node| 
  if node[:data][:type] == 'Taxistandplaats'
    $api.match_create_node(node)
  end
end

$api.release
