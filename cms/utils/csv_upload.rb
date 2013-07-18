#encoding: utf-8

require "citysdk"
require "base64"

class CSDK_CMS < Sinatra::Base

  def parseCSV(f,l)
    begin
      
      pars = {
        :file_path      => f.path,
        :layername      => l,
        :email          => session[:e],
        :passw          => session[:p],
        :originalfile   => @original_file,
        :host => API_SERVER
      }
      
      csv = CitySDK::Importer.new(pars)
      
      @params = csv.params
      
      
      @filename = f.path.gsub(/^\/tmp\//,'./filetmp/')
      @params[:file_path] = @filename + '.csdk'
      @params[:utf8_fixed] = true
      
      @unique_id = "<select name='unique_id'><option>&lt;no unique id&gt;</option> "
      @name = "<select name='name'><option>&lt;no name&gt;</option> "

      @house_nr = "<select name='housenumber'><option>&lt;no housenr.&gt;</option> "
      @postcode = "<select name='postcode'><option>&lt;no postcode&gt;</option> "

      nt = it = true
      @params[:fields].each do |h|

        if h == @params[:postcode]
          @postcode += "<option selected='selected'>#{h}</option>"
        else
          @postcode += "<option>#{h}</option>"
        end

        if h == @params[:housenumber]
          @house_nr += "<option selected='selected'>#{h}</option>"
        else
          @house_nr += "<option>#{h}</option>"
        end

        if h == @params[:unique_id]
          @unique_id += "<option selected='selected'>#{h}</option>"
        else
          @unique_id += "<option>#{h}</option>"
        end
        
        if h == @params[:name]
          @name += "<option selected='selected'>#{h}</option>"
        else
          @name += "<option>#{h}</option>"
        end
      end
      
      @name += "</select>"
      @unique_id += "</select>"
      
      if @params[:hasgeometry] == 'unknown' or @params[:hasgeometry]=='maybe' 
        @sel_x = "<select name='x'><option>&lt;no longtitude&gt;</option> "
        @sel_y = "<select name='y'><option>&lt;no latitude&gt;</option> "
        
        @params[:fields].each do |h|
          if h == @params[:x]
            @sel_x += "<option selected value='#{h}' >#{h}</option>"
          else
            @sel_x += "<option value='#{h}' >#{h}</option>"
          end
  
          if h == @params[:y]
            @sel_y += "<option selected value='#{h}' >#{h}</option>"
          else
            @sel_y += "<option value='#{h}' >#{h}</option>"
          end
        end
        @sel_x += "</select>"
        @sel_y += "</select>"
      end
      
      @srid = @params[:srid]
      @layername = @params[:layername]
      @colsep = @params[:colsep]

      @parameters = Base64.encode64(@params.to_json)
       

      csv.write(@filename)
      

      erb :selectheaders, :layout => false
    rescue Exception => e
      puts e.message
      puts e.backtrace
      raise e
    end
  end
  
  
  # def matchCSV(pars) 
  #   
  #   count = 0
  #   # {
  #   #     "filename"=>"/tmp/RackMultipart20130531-1792-1plluf2", 
  #   #     "layer"=>"38", 
  #   #     "srid"=>"4326", 
  #   #     "geometry"=>"", 
  #   #     "geometry_type"=>"", 
  #   #     "name"=>"TITEL", 
  #   #     "unique_id"=>"ID", 
  #   #     "y_field"=>"LATITUDE", 
  #   #     "x_field"=>"LONGITUDE", 
  #   #     "layer_select"=>{"0"=>"osm", "1"=>"artsholland"}, 
  #   #     "tag_select"=>{"0"=>"artist", "1"=>"locality"}, 
  #   #     "tag_value"=>{"0"=>"", "1"=>"amsterdam"}
  #   # }
  #   match = {
  #     :match => {
  #       :params => {
  #         :srid => pars['srid'],
  #         :radius => 200,
  #         :debug => true,
  #         :geometry_type => pars['geometry_type'],
  #         :data_op => "or",
  #         :layers => {}
  #       }
  #     }
  #   }
  #   
  #   
  #   begin
  #     
  #     match[:match][:params][:srid] = pars['srid']
  #   
  #     layers = match[:match][:params][:layers]
  # 
  #     pars['layer_select'].each_key do |k|
  #       layer = pars['layer_select'][k]
  #       tag = pars['tag_select'][k]
  #       val = pars['tag_value'][k]
  #       layers[layer] = {} if( layers[layer].nil? )
  #       if(val != '')
  #         layers[layer][tag] = [] if( layers[layer][tag].nil? )
  #         layers[layer][tag] << val
  #       else
  #         layers[layer][tag] = '' if( layers[layer][tag].nil? )
  #       end
  #     end
  #   
  #   
  #     api = CitySDK_API.new(session[:e],session[:p])
  #     api.set_host('api.citysdk.waag.org') # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  #     api.set_matchTemplate(match)
  #     api.set_layer(pars['layername'])
  #     
  #     if api.authenticate
  #       
  #       nodes = []
  #       res = ''
  # 
  #       content = File.read(pars['file_path']).force_encoding('utf-8')
  #       csv = CSV.new(content, :col_sep => pars['colsep'], :headers => true, :skip_blanks =>true)
  #       
  #       csv.each do |row|
  #         
  #         if pars['geometry'] && pars['geometry'] != ''
  #           geom = row.delete(pars['geometry'])
  #           node = {
  #             :id => row[pars['unique_id']],
  #             :name => row[pars['name']],
  #             :geom => {
  #               :type => 'wkb',
  #               :wkb => geom[1]
  #             },
  #             :data => row.to_hash
  #           }
  #           
  #         else
  # 
  #           lon = row.delete(pars['x_field'])
  #           lat = row.delete(pars['y_field'])
  #         
  #           next if lon[1].nil? or lat[1].nil?
  #         
  #           lon = lon[1].gsub(',','.')
  #           lat = lat[1].gsub(',','.')
  # 
  #           node = {
  #             :id => row[pars['unique_id']],
  #             :name => row[pars['name']],
  #             :geom => {
  #               :type => :Point,
  #               :coordinates => [
  #                 lon.to_f,
  #                 lat.to_f
  #               ]
  #             },
  #             :data => row.to_hash
  #           }
  #         end
  #         
  #         res = api.match_node(node)
  #         if(res) 
  #           api.release()
  #           return res
  #         end
  #         
  #         count += 1;
  #         
  #       end
  #       api.release()
  #     else
  #       "could not authenticate...."
  #     end
  # 
  #   rescue Exception => e
  #     "row: #{count}" + '<br/>' + e.message + '<br/>' + e.backtrace.join('<br/>')
  #   end
  # 
  # 
  # end
  
end
