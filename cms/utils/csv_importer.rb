require 'pg'
require 'csv'
require 'faraday'
require 'json'
require 'charlock_holmes'
require '/var/www/csdk_cms/current/utils/citysdk_api.rb'

$cdkpw = '/var/www/citysdk/shared/config/cdkpw.json'

  # parameters:
  # 
  # required:
  #   email
  #   passw
  #   layername
  #   filepath
  # optional:
  #   utf8_fixed: true => file is clean utf8; no need to convert (has been done elsewhere).
  #   geometry: name of geometry column, if exists.
  #   x: name of lon column, if exists.
  #   y: name of lat column, if exists.
  #   srid: 
  

class CsvImporter
  attr_accessor :params
  
  def bailWithError(excpt,l)
    message = "#{Time.now.strftime("%b %M %Y, %H:%M")}\nCsvImporter: exception in #{File.basename(__FILE__)}, #{l}:\nProcessing file: #{File.basename(@params['filepath'])}\n#{excpt.message}"
    setLayerStatus(message) if @params['layername']
    $stderr.puts(message)
    $stderr.puts JSON.pretty_generate(@params)
    exit!(-1)
  end
  
  def setLayerStatus(m)
    begin
      dbconf = JSON.parse(File.read('/var/www/citysdk/current/database.json'))
      @pg_csdk = PGconn.new(dbconf['host'], '5432', nil, nil, dbconf['database'], dbconf['user'], dbconf['passwd'])
      @pg_csdk.exec("update layers set import_status = '#{m}' where name = #{@params['layername']};")
      @pg_csdk.close
    rescue
    end
  end

  def initialize(p)
    begin
      
      @params = p
      @params.each_key do |k|
        @params[k] = nil if @params[k] == ''
      end
      
       @signed_in = false

      bailWithError(Exception.new('No file name supplied'), __LINE__) if not @params['filepath']
      bailWithError(Exception.new('No layer name supplied'), __LINE__) if not @params['layername']
      
      @params['email'] = @params['email'] || 'citysdk@waag.org'
      if @params['passw'].nil?
        pw = File.exists?($cdkpw) ? JSON.parse(File.read($cdkpw)) : nil
        @params['passw'] = pw ? pw[@email] : ''
      end
      
      geFileContents
      
      @params['colsep'] = findColSep(StringIO.new(@content)) if !@params['colsep']
      
      getHeaders
      
      guessName if not @params['name']

      if not ((@params['x'] and @params['y']) or @params['geometry'])
        colname,srid,type = findGeometryColumn
        if colname
          @params['geometry'] = colname
          @params['srid'] = srid
          @params['geometry_type'] = 'wkb'
        else
          x,y,lon,lat = findXYColumns
          if(x)
            @params['x'] = x
            @params['y'] = y
            @params['geometry_type'] = 'Point'
            @params['srid'] = guessSRID(lon,lat) if @params['srid'].nil?
          end
        end
      end
      
      return if not ((@params['x'] and @params['y']) or @params['geometry'])

      findUniqueColumn if @params['unique_id'].nil?
      @params['srid'] = 4326 if @params['srid'].nil?
      @params['batch_size'] = 50 if @params['batch_size'].nil?

    rescue => excpt
      bailWithError(excpt, __LINE__)
    end
  end
  
  
  def guessName
    @params['headers'].each do |h|
      if(h =~ /^(title|titel|naam|name)/i)
        @params['name'] = h
      end
    end
  end
  
  def guessSRID(lon,lat)
    begin
      comma = lat =~ /,/  # comma as decimal point? -- could be dutch
      lat = lat.gsub(',','.').to_f
      lon = lon.gsub(',','.').to_f
      return 4326 if lon > -180.0 and lon < 180.0 and lat > -90.0 and lat < 90.0 
      return 28992 if lon > -7000.0 and lon < 300000.0 and lat > 289000.0 and lat < 629000.0
    rescue => excpt
    end
    nil
  end
  
  def findColSep(f)
    begin
      a = f.gets
      b = f.gets
      [";","\t","|"].each do |s|
        return s if (a.split(s).length == b.split(s).length) and b.split(s).length > 1
      end
    rescue => excpt
      bailWithError(excpt, __LINE__)
    ensure
      f.rewind
    end
    ','
  end
  
  def getHeaders
    @params['headers'] = []
    begin
      csv = CSV.new(@content, :col_sep => @params['colsep'], :headers => true, :skip_blanks =>true)
      csv.each do |row|
        row.headers.each do |h|
          @params['headers'] << h
        end
        return
      end
    rescue
    end
  end

  def isGeometryColumn(s)
    return nil,nil if @pg_csdk.nil?
    begin 
      res1 = @pg_csdk.exec("select st_srid('#{s}'::geometry)")
      res2 = @pg_csdk.exec("select GeometryType('#{s}'::geometry)")
      return res1[0]['st_srid'], res2[0]['geometrytype']
    rescue
      return nil,nil
    end
  end

  def findUniqueColumn
    cols = {}
    count = 0
    begin
      csv = CSV.new(@content, :col_sep => @params['colsep'], :headers => true, :skip_blanks =>true)
      csv.each do |row|
        if cols == {}
          row.headers.each do |h|
            cols[h] = Hash.new(0)
          end
        end
        count = count + 1
        row.headers.each do |h|
          cols[h][row[h]] += 1 if row[h] and cols[h]
        end
      end

      @params['rowcount'] = count
      cols.each_key do |k|
        @params['headers'] << k
        if cols[k].length == count
          @params['unique_id'] = k
          break
        end
      end
      nil
    rescue => excpt
      bailWithError(excpt, __LINE__)
    end
  end
    
  def findXYColumns
    x = y = nil
    xs = ys = true
    begin
      csv = CSV.new(@content, :col_sep => @params['colsep'], :headers => true, :skip_blanks =>true)
      csv.each do |row|
        row.headers.each do |h|
          next if h.nil? or h == ''
          hdc = h.downcase
          if hdc == 'longitude' or hdc == 'lon'
            x=h; xs=false
          end
          if hdc == 'latitude' or hdc == 'lat'
            y=h; ys=false
          end
          x = h if xs and (hdc =~ /lon|lng/ or hdc =~ /x.*coord|location/)
          y = h if ys and (hdc =~ /lat/ or hdc =~ /y.*coord|location/)
        end
        return x,y,row[x],row[y] if(x and y and (x != y))
        return nil
      end
    rescue => excpt
      bailWithError(excpt, __LINE__)
    end
  end

  def findGeometryColumn
    begin
      dbconf = JSON.parse(File.read('/var/www/citysdk/current/database.json'))
      @pg_csdk = PGconn.new(dbconf['host'], '5432', nil, nil, dbconf['database'], dbconf['user'], dbconf['passwd'])
      csv = CSV.new(@content, :col_sep => @params['colsep'], :headers => true, :skip_blanks =>true)
      csv.each do |row|
        row.headers.each do |h|
          next if h.nil? or h == ''
          srid,g_type = isGeometryColumn(row[h])
          if(srid)
            return h,srid,g_type
          end
        end
        return nil,nil,nil
      end
    rescue => excpt
      bailWithError(excpt, __LINE__)
    ensure
      @pg_csdk.close
    end
  end

  def geFileContents
    begin
      content=''
      File.open(@params['filepath'], "r:bom|utf-8") do |fd|
        content = fd.read
      end
      if true != @params['utf8_fixed']
        detect = CharlockHolmes::EncodingDetector.detect(content)
        content =	CharlockHolmes::Converter.convert(content, detect[:encoding], 'UTF-8') if detect
      end
      @content = content.force_encoding('utf-8')
    rescue => excpt
      bailWithError(excpt, __LINE__)
    end
  end
  
  def writeFileContents(f=nil)
    begin
      f = @params['filepath'] if f.nil?
      File.open(f,"w") do |fd|
        fd.write(@content)
      end
    rescue => excpt
      bailWithError(excpt, __LINE__)
    end
  end
  
  def sign_in
    begin
      sign_out if @signed_in
      
      @api = CitySDK_API.new(@params['email'],@params['passw'])
      @api.set_host(@params['host']) if @params['host']
      @api.authenticate
      @api.set_layer(@params['layername'])
      
      @api.set_matchTemplate(@params['match_tpl']) if @params['match_tpl']
      @api.set_createTemplate(@params['create_tpl']) if @params['create_tpl']
      
      @signed_in = true
    rescue => e
      puts e.message
    end
  end
  
  def sign_out
    ret = @api.release
    @signed_in = false
    return ret
  end
  
  def add_to_address(dry_run=false)
    failed = []
    sign_in
    
    begin
      qres=''
      csv = CSV.new(@content, :col_sep => @params['colsep'], :headers => true, :skip_blanks =>true)
      csv.each do |row|
      
        yielded = yield(row.to_hash)
        pc = yielded[0]
        hn = yielded[1]
        hn.scan(/\d+/) { |n| # takek care of addresses with range of numbers, 79-83 f.i.
          qres = @api.get("/nodes?bag.vbo::postcode_huisnummer=#{(pc + n).downcase}")
          break if qres['status']=='success' and qres['record_count'].to_i >= 1
        }
        
        if qres['status']=='success' and qres['results'] and qres['results'][0]
          url = '/' + qres['results'][0]['cdk_id'] + '/' + @params['layername']
          data = yielded[2]
          data.delete(@params['x']) if @params['x']
          data.delete(@params['y']) if @params['y']
          data.delete(@params['geometry']) if @params['geometry']
          @api.put(url,{'data'=>data}) if not dry_run
        else
          failed << yielded[2]
        end
      end
    rescue => excpt
      bailWithError(excpt, __LINE__)
    ensure
      sign_out
    end

    return failed
    
  end
  
  def do_import
    
    sign_in
    
    @api.set_createTemplate(
      {
        :create => {
          :params => {
            :create_type => "create",
            :srid => @params['srid']
          }
        }
      }
    )
    
    csv = CSV.new(@content, :col_sep => @params['colsep'], :headers => true, :skip_blanks =>true)
    csv.each do |row|
      
      if @params['geometry']
        geom = row.delete(@params['geometry'])
        node = {
          :geom => {
            :type => 'wkb',
            :wkb => geom[1]
          }
        }
      
      else

        lon = row.delete(@params['x'])
        lat = row.delete(@params['y'])
      
        next if lon[1].nil? or lat[1].nil?
      
        lon = lon[1].gsub(',','.')
        lat = lat[1].gsub(',','.')

        node = {
          :geom => {
            :type => @params['geometry_type'],
            :coordinates => [
              lon.to_f,
              lat.to_f
            ]
          }
        }
      end
      
      data = row.to_hash
      data = yield(data) if defined? yield
        
      node[:id]   = row[@params['unique_id']]
      node[:data] = data
      node[:name] = data[@params['name']] if @params['name'] and data[@params['name']]
            
      @api.create_node(node)

    end
    
    return sign_out

  end

  def getCsvParams
    return @params.to_json
  end

end

