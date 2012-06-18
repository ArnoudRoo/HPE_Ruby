require_relative '../ruby/node'

module Ruby
  class StringConcat < List
  end

  class String < DelimitedList
    def initialize(contents = nil, ldelim = nil, rdelim = nil)
      super(contents, ldelim, rdelim)
    end

    def value
      map { |content| content.value }.join
    end

    def dynamic?
      !elements.inject(true) { |result, element| result && element.respond_to?(:value) }
    end

    def respond_to?(method)
      return false if method.to_sym == :value && dynamic?
      super
    end

    def primitive?
      self.elements.all? { |element| element.primitive? }
    end

    def compileTime?
      self.elements.all? { |element| element.compileTime? }
    end

    def pe(env)
      peValueResult = Ruby::StringContent.new()
      peValueResult.token = ""
      #pe all the nodes
      elements.map! { |node|
        if (node.respond_to? :pe)
          peExprResult, peValueResult = node.pe(env)
          #the result of an assignment isn't needed at this point.
          Helpers.compileTime?(peValueResult) ? peValueResult : peExprResult
        end
      }
      return self, peValueResult
    end

    def evaluate
      self
    end
  end

  class Heredoc < String
  end

  class StringContent < Token
    def primitive?
      true
    end

    def value
      token
    end

    def evaluate
      self
    end
  end

  class Regexp < String
  end

  class ExecutableString < String
  end
end