$LOAD_PATH.unshift File.dirname(__FILE__)
require 'active_support/core_ext'
require 'faraday'
require 'sinatra'
require 'json'

class CitySDK_Services < Sinatra::Base
  def do_abort(code,message)
    throw(:halt, [code, {'Content-Type' => 'application/json'}, message])
  end

  before do
    
  end
  
  after do
    content_type 'application/json'
  end

  def parse_request_json
    begin  
      return JSON.parse(request.body.read)
    rescue => exception
      self.do_abort(422, {"result"=>"fail", "error"=>"Error parsing JSON", "message"=>exception.message}.to_json)
    end
  end
  
  def httpget(connection, path)
    response = ''
    begin
      response = connection.get do |req|
        req.url path
        req.options[:timeout] = 5
        req.options[:open_timeout] = 2
      end
    rescue Exception => e
      self.do_abort(408, {"result"=>"fail", "error"=>"Error requesting resource.", "message"=>e.message}.to_json)
    end
    return response
  end

  
  
  get '/' do
    { :status => 'success', 
      :url => request.url, 
    }.to_json 
  end
  
  Helsinki311_URL = "https://asiointi.hel.fi"
  Helsinki311_PATH = "/palautews/rest/v1/requests.json?service_request_id="
  post '/311.helsinki' do
    @json = self.parse_request_json
    
    @connection = Faraday.new(:url => Helsinki311_URL, :ssl => {:verify => false, :version => 'SSLv3'}) do |c|
      c.use Faraday::Request::UrlEncoded  # encode request params as "www-form-urlencoded"
      # c.use Faraday::Response::Logger     # log request & response to STDOUT
      c.use Faraday::Adapter::NetHttp     # perform requests with Net::HTTP
    end

    resp = httpget(@connection, Helsinki311_PATH + @json['service_request_id'])
    data = JSON.parse(resp.body)
    
    @json = data[0] if resp.status == 200
    return { :status => 'success', 
      :url => request.url, 
      :data => @json
    }.to_json 
  end
  
  post '/divv_tf' do
    puts "maar hier wel"
    # dummy; added for consistent implemtation of rt services.
    # values are always retrieved from memcache, so this should never be called.
    @json = self.parse_request_json
    return { :status => 'success', 
      :url => request.url, 
      :data => @json
    }.to_json 
  end
  
  
