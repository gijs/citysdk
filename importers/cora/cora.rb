require '/var/www/csdk_cms/current/utils/citysdk_api.rb'

# CORA

pw = JSON.parse(File.read('/var/www/citysdk/shared/config/cdkpw.json')) if File.exists?('/var/www/citysdk/shared/config/cdkpw.json')
$email = ARGV[0] || 'citysdk@waag.org'
$password = ARGV[1] || (pw ? pw[$email] : '')

$api = CitySDK_API.new($email, $password)

$api.set_host('localhost',3000)
cora_host = "https://dl.dropboxusercontent.com"
cora_path = "/u/12905316/citysdk/cora/%s_Amsterdam_GeoJson.json"

if $api.authenticate == false 
  puts "Auth failure with citysdk."
  exit!
end

layers = {
  #"belemmeringen",
  #"omleidingen",
  "projecten" => "WIORPR_ID"
}
 
layers.each { |layer, id| 
 
   ###### Download CORA data ######
   puts "Downloading CORA data: #{layer}..."
 
   cora_conn = Faraday.new(:url => cora_host)
   response = cora_conn.get cora_path % [layer]
   results = JSON.parse(response.body)
 
   nodes = results['features'].map do |f|
     {
       :id => f['properties']['WIORPR_ID'],       
       :geom => f['geometry'],
       :data => f['properties']       
     }
   end
 
   puts "Received #{nodes.length} nodes.."
   $stderr.puts "Received #{nodes.length} nodes.."
 
   $api.set_layer("cora.#{layer}")
 
   $api.set_createTemplate( {
     :create => {
       :params => {
         :create_type => "create",
         :srid => 28992
       }
     }
   } )
 
   # puts JSON.pretty_generate(   
   # nodes.map do |n|
   #   {
   #     :id => n[:id]
   #   }
   # end
   # )
   
   nodes.each do |n|
     $api.create_node(n)
   end
 
}

$api.release

