require_relative '../ruby/node'

module Ruby
  class If < ChainedBlock
    child_accessor :expression

    def initialize(identifier, expression, statements = nil, ldelim = nil, rdelim = nil, else_block = nil)
      self.expression = expression
      super(identifier, [else_block], statements, nil, ldelim, rdelim)
    end

    def nodes
      [identifier, expression, ldelim, elements, blocks, rdelim].compact
    end

    def pe(env)
      peIf(env, false)
    end
  end

  class Unless < If
    def pe(env)
      peIf(env, true)
    end
  end
  class Else < NamedBlock;
  end

  class IfMod < NamedBlock
    child_accessor :expression

    def initialize(identifier, expression, statements)
      self.expression = expression
      super(identifier, statements)
    end

    def pe(env)
      peIf(env,false)
    end

    def nodes
      [elements, identifier, expression].compact
    end
  end

  class UnlessMod < IfMod
    def pe(env)
      peIf(env, true)
    end
  end
  class RescueMod < IfMod;
  end
end