#encoding: utf-8

Sequel.migration do
	up do

    # Insert modalities
    self[:modalities].insert(:id =>   0, :name => 'tram')       # Tram, Streetcar, Light rail
    self[:modalities].insert(:id =>   1, :name => 'subway')    # Subway, Metro
    self[:modalities].insert(:id =>   2, :name => 'rail')      # Rail
    self[:modalities].insert(:id =>   3, :name => 'bus')       # Bus
    self[:modalities].insert(:id =>   4, :name => 'ferry')     # Ferry
    self[:modalities].insert(:id =>   5, :name => 'cable_car') # Cable car
    self[:modalities].insert(:id =>   6, :name => 'gondola')   # Gondola, Suspended cable car
    self[:modalities].insert(:id =>   7, :name => 'funicular') # Funicular
    self[:modalities].insert(:id => 109, :name => 'airplane ') # Airplane 
    self[:modalities].insert(:id => 110, :name => 'foot')      # Foot, walking
    self[:modalities].insert(:id => 111, :name => 'bicycle')   # Bicycle
    self[:modalities].insert(:id => 112, :name => 'moped')     # Light motorbike, moped
    self[:modalities].insert(:id => 113, :name => 'motorbike') # Motorbike
    self[:modalities].insert(:id => 114, :name => 'car')       # Car
    self[:modalities].insert(:id => 115, :name => 'truck')     # Truck
    self[:modalities].insert(:id => 116, :name => 'horse')     # Horse
    self[:modalities].insert(:id => 200, :name => 'any')       # Any    

    # Insert node types
    self[:node_types].insert(:id => 0, :name => 'node')
    self[:node_types].insert(:id => 1, :name => 'route')
    self[:node_types].insert(:id => 2, :name => 'ptstop')
    self[:node_types].insert(:id => 3, :name => 'ptline')
   
    self[:categories].insert(:name => 'natural')
    self[:categories].insert(:name => 'cultural')
    self[:categories].insert(:name => 'civic')
    self[:categories].insert(:name => 'tourism')
    self[:categories].insert(:name => 'mobility')
    self[:categories].insert(:name => 'administrative')
    self[:categories].insert(:name => 'environment')
    self[:categories].insert(:name => 'health')
    self[:categories].insert(:name => 'education')
    self[:categories].insert(:name => 'security')
    self[:categories].insert(:name => 'commercial')
   
    # Insert node_data types
    self[:node_data_types].insert([0, 'layer_data'])
    self[:node_data_types].insert([1, 'comment'])
        
    # Insert default layers 
    # TODO: categories for default layers!!
    
    self[:layers].insert(
      :id => 0, 
      :name => 'osm', 
      :title => 'OpenStreetMap', 
      :description => 'Base geograpy layer.', 
      :data_sources => '{"Data from OpenstreetMap; openstreetmap.org © OpenStreetMap contributors"}'
      #:validity => 
      #:categories =>
    )
    
    self[:layers].insert(
      :id => 1, 
      :name => 'gtfs', 
      :title => 'Public transport', 
      :description => 'Layer representing GTFS public transport information.', 
      :data_sources => '{"OpenOV/GOVI import through gtfs.ovapi.nl"}'
      #:validity => 
      #:categories =>
    )
    
    self[:layers].insert(
      :id => 2, 
      :name => 'admr', 
      :title => 'Administrative borders', 
      :description => 'Administrative borders.', 
      :data_sources => '{"Bron: © 2012, Centraal Bureau voor de Statistiek / Kadaster, Zwolle, 2012"}'
      #:validity => 
      #:categories =>
    )
        
    # Insert default owners   
    self[:owners].insert(:id => 0, :name => 'CitySDK', :email => 'citysdk@waag.org')
    # self[:owners].insert([1,'tom','tom@waag.org'])
    # self[:owners].insert([2,'bert','bert@waag.org'])
  end

  down do
    DB[:modalities].truncate
    DB[:node_types].truncate
    DB[:node_data_types].truncate
    DB[:sources].truncate
    DB[:layers].truncate
    DB[:owners].truncate
  end
  
end
