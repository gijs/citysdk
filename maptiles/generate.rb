#require "sqlite3"
require "json"

# sudo apt-add-repository ppa:developmentseed/mapbox
# sudo apt-get install nodejs
# sudo apt-get install tilemill
# sudo apt-get install npm
# Install https://github.com/mapbox/tilestream

tilesets = JSON.parse(File.read('./tilesets.json'))
config = JSON.parse(File.read('./config.json'))

default_minzoom = tilesets["minzoom"]
default_maxzoom = tilesets["maxzoom"]

tiles_path = config["paths"]["tiles"]
projects_path = config["paths"]["projects"]
tilemill_path = config["paths"]["tilemill"]
script_path = File.expand_path(File.dirname(__FILE__))

tile_cmd = "#{tilemill_path}/index.js export citysdk #{tiles_path}/%s.mbtiles --format=mbtiles --bbox=%s --minzoom=%s --maxzoom=%s --metatile=2 --files=#{projects_path}"

if not Dir["#{tiles_path}/*"].empty?
  puts "Tiles directory is not empty: #{tiles_path}"
  puts "Please move or delete all files from tiles directory."
  exit
end

Dir.chdir(tilemill_path)
tilesets["tilesets"].each {|name, tileset|  
  puts "Starting TileMill renderer: %s" % [name]
  bbox = tileset["bbox"]
  
  minzoom = tileset.has_key?("minzoom") ? tileset["minzoom"] : default_minzoom
  maxzoom = tileset.has_key?("maxzoom") ? tileset["maxzoom"] : default_maxzoom
  system tile_cmd % [name, bbox, minzoom, maxzoom]
}

# If more than one tileset is present in tilesets file, merge them!!!
if tilesets.length > 1
  base = tilesets["base"]
  dst = tilesets["name"]
  
  # Copy base.mbtiles to dst.mbtiles
  # Only zoom levels present in base.mbtiles will be present in dst.mbtiles
  # (do not use file with 2 zoom levels and merge file with more zoom levels into it!)  

  cp_cmd = "cp #{tiles_path}/#{base}.mbtiles #{tiles_path}/#{dst}.mbtiles"
  system cp_cmb

  # Merge mbtiles files
  # https://github.com/mapbox/node-mbtiles/wiki/Post-processing-MBTiles-with-MBPipe
  patch_cmd = "bash patch.sh #{tiles_path}/%s.mbtiles #{tiles_path}/#{dst}.mbtiles"
  Dir.chdir(script_path)
  tilesets["tilesets"].each {|src, tileset|
    if not src == base
      puts "Merging tiles: %s" % [src]
      system patch_cmd % [src]
    end
  }

  # Set bounding box to world
  system "sqlite3 #{tiles_path}/#{dst}.mbtiles < bbox.sql"
end

# And then, run tilestream!
# ./index.js start --host=test-api.citysdk.waag.org  --tiles=/data/tiles
# Of met forever:
# forever start index.js start --host=test-api.citysdk.waag.org  --tiles=/data/tileserver/tiles
