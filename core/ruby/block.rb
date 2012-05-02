require_relative '../ruby/statements'

module Ruby
  class Block < Statements
    child_accessor :params

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
    def peIf(env, inverted)

      self.expression = self.expression.pe(env)
      #if the expression isn't ct then we can't determine which part needs to be executed so return the whole if statement
      #with the expression and the branches partial evaluated. assignments to vars that are marked as ct will be changed to runtime.
      if !self.expression.compileTime? || env.markAsRuntime #TODO check if nested ifs really need to be marked with mark as runtime

        orgEnv = env.deep_copy

        #pe the if block
        self.elements = self.elements.pe(env)

        #if there is an else block
        if self.blocks[0]
          elseEnv = orgEnv.deep_copy
          self.blocks[0] = self.blocks[0].pe(elseEnv)
          #if an else block is present the if and else store need to be the same
          raise "There is a ct variable that is used as a rt variable in the if at line #{self.row+1}" if !env.store.eql?(elseEnv.store)
        else
          #if there is no else block then the org store need to be the same as the if store
          raise "There is a ct variable that is used as a rt variable in the if at line #{self.row+1}" if !orgEnv.store.eql?(env.store)
        end


        return self
      else
        #expression is ct
        expResult = expression.evaluate

        #if the expression is true and not inverted or false and inverted then remove the if and render code else remove if and the code
        if (expResult.value && !inverted) || (!expResult.value && inverted) then
          return elements.pe(env)
        else
          # check if there are nested blocks, blocks can be elsif represented als If blocks or else blocks
          if (respond_to? :blocks)
            if (blocks[0].class == Ruby::Else)
              # because the condition of the if was false return the code in the else the else.
              return blocks[0].elements.pe(env)
            elsif (blocks[0].class == Ruby::If)
              # check if one of the next elsifs is true.
              return blocks[0].peIf(env, inverted)
            end
          else
            #if there is no block (else or elsif) and the condition of the if wasn't true the if is removed from the residual code.
            return nil
          end
        end
      end
    end

    def peLoop(env)
      #try to get the range, if it is a var then check if it is in the store.
      if (self.range.class == Ruby::Variable && env.store.isCT(range.token))
        rubyRange = env.store.astVal(range.token)
      elsif (range.class == Ruby::Range)
        rubyRange = range
      end

      #check if the range is CT
      if (rubyRange)

        result = Ruby::Node::Composite::Array.new

        for elem in rubyRange.value
          forStore = env.store
          ripperElem = convertRubyToRipperObject(elem)
          loopVar = StoreVar.new(variable.token, ripperElem, :compileTime)
          forStore.update(loopVar)
          clonedElements = self.elements.deep_copy
          result += clonedElements.pe(env.changeStore(forStore))
        end
        return result
      else
        self.elements = self.elements.pe(env.changeMR(true))
      end
      return self
    end

    def peWhile(env, inverted)
      #check if the expression is compile time
      ct = @expression.deep_copy.pe(env).compileTime?
      if (ct)
        #if compile time the loop can be unfolded
        result = Ruby::Node::Composite::Array.new
        while (@expression.deep_copy.pe(env).evaluate.value && !inverted) || (!@expression.deep_copy.pe(env).evaluate.value && inverted)
          result += @elements.deep_copy.pe(env)
        end
        return result
      else
        orgStore = env.store.deep_copy
        self.elements = @elements.pe(env)
        raise "There is a ct variable that is used as a rt variable in the while at line #{self.row+1}" if !orgStore.eql?(env.store)
        return self
      end
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