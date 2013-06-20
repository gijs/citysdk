require "pg"
require 'csv'
require 'digest/md5'
require 'json'
require 'socket'

local_ip = UDPSocket.open {|s| s.connect("123.123.123.123", 1); s.addr.last}
if(local_ip =~ /192\.168|10\.0\.135/)
  dbconf = JSON.parse(File.read('../../../server/database.json'))
else
  dbconf = JSON.parse(File.read('/var/www/citysdk/current/database.json'))
end

# -2: world
# -1: continent
# 0:  country
# 1: state/province
# 2: county/region
# 3: city/town
# 4: quarter
# 5: neighborhood
# 6: area 



class ZRPrinter
  def n() $stderr.write "\n\033[s" end
  def initialize() $stderr.write "\033[s" end
  def p(s) $stderr.puts "\033[u\033[A\033[K#{s}" end
end

class Hash
  def to_hstore(pg_connection)
    pairs = []
    data =  "hstore(ARRAY["
    self.each_pair do |p|
      pairs << "['#{pg_connection.escape(p[0].to_s)}','#{pg_connection.escape(p[1].to_s)}']"
    end
    data += pairs.join(',')
    data += "])"
    data
  end
end



def createNewNode(b, cdkid, layer_id)

  while $pg_csdk.exec("select cdk_id from nodes where cdk_id = '#{cdkid}'").cmd_tuples != 0
    cdkid = cdkid + '_'
  end
  id = $pg_csdk.exec("select nextval('nodes1_id_seq')")[0]['nextval'].to_i
  location = b['geom']
  name = $pg_csdk.escape(b['name'])
  loc = "ST_Simplify('#{location}'::geometry,0.00001)"
  queri = "insert into nodes (id,cdk_id,layer_id,node_type,name,geom) VALUES 
    (#{id},'#{cdkid}',#{layer_id}, 0, '#{name}', #{loc});"
  begin 
    r = $pg_csdk.exec(queri)
  rescue Exception => e
    puts e.message
    return nil
  end
  if( r && r.result_status == 1)
    $nodes_added += 1
    return id
  end
  return nil
end

def createNewNodeData(node_id, h, layer_id)
  #delete old cbs info
  $pg_csdk.exec("delete from node_data where node_id = #{node_id} and layer_id = #{layer_id};")

  id = $pg_csdk.exec("select nextval('node_data_id_seq')")[0]['nextval'].to_i
  queri =  "insert into node_data (id,node_id,layer_id,node_data_type,data) "
  queri += "VALUES (#{id},'#{node_id}',#{layer_id}, 0, #{h.to_hstore($pg_csdk)});"
  begin 
    r = $pg_csdk.exec(queri)
  rescue Exception => e
    puts e.message
    return nil
  end
  if( r && r.result_status == 1)
    $node_data_added += 1
    return id
  end
  return nil
end




def do_exit(s=nil)
  puts s if s
  $pg_csdk.close
  $stderr.puts
  $stderr.puts "New nodes added: #{$nodes_added}"
  $stderr.puts "Node-data added: #{$node_data_added}"
  exit(0)
end

Signal.trap("SIGINT") do
  do_exit("\n\nUser interrupt\n")
end


begin
  puts dbconf
  $pg_csdk = PGconn.new(dbconf['host'], '5432', nil, nil, dbconf['database'], dbconf['user'], dbconf['passwd'])
rescue
  do_exit "Couldn't connect to database..."
end
$zrp = ZRPrinter.new()

$nodes_added = 0
$node_data_added = 0

res = $pg_csdk.exec("select id from layers where name = 'admr'");
$admr_layerID = res[0]['id'].to_i if res.cmdtuples > 0
if($admr_layerID.nil?)
	$stderr.puts "No admr layer found!"
	exit(-1)
end

count = 0
$pg_csdk.transaction do
  # "nationalcode";"localid";"nationallevel";"name";"admn_level";"geom"
  CSV.foreach('admr.finland.csv', :quote_char => '"', :col_sep =>';', :headers => true, :row_sep =>:auto, :encoding => 'utf-8') do |row|
    if(row['admn_level'] == '0')
      row['name'] = 'Suomi'
    else
      if row['name'] =~ /{(.*),(.*)}/
        row['name'] = row['name:fi'] = $1
        row['name:sv'] = $2
      end
    end
    row['name'] = row['name'].gsub('"','')
    row['name:sv'] = row['name:sv'].gsub('"','') if row['name:sv']
    row['name:fi'] = row['name:fi'].gsub('"','') if row['name:fi']
    
    h = row.to_hash
    cdk_id = "admr.fi." + "#{row['name'].gsub(/\s/,'_').gsub(/\W/,'')}".downcase
    $zrp.p("count: #{count}; #{h['name']}")
    id = createNewNode(h, cdk_id, $admr_layerID)
    h.delete('name')
    h.delete('geom')
    createNewNodeData(id, h, $admr_layerID) if id
    count += 1
  end
  
  
end


do_exit

