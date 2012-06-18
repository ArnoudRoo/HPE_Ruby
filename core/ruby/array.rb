require_relative '../ruby/list'

module Ruby
  class Array < DelimitedList
    def value
      elements.map { |element| element.value }
    end

    def primitive?
      true
    end

    def pe(env)
      return self, self
    end

  end

  class Range < Aggregate
    child_accessor :left, :operator, :right

    def initialize(left, operator, right)
      self.left = left
      self.operator = operator
      self.right = right
    end

    def value
      operator.token == '..' ? (left.value..right.value) : (left.value...right.value)
    end

    def nodes
      [left, operator, right]
    end

    def primitive?
      true
    end

    def pe(env)
      @left = @left.pe(env)[0]
      @right = @right.pe(env)[0]

      if Helpers.primitive?(@left)
        cLeft = CTObject.new(@left)
        cLeft.prolog = @left.prolog
        @left = cLeft
      end

      if Helpers.primitive?(@right)
        cRight = CTObject.new(@right) if Helpers.primitive?(@right)
        cRight.prolog = @right.prolog
        @right = cRight
      end

      if (Helpers.compileTime?(@left) && Helpers.compileTime?(@right))
        return CTObject.new(self.value), CTObject.new(self.value)
      else
        return self, self
      end
    end

    def compileTime?
      false
    end
  end
end