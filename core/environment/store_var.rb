class StoreVar
  def initialize(name, astVal, state)
    throwIfWrongState(state)
    @name = name
    @astVal = astVal
    @state = state
    @type = nil
  end

  def isCT
    @state == :compileTime
  end

  def isPO
    @state == :partial
  end

  def state=(state)
    throwIfWrongState(state)
    @state = state
  end

  def name
    @name
  end

  def state
    @state
  end

  def astVal=(astVal)
    @astVal = astVal
  end

  def val
    eval(@astVal.to_ruby)
  end

  def astVal
    @astVal
  end

  #the eql function is used when 2 stores are compared to each other.
  def eql?(other)
    if (astVal.class == CTObject)
      data = Marshal.dump(astVal.rawObject)
      dataOther = Marshal.dump(other.astVal.rawObject)
      return data.eql?(dataOther)
    elsif(astVal.class == PartialObject && self.name != Helpers.selfIdentifier)
      #check only the compile time vars in the store of the partial object.
      astVal.store.eql?(other.astVal.store)
    else
      true
    end
  end

  private
  def throwIfWrongState(state)
    raise TypeError, "the type must be runtime, compileTime or partial" if (state != :runtime && state != :compileTime && state != :partial && state != :external)
  end
end