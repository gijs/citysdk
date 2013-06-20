require "sequel/model"

class Layer < Sequel::Model
  many_to_one :owner
  plugin :validation_helpers

  def validate
    super
    validates_presence [:name, :description, :organization, :category]
    validates_unique :name
    validates_format /^\w+(\.\w+)*$/, :name
    validates_format /^\w+\.\w+$/, :category
  end
  
  def self.category_select(sel=false, all=false)
    s= all ? 
      "<select name='catprefix' onchange='layerSelect(this)'> " : 
      "<select name='catprefix'> "
    
    s += "<option #{sel=='all' ? 'selected="selected"' : ''}>all</option>" if all
    sel = 'administrative' if sel==false
    
    Category.order(:name).all.each do |c|
      s += "<option #{c.name==sel ? 'selected="selected"' : ''}>#{c.name}</option>"
    end
    s += "</select>"
    s
  end
  
  
  def cat_select
    self.category = '.' if self.category.nil?
    pref = self.category.split('.')[0]
    categories = Layer.category_select(pref)
    self.category = self.category.split('.')[1]
    return categories
  end
  
  
  def self.selectTag 
    r = "<select>"
    Layer.order(:id).all do |l|
      r += "<option>#{l.name}</option>"
    end
    r += "</select>"

  end
  
  
  
end
