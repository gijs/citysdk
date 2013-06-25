require '/var/www/csdk_cms/current/utils/citysdk_api.rb'

# CORA

pw = JSON.parse(File.read('/var/www/citysdk/shared/config/cdkpw.json')) if File.exists?('/var/www/citysdk/shared/config/cdkpw.json')
$email = ARGV[0] || 'citysdk@waag.org'
$password = ARGV[1] || (pw ? pw[$email] : '')


begin 
$api = CitySDK_API.new($email, $password)

# cora_host = "https://dl.dropboxusercontent.com"
# cora_path = "/u/12905316/citysdk/cora/%s_Amsterdam_GeoJson.json"

cora_host = "http://dev.citysdk.waag.org"
cora_path = "/%s_Amsterdam_GeoJson.json"

if $api.authenticate == false 
  puts "Auth failure with citysdk."
  exit!
end

layers = {
  # "belemmeringen"=>"PROJECT_ID",
  # "omleidingen"=>"OMLEIDING_ID",
  "projecten" => "WIORPR_ID"
}

def downkeys(h) 
  hh = {}
  h.each do |k,v|
    hh[k.downcase] = v
  end
  return hh
end
  


$api.batch_size = 1

count = 10000
 
layers.each { |layer, id| 
 
   ###### Download CORA data ######
   puts "Downloading CORA data: #{layer}..."
 
   cora_conn = Faraday.new(:url => cora_host)
   response = cora_conn.get cora_path % [layer]
   results = JSON.parse(response.body)
 

   $api.set_layer("divv.cora.#{layer}")
 
   $api.set_createTemplate( {
     :create => {
       :params => {
         :create_type => "create",
         :srid => 28992
       }
     }
   } )

   results['features'].each do |f|

     count += 1
     begin
       $api.create_node(
         {
           :id => f['properties'][id].to_s,       
           # :id => count.to_s,       
           :geom => f['geometry'],
           :data => downkeys(f['properties'])
         })
     rescue
     end
   end
   
   # puts "Received #{nodes.length} nodes.."
   # $stderr.puts "Received #{nodes.length} nodes.."
 
 
   # puts JSON.pretty_generate(   
   # nodes.map do |n|
   #   {
   #     :id => n[:id]
   #   }
   # end
   # )
   
 
}

ensure 

$api.release

end