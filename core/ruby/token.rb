require_relative '../ruby/node'

module Ruby
  class Token < Node
    include Conversions::Token

    attr_accessor :token, :position, :prolog

    def initialize(token = '', position = nil, prolog = nil)
      self.token = token
      self.position = position if position
      self.prolog = prolog || Prolog.new
    end

    alias :peIdentifier :token

    def position(prolog = false)
      (self.prolog.try(:position) if prolog) || @position
    end

    def position=(position)
      @position = position.dup if position
    end

    def to_s
      token.to_s
    end

    def compileTime?
      false
    end

    def pe(env)
      #default behavior of token is to return self.
      return self, self
    end

    def to_ruby(prolog = false)
      (prolog && self.prolog.try(:to_ruby, prolog) || '') + token.to_s
    end

  end

  class Whitespace < Token
    def empty?
      token.empty?
    end

    def inspect
      token.inspect
    end
  end

  class Keyword < Token
    def primitive?
      true
    end

    def peIdentifier
      @token.token
    end

    def pe(env)
      if(peIdentifier == "self")
        puts "haha"
        return self, env.store.astVal(Helpers.selfIdentifier)
      end
      super
    end
  end

  class HeredocBegin < Token
    attr_accessor :heredoc
    def primitive?
      true
    end
  end

  class Identifier < Token
    def primitive?
      true
    end

    alias :peIdentifier :token
    alias :peIdentifier= :token=
  end
end