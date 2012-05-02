class SModule
  include AddModule
  include AddClass
  include AddMethod
  include SpecializeMethod

  def initialize(astNode,type)
    @classes = []
    @modules = []
    @methods = []
    @astNode = astNode
    @type = type
  end

  def classes
    @classes
  end

  def modules
    @modules
  end

  def identifier
    @astNode.const.identifier.token
  end

  def astNode
    @astNode
  end

  def to_ruby
    "module #{identifier}\n" + (@classes.map{|item| item.to_ruby + "\n"} + @modules.map{|item| item.to_ruby}).join + "\nend\n"
  end

end