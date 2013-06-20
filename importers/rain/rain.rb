require 'socket'
require 'json'
require 'pg'

local_ip = UDPSocket.open {|s| s.connect("123.123.123.123", 1); s.addr.last}
if(local_ip =~ /192\.168|10\.0\.135/)
  dbconf = JSON.parse(File.read('../../server/database.json'))
else
  dbconf = JSON.parse(File.read('/var/www/citysdk/current/database.json'))
end

conn = PGconn.new(dbconf['host'], '5432', nil, nil, dbconf['database'], dbconf['user'], dbconf['passwd'])

rain_layer_name = 'rain'
admr_layer_name = 'admr'

res = conn.exec("SELECT id FROM layers WHERE name = '#{rain_layer_name}'");
rain_layer_id = res[0]['id'].to_i if res.cmdtuples > 0
if(rain_layer_id.nil?)
  $stderr.puts "No 'rain' layer found!"
  exit(-1)
end

res = conn.exec("SELECT id FROM layers WHERE name = '#{admr_layer_name}'");
admr_layer_id = res[0]['id'].to_i if res.cmdtuples > 0
if(rain_layer_id.nil?)
  $stderr.puts "No 'admr' layer found!"
  exit(-1)
end

truncate = <<-SQL
  DELETE FROM node_data WHERE layer_id = #{rain_layer_id}
SQL

conn.exec(truncate)

# Get all quarters and their centroid lat/lon from administrative region layer, insert into node_data
quarters = <<-SQL
  INSERT INTO node_data(id, node_id, data, layer_id, node_data_type)
  SELECT 
    nextval('node_data_id_seq'), id AS node_id, 
    hstore(ARRAY['centroid:lon', ST_X(centroid)::text, 'centroid:lat', ST_Y(centroid)::text]) AS data, 
    #{rain_layer_id} AS layer_id, 0 AS node_data_type
  FROM (
    SELECT nodes.id, ST_AsText(ST_Centroid(geom)) AS centroid FROM nodes 
    JOIN node_data ON node_data.node_id = nodes.id
    WHERE nodes.layer_id = #{admr_layer_id} AND data -> 'admn_level' = '4'
  ) c
SQL

res = conn.exec(quarters)
puts "Done! Rain node data created for #{res.cmd_tuples()} administrative regions!"

