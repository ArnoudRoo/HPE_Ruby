class SMethod
  attr_accessor :ssParent, :specializations, :astNode, :orgPath, :created

  def initialize(astNode, orgPath)
    @astNode = astNode
    @specializations = []
    @orgPath = orgPath
    @created = Time.now
  end

  def getAllOfType(type)
    self.kind_of?(type) ? [self] : [nil]
  end

  def identifier
    if (@astNode.identifier.respond_to?(:token))
      @astNode.identifier.token
    else
      @astNode.identifier.identifier.token
    end
  end

  def identifier=(value)
    if (@astNode.identifier.respond_to?(:token))
      @astNode.identifier.token = value
    else
      @astNode.identifier.identifier.token = value
    end
  end

  def instantiateCode
    ssParent.respond_to?(:instantiateCode) ? ssParent.instantiateCode(self.deep_copy.to_ruby) : nil
  end

  def to_ruby(prolog = true)
    "\n" + @astNode.to_ruby + "\n" + @specializations.map { |method| "\n" + method.to_ruby(prolog) + "\n" if method.respond_to?(:to_ruby) }.join
  end

  def specialize(newMethodName, arguments, block, store = nil)
    if(!store)
      store = Store.new(nil)
      store.update(StoreVar.new(Helpers.selfIdentifier,:kernel,:runtime))
    end
    store.update(StoreVar.new(Helpers.blockIdentifier, block, :runtime))
    clonedMethod, peInfo = specializeMethodOrConstructor(newMethodName, arguments, store)
    @specializations << clonedMethod
    peInfo
  end

  #useVarsInStore is used when methods of partial objects get specialized, the vars in the store are the fields.
  def specializeMethodOrConstructor(newMethodName, arguments, store = Store.new)
    #this collection contains the parameters that need to be removed because the arguments passed in for the parameters are compile time
    paramsToRemove = []

    #loop through all the arguments and check if it are compile time variables.
    #if it is a compile time argument add it to the store and to the paramsToRemove collection.
    argCount = (arguments.respond_to? :length) ? arguments.length : 0

    return nil, nil if(argCount != @astNode.params.elements.length && !store.inStore?(Helpers.blockIdentifier))

    for i in 0..argCount-1
      paramName = @astNode.params.elements[i].param.token
      if (Helpers.compileTime?(arguments[i]))
        store.update(StoreVar.new(paramName, arguments[i], :compileTime))
        paramsToRemove << i
      else
        store.update(StoreVar.new(paramName, arguments[i], (arguments[i].respond_to?(:external) && arguments[i].external) ? :external : :runtime))
      end
    end

    #the cloned Method gets partial evaluated so it becomes the specialized method
    clonedMethod = @astNode.deep_copy

    #remove the parameters that contain ct arguments.
    paramsToRemove.reverse.each { |i| clonedMethod.params.elements.delete_at(i) }
    env = PeEnv.new
    env.store = store

    #set the new name of the method.
    clonedMethod.peIdentifier = newMethodName

    #be sure that there is always a whitespace between the method name and the first parameter and that it is not a ","
    if (clonedMethod.params.elements[0] && clonedMethod.params.elements[0].prolog.elements[0])
      clonedMethod.params.elements[0].prolog.elements[0].token = " "
    end

    #partial evaluate the method with the ct arguments mapped to the parameters of the method (using the store).
    peBodyExpResult, peBodyValueResult = clonedMethod.peBody(env)

    return clonedMethod, peBodyValueResult
  end


end