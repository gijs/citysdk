require "pg"
require 'base62'
require 'digest/md5'
require 'json'
require 'socket'

local_ip = UDPSocket.open {|s| s.connect("123.123.123.123", 1); s.addr.last}
if(local_ip =~ /192\.168|10\.0\.135/)
  dbconf = JSON.parse(File.read('../../server/database.json'))
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


# TODO link to osm:

# select count(*) from node_data 
# join nodes on node_data.node_id = nodes.id
# where 
#   data -> 'boundary' = 'administrative' and
#   data -> 'authoritative' = 'yes' and
#   data ? 'name' and
#   data -> 'name' != '' and
#   
#   node_data.layer_id = 0 and
#   nodes.cdk_id like 'r%'
  

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
  queri = "insert into nodes (id,cdk_id,layer_id,node_type,name,geom) VALUES 
    (#{id},'#{cdkid}',#{layer_id}, 0, '#{$pg_csdk.escape(b['name'])}', ST_Transform('#{location}'::geometry, 4326));"
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
  $pg_cbs.close
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
  $pg_cbs = PGconn.new(dbconf['host'], '5432', nil, nil, 'oens', dbconf['user'], dbconf['passwd'])
rescue
  do_exit "Couldn't connect to database..."
end
$zrp = ZRPrinter.new()
$cbs_layerID = nil
$nodes_added = 0
$node_data_added = 0

res = $pg_csdk.exec("select id from layers where name = 'oens'");
$oens_layerID = res[0]['id'].to_i if res.cmdtuples > 0
if($oens_layerID.nil?)
	$stderr.puts "No oens layer found!"
	exit(-1)
end

res = $pg_csdk.exec("select id from layers where name = 'admr'");
$admr_layerID = res[0]['id'].to_i if res.cmdtuples > 0
if($admr_layerID.nil?)
	$stderr.puts "No admr layer found!"
	exit(-1)
end

res = $pg_csdk.exec("select id from layers where name = 'cbs'");
$cbs_layerID = res[0]['id'].to_i if res.cmdtuples > 0
if($cbs_layerID.nil?)
	$stderr.puts "No cbs layer found!"
	exit(-1)
end


# get buurtcodes from cbs to match
$cbsBuurten=[]
res = $pg_csdk.exec <<-SQL
select data -> 'wk_code' as wk_code 
  from node_data 
  where layer_id = 3 and 
  data -> 'gm_code' = 'GM0363' and 
  data -> 'wk_code' != '' 
  group by wk_code
  SQL

res.each do |row|
  $cbsBuurten << row['wk_code'].gsub('WK','BU')
end
  
def findCBSNode(bucode)
  $cbsBuurten.each do |c|
    cbs_code = c + bucode
    res = $pg_csdk.exec("select node_id from node_data where data -> 'bu_code' = '#{cbs_code}'")
    res.each do |row|
      return row['node_id']
    end
  end
  nil
end


count = 0
$pg_csdk.transaction do
  
  $pg_csdk.exec <<-SQL
  delete from nodes where id in (SELECT node_id
    FROM node_data 
    WHERE data::hstore -> 'admn_level' = '6')
  SQL

  $pg_csdk.exec <<-SQL
    delete FROM node_data 
    WHERE data::hstore -> 'admn_level' = '6'
  SQL
  
  $pg_csdk.exec <<-SQL
    delete FROM nodes 
    WHERE layer_id = #{$oens_layerID}
  SQL
  
  $pg_csdk.exec <<-SQL
    delete FROM node_data 
    WHERE layer_id = #{$oens_layerID}
  SQL
  
  res = $pg_cbs.exec("select * from buurt")
  res.each do |row|
    next if row['bcnaam'].nil?
    row.delete('gid')
    $zrp.p "#{row['bcnaam']}; #{count}" 
    cid = "admr.nl." + "#{row['bcnaam'].gsub(/\s/,'_').gsub(/\W/,'')}".downcase
    row['name'] = row['bcnaam']
    id=createNewNode(row,cid,$admr_layerID)
    row.delete('geom')
    h = {
      'name'  => row['bcnaam'],
      'admn_level' => '6'
    }
    createNewNodeData(id, h, $admr_layerID) if id
    createNewNodeData(id, row, $oens_layerID) if id
    count += 1
  end
  
  res = $pg_cbs.exec("select * from buurtc")
  res.each do |row|
    
    next if row['bcnaam'].nil?
    row.delete('gid')
    $zrp.p "#{row['bcnaam']}; #{count}" 
    cid = "admr.nl." + "#{row['bcnaam'].gsub(/\s/,'_').gsub(/\W/,'')}".downcase
    row['name'] = row['bcnaam']
    id = findCBSNode(row['bc'])
    if id.nil?
      id=createNewNode(row,cid,$oens_layerID)
    end
    row.delete('geom')
    createNewNodeData(id, row, $oens_layerID) if id
    count += 1
  end
  
  res = $pg_cbs.exec("select * from stadsdeel")
  res.each do |row|
    next if row['stadsdeeln'].nil?
    row.delete('gid')
    $zrp.p "#{row['stadsdeeln']}; #{count}" 
    cid = "admr.nl." + "#{row['stadsdeeln'].gsub(/\s/,'_').gsub(/\W/,'')}".downcase
    row['name'] = row['stadsdeeln']
    id=createNewNode(row,cid,$oens_layerID)
    row.delete('geom')
    createNewNodeData(id, row, $oens_layerID) if id
    count += 1
  end
  

  $pg_csdk.exec <<-SQL
    drop view if exists areas;
    CREATE VIEW areas
        AS select 
            nodes.id,
          	nodes.cdk_id,
            nodes.name, 
            nodes.geom
          from 
          	nodes
          left join 
          	node_data on nodes.id = node_data.node_id
          where
            nodes.layer_id = 2 and
          	(node_data.data @> '"admn_level"=>"6"')
          order by 
          	name;
  SQL


end


do_exit

