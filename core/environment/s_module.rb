class SModule < BaseSSObject

  def initialize(astNode)
    super()
    @astNode = astNode
  end

  def identifier
    @astNode.const.identifier.token
  end

  def instantiateCode(childCode)
    code = "\nmodule #{identifier}\n" + childCode + "\nend\n"
    ssParent.respond_to?("instantiateCode") ? ssParent.instantiateCode(code) : code
  end

  def to_ruby(prolog=true)
    replacePlaceHolders
    "\nmodule #{identifier}\n" + (@elements.map { |item| item.to_ruby(prolog) + "\n" }).join + "\nend\n"
  end

  def path
    @astNode.path
  end
end