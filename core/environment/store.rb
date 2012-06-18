class Store
  attr_accessor :parentStore, :blockStore
  #the blockstore is used while pe a block. the blockstore contains the vars of the calling environment.

  def initialize(parentStore = nil)
    raise TypeError, "The parent store must also be of the type Store" if parentStore != nil && parentStore.class != Store
    @parentStore = parentStore
    @vars = {}
  end

  # this function returns the store without the parent stores.
  # this is used by pe classes. the parent contains fields that are introduced through the constructor, and not the arguments to the constructor.
  def top
    copy = self.deep_copy
    copy.parent = nil
    copy
  end

  #this method deletes all the variables that are in the store and that are no fields, not starting with an @ sign
  def removeNonFields
    @vars.delete_if {|name, value| !name.start_with?("@") }
    @parentStore.removeNonFields if @parentStore
  end

  def update(var)
    raise TypeError, "The specified var is not of the type StoreVar" if var.class != StoreVar
    if (inStore? var.name)
      find(var.name).astVal = var.astVal
    else
      @vars[var.name] = var
    end
  end

  def find(name)
    return blockStore.find(name) if blockStore && blockStore.inStore?(name)
    return @vars[name] if inStore?(name, false)
    return @parentStore.find(name) if @parentStore != nil
  end

  def inStore?(name, includeParent=true)
    return (@vars[name].class == StoreVar || (blockStore && blockStore.inStore?(name,includeParent))) if !includeParent
    return find(name).class == StoreVar if (includeParent)
  end

  def throwIfVarNotInStore(name)
    raise "There was no var with name #{name} in the store." if !inStore?(name)
  end

  def setState(name, state, throwOnNotInStore=true)
    return if (!inStore?(name) && !throwOnNotInStore)
    throwIfVarNotInStore(name)
    find(name).state = state
  end



  def isCT(name, throwOnNotInStore=true)
    throwIfVarNotInStore(name) if throwOnNotInStore
    return false if !(inStore? name)
    find(name).isCT
  end

  def isPO(name, throwOnNotInStore=true)
    throwIfVarNotInStore(name) if throwOnNotInStore
    return false if !(inStore? name)
    find(name).isPO
  end

  def astVal(name)
    throwIfVarNotInStore(name)
    find(name).astVal
  end

  def state(name)
    return find(name).state if inStore?(name)
    return :nil
  end


  def vars
    return @vars
  end

  def allVars
    allVars = []
    allVars = @parentStore.allVars if(@parentStore)
    allVars += @vars.values
    return allVars
  end

  #used to check if both the stores are the same.
  def eql?(other)
    selfCTVarCount = allVars.select{|var| var.isCT || var.isPO}.length
    otherCTVarCount = other.allVars.select{|var| var.isCT || var.isPO}.length
    return false if(selfCTVarCount != otherCTVarCount)
    allVars.all?{|var| var.eql?(other.find(var.name))}
  end
end