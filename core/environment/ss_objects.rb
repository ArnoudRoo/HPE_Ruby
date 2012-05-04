class BaseSSObject
  attr_accessor :elements

  def replaceMethodPlaceHolders
    ssElements = @elements.select { |elem| elem.class == SMethod || (elem.kind_of? BaseSSObject) }
    if self.class == SharedStore
      body = @elements.select { |elem| elem.class == Ruby::Program }[0]
      body.elements.map! { |node|
        if (node.class == Ruby::PlaceHolder)
          ssElements.select { |element| element.identifier == node.token }[0]
        else
          node
        end
      }
      @elements = [body]
    else
      body = @elements.select { |elem| elem.class == Ruby::Node::Composite::Array }
      body.each{|arrayNode| arrayNode.select{|a| a.class == Ruby::Statements}.each{|b|b.elements.map!{ |node|
        if (node.class == Ruby::PlaceHolder)
          ssElements.select { |element| element.identifier == node.token }[0]
        else
          node
        end
      }}}
      @elements = body
    end
  end

  def addModule(moduleToAdd, path = nil)
    path = moduleToAdd.getPath if (path == nil)
    addSSObject(SModule.new(moduleToAdd, "module"), path)
  end

  def addClass(classToAdd, path = nil)
    path = classToAdd.getPath if (path == nil)
    addSSObject(SClass.new(classToAdd), path)
  end

  def addSSObject(object, path)
    if (path.length == 1)
      @elements << object
    else
      match = @elements.find_all { |item| item.respond_to?(:identifier) && item.identifier == path[0] }
      if (match.any?)
        match.last.addSSObject(object, path[1..-1])
      else
        raise "Module #{moduleToAdd.const.identifier.token} could not be found"
      end
    end
  end

  def addStatements(statements, path)
    if (path.length == 0)
      @elements << statements
    else
      match = @elements.find_all { |item| item.respond_to?(:identifier) && item.identifier == path[0] }
      if (match.any?)
        match.last.addStatements(statements, path[1..-1])
      else
        raise "Module #{moduleToAdd.const.identifier.token} could not be found"
      end
    end
  end

  def addMethod(methodToAdd, path = nil)
    path = methodToAdd.getPath if path == nil

    if (path.length == 0)
      @elements << SMethod.new(methodToAdd)
    else
      matches = @elements.find_all { |item| item.respond_to?(:identifier) && item.identifier == path[0] }

      if (matches.any?)
        matches.last.addMethod(methodToAdd, path[1..-1])
      else
        raise "Module #{path[0]} could not be found"
      end
    end
  end

  def specializeMethod(unspecializedName, specializedName, arguments, store)
    methods = @elements.find_all { |elem| elem.class == SMethod && elem.identifier == unspecializedName }
    methods.each { |method| method.specialize(specializedName, arguments, store) }
    @elements.each { |item| item.specializeMethod(unspecializedName, specializedName, arguments, store) if (item.respond_to? :specializeMethod) } if (defined? elements)
  end

end

class SModule < BaseSSObject

  def initialize(astNode, type)
    @elements = []
    @astNode = astNode
    @type = type
  end

  def identifier
    @astNode.const.identifier.token
  end

  def astNode
    @astNode
  end

  def to_ruby(prolog=true)
    replaceMethodPlaceHolders
    "\nmodule #{identifier}\n" + (@elements.map { |item| item.to_ruby(true) + "\n" }).join + "\nend\n"
  end
end


class SClass < BaseSSObject

  def initialize(astNode)
    @astNode = astNode
    @elements = []
  end

  def identifier
    @astNode.identifier.identifier.token
  end

  def addMethod(methodToAdd, path)
    @elements << SMethod.new(methodToAdd)
  end

  def astNode
    @astNode
  end

  def to_ruby(prolog=true)
    replaceMethodPlaceHolders
    "\nclass #{identifier}\n" + @elements.map { |item| item.to_ruby(true) }.join + "\nend\n"
  end
end


class SMethod

  def initialize(astNode)
    @astNode = astNode
    @specialized = []
  end

  def identifier
    @astNode.identifier.token
  end

  def paramCount
    @astNode.params.elements.count
  end

  def astNode
    @astNode
  end

  def to_ruby(prolog = true)
    orgMethodStore = Store.new
    env = PeEnv.new
    env.store = orgMethodStore
#    @astNode.nodes.map! { |node| (node.respond_to? :pe) ? node.pe(env) : node }
    "\n" + @astNode.to_ruby + "\n" + @specialized.map { |method| method.to_ruby + "\n" }.join
  end


  def specialize(newMethodName, arguments, store)

    #this collection contains the parameters that need to be removed because the arguments passed in for the parameters are compile time
    paramsToRemove = []

    #the callStore contains the compile time vars for the parameters with compile time arguments.
    callStore = Store.new

    #loop through all the arguments and check if it are compile time variables.
    #if it is a compile time argument add it to the callStore and to the paramsToRemove collection.
    argCount = (arguments.respond_to? :length) ? arguments.length : 0
    for i in 0..argCount-1
      paramName = @astNode.params.elements[i].param.token

      if (arguments[i].class == Ruby::Const && store.isCT(arguments[i].getNameOfVarOrConst(arguments[i])))
        #add the compile time argument to the store.
        #change the name of the callStore var to the name of the parameter instead of the name of the argument
        #f.e. ==>  def foo(a) | b = 10 | ct b | foo(b)  ==>  a needs to be a compile time var in the callStore
        tempVar = store.find(arguments[i].token)
        tempVar.name = paramName
        callStore.update(tempVar)
        paramsToRemove << i
      elsif (arguments[i].class != Ruby::Const && arguments[i].compileTime?)
        tempVar = StoreVar.new(paramName, arguments[i], :compileTime)
        callStore.update(tempVar)
        paramsToRemove << i
      end
    end

    #the cloned Method gets partial evaluated so it becomes the specialized method
    clonedMethod = @astNode.deep_copy

    paramsToRemove.reverse.each { |i| clonedMethod.params.elements.delete_at(i) }
    env = PeEnv.new
    env.store = callStore

    clonedMethod.identifier.token = newMethodName

    #be sure that there is always a whitespace between the method name and the first parameter and that it is not a ","
    if (clonedMethod.params.elements[0] && clonedMethod.params.elements[0].prolog.elements[0])
      clonedMethod.params.elements[0].prolog.elements[0].token = " "
    end

    @specialized << clonedMethod

    #partial evaluate the method with the ct arguments mapped to the parameters of the method (using the store).
    clonedMethod.nodes.map! { |node| (node.respond_to? :pe) ? node.pe(env) : node }

    return newMethodName
  end
end