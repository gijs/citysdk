

module CitySDK
  TEST_HOST = 'test-api.citysdk.waag.org'
  TEST_USER = 'test@waag.org'
  TEST_PASS = '123Test321'

  TEST_LAYER = {
    :data => {
      :name => 'test.rspec',
      :description => 'for testing',
      :organization => 'waag',
      :category => 'security.test'
    }
  }
  
  describe API do

    before(:each) do
      @api = API.new(TEST_HOST)
      TEST_USER.should_not == 'citysdk@waag.org'
    end

    after(:each) do
      @api.release
    end

    it "can be connected to" do
      @api.should_not == nil
    end

    it "can be queried" do
      @api.get('/layers')[:status].should == 'success'
    end

    it "can be authorized against" do
      @api.authenticate(TEST_USER,TEST_PASS).should == true
    end
    
    # it "can create and delete a test layer" do
    #   @api.authenticate(TEST_USER,TEST_PASS).should == true
    #   @api.put('/layers',TEST_LAYER)[:status].should == 'success'
    #   @api.delete('/layer/test.rspec?delete_layer=true')[:status].should == 'success'
    # end

    it "can not create a layer in an unauthorized domain" do
      h = TEST_LAYER.dup
      h[:data][:name] = 'unauthorized.rspec'
      @api.authenticate(TEST_USER,TEST_PASS).should == true
      expect { @api.put('/layers',h) }.to raise_error(HostException,"Not authorized for domain 'unauthorized'.")
      TEST_LAYER[:data][:name] = 'test.rspec'
    end

    it "can not add data to a layer not owned" do
      res = @api.get('/nodes?per_page=1')
      res[:status].should == 'success'
      cdk = res[:results][0][:cdk_id]
      @api.authenticate(TEST_USER,TEST_PASS).should == true
      expect { @api.put("/#{cdk}/osm",{:data=>{:plop => 'pipo'}}) }.to raise_error(HostException,"Not authorized for layer 'osm'.")
    end

  end
  
end