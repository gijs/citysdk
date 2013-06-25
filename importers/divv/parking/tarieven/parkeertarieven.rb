require 'active_support/core_ext'
require 'faraday'
require 'json'

require '/Users/tom/Dropbox/Docs/csv.rb'
require '/var/www/csdk_cms/current/utils/csv_importer.rb'


tarieven = Hash.from_xml(File.read('20120611_363_RetrieveAreaRegulationFareInfo.xml'))
AreaData = tarieven['Envelope']['Body']['RetrieveAreaRegulationFareInfoResponse']['AreaRegulationFareInfoResponseData']['AreaTable']['AreaData'].select do |a|
  a['UsageId'] == 'BETAALDP'
end




[ 
  {'filepath' => 'parkeertariefgebied.csv' ,'layername' => 'divv.parkeertarieven', 'name' => 'AreaDesc'},
  {'filepath' => 'uitzonderinggebied.csv' ,'layername' => 'divv.parkeertarieven_uitz', 'name' => 'AreaDesc'}
].each do |iPars|

  csv = CsvImporter.new(iPars)

  puts JSON.pretty_generate(csv.params)
  puts "AreaData: #{AreaData.length} items."


  csv.do_import do |h|
  
    puts JSON.pretty_generate(h)
  
    h = AreaData.select do |a|
      a['AreaId'] == h['gebied_cod']
    end
  
    if h and h[0]
      h[0].delete('AreaRegulationTable')
      h[0].delete('UsageId')
    end
    puts JSON.pretty_generate(h[0])
    h[0]

  end

end


