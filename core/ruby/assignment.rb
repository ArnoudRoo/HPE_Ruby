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
      store.isCT(getNameOfVarOrConst(left), false)
    end

    def pe(env)
      peRight = self.right.pe(env)

      #if the assignment is done in an if branch that has no CT expression the var needs to be marked as runtime, from this point on we can't know the right value
      env.store.setState(left.token, :runtime, false) if env.markAsRuntime

      #get the name of the variable or constant to set.
      varName = getNameOfVarOrConst(left)


      #get var type from store
      case env.store.state(varName)
        when :compileTime
          #check expression (right hand) is also CT
          if peRight.compileTime?
            val = peRight
            # check if not = operator, if it is not an = operator it is an +=, -=, etc operator.
            if (self.operator.token != '=')
              # compute the value after the operator calculation
              val = execWithOperator(env)
            end
            #replace var in store with new value
            env.store.update(StoreVar.new(varName, val, :compileTime))
            return self #compile time vars get deleted from the residual code in the parent.
          else
            raise "The var #{varName} was compile time and the code tried to assign a not compile time value to it."
          end
        when :runtime
          #Assign PE result of right hand to itself and return the pe code.
          self.right = peRight
          return self
        when :nil
          #the var isn't known at this point
          isConstant = left.class == Ruby::Const
          #check if the right and is not compile time or the left hand is a constant. If this is the case it is an runtime var.
          if (isConstant || !peRight.compileTime?)
            self.right = peRight
            env.store.update StoreVar.new(varName, peRight, :runtime)
            return self
          else
            env.store.update StoreVar.new(varName, peRight, :compileTime)
            return self  #compile time vars get deleted from the residual code in the parent.
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
