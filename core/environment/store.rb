class Store
  def initialize(parent = nil)
    raise TypeError, "The parent store must also be of the type Store" if parent != nil && parent.class != Store
    @parent = parent
    @vars = {}
  end

  def update(var)
    raise TypeError, "The specified var is not of the type StoreVar" if var.class != StoreVar
    if (inStore? var.name)
      find(var.name).astVal = var.astVal
    else
      @vars[var.name] = var
    end
  end

  def asAssignment(name)
    throwIfVarNotInStore name
    find(name).asAssignment
  end

  def find(name)
    return @vars[name] if inStore?(name, false)
    return @parent.find(name) if @parent != nil
  end

  def inStore?(name, includeParent=true)
    return @vars[name].class == StoreVar if !includeParent
    return find(name).class == StoreVar if (includeParent)
  end

  def throwIfVarNotInStore(name)
    raise "There was no var with name #{name} in the store." if !inStore?(name)
  end

  #method used by call
  def changeName(oldName, newName)
    newVar = find(oldName)
    newVar.name = newName
    #@vars.delete(oldName)
    @vars[newName] = newVar
  end

  def setState(name, state, throwOnNotInStore=true)
    raise TypeError, "The markType parameter must be :runtime or :compileTime" if state != :compileTime && state != :runtime
    return if (!inStore?(name) && !throwOnNotInStore)
    throwIfVarNotInStore(name)
    find(name).state = state
  end

  def setType(name, type, throwOnNotInStore=true)
    return if (!inStore?(name) && !throwOnNotInStore)
    throwIfVarNotInStore(name)
    find(name).type = type
  end

  def isCT(name, throwOnNotInStore=true)
    throwIfVarNotInStore(name) if throwOnNotInStore
    return false if !(inStore? name)
    find(name).isCT
  end

  def astVal(name)
    throwIfVarNotInStore(name)
    find(name).astVal
  end

  def val(name)
    throwIfVarNotInStore(name)
    find(name).val
  end

  def state(name)
    return find(name).state if inStore?(name)
    return :nil
  end

  def type(name)
    return find(name).type
  end

  def vars
    return @vars
  end

  #used to check if both the stores are the same.
  def eql?(other)

    selfCTVarCount = @vars.select{|name,var| var.isCT}.length
    otherCTVarCount = other.vars.select{|name,var| var.isCT}.length

    return false if(selfCTVarCount != otherCTVarCount)

    varsEql = @vars.all?{|var| !var[1].isCT || var[1].eql?(other.find(var[1].name))}
    parentVarsEql = true
    if(@parent)
      parentVarsEql = @parent.eql?(other.parent)
    end
    return varsEql && parentVarsEql
  end
end