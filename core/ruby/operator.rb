require_relative '../ruby/node'

module Ruby
  class Operator < DelimitedAggregate
  end

  class Unary < Operator
    child_accessor :operator, :operand

    def initialize(operator, operand, ldelim, rdelim)
      self.operator = operator or raise "operator can not be nil"
      self.operand = operand
      super(ldelim, rdelim)
    end

    def nodes
      [operator, ldelim, operand, rdelim].compact
    end

    def pe(env)

      self.operand = operand.compileTime? ? operand.evaluate : self.operand.pe(env)
      self
    end
  end

  class Binary < Operator
    child_accessor :operator, :left, :right

    def initialize(operator, left, right)
      self.operator = operator or raise "operator can not be nil"
      self.left = left
      self.right = right
    end

    def pe(env)

      #the old prolog is used to get the right whitspace in front of the left and right hand
      oldLeftProlog = left.prolog
      oldRightProlog = right.prolog

      #added for +=. if the left hand is an identifier this means that it is an variable and the += operator is used.
      #the right hand is always a var if it is used (doesn't need to be looked up in the store).
      self.left = env.store.astVal(self.left.token) if self.left.class == Ruby::Identifier

      #if the left or right hand is compile time then evaluate the code else partial evaluate the code.
      self.left = left.compileTime? ? left.evaluate : left.pe(env)
      self.right = right.compileTime? ? right.evaluate : right.pe(env)

      left.prolog = oldLeftProlog if left.prolog
      right.prolog = oldRightProlog if right.prolog

      #if both the left and right hand are compile time the total binary operation can be evaluated.
      #if one or both are runtime return the partial evaluated binary operation.
      (self.right.compileTime? && self.left.compileTime?) ? evaluate : self
    end

    def nodes
      [left, operator, right].compact
    end
  end

  class IfOp < Operator
    child_accessor :condition, :left, :right, :operators

    def initialize(condition, left, right, operators)
      self.condition = condition
      self.left = left
      self.right = right
      self.operators = operators
    end

    def nodes
      [[condition, left, right].zip(operators)].compact
    end
  end
end