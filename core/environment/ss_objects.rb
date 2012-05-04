class BaseSSObject
  attr_accessor :elements

  def initialize
    @elements = []
  end

  def replacePlaceHolders
    ssElements = @elements.select { |elem| elem.class == SMethod || (elem.kind_of? BaseSSObject) }
    if self.class == SharedStore
      # if the class = SharedStore this means that it is the main program.
      body = @elements.select { |elem| elem.class == Ruby::Program }[0]
      # loop through all the elements and replace the placeholders with the real methods, classes and modules.
      body.elements.map! { |node|
        replacePlaceHolderIfNeeded(node, ssElements)
      }
      @elements = [body]
    else
      # if the class is something else as SharedStore, for example SModule, SClass then select all the Ruby::Node::Composite::Array elements and replace the placeholders within the sub arrays
      body = @elements.select { |elem| elem.class == Ruby::Node::Composite::Array }
      # loop through all the elements and replace the placeholders with the real methods, classes and modules.
      body.each { |arrayNode| arrayNode.select { |a| a.class == Ruby::Statements }.each { |b| b.elements.map! { |node|
        replacePlaceHolderIfNeeded(node, ssElements)
      } } }
      @elements = body
    end
  end

  #this function is used by replacePlaceHolders to replace a placeholder with the real method, module or class. Used multiple times.
  def replacePlaceHolderIfNeeded(node, ssElement)
    if (node.class == Ruby::PlaceHolder)
      replaceValue = ssElement.select { |element| element.identifier == node.token }[0]
      ssElement.delete(replaceValue)
      replaceValue
    else
      node
    end
  end

  #add an object to the shared store. Used to add methods, modules, classes and statement sections.
  def addSSObject(object, path)
    #for classes and modules a pathlength of 1 is needed. for methods and statements 0. By classes and modules the last part of the path is the module or class itself.
    neededPathLength =(object.class == SModule || object.class == SClass) ? 1 : 0

    if (path.length == neededPathLength)
      @elements << object
    else
      match = @elements.find_all { |item| item.respond_to?(:identifier) && item.identifier == path[0] }
      if (match.any?)
        match.last.addSSObject(object, path[1..-1])
      else
        raise "Error adding object to the shared store, wrong path (#{path.to_s})"
      end
    end
  end

  #ToDo: add logic to get the right class. Combine multiple classes if they exist.
  def createObject(path)
    return @elements.select{|i| i.class == SClass}[0].createObject
  end

  #specialize all the methods with the specified unspecializedName. The real specialization is implemented in the SMethod class.
  def specializeMethod(unspecializedName, specializedName, arguments, store)
    methods = @elements.find_all { |elem| elem.class == SMethod && elem.identifier == unspecializedName }
    methods.each { |method| method.specialize(specializedName, arguments, store) }
    @elements.each { |item| item.specializeMethod(unspecializedName, specializedName, arguments, store) if (item.respond_to? :specializeMethod) } if (defined? elements)
  end

end

class SModule < BaseSSObject

  def initialize(astNode)
    super()
    @astNode = astNode
  end

  def identifier
    @astNode.const.identifier.token
  end

  def astNode
    @astNode
  end

  def to_ruby(prolog=true)
    replacePlaceHolders
    "\nmodule #{identifier}\n" + (@elements.map { |item| item.to_ruby(prolog) + "\n" }).join + "\nend\n"
  end
end


class SClass < BaseSSObject

  #TODO: extend to let it work.
  def createObject
    eval(self.to_ruby)
    a = A.new
    a.foo(3)
    a
  end

  def initialize(astNode)
    super()
    @astNode = astNode
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
    replacePlaceHolders
    "\nclass #{identifier}\n" + @elements.map { |item| item.to_ruby(prolog) }.join + "\nend\n"
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
    "\n" + @astNode.to_ruby + "\n" + @specialized.map { |method| method.to_ruby(prolog) + "\n" }.join
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