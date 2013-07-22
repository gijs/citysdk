module CitySDK
  
  class Importer
    attr_reader :filereader, :api, :params
    
    def initialize(pars)
      @params = pars
      
      raise Exception.new("Missing :host in Importer parameters.") if @params[:host].nil?
      raise Exception.new("Missing :layername in Importer parameters.") if @params[:layername].nil?
      raise Exception.new("Missing :file_path in Importer parameters.") if @params[:file_path].nil?

      @api = CitySDK::API.new(@params[:host])
      if @params[:email]
        raise Exception.new("Missing :passw in Importer parameters.") if @params[:passw].nil?
        raise Exception.new("Failure to authenticate '#{@params[:email]}' with api.") if not @api.authenticate(@params[:email],@params[:passw])
        @api.release
      end

      @params[:addresslayer] = 'bag.vbo' if @params[:addressleyer].nil?
      @params[:addressfield] = 'postcode_huisnummer' if @params[:addressfield].nil?
      
      @params[:create_type] = 'create' if @params[:create_type].nil?
      # CREATE_TYPE_UPDATE = 'update' 
      # CREATE_TYPE_ROUTES = 'routes'
      # CREATE_TYPE_CREATE = 'create'

      @filereader = FileReader.new(@params)
    end
    
    
    def write(path)
      return @filereader.write(path)
    end
    
    def setLayerStatus(m)
      begin
        sign_in
        @api.set_layer_status(m.gsub("\n","<br/>"))
        sign_out
      rescue Exception => e
        puts "File Importer setLayerStatus Exception #{e.message}"
      end
    end
    
    def setParameter(k,v)
      begin
        @params[(k.to_sym rescue k) || k] = v
        return true
      rescue
      end
      nil
    end

    def setMatchParameter(l,f,v)
      begin
        @params[:match] = [] if @params[:match].nil?
        @params[:match] << [l,f,v] 
        return true
      rescue
      end
      nil
    end

    def sign_in
      if @params[:email].nil?
        raise Exception.new("No credentials provided..")
      end
        
      begin
        sign_out if @signed_in
        @api.set_host(@params[:host])
        @api.set_layer(@params[:layername])
        @api.set_matchTemplate(@params[:match_tpl]) if @params[:match_tpl]
        @api.set_createTemplate(@params[:create_tpl]) if @params[:create_tpl]
        @api.authenticate(@params[:email],@params[:passw])
        @signed_in = true
      rescue => e
        @api.release
        raise e
      ensure
      end
    end

    def sign_out
      @signed_in = false
      return @api.release
    end
  
    def filterFields(h)
      data = {}
      h.each_key do |k|
        data[k] = h[k] if @params[:fields].include?(k)
      end
      data
    end
  
    def doImport(dryrun=false)
      result = {
        :updated => 0,
        :created => 0,
        :not_added => 0
      }
      
      failed = nil
      
      if @params[:hasaddress] == 'certain'
        failed = addToAddress(dryrun)
      # elsif @params[:hasaddress] == 'maybe'
      #   failed = addToAddress(dryrun)
      end

      if failed == []
        result[:updated] += @filereader.content.length
        return result
      end

      if failed 
        result[:updated] += (@filereader.content.length - failed.length)
      end
      
      nodes = failed || @filereader.content
      
      count = nodes.length
      
      @api.set_createTemplate(
        {
          :create => {
            :params => { #TODO other create types!!
              :create_type => @params[:create_type],
              :srid => @params[:srid] || 4326
            }
          }
        }
      )
      
      match_tpl = {
        :match => {
          :params => {
            :debug => true,
            :layers => {}
          }
        }
      }

      begin
        sign_in
        if @params[:unique_id] and @params[:match] and (@params[:hasgeometry] != 'unknown')

          # puts ""
          # puts "doImport... 1"
          # puts ""

          match_tpl[:match][:params][:radius] = @params[:radius] || 200
          match_tpl[:match][:params][:geometry_type] = @params[:geometry_type] || :point
          @params[:match].each do |a|
            match_tpl[:match][:params][:layers][a[0]] = {} if match_tpl[:match][:params][:layers][a[0]].nil?
            match_tpl[:match][:params][:layers][a[0]][a[1]] = a[2]
          end
          @api.set_matchTemplate(match_tpl)
          nodes.each do |rec|
            node = {
              :geom => rec[:geometry],
              :id   => rec[:id]
            }
            node[:name] = rec[:properties][@params[:name]] if @params[:name]
            node[:data] = rec[:properties]

            # puts JSON.pretty_generate(node)
            
            @api.match_create_node(node) if not dryrun
            count -= 1
          end
          @api.match_create_flush
      
        elsif @params[:unique_id] and (@params[:hasgeometry] != 'unknown')
          
          # puts ""
          # puts "doImport... 2"
          # puts ""

          begin
            nodes.each do |rec|
              
              node = {
                :geom => rec[:geometry],
                :id   => rec[:id]
              }
              node[:name] = rec[:properties][@params[:name]] if @params[:name]
              node[:data] = rec[:properties]

              # puts JSON.pretty_generate(node)
            
              @api.create_node(node) if not dryrun
              count -= 1
            end
            @api.create_flush
          rescue => e
            raise e
          end
        else
          raise Exception.new("Cannot import. Geometry or uniuque id is not known for records.") if failed.nil?
        end
      ensure
        a = sign_out
        result[:updated] += a[0]
        result[:created] += a[1]
        result[:not_added] = count
      end
      return result
    end

    def addToAddress(dryrun=false)
      failed = []
      if @params[:postcode] and @params[:housenumber]
        begin
          sign_in
          @filereader.content.each do |rec|
            row = rec[:properties]
            
            pc = row[@params[:postcode]].to_s
            hn = row[@params[:housenumber]].to_s
            qres = {}
            if not (pc.empty? or hn.empty?)
              pc = pc.downcase.gsub(/[^a-z0-9]/,'')
              hn.scan(/\d+/).reverse.each { |n|
                qres = @api.get("/nodes?#{@params[:addresslayer]}::#{@params[:addressfield]}=#{pc + n}")
                break if qres[:status]=='success' and qres[:record_count].to_i >= 1
              }
            else
              qres[:status]='nix'
            end
            if qres[:status]=='success' and qres[:results] and qres[:results][0]
              url = '/' + qres[:results][0][:cdk_id] + '/' + @params[:layername]
              n = @api.put(url,{'data'=>filterFields(row)}) if not dryrun
            else
              failed << rec
            end
          end
        rescue => e
          raise e
        ensure
          sign_out
        end
        return failed
      end
      raise Exception.new("Addresses not well defined in dataset.")
    end

  end
end