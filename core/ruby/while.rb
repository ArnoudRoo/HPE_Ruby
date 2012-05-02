require_relative '../ruby/node'

module Ruby
  class While < NamedBlock
    child_accessor :expression

    def initialize(identifier, expression, statements, ldelim = nil, rdelim = nil)
      self.expression = expression
      super(identifier, statements, nil, ldelim, rdelim)
    end

    def nodes
      [identifier, expression, ldelim, elements, rdelim].compact
    end

    def pe(env)
      peWhile(env, false)
    end
  end

  class WhileMod < NamedBlock
    child_accessor :expression

    def initialize(identifier, expression, statements)
      self.expression = expression
      super(identifier, statements)
    end

    def nodes
      [elements, identifier, expression].compact
    end

    def pe(env)
      peWhile(env, false)
    end
  end

  class Until < While;
    def pe(env)
      peWhile(env, true)
    end
  end
  class UntilMod < WhileMod;
    def pe(env)
      peWhile(env, true)
    end
  end
end