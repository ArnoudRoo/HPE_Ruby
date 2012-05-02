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

  def to_ruby
    orgMethodStore = Store.new
    env = PeEnv.new
    env.store = orgMethodStore
#    @astNode.nodes.map! { |node| (node.respond_to? :pe) ? node.pe(env) : node }
    @astNode.to_ruby + "\n" + @specialized.map { |method| method.to_ruby + "\n" }.join
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
      paramName =  @astNode.params.elements[i].param.token

      if (arguments[i].class == Ruby::Const && store.isCT(arguments[i].getNameOfVarOrConst(arguments[i])))
        #add the compile time argument to the store.
        #change the name of the callStore var to the name of the parameter instead of the name of the argument
        #f.e. ==>  def foo(a) | b = 10 | ct b | foo(b)  ==>  a needs to be a compile time var in the callStore
        tempVar = store.find(arguments[i].token)
        tempVar.name = paramName
        callStore.update(tempVar)
        paramsToRemove << i
      elsif (arguments[i].class != Ruby::Const && arguments[i].compileTime?)
        tempVar = StoreVar.new(paramName,arguments[i],:compileTime)
        callStore.update(tempVar)
        paramsToRemove << i
      end
    end

    #the cloned Method gets partial evaluated so it becomes the specialized method
    clonedMethod = @astNode.deep_copy

    paramsToRemove.reverse.each { |i| clonedMethod.params.elements.delete_at(i) }
    env = PeEnv.new
    env.store = callStore
    env.markAsRuntime = false

    clonedMethod.identifier.token = newMethodName

    #be sure that there is always a whitespace between the method name and the first parameter and that it is not a ","
    if(clonedMethod.params.elements[0] && clonedMethod.params.elements[0].prolog.elements[0])
       clonedMethod.params.elements[0].prolog.elements[0].token = " "
    end

    @specialized << clonedMethod

    #partial evaluate the method with the ct arguments mapped to the parameters of the method (using the store).
    clonedMethod.nodes.map! { |node| (node.respond_to? :pe) ? node.pe(env) : node }

    return newMethodName
  end
end