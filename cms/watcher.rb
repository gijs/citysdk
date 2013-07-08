require 'rb-fsevent'

fsevent = FSEvent.new
fsevent.watch Dir.pwd do |directories|
  if (File.expand_path('./tmp') + '/') != directories[0]
    system 'touch ./tmp/restart.txt'
  end
end
fsevent.run
