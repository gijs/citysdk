require 'faraday'
require 'json'
require '/var/www/csdk_cms/current/utils/citysdk_api.rb'

dry_run = false

rce_url = "http://api.rijksmonumenten.info"
rce_path = "/select/"

rce_layer = "rce.rijksmonumenten"

pw = JSON.parse(File.read('/var/www/citysdk/shared/config/cdkpw.json')) if File.exists?('/var/www/citysdk/shared/config/cdkpw.json')
$email = ARGV[0] || 'citysdk@waag.org'
$password = ARGV[1] || pw ? pw[$email] : ''

@rce_conn = Faraday.new :url => rce_url

@api = CitySDK_API.new($email, $password)

if @api.authenticate == false 
  puts "Auth. failure with citysdk."
  exit!
end

start = 0
rows = 500

numFound = 0
failed = []
while start < numFound or numFound == 0 do
  response = @rce_conn.get rce_path, {:q => "*:*", :wt => "json", :start => start, :rows => 100}
  results = JSON.parse(response.body)
  
  numFound = results["response"]["numFound"]  
  puts "Downloading and parsing URL #{start / rows + 1}/#{numFound / rows + 1}"
  
  results["response"]["docs"].each { |doc|
  
    monumentnummer = doc["rce_objrijksnr"]
    
    data = {
      :monumentnummer => monumentnummer,
      :naam => doc["rce_objectnaam"],
      :categorie => doc["rce_categorie"],
      :weblink => doc["weblink_link"],
      :wikipedia => doc["wiki_article_url"]
    }.reject {|key,value| value == nil or value == ""}

    # Use BAG's verblijfsobjecten to find matching CitySDK node
    
    postcode = doc["rce_postcode"]
    huisnummer = doc["rce_huisnummer"]    
    postcode_huisnummer = (postcode + huisnummer).gsub(/\s+/, "").downcase
  
    qres = @api.get("/nodes?bag.vbo::postcode_huisnummer=#{postcode_huisnummer}")    
     
   if qres['status']=='success' and qres['results'] and qres['results'][0]
     cdk_id = qres['results'][0]['cdk_id']
     
     puts "\t#{cdk_id} => #{monumentnummer}"
     url = '/' + cdk_id + '/' + rce_layer
     @api.put(url, {'data' => data}) if not dry_run
   else
     failed << monumentnummer
     puts "\tNot found: #{monumentnummer}"
   end
			
  }
  
  start += rows
end