#  http://gps.buienradar.nl/getrr.php?lat=52.3715975723131&lon=4.89971325769402
  BR_Url = "http://gps.buienradar.nl" 
  BR_Getr = "/getrr.php?"
  # curl --data '{"centroid:lat":"52.3715975723131", "centroid:lon":"4.89971325769402"}' http://localhost:3000/rain
  post '/rain' do
    
    @json = self.parse_request_json
    
    lat = @json["centroid:lat"]
    lon = @json["centroid:lon"]
    
    @connection = Faraday.new :url => BR_Url
    response = httpget(@connection,BR_Getr + "lat=#{lat}&lon=#{lon}")
    data = {:centroid => {:lat => lat, :lon => lon}, :rain => {}}
    
    if response.status == 200
      response.body.split(' ').each do |d|
        value, time = d.split('|')
        value = value.to_i
        data[:rain][time] = value
      end
      return { 
        :status => 'success', 
        :url => request.url, 
        :data => data
      }.to_json 
    else
      self.do_abort(response.status, {"result"=>"fail", "error"=>"Error requesting resource", "message"=>exception.message}.to_json)
    end
  end

  NS_Key = JSON.parse(File.read('/var/www/citysdk/shared/config/nskey.json')) 
  NS_Url = "https://webservices.ns.nl" 
  NS_AVT = "/ns-api-avt?station="
  NS_Prijzen = "/ns-api-prijzen-v2?"
  NS_Stations = "/ns-api-stations"
  NS_Storingen = "/ns-api-storingen?"
  NS_Planner = "/ns-api-treinplanner?"
  
  NS_CDK_IDS = JSON.parse(File.read('ns/cdk_ids.json')) 
  NS_STATION_CODES = JSON.parse(File.read('ns/station_codes.json')) 
  NS_LINES = JSON.parse(File.read('ns/lines.json')) 
  
  # curl -u tom@waag.org:mGdLkTCCW8419MeZ2LtpEjvuLZzN08agECQY7eZihoCADK8F45cakg https:webservices.ns.nl/ns-api-avt?station=HT
  # curl --data '{"code":"HT", "land":"NL", "type":"knooppuntIntercitystation", "uiccode":"8400319"}' http://services.citysdk.waag.org/ns_avt
  post '/ns_avt' do
    
    @json = self.parse_request_json
    
    if @json['code'] and @json['code'] != ''
      @connection = Faraday.new :url => NS_Url, :ssl => {:verify => false}
      @connection.basic_auth(NS_Key["usr"], NS_Key["key"])

      data = @json
      response = httpget(@connection,NS_AVT + @json['code'])
      if response.status == 200
        h = Hash.from_xml(response.body)
        
        data["vertrekkende_treinen"] = []
        h['ActueleVertrekTijden']['VertrekkendeTrein'].each { |vt|
          
          vertrekkende_trein = {
            :type => vt["TreinSoort"].downcase.gsub(/\W+/, '_'),
            :vervoerder => vt["Vervoerder"],
            :ritnummer => vt["RitNummer"],
            :vertrektijd => vt["VertrekTijd"],
            :route => {},
            :eindbestemming => {
              :naam => vt["EindBestemming"]              
            }
          }
            
          vertrekkende_trein[:route][:tekst] = vt["RouteTekst"] if vt["RouteTekst"]
          
          # "VertrekSpoor": "9", 
          
          # Eindbestemming, code & cdk_id:
          code = NS_STATION_CODES[vt['EindBestemming']]
          cdk_id = NS_CDK_IDS[code]
          type = vt["TreinSoort"].downcase.gsub(/\W+/, '_')
          
          vertrekkende_trein[:eindbestemming][:code] = code if code
          vertrekkende_trein[:eindbestemming][:cdk_id] = cdk_id if cdk_id   

          # Route
          line = nil
          if NS_LINES.has_key? type
            NS_LINES[type].each { |l|
              # Two options to check whether l is the correct line
              # 1. l must contain code and @json['code'] with index of code > index @json['code']
              # 2. code must be terminus of l and l must contain @json['code']
              
              if i1 = l.index(@json['code']) and i2 = l.index(code) and i1 < i2 # Option 1
              #if l[-1] == code and l.include? @json['code'] # Option 2
                line = l
                break
              end
            }
          end
          
          if line
            vertrekkende_trein[:route][:cdk_id] = "ns.#{type}.#{line[0]}.#{line[-1]}".downcase
            vertrekkende_trein[:route][:stations] = {}
            vertrekkende_trein[:route][:stations][:codes] = line
            vertrekkende_trein[:route][:stations][:cdk_ids] = line.map { |code|  NS_CDK_IDS[code]}
          end
          
          data["vertrekkende_treinen"] << vertrekkende_trein   
        }        
        
        return { :status => 'success', 
          :url => request.url, 
          :data => data
        }.to_json 
      else
        self.do_abort(response.status, {"result"=>"fail", "error"=>"Error requesting resource", "message"=>response.body}.to_json)
      end

    else
      return { :status => 'success', 
        :url => request.url, 
        :data => @json
      }.to_json 
    end

    
  end

  AH_Key = '91f8cb2755d2683eb442b3837dbe6274' 
  AH_Query = File.open('artsholland.sparql','r').read
  AH_Url = "http://api.artsholland.com" 

  post '/artsholland' do
    
    @json = self.parse_request_json
    
    # @json = {
    #   'title' => 'Rijksmuseum',
    #   'uri' => 'http://data.artsholland.com/venue/1998-l-001-0000187'
    # }
    
    if @json['uri'] and @json['uri'] != ''
      
      start_date = DateTime.now.strftime()
      end_date = (DateTime.now + 2.week).strftime()      
      
      ahPostData = {
        :output => :json,
        :query => AH_Query % [@json['uri'], start_date, end_date]
      }

      @connection = Faraday.new :url => AH_Url
      response = @connection.post do |req|
        req.url '/sparql'
        req.headers = {
         'Content-Type' => 'application/x-www-form-urlencoded',
         'Accept' => 'application/sparql-results+json'
        }
        req.params['api_key'] = AH_Key
        req.body = ahPostData
      end

      events = []
      if response.status == 200 
         results = JSON.parse(response.body)
         
         results["results"]["bindings"].each { |event|
           events << {
             :title => event["title"]["value"],
             :time => event["time"]["value"],
             :event_uri => event["e"]["value"],
             :production_uri => event["p"]["value"],
           }
         }
                  
         return { :status => 'success', 
           :url => request.url, 
           :data => @json.merge({
             :events => events
           })           
         }.to_json         

      else
        self.do_abort(response.status, {"result"=>"fail", "error"=>"Error requesting resource", "message"=>response.body}.to_json)
      end

    else
      return { :status => 'success', 
        :url => request.url, 
        :data => @json
      }.to_json 
    end
    
  end

end
