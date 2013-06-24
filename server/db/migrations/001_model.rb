Sequel.migration do

	up do

    $stderr.puts("Creating tables...")

		# TODO: rename node_type to node_type_id
    create_table :nodes do
      bigint :id, :primary_key => true
		  String :cdk_id, :null => false
		  String :name
      column :members, 'bigint[]'
      column :related, 'bigint[]'
      integer :layer_id, :null => false     
      integer :node_type, :null => false , :default => 0
      column :modalities, 'integer[]'
      timestamptz :created_at, :null => false, :default => :now.sql_function
      timestamptz :updated_at, :null => false, :default => :now.sql_function
			column :geom, 'geometry'
		end

    nodes_cdk_id_unique = <<-SQL
      ALTER TABLE nodes ADD CONSTRAINT constraint_cdk_id_unique UNIQUE (cdk_id);
      ALTER TABLE nodes ADD CONSTRAINT constraint_geom_4326 CHECK (ST_SRID(geom) = 4326);
    SQL
		
    run nodes_cdk_id_unique

		create_table :node_types do
			primary_key :id
			String :name, :null => false
    end

		create_table :modalities do
			primary_key :id
      String :name, :null => false
    end

		create_table :categories do
      column :id, 'serial'
			String :name, :null => false
    end

    create_table :node_data do
      bigint :id, :primary_key => true
      bigint :node_id, :null => false
      integer :layer_id, :null => false
      column :data, 'hstore'
      column :modalities, 'integer[]'
      integer :node_data_type, :null => false, :default => 0
      column :validity, 'tstzrange', :default => nil
      timestamptz :created_at, :null => false, :default => :now.sql_function
      timestamptz :updated_at, :null => false, :default => :now.sql_function
    end
    
    create_table :node_data_types do
      primary_key :id
      String :name, :null => false
    end

    create_table :owners do      
      primary_key :id
      String :name, :null => false
      String :email, :null => false
      String :www
      String :auth_key
      String :organization
      String :domains
      timestamptz :created_at, :null => false, :default => :now.sql_function
    end

    create_table :layers do      
      primary_key :id
      String :name, :null => false
      String :title
      String :description
      column :data_sources, 'text[]'
      Boolean :realtime, :default => false # get real-time data from memcache
      integer :update_rate, :default => 0 # in seconds..
      String :webservice # get data from web service if not in memcache
      column :validity, 'tstzrange'
      integer :owner_id, :null => false, :default => 0
      timestamptz :imported_at, :default => nil                                                
      timestamptz :created_at, :null => false, :default => :now.sql_function
      column :bbox, 'geometry'
      String :category
      String :organization
      String :status
      String :fileconfiguration
    end

    run = <<-SQL
      ALTER TABLE layers ADD CONSTRAINT constraint_layer_name_unique UNIQUE(name);
      
      ALTER TABLE layers ADD CONSTRAINT constraint_layer_name_alphanumeric_with_dots      
        CHECK (name SIMILAR TO '([A-Za-z0-9]+)|([A-Za-z0-9]+)(\.[A-Za-z0-9]+)*([A-Za-z0-9]+)');      
        
      ALTER TABLE layers ADD CONSTRAINT constraint_bbox_4326 CHECK (ST_SRID(bbox) = 4326);
    SQL
	
	end
	
	down do
		drop_table(:nodes)
		drop_table(:node_types)
		drop_table(:modalities)
		drop_table(:node_data)
		drop_table(:node_data_types)
		drop_table(:layers)
		drop_table(:sets)
		drop_table(:sources)
	end
end
