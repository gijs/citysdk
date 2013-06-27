Sequel.migration do

	up do

    $stderr.puts("Add indexes...")
    $stderr.puts("\tNode indexes...")

    run "create extension pg_trgm;"

  	# node indexes
    $stderr.puts("\t\tNode index id...")
      run "CREATE INDEX ON nodes USING btree (id);"
    $stderr.puts("\t\tNode index cdk_id...")
      run "CREATE INDEX ON nodes USING btree (cdk_id);"
    $stderr.puts("\t\tNode index members...")
      run "CREATE INDEX ON nodes USING gin (members);"
    $stderr.puts("\t\tNode index modalities...")
      run "CREATE INDEX ON nodes USING gin (modalities);"      
    $stderr.puts("\t\tNode index geom...")
      run "CREATE INDEX ON nodes USING gist (geom);"
    $stderr.puts("\t\tNode index node_type...")
      run "CREATE INDEX ON nodes USING btree (node_type);"
    $stderr.puts("\t\tNode index layer_id...")
      run "CREATE INDEX ON nodes USING btree (layer_id);"
    $stderr.puts("\t\tNode index name...")
      run "CREATE INDEX ON nodes USING gist (name gist_trgm_ops);"
      run "CREATE INDEX ON nodes USING btree(lower(name));"
      
    $stderr.puts("\t\tNode index members[0]...")
      run "CREATE INDEX ON nodes USING btree ((members[array_lower(members, 1)]));"
    $stderr.puts("\t\tNode index members[-1]...")
      run "CREATE INDEX ON nodes USING btree ((members[array_upper(members, 1)]));"

    # Loading pages with high page number is VERY slow:
    # http://localhost:3000/nodes?page=9000&per_page=100
    # 
    # More information:
    # http://stackoverflow.com/questions/6618366/improving-offset-performance-in-postgresql
    # http://www.depesz.com/2011/05/20/pagination-with-fixed-order/
    #
    # We need to look into ways to either make this faster or forbid queries with high page numbers.

      $stderr.puts("\tNode data indexes...")
      # node_data indexes
    $stderr.puts("\t\tNode data index node_id...")
      run "CREATE INDEX ON node_data USING btree (node_id);"
    $stderr.puts("\t\tNode data index data...")
      run "CREATE INDEX ON node_data USING gin (data);"
    $stderr.puts("\t\tNode data index modalities...")
      run "CREATE INDEX ON node_data USING gin (modalities);"
    $stderr.puts("\t\tNode data index validity...")
      run "CREATE INDEX ON node_data USING gist (validity);"
    $stderr.puts("\t\tNode data index layer_id...")
      run "CREATE INDEX ON node_data USING btree (layer_id);"
 
	end

	down do
		# remove indexes
	end
end