require 'faraday'
require 'json'
require '/var/www/csdk_cms/current/utils/citysdk_api.rb'

dry_run = false

rce_url = "http://api.rijksmonumenten.info"
rce_path = "/select/"

rce_layer = "rce.rijksmonumenten"

# TODO: add layer/webservice for RCE Beeldbank
# Beeld per monumentnummer: http://cultureelerfgoed.adlibsoft.com/harvest/wwwopac.ashx?database=images&search=pointer%201009%20and%20monument.record_number-%3EmD=%225941%22&limit=100&xmltype=grouped
# Image URL: http://images.memorix.nl/rce/thumb/800x800/7369c0a4-e1e9-7fd8-a162-31012f891071.jpg

pw = JSON.parse(File.read('/var/www/citysdk/shared/config/cdkpw.json')) if File.exists?('/var/www/citysdk/shared/config/cdkpw.json')
$email = ARGV[0] || 'citysdk@waag.org'
$password = ARGV[1] || (pw ? pw[$email] : '')

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
  response = @rce_conn.get rce_path, {:q => "*:*", :wt => "json", :start => start, :rows => rows}
  results = JSON.parse(response.body)
  
  numFound = results["response"]["numFound"]  
  puts "Downloading and parsing URL #{start / rows + 1}/#{numFound / rows + 1}"
  
  results["response"]["docs"].each { |doc|
  
    monumentnummer = doc["rce_objrijksnr"]
    
    url = nil
    if doc["weblink_primair"] and doc["weblink_primair"].length > 0 and doc["weblink_primair"][0] and doc["weblink_link"] and doc["weblink_link"].length > 0
      url = doc["weblink_link"][0]
    end
    
    naam = nil
    if doc["rce_objectnaam"]
      naam = doc["rce_objectnaam"]
    else
      naam = doc["abc_objectnaam"]
    end
        
    data = {
      :monumentnummer => monumentnummer,
      :naam => naam,
      :omschrijving => doc["rce_omschrijving_redengevend"],
      :categorie => doc["rce_categorie"],
      :url => url,
      :wikipedia => doc["wiki_article_url"],
      :image_url => doc["wiki_image_url"]      
    }.reject {|key,value| value == nil or value.strip == ""}

    # Use BAG's verblijfsobjecten to find matching CitySDK node
    
    postcode = doc["rce_postcode"]
    #huisnummer = doc["rce_huisnummer"]
    huisnummer = doc["rce_huisnr_van"]
      
    if postcode and huisnummer 
      
      # rce_huisnummer does not include toevoeging. abc_adres does include toevoeging
      # but also street name and number. Search index of huisnummer and return
      # substring from end of that occurence.
      toevoeging = ""
      adres = doc["abc_adres"]
      if adres and adres.index(huisnummer)
        toevoeging_index = adres.index(huisnummer) + huisnummer.length
        toevoeging = adres[toevoeging_index..-1]     
      end
         
      # Try multiple postcode/number variants
      variants = [
        (postcode + huisnummer).gsub(/\s+/, "").downcase,
        (postcode + huisnummer + toevoeging).gsub(/[\W\s]+/, "").downcase
      ].uniq
          
      success = false
      variants.each { |variant| 
        qres = @api.get("/nodes?bag.vbo::postcode_huisnummer=#{variant}")      
        if qres['status']=='success' and qres['results'] and qres['results'][0]
          cdk_id = qres['results'][0]['cdk_id']
     
          puts "\t#{cdk_id} => #{monumentnummer}"
          url = '/' + cdk_id + '/' + rce_layer
          begin
            @api.put(url, {'data' => data}) if not dry_run
            success = true
          rescue Exception => e

          end
          
          break if success == true
          
        end
      }
      
      if not success      
        failed << monumentnummer
        puts "\tNot found: #{monumentnummer}: #{doc["abc_adres"]}"
      end  
      
    end
			
  }
  
  start += rows
end

File.write("failed.json", failed.to_json)

@api.release
