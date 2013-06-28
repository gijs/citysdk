# Example ow to import data with an address, and add it to the 
# 'bag verblijfsobjecten' layer, which is the 'official' address layer.

require '/var/www/csdk_cms/current/utils/csv_importer.rb'

$params = {
  'filepath' => 'hotels.csv' ,
  'layername' => 'amsterdam.hotels',
  'email' => ARGV[0],
  'passw' => ARGV[1]
}

# file looks like this:
# nummer;name;stars;rooms;beds;camping;municipality;town;postcode;street;number;buurt2005;wijk;buurt2010;quarter
# 1;Eden Amsterdam American Hotel;4;175;354; ;Amsterdam;Amsterdam;1017PN;Leidsekade;97;A07b;A;A07b;A


$csv = CsvImporter.new($params)

# 'add_to_address' adds data to bag verblijfsobjecten
# is rather slow; @ the moment needs two calls for every row
# when a postcode/housenumber combination is not found, data is not added, 
# line is skipped and returned.
#

failed = $csv.add_to_address do |h|
  # !! the block has to return [postcode,housenumber,data]
  h.delete('nummer') #just a line number; is not relevant in this file
  [ h['postcode'],h['number'],h ]
end


# add_to_address returns an array of data objects that could not be matched to an address

puts JSON.pretty_generate(failed)

