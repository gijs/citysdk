# Downloaded from:
# https://gist.github.com/1730288
# Modified by Bert Spaan for CitySDK
 
class Edge
  attr_accessor :src, :dst, :label, :length
  
  def initialize(src, dst, label, length = 1)
    @src = src
    @dst = dst
    @label = label
    @length = length
  end
end
 
class Graph < Array
  attr_reader :edges
  
  def initialize
    @edges = []
    @src_dst = {}
  end

  def add_edge(src, dst, label, length)
  	edge = Edge.new(src, dst, label, length)
  	@edges.push(edge)
  	@src_dst[[src, dst]] = edge
  end
  
  def connect(src, dst, label, length = 1, directed = false)

		if not self.include? src
			self.push src
		end		
		if not self.include? dst
			self.push dst
		end
    
    self.add_edge(src, dst, label, length)
    if not directed  	  
  	  self.add_edge(dst, src, label, length)
  	end
  end  
 
  def neighbors(vertex)
    neighbors = []
    @edges.each do |edge|
      neighbors.push edge.dst if edge.src == vertex
    end
    return neighbors.uniq
  end
 
  def length_between(src, dst)
    @edges.each do |edge|
      return edge.length if edge.src == src and edge.dst == dst
    end
    nil
  end
 
  def dijkstra(src, dst = nil)
    distances = {}
    previouses = {}
    self.each do |vertex|
      distances[vertex] = nil # Infinity
      previouses[vertex] = nil
    end
    distances[src] = 0
    vertices = self.clone
    until vertices.empty?
      nearest_vertex = vertices.inject do |a, b|
        next b unless distances[a]
        next a unless distances[b]
        next a if distances[a] < distances[b]
        b
      end
      break unless distances[nearest_vertex] # Infinity
      if dst and nearest_vertex == dst

      	path = []      	
      	while dst do      		
      		path << dst
      		dst = previouses[dst]
      	end

        path.reverse!
        labels = []
        (0..(path.length - 2)).each do |i|                 
					src = path[i]
					dst = path[i + 1]
					labels << @src_dst[[src, dst]].label					
				end
        
        labels = labels.uniq
        distance = distances[dst]

        if labels != [] and distance != nil
          return labels, distance
        end
        #else
        #  return nil?? of is er misschien nog ander pad mogelijk later in loop?
      end
      neighbors = vertices.neighbors(nearest_vertex)
      neighbors.each do |vertex|
        alt = distances[nearest_vertex] + vertices.length_between(nearest_vertex, vertex)
        if distances[vertex].nil? or alt < distances[vertex]
          distances[vertex] = alt
          previouses[vertex] = nearest_vertex          
          # decrease-key v in Q # ???
        end
      end
      vertices.delete nearest_vertex
    end

    return nil
  end
end