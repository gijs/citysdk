require 'date'
require 'json'
require 'yaml'
require './gtfs_util.rb'

@agencies = nil
@dlds = []
@yamlFile = 'feed_dlds.yaml'

Agencies = [
  ['govi.','http://gtfs.ovapi.nl/govi/gtfs-kv7-latest.zip', '2010-01-01'], #netherlands
  ['gbmc.','http://store.datagm.org.uk/sets/tfgm/tfgmgtfs.zip', '2010-01-01'], # manchester
  ['fitp.','http://files.itsfactory.fi/google_transit.zip', '2010-01-01'], #tampere
  ['fihk.','http://tomdemeyer:c09f48618dc1cd262ebec1f601255383c46f3256dd7fbff81da6da410e681799@api.reittiopas.fi/data/google_transit.zip','2010-01-01']  #helsinki
] 

def do_one_feed(feed)
  $stderr.puts "Updating: #{feed[0]}\n\n"
  begin
    system "mkdir -p /tmp/cdk_gtfs"
    system "rm -rf /tmp/cdk_gtfs/*"
    system "wget -O /tmp/cdk_gtfs/gtfs.zip '#{feed[1]}'"
    system "unzip /tmp/cdk_gtfs/gtfs.zip -d /tmp/cdk_gtfs"
    case feed[0]
      when 'gbmc.'
        system "mv /tmp/cdk_gtfs/gtdf-out/* /tmp/cdk_gtfs/"
      when 'govi.'
        system "ruby ./import.rb /tmp/cdk_gtfs"
        return true
    end
    system "ruby ./import.rb -p #{feed[0]} /tmp/cdk_gtfs"
    return true
  rescue Exception => e
    $stderr.puts e.message
  end
  false
end

GTFS_Import::do_log('Checking for updates..')        

@agencies = YAML.load_file(@yamlFile) if File.exists?(@yamlFile)
@agencies = Agencies if(@agencies.nil?)

@agencies.each do |a|
  lm = `curl --silent --head #{a[1]} | grep Last-Modified`
  if lm =~ /.*,\s+(.*)\s+\d\d:/
    GTFS_Import::do_log(" #{a[0]} last: #{a[2]}; current: #{$1}")
    if Date.parse($1) > Date.parse(a[2])
      nd = $1
      a[2] = nd if do_one_feed(a)
    end
  end
end


File.open(@yamlFile,'w') do |f|
  f.write(@agencies.to_yaml)
end


