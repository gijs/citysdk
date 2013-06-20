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
      pairs << "['#{pg_connection.escape(p[0])}','#{pg_connection.escape(p[1])}']"
    end
    data += pairs.join(',')
    data += "])"
    data
  end
end



def createNewNode(b, cdkid)
  while $pg_csdk.exec("select cdk_id from nodes where cdk_id = '#{cdkid}'").cmd_tuples != 0
    cdkid = cdkid + '_'
  end
  id = $pg_csdk.exec("select nextval('nodes1_id_seq')")[0]['nextval'].to_i
  location = b['geom']
  queri = "insert into nodes (id,cdk_id,layer_id,node_type,name,geom) VALUES 
    (#{id},'#{cdkid}',#{$admr_layerID}, 0, '#{$pg_csdk.escape(b['name'])}', ST_Transform('#{location}'::geometry, 4326));"
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
  $pg_csdk = PGconn.new(dbconf['host'], '5432', nil, nil, dbconf['database'], dbconf['user'], dbconf['passwd'])
  $pg_cbs = PGconn.new(dbconf['host'], '5432', nil, nil, 'cbs', dbconf['user'], dbconf['passwd'])
rescue
  do_exit "Couldn't connect to database..."
end
$zrp = ZRPrinter.new()
$cbs_layerID = nil
$nodes_added = 0
$node_data_added = 0


res = $pg_csdk.exec("select id from layers where name = 'cbs'");
$cbs_layerID = res[0]['id'].to_i if res.cmdtuples > 0
if($cbs_layerID.nil?)
	$stderr.puts "No cbs layer found!"
	exit(-1)
end

res = $pg_csdk.exec("select id from layers where name = 'admr'");
$admr_layerID = res[0]['id'].to_i if res.cmdtuples > 0
if($admr_layerID.nil?)
	$stderr.puts "No admr layer found!"
	exit(-1)
end


count = 0
$pg_csdk.transaction do
  
  $pg_csdk.exec "delete from nodes where layer_id = #{$admr_layerID}"
  $pg_csdk.exec "delete from node_data where layer_id = #{$admr_layerID}"
  $pg_csdk.exec "delete from node_data where layer_id = #{$cbs_layerID}"

  res = $pg_cbs.exec("select * from gem_2011_gn1")
  res.each do |row|
    next if row['gm_naam'].nil?
    row.delete('gid')
    $zrp.p "#{row['gm_naam']}; #{row['gm_code']}; #{count}" 
    cid = "admr.nl." + "#{row['gm_naam'].gsub(/\s/,'_').gsub(/\W/,'')}".downcase
    row['name'] = row['gm_naam']
    id=createNewNode(row,cid)
    row.delete('geom')
    h = {
      'name'  => row['name'],
      'admn_level' => '3'
    }
    createNewNodeData(id, h, $admr_layerID) if id
    createNewNodeData(id, row, $cbs_layerID) if id
    count += 1
  end
  
  $zrp.n
  res = $pg_cbs.exec("select * from wijk_2011_gn1")
  res.each do |row|
    next if row['wk_naam'].nil?
    row.delete('gid')
    $zrp.p "#{row['gm_naam']}; #{row['wk_naam']}; #{count}" 
    cid = "admr.nl." + "#{row['gm_naam']}_#{row['wk_naam']}}".gsub(/\s/,'_').gsub(/\W/,'').downcase
    row['name'] = row['wk_naam']
    id=createNewNode(row,cid)
    row.delete('geom')
    h = {
      'name'  => row['name'],
      'admn_level' => '4'
    }
    createNewNodeData(id, h, $admr_layerID) if id
    createNewNodeData(id, row, $cbs_layerID) if id
    count += 1
  end
  
  $zrp.n
  res = $pg_cbs.exec("select * from brt_2011_gn1")
  res.each do |row|
    next if row['bu_naam'].nil?
    row.delete('gid')
    wk_code = row['wk_code']
    wk_naam = $pg_cbs.exec("select wk_naam from wijk_2011_gn1 where wk_code = '#{wk_code}'")[0]['wk_naam']
    cid="#{row['gm_naam']}_#{wk_naam}_#{row['bu_naam']}".gsub(/\s+/,'_').gsub(/\W+/,'').downcase
    $zrp.p "#{cid}; #{count}" 
    cid = "admr.nl.#{cid}"
    row['name'] = row['bu_naam']
    id=createNewNode(row,cid)
    row.delete('geom')
    h = {
      'name'  => row['name'],
      'admn_level' => '5'
    }
    createNewNodeData(id, h, $admr_layerID) if id
    createNewNodeData(id, row, $cbs_layerID) if id
    count += 1
  end
  
  
  

  $pg_csdk.exec <<-SQL
    create or replace function admn_parents(cdk text) 
    returns setof nodes as $$
    begin
        return query 
          select * from nodes where 
            nodes.layer_id = 2 and 
            nodes.cdk_id != cdk and
            ST_Contains(
              nodes.geom, 
              ( select ST_Buffer( (select nodes.geom from nodes where nodes.cdk_id = cdk),-0.0000001) )
            ) 
          order by nodes.id desc;
    end $$ language plpgsql;

    create or replace function admn_children(cdk text) 
    returns setof nodes as $$
    begin
        return query 
          select * from nodes where 
            nodes.layer_id = 2 and 
            nodes.cdk_id != cdk and
            ST_Contains( 
              ( select ST_Buffer( (select nodes.geom from nodes where nodes.cdk_id = cdk),0.0000001) ),
              nodes.geom
            ) 
          order by nodes.id desc;
    end $$ language plpgsql;
  SQL




  $pg_csdk.exec <<-SQL
    drop view if exists provinces;
    CREATE VIEW provinces
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
          	(node_data.data @> '"admn_level"=>"1"')
          order by 
          	name;
  SQL


  $pg_csdk.exec <<-SQL
    drop view if exists towns;
    CREATE VIEW towns
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
          	(node_data.data @> '"admn_level"=>"3"')
          order by 
          	name;
  SQL


  $pg_csdk.exec <<-SQL
    drop view if exists quarters;
    CREATE VIEW quarters
        AS select 
            nodes.id,
            nodes.cdk_id, 
            nodes.name, 
            node_data.data -> 'gm_naam' as gm_naam,
            nodes.geom
          from 
            nodes
          left join 
            node_data on nodes.id = node_data.node_id
          where
            nodes.layer_id = 2 and
            (node_data.data @> '"admn_level"=>"4"')
          order by 
            name;
  SQL


  $pg_csdk.exec <<-SQL
    drop view if exists hoods;
    CREATE VIEW hoods
        AS select 
            nodes.id,
          	nodes.cdk_id, 
            nodes.name, 
          	node_data.data -> 'postcode' as postcode,
          	node_data.data -> 'gm_naam' as gm_naam,
            nodes.geom
          from 
          	nodes
          left join 
          	node_data on nodes.id = node_data.node_id
          where
            nodes.layer_id = 2 and
          	(node_data.data @> '"admn_level"=>"5"')
          order by 
          	name;
  SQL


end


do_exit

