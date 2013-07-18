require 'json'

class NilClass
  def empty?; true; end
end

module CitySDK

  class Exception < ::Exception
    def initialize(message,parms=nil,srcfile=nil,srcline=nil)
      if parms and srcfile and srcline
        file = File.basename( parms[:originalfile] ? parms[:originalfile] : ( parms[:file_path] || '-' ) )
        m = "#{Time.now.strftime("%b %M %Y, %H:%M")}; CitySDK, processing file: #{file}\n Exception in #{File.basename(srcfile)}, #{srcline}\n #{message}"
      else
        m = "#{Time.now.strftime("%b %M %Y, %H:%M")}; CitySDK Exception: #{message}"
      end
      super(m)
      $stderr.puts(m) if parms and parms[:verbose]
    end
  end

  def self.parseJson(jsonstring)
    begin
      return JSON.parse(jsonstring,{:symbolize_names => true})
    rescue Exception => e
      raise CitySDK::Exception.new(e.message)
    end
  end

end



