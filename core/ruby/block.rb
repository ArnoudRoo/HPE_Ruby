require_relative '../ruby/statements'

module Ruby
  class Block < Statements
    child_accessor :params, :orgStore

    def initialize(statements, params = nil, ldelim = nil, rdelim = nil)
      self.params = params
      super(statements, ldelim, rdelim)
    end

    def nodes
      [ldelim, params, elements, rdelim].compact
    end

  end

  class NamedBlock < Block
    child_accessor :identifier

    def initialize(identifier, statements, params = nil, ldelim = nil, rdelim = nil)
      self.identifier = identifier
      super(statements, params, ldelim, rdelim)
    end

    def nodes
      [identifier, super].flatten(1).compact
    end

    #partial evaluate an if.
    #the inverted var is used for unless ifs.
    #the rt var is used to be sure the if is processed as a runtime if. This is used by elsif statements.
    def peIf(env, inverted, rt=false)

      #partial evaluate the expression. so we can check if the expression is compile time or runtime
      peExpExpResult, peExpValueResult = @expression.pe(env)

      if (Helpers.compileTime?(peExpValueResult))
        return handleCTIf(env, inverted, peExpValueResult, rt)
      else
        return handleRTIf(env, peExpExpResult)
      end
    end

    def peLoop(env)
      #try to get the range, if it is a var then check if it is in the store.

      peRangeExpResult, peRangeValueResult = @range.pe(env)
      @range = peRangeExpResult

      #check if the range is CT
      if (Helpers.compileTime?(peRangeValueResult))

        result = Ruby::Node::Composite::Array.new

        for elem in peRangeValueResult.rawObject
          ctLoopEnv = env.changeInCTLoop(true)
          loopVar = StoreVar.new(variable.token, CTObject.new(elem), :compileTime)
          ctLoopEnv.store.update(loopVar)
          clonedElements = self.elements.deep_copy
          result += clonedElements.pe(ctLoopEnv)[0]
          case ctLoopEnv.loopControl
            when "break"
              break
            when "next"
              next
            when "redo"
              redo
          end
        end
        return result, result.last
      else
        orgStore = env.store.deep_copy
        peElementsExpResult, peElementsValueResult = self.elements.pe(env)
        raise "There is a ct variable that is used as a rt variable in the while at line #{self.row+1}" if !orgStore.eql?(env.store)
        self.elements = peElementsExpResult
      end
      return self, :top
    end

    def peWhile(env, inverted)
      #check if the expression is compile time
      ct = Helpers.compileTime?(@expression.deep_copy.pe(env)[1])
      if (ct)
        #if compile time the loop can be unfolded
        result = Ruby::Node::Composite::Array.new
        while (@expression.deep_copy.pe(env)[0].evaluate.value && !inverted) || (!@expression.deep_copy.pe(env)[0].evaluate.value && inverted)
          ctLoopEnv = env.changeInCTLoop(true)
          result += @elements.deep_copy.pe(ctLoopEnv)[0]
          case ctLoopEnv.loopControl
            when "break"
              break
            when "next"
              next
            when "redo"
              redo
          end

        end
        return result, result.last
      else
        orgStore = env.store.deep_copy
        @expression = @expression.pe(env)[0]
        self.elements = @elements.pe(env)[0]
        raise "There is a ct variable that is used as a rt variable in the while at line #{self.row+1}" if !orgStore.eql?(env.store)
        return self, :top
      end
    end

    private

    def handleCTIf(env, inverted, peExpValueResult, rt = false)
      #if the expression is true and not inverted or false and inverted then remove the if and render code else remove if and the code
      if (peExpValueResult.rawObject && !inverted) || (!peExpValueResult.rawObject && inverted) then
        if (rt)
          @expression = Ruby::Statements.new()
          @expression.elements << Ruby::True.new("true")
          @expression.ldelim = Ruby::Token.new("(")
          @expression.rdelim = Ruby::Token.new(")")
          @elements = elements.pe(env)[0]
          @blocks = nil
          @rdelim = Ruby::Token.new("\nend")
          return self, :top
        else
          return elements.pe(env)
        end
      else
        # check if there are nested blocks, blocks can be elsif represented als If blocks or else blocks
        if (respond_to?(:blocks) && blocks[0])
          if (blocks[0].class == Ruby::Else)
            # because the condition of the if was false return the code in the else the else.
            if (rt)
              blocks[0].rdelim = Ruby::Token.new("\nend")
              return blocks[0].peIf(env,inverted,rt)
            else
              return blocks[0].elements.pe(env)
            end
          elsif (blocks[0].class == Ruby::If)
            # check if one of the next elsifs is true.
            return blocks[0].peIf(env, inverted, rt)
          end
        else
          #if there is no block (else or elsif) and the condition of the if wasn't true the if is removed from the residual code.
          s = nil
          if(rt)
            s = Ruby::Statements.new()
            s.rdelim = Ruby::Token.new("\nend")
          end
          return s, :top
        end
      end
    end

    def handleRTIf(env, peExpExpResult)
      #if the expression isn't ct then we can't determine which part needs to be executed so return the whole if statement
      #with the expression and the branches partial evaluated.

      #set the expression to the pe expression result
      @expression = peExpExpResult

      #remember the old loopcontrol
      oldLoopControl = env.loopControl

      #remember the original environment. This is used to partial evaluate the else branch if there is one.
      #if there is no else branch the store of the if needs to be the same as the original environment (cloned environment).
      #the else branches need to be partially evaluated with the same environment as the if branch.
      clonedEnv = env.deep_copy

      #pe the elements of the if block
      @elements = @elements.pe(env)[0]

      #raise an error when a break, next or redo statement is detected in the runtime if.
      raise "A break or next is found in a runtime if while the containing loop is compile time. At line #{self.row+1}" if (env.inCTLoop && oldLoopControl != env.loopControl)

      #if there is an else or elsif block
      if (self.respond_to? :blocks) && self.blocks[0]
        #pe the else branch with the original environment. if the block is an if then set the rt argument to true, this ensures that the if is processed as an rt if statement
        @blocks[0] = @blocks[0].class == Ruby::If ? @blocks[0].pe(clonedEnv, true)[0] : @blocks[0].pe(clonedEnv)[0]
      end
      #check if the stores are consistent.
      raise "Inconsistent store change. There is a ct variable that is used as a rt variable in the if at line #{self.row+1}" if !env.store.eql?(clonedEnv.store)

      return self, :top
    end


  end


  class ChainedBlock < NamedBlock
    child_accessor :blocks



    def initialize(identifier, blocks, statements, params = nil, ldelim = nil, rdelim = nil)
      self.blocks = Array(blocks) || []
      super(identifier, statements, params, ldelim, rdelim)
    end

    def nodes
      [identifier, params, ldelim, elements, blocks, rdelim].compact
    end
  end
end