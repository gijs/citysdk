#encoding: utf-8

require "csv"
require 'charlock_holmes'

def isGeometry(s)
  begin 
    res1 = database.fetch("select st_srid('#{s}'::geometry)").all
    res2 = database.fetch("select GeometryType('#{s}'::geometry)").all
    return res1[0][:st_srid], res2[0][:geometrytype]
  rescue
    return nil,nil
  end
end

def colsep(f)
  begin
    a = f.gets
    b = f.gets
    [";","\t","|"].each do |s|
      return s if (a.split(s).length  == b.split(s).length) and b.split(s).length > 1
    end
  rescue
  ensure
    f.rewind
  end
  ','
end


def getUploadedFileContents(f)
  content = File.read(f)
  detect = CharlockHolmes::EncodingDetector.detect(content)
  return detect ? 
  	CharlockHolmes::Converter.convert(content, detect[:encoding], 'UTF-8') :
  	content
end



  def parseCSV(f,l)
    begin
      
      content = getUploadedFileContents(f.path).force_encoding('utf-8')
      
      @filename = f.path.gsub(/^\/tmp\//,'./filetmp/')
      File.open(@filename,"w") do |fd|
        fd.write(content)
      end
      @geometry_column = ''
      @srid = '4326'
      
      csv = CSV.new(content, :col_sep => colsep(StringIO.new(content)), :headers => true, :skip_blanks =>true)
      csv.each do |row|
        @headers = row.headers
        @headers.each do |h|
          res,type = isGeometry(row[h])
          if(res)
            @geometry_type = type
            @geometry_column = h
            @srid = res
            break
          end
        end
        break
      end
      
      @unique_id = "<select name='unique_id'> "
      @name = "<select name='name'><option>&lt;no name&gt;</option> "
      nt = it = true
      @headers.each do |h|
        
        if(it and h =~ /.*id$/i)
          it = false
          @unique_id += "<option selected='selected'>#{h}</option>"
        else
          @unique_id += "<option>#{h}</option>"
        end
          
        if(nt and h =~ /title|titel|naam|name/i)
          nt = false
          @name += "<option selected='selected'>#{h}</option>"
        else
          @name += "<option>#{h}</option>"
        end

      end
      @name += "</select>"
      @unique_id += "</select>"

      if @geometry_column == ''
        @sel_x = "<select name='x_field'> "
        @sel_y = "<select name='y_field'> "
        @headers.each do |h|
          if h =~ /lon|lng/i or (h =~ /coord|location/i and h =~ /x/i)
            @sel_x += "<option selected value='#{h}' >#{h}</option>"
          else
            @sel_x += "<option value='#{h}' >#{h}</option>"
          end
  
          if h =~ /lat/i or (h =~ /coord|location/i and h =~ /y/i)
            @sel_y += "<option selected value='#{h}' >#{h}</option>"
          else
            @sel_y += "<option value='#{h}' >#{h}</option>"
          end
        end
        @sel_x += "</select>"
        @sel_y += "</select>"
      end

      erb :selectheaders, :layout => false
    rescue Exception => e
      e.message
      # e.backtrace.join('<br/>')
    end
  end
  
  
  def processCSV(pars) 
    
    count = 0
    # {
    #     "filename"=>"/tmp/RackMultipart20130531-1792-1plluf2", 
    #     "layer"=>"38", 
    #     "srid"=>"4326", 
    #     "geometry"=>"", 
    #     "geometry_type"=>"", 
    #     "name"=>"TITEL", 
    #     "unique_id"=>"ID", 
    #     "y_field"=>"LATITUDE", 
    #     "x_field"=>"LONGITUDE", 
    #     "layer_select"=>{"0"=>"osm", "1"=>"artsholland"}, 
    #     "tag_select"=>{"0"=>"artist", "1"=>"locality"}, 
    #     "tag_value"=>{"0"=>"", "1"=>"amsterdam"}
    # }
    match = {
      :match => {
        :params => {
          :radius => 200,
          :debug => true,
          :geometry_type => :point,
          :data_op => "or",
          :layers => {}
        }
      }
    }
    
    
    begin
      
      match[:match][:params][:srid] = pars['srid']
    
      layers = match[:match][:params][:layers]

      pars['layer_select'].each_key do |k|
        layer = pars['layer_select'][k]
        tag = pars['tag_select'][k]
        val = pars['tag_value'][k]
        layers[layer] = {} if( layers[layer].nil? )
        if(val != '')
          layers[layer][tag] = [] if( layers[layer][tag].nil? )
          layers[layer][tag] << val
        else
          layers[layer][tag] = '' if( layers[layer][tag].nil? )
        end
      end
    
    
      api = CitySDK_API.new(session[:e],session[:p])
      api.set_matchTemplate(match)
      api.set_layer(Layer[pars['layer'].to_i].name)
      
      if api.authenticate
        
        nodes = []
        res = ''

        content = File.read(pars['filename']).force_encoding('utf-8')
        csv = CSV.new(content, :col_sep => colsep(StringIO.new(content)), :headers => true, :skip_blanks =>true)
        
        csv.each do |row|
          
          if pars['geometry'] && pars['geometry'] != ''
            geom = row.delete(pars['geometry'])
            node = {
              :id => row[pars['unique_id']],
              :name => row[pars['name']],
              :geom => {
                :type => 'wkb',
                :wkb => geom[1]
              },
              :data => row.to_hash
            }
            
          else

            lon = row.delete(pars['x_field'])
            lat = row.delete(pars['y_field'])
          
            next if lon[1].nil? or lat[1].nil?
          
            lon = lon[1].gsub(',','.')
            lat = lat[1].gsub(',','.')

            node = {
              :id => row[pars['unique_id']],
              :name => row[pars['name']],
              :geom => {
                :type => :Point,
                :coordinates => [
                  lon.to_f,
                  lat.to_f
                ]
              },
              :data => row.to_hash
            }
          end
          
          if(pars['add'])
            if pars['geometry'] && pars['geometry'] != '' ###TO-FIX
              api.create_node(node)
            else
              api.match_create_node(node)
            end
          else
            res = api.match_node(node)
            if(res) 
              api.release()
              return JSON.pretty_generate(res)
            end
          end
          
          count += 1;
          
        end
        api.release()
      end

    rescue Exception => e
      "row: #{count}" + '<br/>' + e.message + '<br/>' + e.backtrace.join('<br/>')
    end


  end
