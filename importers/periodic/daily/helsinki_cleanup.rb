require 'date'
require '/var/www/csdk_cms/current/utils/citysdk_api.rb'

pw = JSON.parse(File.read('/var/www/citysdk/shared/config/cdkpw.json')) if File.exists?('/var/www/citysdk/shared/config/cdkpw.json')
$email = ARGV[0] || 'citysdk@waag.org'
$password = ARGV[1] || pw ? pw[$email] : ''


$layer = '311.helsinki'
$api = CitySDK_API.new($email,$password)
if $api.authenticate == false 
  puts "Auth failure.."
  $stderr.puts "Auth failure.."
  exit!
end


puts "Cleaning up layer #{$layer}.."
$stderr.puts "Cleaning up layer #{$layer}.."


url = "/nodes?layer=#{$layer}&per_page=10&skip_webservice"
page = 1
count = 0
now = Date.today
begin
  resp = $api.get(url + "&page=#{page}")
  resp['results'].each do |n|
    u = Date.parse n['layers'][$layer]['data']['updated_datetime']
    if (now - u).to_i > 90 
      $api.delete("/#{n['cdk_id']}/#{$layer}?delete_node=true")
      count += 1
    end
  end
  page = resp['next_page'].to_i
end while page > 0

$api.release()

puts "\tdeleted #{count} nodes."
$stderr.puts "\tdeleted #{count} nodes."
