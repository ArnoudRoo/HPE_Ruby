require_relative '../ruby/aggregate'

module Ruby
  class PlaceHolder < Ruby::Token
  end

  class Const < DelimitedAggregate
    child_accessor :identifier, :namespace

    def peIdentifier
      @identifier.token
    end

    def peIdentifier=(value)
      @identifier.token = value
    end

    def initialize(token = nil, position = nil, prolog = nil, ldelim = nil)
      self.identifier = Ruby::Identifier.new(token, position, prolog)
      super(ldelim)
    end

    def compileTime?
      false
    end

    def position(*)
      super
    end

    def pe(env)
      peVarOrConst(env)
    end

    #loop through the call path to get the path as array. f.e. [A::B::C].new [A::B::C] makes ["A","B","C"]
    def getCallPath
      left = @namespace ? @namespace.getCallPath : []
      left + [identifier.token]
    end

    def nodes
      [namespace, ldelim, identifier].compact
    end
  end

  class Module < DelimitedAggregate
    child_accessor :const, :body

    def initialize(const, body, ldelim, rdelim)
      self.const = const
      self.body = body
      super(ldelim, rdelim)
    end

    def nodes
      [ldelim, const, body, rdelim].compact
    end

    def pe(env)
      $sharedStore.addSSObject(SModule.new(self), path)
      $sharedStore.addSSObject(self.body.pe(env)[0], path)
      return Ruby::PlaceHolder.new(self.const.identifier.token), false
    end

    def path
      @const.getPath
    end

  end

  class Class < NamedAggregate
    child_accessor :operator, :super_class, :body

    def initialize(const, operator, super_class, body, ldelim, rdelim)
      self.operator = operator
      self.super_class = super_class
      self.body = body
      super(const, ldelim, rdelim)
    end

    def nodes
      [ldelim, identifier, operator, super_class, body, rdelim].compact
    end

    def pe(env)
      superClass = @super_class ? @super_class.getCallPath : nil
      $sharedStore.addSSObject(SClass.new(self, path, superClass), path)
      $sharedStore.addSSObject(self.body.pe(env)[0], path)
      return Ruby::PlaceHolder.new(self.identifier.identifier.token), :top
    end

    def path
      identifier.getPath
    end
  end
end