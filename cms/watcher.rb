require 'rb-fsevent'

fsevent = FSEvent.new
fsevent.watch Dir.pwd do |directories|
  system 'touch ./tmp/restart.txt'
end
fsevent.run
