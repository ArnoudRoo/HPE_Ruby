class SClass
  include SpecializeMethod
  
  def initialize(astNode)
    @astNode = astNode
    @methods = []
  end
  
  def identifier
    @astNode.identifier.identifier.token
  end
  
  def addMethod(methodToAdd, path)
    @methods << SMethod.new(methodToAdd)   
  end

  def astNode
    @astNode
  end

  def to_ruby
    "class #{identifier}\n" + @methods.map{|item| item.to_ruby}.join + "\nend\n"
  end
end