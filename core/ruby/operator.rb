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

      peOperandExpResult, peOperandValueResult = @operand.pe(env)
      @operand = peOperandExpResult
      if (Helpers.compileTime?(peOperandValueResult))
        #execute the unary operator. The getOperator is used to get the right operator. Ripper gives back the same operator for unary and binary operators.
        #for example the + operator, ripper gives + for binary as well as unary. getOperator converts + to +@ for a unary operator.
        result = @operand.sendO(Helpers.getOperator(operator.token, :unary), [], nil)
        return CTObject.new(result), CTObject.new(result)
      else
        return self, :top
      end

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

      #the old prolog is used to get the right whitespace in front of the left and right hand
      oldLeftProlog = left.prolog
      oldRightProlog = right.prolog

      #added for +=. if the left hand is an identifier this means that it is an variable and the += operator is used.
      #the right hand is always a var if it is used (doesn't need to be looked up in the store).
      @left = env.store.astVal(@left.peIdentifier) if (@left.class == Ruby::Identifier)

      leftExpResult, leftValueResult = @left.pe(env)
      rightExpResult, rightValueResult = @right.pe(env)

      #if left or right is ct and the other is primitive convert the primitive to a ct object.
      if (Helpers.compileTime?(rightValueResult) || Helpers.compileTime?(leftValueResult))
        leftValueResult = CTObject.new(leftValueResult) if Helpers.primitive?(leftValueResult)
        rightValueResult = CTObject.new(rightValueResult) if Helpers.primitive?(rightValueResult)
      end

      #if the left or right hand is compile time then evaluate the code else partial evaluate the code.
      @left = leftExpResult
      @right = rightExpResult

      left.prolog = oldLeftProlog if left.respond_to?(:prolog)
      right.prolog = oldRightProlog if right.respond_to?(:prolog)

      #if both the left and right hand are compile time the total binary operation can be evaluated.
      #if one or both are runtime return the partial evaluated binary operation.
      if (Helpers.compileTime?(rightValueResult) && Helpers.compileTime?(leftValueResult))
        result = leftValueResult.sendO(@operator.token, [rightValueResult], nil)
        #added << for arrays
        return operator.token == "<<" ? nil : CTObject.new(result), CTObject.new(result)
      elsif(Helpers.partialObject?(leftValueResult))
        argList = Ruby::ArgsList.new()
        argList << Ruby::Arg.new(@left)
        return Ruby::Call.new(@right,Ruby::Token.new("."), self.operator,argList, nil ).pe(env)
      else
        return self, :top
      end

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