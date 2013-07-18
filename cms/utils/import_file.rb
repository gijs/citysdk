if ARGV[0]

  puts "\nFile import at #{Time.now.strftime('%b %d %Y - %H:%M:%S')}"
  csv = nil
  
  begin 

    require 'citysdk'

    params = JSON.parse(ARGV[0], {:symbolize_names => true} )

    params[:host] = 'test-api.citysdk.waag.org' #TOM FIX!!
  
    puts "\tlayer: #{params[:layername]}\n\tfile: #{params[:originalfile]}"  

    if true
      puts "params: #{JSON.pretty_generate(params)}"
    end

    csv = CitySDK::Importer.new(params)
    
    
    puts "setLayerStatus"
    csv.setLayerStatus("importing...")
    
    ret = csv.doImport
    puts "ret: #{JSON.pretty_generate(ret)}"
    
    s = "updated: #{ret[:updated]}; added: #{ret[:created]}; not added: #{ret[:not_added]}"
    puts s
    
    csv.setLayerStatus(s)
    

  rescue Exception => e
    csv.setLayerStatus(e.message) if csv
    puts "Exception:"
    puts e.message
    puts e.backtrace
  end

end


