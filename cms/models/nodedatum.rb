require 'sequel/model'


class Node < Sequel::Model
  one_to_many :node_data
end


class NodeDatum < Sequel::Model
  many_to_one :node
  many_to_one :layer
end
