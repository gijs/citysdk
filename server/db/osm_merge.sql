
-- even very distant regions share features like coatslines, roads etc
-- duplicate id's are not allowed
-- pragmatical solution is to delete them
delete from public.planet_osm_rels where id in (select id from osm.planet_osm_rels);
delete from public.planet_osm_ways where id in (select id from osm.planet_osm_ways);
delete from public.planet_osm_nodes where id in (select id from osm.planet_osm_nodes);

  -- merge 
insert into osm.planet_osm_line select * from public.planet_osm_line;
insert into osm.planet_osm_nodes select * from public.planet_osm_nodes;
insert into osm.planet_osm_point select * from public.planet_osm_point;
insert into osm.planet_osm_polygon select * from public.planet_osm_polygon;
insert into osm.planet_osm_rels select * from public.planet_osm_rels;
insert into osm.planet_osm_roads select * from public.planet_osm_roads;
insert into osm.planet_osm_ways select * from public.planet_osm_ways;
  
  -- and clean up
drop table public.planet_osm_line;
drop table public.planet_osm_nodes;
drop table public.planet_osm_point;
drop table public.planet_osm_polygon;
drop table public.planet_osm_rels;
drop table public.planet_osm_roads;
drop table public.planet_osm_ways;
