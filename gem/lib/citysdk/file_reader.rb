require 'csv'
require 'geo_ruby'
require 'geo_ruby/shp'
require 'geo_ruby/geojson'
require 'charlock_holmes'
require 'tmpdir'

module CitySDK


  class FileReader
    
    RE_Y = /lat|(y.*coord)|(y.*loc(atie|ation)?)/i
    RE_X = /lon|lng|(x.*coord)|(x.*loc(atie|ation)?)/i
    RE_GEO = /^geom(etry)?|location|locatie$/i
    RE_NAME = /(title|titel|naam|name)/i
    RE_A_NAME = /^(naam|name|title|titel)$/i
    
    attr_reader :file, :content,:params

    def initialize(pars)
      @params = pars
      file_path = File.expand_path(@params[:file_path])
      if File.extname(file_path) == '.csdk'
        readCsdk(file_path)
      else
        ext = @params[:originalfile] ? File.extname(@params[:originalfile]) : File.extname(file_path)
        case ext
          when /\.zip/i
            readZip(file_path)
          when /\.(geo)?json/i
            readJSON(file_path)
          when /\.shape/i
            readShape(file_path)
          when /\.csv|tsv/i
            readCsv(file_path)
          when /\.csdk/i
            readCsdk(file_path)
        end
      end

      @params[:rowcount] = @content.length
      getFields if not @params[:fields]
      guessName if not @params[:name]
      guessSRID if not @params[:srid]
      findUniqueField  if not @params[:unique_id]
      getAddress if not @params[:hasaddress]
      @params[:hasgeometry] = 'unknown' if @params[:hasgeometry].nil?
    end
    
    def getAddress
      pd = pc = hn = ad = false
      @params[:fields].reverse.each do |f|
        pd = f if ( f.to_s =~ /postcode|post/i )
        pc = f if ( f.to_s =~ /^postcode$/i )
        hn = f if ( f.to_s =~ /huisnummer|housenumber|(house|huis)(nr|no)|number/i)
        ad = f if ( f.to_s =~ /address|street|straat|adres/i)
      end
      @params[:hasaddress] = 'unknown'
      if (ad or hn)
        if pc 
          @params[:hasaddress] = 'certain'
          @params[:postcode] = pc
        elsif pd
          @params[:hasaddress] = 'maybe'
          @params[:postcode] = pd
        end
        @params[:housenumber] = hn ? hn : ad
      end
    end

    def findUniqueField
      fields = {}
      unfield = nil

      return if @content[0][:id]

      @content.each do |h|
        h[:properties].each do |k,v|
          fields[k] = {} if fields[k].nil?
          (fields[k][v] == nil) ? fields[k][v] = 1 : fields[k][v] += 1
        end
      end

      fields.each_key do |k|
        if fields[k].length == @params[:rowcount]
          @params[:unique_id] = unfield = k
          break
        end
      end

      if unfield
        @content.each do |h|
          h[:id] = h[:properties][unfield]
        end
      end

    end

    def guessName
      @params[:fields].reverse.each do |k|
        if(k.to_s =~ RE_A_NAME)
          @params[:name] = k
          return
        end
        if(k.to_s =~ RE_NAME)
          @params[:name] = k
        end
      end
    end

    def getFields
      @params[:fields] = []
      @content[0][:properties].each_key do |k|
        @params[:fields] << k
      end
    end
    
    def guessSRID
      return if @content[0][:geometry].nil?
      @params[:srid] = 4326 
      g = @content[0][:geometry][:coordinates]
      while g[0].is_a?(Array)
        g = g[0]
      end
      lon = g[0]
      lat = g[1]
      # if lon > -180.0 and lon < 180.0 and lat > -90.0 and lat < 90.0 
      #   @params[:srid] = 4326 
      # els
      if lon > -7000.0 and lon < 300000.0 and lat > 289000.0 and lat < 629000.0
        # Dutch new rd system
        @params[:srid] = 28992
      end
    end
    
    def findColSep(f)
      a = f.gets
      b = f.gets
      [";","\t","|"].each do |s|
        return s if (a.split(s).length == b.split(s).length) and b.split(s).length > 1
      end
      ','
    end

    def isWkbGeometry(s)
      begin
        f = GeoRuby::SimpleFeatures::GeometryFactory::new
        p = GeoRuby::SimpleFeatures::HexEWKBParser.new(f)
        p.parse(s)
        g = f.geometry
        return g.srid,g.as_json[:type],g
      rescue Exception=>e
      end
      nil
    end

    def isGeoJSON(s)
      begin
        if ['Point', 'MultiPoint', 'LineString', 'MultiLineString', 'Polygon', 'MultiPolygon', 'GeometryCollection'].include?(s[:type])
          srid = 4326
          if s[:crs] && s[:crs][:type] == 'OGC'
            urn = s[:crs][:properties][:urn].split(':')
            srid = urn.last.to_i if (urn[4] == 'EPSG')
          end
          return srid,s[:type],s
        end
      rescue Exception=>e
      end
      nil
    end
    
    
    def findGeometry
      xfield = nil; xs = true
      yfield = nil; ys = true
      @content[0][:properties].each do |k,v|
        if k.to_s =~ RE_GEO
          srid,g_type = isWkbGeometry(v)
          if(srid)
            @params[:srid] = srid
            @params[:geomtry_type] = g_type
            @content.each do |h|
              a,b,g = isWkbGeometry(h[:properties][k])
              h[:geometry] = g
              h[:properties].delete(k)
            end
            @params[:hasgeometry] = 'certain'
            return true
          end
          
          srid,g_type = isGeoJSON(v)
          if(srid)
            @params[:srid] = srid
            @params[:geomtry_type] = g_type
            @content.each do |h|
              h[:geometry] = h[:properties][k]
              h[:properties].delete(k)
            end
            @params[:hasgeometry] = 'certain'
            return true
          end
          
          @content.each do |h|
            h[:geometry] = h[:properties][k]
            h[:properties].delete(k)
          end
          @params[:hasgeometry] = 'maybe'
          return
        end
        
        hdc = k.to_sym.downcase
        if hdc == 'longitude' or hdc == 'lon'
          xfield=k; xs=false
        end
        if hdc == 'latitude' or hdc == 'lat'
          yfield=k; ys=false
        end
        xfield = k if xs and (hdc =~ RE_X) 
        yfield = k if ys and (hdc =~ RE_Y)
      end

      if xfield and yfield and (xfield != yfield)
        @params[:hasgeometry] = 'certain'
        @content.each do |h|
          h[:geometry] = {:type => 'Point', :coordinates => [h[:properties][xfield].gsub(',','.').to_f, h[:properties][yfield].gsub(',','.').to_f]}
          h[:properties].delete(yfield)
          h[:properties].delete(xfield)
        end
        @params[:geomtry_type] = 'Point'
        return true
      end
      false
    end
    
    
    def readCsv(path)
      @file = path
      c=''
      File.open(path, "r:bom|utf-8") do |fd|
        c = fd.read
      end
      if true != @params[:utf8_fixed]
        detect = CharlockHolmes::EncodingDetector.detect(c)
        c =	CharlockHolmes::Converter.convert(c, detect[:encoding], 'UTF-8') if detect
      end
      c = c.force_encoding('utf-8')
      @content = []
      @params[:colsep] = findColSep(StringIO.new(c))
      csv = CSV.new(c, :col_sep => @params[:colsep], :headers => true, :skip_blanks =>true)
      csv.each do |row|
        r = row.to_hash
        h = {}
        r.each do |k,v|
          h[(k.to_sym rescue k) || k] = v
        end
        @content << {:properties => h }
      end
      findGeometry
    end


    def readJSON(path)
      @content = []
      @file = path
      raw = ''
      File.open(path, "r:bom|utf-8") do |fd|
        raw = fd.read
      end
      hash = CitySDK::parseJson(raw)

      if hash.is_a?(Hash) and hash[:type] and (hash[:type] == 'FeatureCollection')
        hash[:features].each do |f|
          f.delete(:type)
          @content << f
        end
        @params[:hasgeometry] = 'certain'
        findUniqueField if @content[0][:id].nil?
      else
        val,length = nil,0

        if hash.is_a?(Array)
           val,length = hash,hash.length
        else
          hash.each do |k,v|
            if v.is_a?(Array)
              val,length = v,v.length if v.length > length
            end
          end
        end
        
        if val
          val.each do |h|
            @content << {:properties => h}
          end
        end
        findGeometry
      end
    end


    def sridFromPrj(str)
      begin
        connection = Faraday.new :url => "http://prj2epsg.org"
        resp = connection.get('/search.json', {:mode => 'wkt', :terms => str})
        if resp.status == 200 
          resp = CitySDK::parseJson resp.body
          @params[:srid] = resp[:codes][0][:code].to_i
        end
      rescue
      end
    end

    def readShape(path)
      @content = []
      @file = path
      
      prj = path.gsub(/.shp$/i,"") + '.prj'
      prj = File.exists?(prj) ? File.read(prj) : nil
      sridFromPrj(prj) if (prj and @params[:srid].nil?)
      
      @params[:hasgeometry] = 'certain'
      
      GeoRuby::Shp4r::ShpFile.open(path) do |shp|
        shp.each do |shape|
          h = {}
          h[:geometry] = CitySDK::parseJson(shape.geometry.to_json) #a GeoRuby SimpleFeature
          h[:properties] = {}
          att_data = shape.data #a Hash
          shp.fields.each do |field|
            h[:properties][field.name.to_sym] = att_data[field.name]
          end
          @content << h
        end
      end
    end
    
    def readCsdk(path)
      h = Marshal.load(File.read(path))
      @params = h[:config]
      @content = h[:content]
    end    
    
    def readZip(path)
      begin 
        Dir.mktmpdir("cdkfi_#{File.basename(path)}") do |dir| 
          raise "Error unzipping #{path}." if not system "unzip #{path} -d #{dir} > /dev/null 2>&1"
          Dir.foreach(dir) do |f|
            next if f =~ /^\./
            case File.extname(f)
              when /\.(geo)?json/i
                readJSON(dir+'/'+f)
                return
              when /\.shp/i
                readShape(dir+'/'+f)
                return
              when /\.csv|tsv/i
                readCsv(dir+'/'+f)
                return
            end
          end
        end
      rescue Exception => e
        raise CitySDK::Exception(e.message, {:originalfile => path}, __FILE__,__LINE__)
      end
    end

    def write(path=nil)
      path = @file_path if path.nil?
      path = path + '.csdk'
      begin
        File.open(path,"w") do |fd|
          fd.write( Marshal.dump({:config=>@params, :content=>@content}) )
        end
      rescue
        return nil
      end
      return path
    end

  end
  
end



# {
#   :headers => ['aap','noot','titel', 'gid', 'geometry']
#   :config => {:geom => 'geometry', :name => 'titel', :id => 'gid', :srid => 28892}
#   :data => [
#     ['jpo','pipo','naam1','1092',{:type => 'Point', :coordinates => [5.3, 52.4]}],
#     ['jpa','popi','naam2','1093',{:type => 'Point', :coordinates => [5.1, 52.1]}]
#   ]
# }
