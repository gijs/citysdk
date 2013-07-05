if ARGV[0]

  puts "\nFile import at #{Time.now.strftime('%b %d %Y - %H:%M:%S')}"

  begin 

    require '/var/www/csdk_cms/current/utils/csv_importer.rb'

    params = JSON.parse(ARGV[0])
  
    puts "\tlayer: #{params['layername']}\n\tfile: #{params['originalfile']}"  

    # params['host'] = 'api.citysdk.waag.org'
    params['host'] = 'api.dev'
    if false
      puts "params: #{JSON.pretty_generate(params)}"
    end

    csv = CsvImporter.new params

    ret = csv.do_import do |h|
      h.each do |k,v|
        h.delete(k) if v.nil? or v =~ /^\s*$/
      end
      h
    end
    
    s = "\tupdated: #{ret[0]}; added: #{ret[1]}"
    csv.setLayerStatus(s[1..10000])

  rescue Exception => e
    puts "Exception:"
    puts e.message
  end

end


