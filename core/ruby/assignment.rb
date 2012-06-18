require_relative '../ruby/node'

module Ruby
  class Assignment < Aggregate
    child_accessor :left, :right, :operator

    def initialize(left, right, operator)
      self.left = left
      self.right = right
      self.operator = operator
    end

    def nodes
      [left, operator, right].compact
    end

    #check if the left side of the assignment is compile time.
    #if this is the case the assignment can be removed from the residual code.
    def ctAssignment?(store)
      store.isCT(Helpers.getNameOfVarOrConst(left), false)
    end

    def pe(env)

      # in case of person.name = "bla" then name= is a method on the person object. so handle it like a method
      if (left.class == Ruby::Call)
        #add the operator to the identifier, example person.age becomes person.age= if the = operator is used.
        if (!left.arguments || left.arguments.length == 0)
          left.identifier.token += operator.token
          arg = Ruby::Arg.new(right.respond_to?(:elements) ? right.elements[0] : right)
          left.arguments = Ruby::ArgsList.new(arg)
          return left.pe(env)
        end
        left.target = left.target.pe(env)[0]
        left.arguments = left.arguments.pe(env)[0]
      end

      orgRight = @right.deep_copy
      rightPEExprResult, rightPEValueResult = @right.pe(env)

      #get the name of the variable or constant to set.
      varName = left.peIdentifier

      #check if assignment is done in a ct object, if so the right hand side must be ct if left is a instance var
      if (Helpers.instanceVar?(varName) && env.store.isCT(Helpers.selfIdentifier))
        raise "The var #{varName} was compile time and the code tried to assign a runtime value to it at line #{row+1}."
      end
      #get var type from store
      varState = env.store.state(varName)
      if (varState == :compileTime)
        #check expression (right hand) is also CT, if not throw an error
        if (!Helpers.compileTime?(rightPEValueResult))
          raise "The var #{varName} was compile time and the code tried to assign a runtime value to it at line #{row+1}."
        end

        # check if not = operator, if it is not an = operator it is an +=, -=, etc operator. Evaluation is needed for that operator
        if (self.operator.token != '=')
          @right = orgRight
          # compute the value after the operator calculation
          rightPEExprResult, rightPEValueResult = execWithOperator(env)
        end

        #replace var in store with new value
        env.store.update(StoreVar.new(varName, rightPEValueResult, :compileTime))
        return rightPEExprResult, rightPEValueResult
      elsif (varState == :runtime || varState == :external || left.class == Ruby::Call)  #left.class == Ruby::Call is added for 2 dimensional arrays.
        raise "Assignment to runtime var with non primitive compile time value at row #{row+1}" if (Helpers.compileTime?(rightPEValueResult) && !Helpers.primitive?(rightPEValueResult))
        #Assign PE result of right hand to itself and return the pe code.
        self.right = Helpers.compileTime?(rightPEValueResult) ? rightPEValueResult : rightPEExprResult
        return self, :top
      elsif (varState == :nil)
        #check if the right hand is not compile time
        if (Helpers.compileTime?(rightPEValueResult))
          env.store.update StoreVar.new(varName, rightPEValueResult, :compileTime)
          return rightPEExprResult, rightPEValueResult
        else
          self.right = rightPEExprResult
          env.store.update(StoreVar.new(varName, rightPEValueResult, rightPEValueResult == :external ? :external : :runtime))
          return self, :top
        end
      end
    end

    # this method is used to execute assignment calculations like +=, **=, *=, etc.
    def execWithOperator(env)
      operatorToken = Ruby::Token.new(self.operator.token[/(.*)=/, 1])
      binaryExpression = Ruby::Binary.new(operatorToken, self.left, self.right)
      #return the partial evaluation result of the newly created binary expression.
      binaryExpression.pe(env)
    end

  end


  class MultiAssignment < DelimitedList
    attr_accessor :kind
    child_accessor :splat

    def initialize(kind, elements = [], ldelim = nil, rdelim = nil, splat = nil)
      self.kind = kind
      self.splat = splat
      super(elements, ldelim, rdelim)
    end

    def nodes
      [ldelim, splat, elements, rdelim].compact
    end
  end
end
