require 'sequel/model'

class Owner < Sequel::Model
  plugin :validation_helpers
  one_to_many :layers
  
  def validate
    super
    validates_presence [:domains, :organization, :email]
    validates_unique :email
    validates_format /^\S+@\S+\.\S+$/, :email
  end
   
  
  def validatePW(s1,s2)
    return true if s1.empty? and s2.empty? and !self.id.nil?
    if s1 == s2
      return true if s1.length > 7 and s1 =~ /\d/ and s1 =~ /[A-Z]/
      self.errors.add(:password, " needs to be > 7 chars, contain numbers and capitals")
    else
      self.errors.add(:password, " and confirmation don't match")
    end
    puts self.errors
    false
  end
  

  def createPW(pw)
    self.salt = Digest::MD5.hexdigest(Random.rand().to_s)
    self.passwd = Digest::MD5.hexdigest(salt+pw)
    self.save
  end
  
  def touch_session
    self.timeout = Time.now + 60
    self.save
  end
  
  def self.validSession(s)
    if(s)
      o = Owner.where(:auth_key => s).first
      return true if o
    end
    nil
  end

  def self.validSessionForLayer(s,l)
    o = Owner.where(:session => s).first
    if(o and o.timeout and o.timeout > Time.now and Layer[l].owner_id == o.id )
      o.touch_session
      return true
    end
    nil
  end
  
  def self.login(email,pw)
    pw = '' if pw.nil?
    o = Owner.where(:email => email).first
    if(o)
      pw = Digest::MD5.hexdigest(o.salt+pw)
      if (pw == o.passwd)
        o.update(:auth_key  => Digest::MD5.hexdigest(o.salt+Random.rand().to_s) )
        return o.id,o.auth_key 
      else
        CSDK_CMS.do_abort(401,'Not Authorized')
      end
    else
      CSDK_CMS.do_abort(422,"email not known: #{email}.")
    end
    CSDK_CMS.do_abort(500,"Server error.")
  end

end

