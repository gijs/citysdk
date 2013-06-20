require '/var/www/csdk_cms/current/utils/citysdk_api.rb'

# Rijkswaterstaat waterdata

pw = JSON.parse(File.read('/var/www/citysdk/shared/config/cdkpw.json')) if File.exists?('/var/www/citysdk/shared/config/cdkpw.json')
$email = ARGV[0] || 'citysdk@waag.org'
$password = ARGV[1] || (pw ? pw[$email] : '')

$api = CitySDK_API.new($email, $password)

if $api.authenticate == false 
  puts "Auth failure with citysdk."
  exit!
end

layers = {
  "temp" => "watertemperatuur",
  "nap" => "waterstanden"
}

layers.each { |layer, rws_name| 

  ###### Download RWS data ######
  puts "Downloading RWS data: #{rws_name}..."

  rws_url = 'http://www.rijkswaterstaat.nl'
  rws_conn = Faraday.new(:url => rws_url)
  response = rws_conn.get '/apps/geoservices/rwsnl/', { :mode => 'features', :projecttype => rws_name, :loadprojects => 0 }
  results = JSON.parse(response.body)

  nodes = results['features'].map do |l|
    {
      :id => l['loc'],
      :name => l['locatienaam'],
      :geom => {
        :type => :Point,
        :coordinates => [
          l['location']['lon'].to_f,
          l['location']['lat'].to_f
        ]
      },
      :data => {
        :waarde => l['waarde'].to_i, # TODO: check for NULL
        :meettijd => Time.at(l['meettijd'].to_i)
      }
    }
  end

  puts "Received #{nodes.length} nodes.."
  $stderr.puts "Received #{nodes.length} nodes.."

  $api.set_layer("rws.#{layer}")

  $api.set_createTemplate( {
    :create => {
      :params => {
        :create_type => "create",
        :srid => 28992
      }
    }
  } )

  nodes.each do |n|
    $api.create_node(n)
  end

}

$api.release

