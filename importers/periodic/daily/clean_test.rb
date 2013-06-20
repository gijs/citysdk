require 'date'
require '/var/www/csdk_cms/current/utils/citysdk_api.rb'

pw = JSON.parse(File.read('/var/www/citysdk/shared/config/cdkpw.json')) if File.exists?('/var/www/citysdk/shared/config/cdkpw.json')
$email = ARGV[0] || 'citysdk@waag.org'
$password = ARGV[1] || pw ? pw[$email] : ''


$layer = 'test.*'
$api = CitySDK_API.new($email,$password)
if $api.authenticate == false 
  puts "Auth failure.."
  $stderr.puts "Auth failure.."
  exit!
end

count = 0

obj = $api.get('layers?name=test')
if obj and obj['results']
  obj['results'].each do |l|
    if l['name'] =~ /^test\..+/
      $api.delete("/layer/#{l['name']}?delete_layer=true")
      puts "\tdeleted layer: #{l['name']}."
    end
  end
end


$api.release()
