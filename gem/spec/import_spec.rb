

module CitySDK

  describe "Importer" do
    
    
    def newImporter(f)
      @importer = Importer.new({
        :host=>TEST_HOST, 
        :layername=>'test.rspec',
        :file_path => f
      })
    end
    
    after(:each) do
      if @layerCreated
        @importer.api.authenticate(TEST_USER,TEST_PASS) do 
          @importer.api.delete("/layer/test.rspec?delete_layer=true")
        end.should_not == nil
      end
    end
    
    
    it "checks parameters" do
      expect { Importer.new({:a=>1}) }.to raise_error(CitySDK::Exception)
    end

    it "succesfully creates a FileReader" do
      newImporter('./spec/files/wkb.csv')
      @importer.should_not == nil 
      @importer.filereader.params[:unique_id].should == :gid
    end

    it "can add a (match) parameter" do
      newImporter('./spec/files/wkb.csv')
      @importer.setParameter('freut',:nix).should be_true
      @importer.setMatchParameter('freut','pipo',nil).should be_true
    end
    
    it "needs authorization to import" do
      newImporter('./spec/files/hotels.csv')
      expect { @importer.doImport }.to raise_error(CitySDK::Exception)
    end

    it "can make a match and add data to osm obj" do
      newImporter('./spec/files/rk.csv')
      
      @importer.api.authenticate(TEST_USER,TEST_PASS) do 
        @importer.api.put('/layers',TEST_LAYER)[:status].should == 'success'
      end.should_not == nil
      @layerCreated = true
      @importer.setParameter(:email,TEST_USER).should be_true
      @importer.setParameter(:passw,TEST_PASS).should be_true

      @importer.setMatchParameter('osm','amenity','fuel').should be_true

      res = @importer.doImport[:not_added].should == 0
      res = @importer.api.get("/nodes?count&layer=test.rspec")
      res[:record_count].should == 5
      # puts JSON.pretty_generate(res)
    end


    it "can make a layer and add data to and address" do
      
      newImporter('./spec/files/hotels.csv')
      
      @importer.api.authenticate(TEST_USER,TEST_PASS) do 
        @importer.api.put('/layers',TEST_LAYER)[:status].should == 'success'
      end.should_not == nil
      @layerCreated = true

      @importer.setParameter(:email,TEST_USER).should be_true
      @importer.setParameter(:passw,TEST_PASS).should be_true
      if TEST_HOST == 'api.citysdk.waag.org'
        @importer.doImport[:not_added].should == 0
        res = @importer.api.get("/nodes?count&layer=test.rspec")
        res[:record_count].should == 4
      else
        @importer.doImport[:not_added].should == 4
      end

    end

  end
  
  describe "FileReader" do

    it "can parse json" do
      j = CitySDK::parseJson('{ "arr" : [0,1,1,1], "hash": {"aap": "noot"}, "num": 0 }')
      j[:arr].length.should == 4
      j[:num].class.should == Fixnum
      j[:hash][:aap].should == "noot"
    end

    it "can read json files" do
      fr = FileReader.new({:file_path => './spec/files/stations.json'})
      File.basename(fr.file).should == 'stations.json'
      fr.params[:geomtry_type].should == 'Point'
      fr.params[:srid].should == 4326
      fr.params[:unique_id].should == :code
    end

    it "can read geojson files" do
      fr = FileReader.new({:file_path => './spec/files/geojsonTest.GeoJSON'})
      File.basename(fr.file).should == 'geojsonTest.GeoJSON'
      fr.params[:unique_id].should == nil
    end

    it "can read csv files" do
      fr = FileReader.new({:file_path => './spec/files/csvtest.zip'})
      File.basename(fr.file).should == 'akw.csv'
      fr.params[:srid].should == 4326
      fr.params[:colsep].should == ';'
      fr.params[:unique_id].should == :ID
    end

    it "can read csv files with wkb geometry" do
      fr = FileReader.new({:file_path => './spec/files/wkb.csv'})
      File.basename(fr.file).should == 'wkb.csv'
      fr.params[:srid].should == 4326
      fr.params[:colsep].should == ';'
      fr.params[:unique_id].should == :gid
    end

    it "can read zipped shape files" do
      fr = FileReader.new({:file_path => './spec/files/shapeTest.zip'})
      fr.params[:srid].should == 2100
    end

  end
  
end


# puts JSON.pretty_generate(fr.content[0])
