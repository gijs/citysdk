require 'sequel/model'

class Owner < Sequel::Model
  one_to_many :layers

  def createPW(pw)
    self.salt = Digest::MD5.hexdigest(Random.rand().to_s)
    self.passwd = Digest::MD5.hexdigest(salt+pw)
    self.save
  end
  
  def touch_session
    self.timeout = Time.now + 60
    self.save
  end
  
  
  def self.domains(s)
    o = Owner.where(:session => s).first
    o ? o.domains.split(',') : []
  end
  
  def self.get_id(s)
    o = Owner.where(:session => s).first
    o ? o.id : -1
  end

  def self.validSession(s)
    o = Owner.where(:session => s).first
    if(o and ((o.id == 0) or (o.timeout and o.timeout > Time.now)) ) 
      o.touch_session
      return true
    end
    nil
  end
  
  def self.release_session(s)
    o = Owner.where(:session => s).first
    if(o)
      o.timeout = Time.now - 160
      o.save
    end
  end

  def self.validSessionForLayer(s,l)
    o = Owner.where(:session => s).first
    if(o and ((o.id == 0) or (o.timeout and o.timeout > Time.now and Layer[l].owner_id == o.id )))
      o.touch_session
      return true
    end
    nil
  end
  
  def self.validateSessionForLayer(s,l)
    o = Owner.where(:session => s).first
    if(o and ((o.id == 0) or (o.timeout and o.timeout > Time.now and Layer[l].owner_id == o.id )))
      o.touch_session
      return true
    end
    CitySDK_API.do_abort(401,"Not authorized for layer '#{Layer[l].name}'.")
  end
  
  def self.login(email,pw)
    pw = '' if pw.nil?
    o = Owner.where(:email => email).first
    if(o)
      pw = Digest::MD5.hexdigest(o.salt+pw)
      return 'fail','session busy' if(o.timeout and o.timeout > Time.now)
      if (pw == o.passwd)
        o.timeout = Time.now + 20
        o.session = Digest::MD5.hexdigest(o.salt+o.timeout.to_s)
        o.save
        puts "[#{Time.now.strftime('%b %d, %Y %H:%M')}] #{email} logged in.."
        return 'success',o.session 
      else
        CitySDK_API.do_abort(401,'Not Authorized')
      end
    else
      CitySDK_API.do_abort(422,"email not known: #{email}.")
    end
    CitySDK_API.do_abort(500,"Server error.")
  end

  def serialize
    {}
  end
end

