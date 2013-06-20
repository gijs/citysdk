Sequel.migration do

  up do

    $stderr.puts("Creating schemas...")
    
    run = <<-SQL
      DROP SCHEMA IF EXISTS gtfs CASCADE;
      CREATE SCHEMA gtfs;
    SQL
 
  end

  down do
    # remove schemas
  end
end

