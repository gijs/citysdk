require '/var/www/csdk_cms/current/utils/csv_importer.rb'

$params = {
  'filepath' => 'hotels.csv' ,
  'layername' => 'amsterdam.hotels',
  'email' => ARGV[0],
  'passwd' => ARGV[1]
}

# file looks like this:
# nummer;name;stars;rooms;beds;camping;municipality;town;postcode;street;number;buurt2005;wijk;buurt2010;quarter


$csv = CsvImporter.new($params)

# 'add_vbo' adds data to bag verblijfsobjecten
# is rather slow; @ the moment needs two calls for every row
# these are basically all entities with an address in the Netherlands (ex P.O. boxes).
# these live in the citysdk 'bag.vbo' layer.
# when a postcode/housenumber combination is not found, data is not added, line is skipped.
#
# !! the add_vbo block has to return [postcode,housenumber,data]

$csv.add_vbo do |h|
  h.delete('nummer') #just a line number; is not relevant in this file
  [ h['postcode'],h['number'],h ]
end
