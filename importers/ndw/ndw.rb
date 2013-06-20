require 'json'
require 'pg'
require 'rexml/document'

# use active_support xml.to_hash

dbconf = JSON.parse(File.read('../../server/database.json'))

conn = PGconn.new(dbconf['host'], '5432', nil, nil, dbconf['database'], dbconf['user'], dbconf['password'])

@xml_path = "../../../data/ndw/meetlocatietabel.xml"

@@locations = []


class Parser
  TAG_NAME = "measurementSiteRecord"
  
  def initialize
    @n = 0
  end

  def tag_start( name, attributes )
    case name
      when TAG_NAME
        @current_object = {}
      else
        @current_property = name
    end
  end

  def text( str )
    if @current_object && @current_property
      if @current_property == 'latitude' or @current_property == 'longitude'
        @current_object[@current_property] = str.to_f
      end
      #@current_object.send( @current_property.to_s + "=", str )
    end
  end

  def tag_end( name )
    if name == TAG_NAME      
      @n += 1

      if @n % 250 == 0
        puts @n
      end

      @@locations << @current_object
      @current_object = nil
    else
      @current_property = nil
    end
  end
end


stream_handler = Parser.new
source = File.new @xml_path
REXML::Document.parse_stream(source, stream_handler)


placemark = <<-KML  
  <Placemark>  
    
    <Point>
      <coordinates>%s, %s</coordinates>
    </Point>
  </Placemark>
KML

file = File.open("locations.kml", "w")
file.write('<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2"><Document>')
@@locations.each  { |location|
  file.write(placemark % [location['longitude'], location['latitude']])
}

file.write('</Document></kml>')
file.close


