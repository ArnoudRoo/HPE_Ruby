class StoreVar
  def initialize(name, astVal, state)
    @name = name
    @astVal = astVal
    raise TypeError, "the type must be runtime or compileTime" if (state != :runtime && state != :compileTime)
    @state = state
    @type = nil
  end

  def isCT
    @state == :compileTime
  end

  def state=(state)
    raise TypeError, "the type must be runtime or compileTime" if (state != :runtime && state != :compileTime)
    @state = state
  end

  def type=(type)
    @type = type
  end

  def name
    @name
  end

  def name=(name)
    @name = name
  end

  def state
    @state
  end

  def type
    @type
  end

  def astVal=(astVal)
    @astVal = astVal
  end

  def val
    if self.respond_to? :to_ruby
      eval(to_ruby)
    else
      eval(@astVal.to_ruby)
    end
  end

  def astVal
    @astVal
  end

  def asAssignment
    varNameToken = Ruby::Token.new(name)
    Ruby::Assignment.new(varNameToken, astVal, Ruby::Token.new("="))
  end

  def eql?(other)
    #todo change code so complex objects are also supported
    val.eql?(other.val)
  end
end