require 'date'
require 'active_support/core_ext'
require '/var/www/csdk_cms/current/utils/citysdk_api.rb'
require '/var/www/csdk_cms/current/utils/sysmail.rb'

pw = JSON.parse(File.read('/var/www/citysdk/shared/config/cdkpw.json')) if File.exists?('/var/www/citysdk/shared/config/cdkpw.json')
$email = ARGV[0] || 'citysdk@waag.org'
$password = ARGV[1] || (pw ? pw[$email] : '')


$adamSR = Faraday.new :url => "http://open311.dataplatform.nl"
$adamPath = "opentunnel/open311/v21/requests.xml?jurisdiction_id=0363&api_key=" + JSON.parse(File.read('/var/www/citysdk/shared/config/adam311.json'))['key']

$layer='311.amsterdam'
puts "Updating layer #{$layer}.."

$api = CitySDK_API.new($email,$password)



begin 
  $api.set_host('api.citysdk.waag.org')
  if $api.authenticate == false 
    puts "Auth failure"
    exit!
  end

  $api.set_layer($layer)

  updated = 0
  new_nodes = 0

  response = $adamSR.get($adamPath)
  if response.status == 200 
    nodes = Hash.from_xml(response.body)['service_requests']['request']
    puts "Number of requests: #{nodes.length}"
    
    nodes.each do |n|
      
      begin
          $api.get("/311.amsterdam.#{n['service_request_id']}")
          # no exception -> node exists -> update data
          data = {
            "data" => {
              "updated_datetime" => n['updated_datetime'],
              "status" => n['status']
            }
          }
          begin 
            $api.put("/311.amsterdam.#{n['service_request_id']}/311.amsterdam",data)
            updated += 1
          rescue Exception => e
            puts "Exception updating node: #{e.message}" 
          end
      rescue CitySDK_Exception => e # node not found..
          node = {
            "id" => n['service_request_id'],
            "name" => "",
            "geom" => {
               "type" => "Point",
                "coordinates" => [
                  n['long'],
                  n['lat']
                ]
             },
             "data" => {
               "updated_datetime" => n['updated_datetime'],
               "service_request_id" => n['service_request_id'],   
               "status" => n['status']
             }
          }  
          begin 
            $api.create_node(node)
            new_nodes += 1
          rescue Exception => e
            puts "Exception creating node: #{e.message}" 
          end
      end
    end

  else
    CitySDK.sysmail('error @ adam311',"Error accessing Amsterdam 311 api.")
    puts "Error accessing Amsterdam 311 api."
    puts response.body
  end

rescue Exception => e
  CitySDK.sysmail('error @ adam311',e.message)
  puts "Exception:"
  puts e.message
ensure
  $api.set_layer_status("updated #{updated} nodes; added #{new_nodes} nodes.")
  $api.release()
end

puts "\tupdated #{updated} nodes; added #{new_nodes} nodes.."
