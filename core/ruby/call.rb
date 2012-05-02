require_relative '../ruby/args'

module Ruby
  class Call < Aggregate
    child_accessor :identifier, :separator, :target, :arguments, :block

    def initialize(target, separator, identifier, arguments = nil, block = nil)
      self.target = target
      self.separator = separator
      self.identifier = identifier
      self.arguments = arguments
      self.block = block
    end

    def token
      identifier.token
    end

    def nodes
      [target, separator, identifier, arguments, block].compact
    end

    def pe(env)
      #TODO: check if proc
      self.block = self.block.pe(env)

      case identifier.token
        when "ct" then
          #the var to make static.
          var = arguments[0].arg.token
          #mark the var as compile time in the store.
          env.store.setState(var, :compileTime)
          #remove the CT method call from the ast so it doesn't exist in the residual code.
          return nil
        when "mt" then
          #add a type to the given var. argument 1 = var, argument 2 = type ([{module1},{module2},{module..},{class}])
          env.store.setType(arguments[0].arg.token, arguments[1].arg.value)
        when "rt" then
          #rt is used to mark an invoke of an method as a runtime invoke (the method doesn't need to be sepcialized)
          self.arguments.elements[0].arg.prolog = self.prolog
          return self.arguments.elements[0].arg
        else
          #normal call
          #partial evaluate the target
          self.target = self.target.pe(env)

          #pe all the arguments of the call and select them into args
          args = self.arguments.elements.map { |item| item.arg.pe(env) } if arguments

          #replace the name of the method to call with the name of the specialized method.
          self.identifier.token, specialized = $sharedStore.specialize(self.identifier.token, args, env.store)

          #delete the compile time arguments if the method was specialized.
          if (specialized)
            self.arguments.elements = self.arguments.elements.select { |item| !item.arg.pe(env).compileTime? } if arguments
          end

          #if the first argument was a CT argument it gets deleted and the arguments 1, 2 ... contain a "," in the prolog. Remove the ","
          if (self.arguments && self.arguments.elements[0] && self.arguments.elements[0].prolog.elements[0] && self.arguments.elements[0].prolog.elements[0].token == ",")
            self.arguments.elements[0].prolog.elements[0].token = ""
          end

          #partial evaluate the left over arguments.
          self.arguments = self.arguments.pe(env)
          return self
      end
    end


    def compileTime?
      #TODO: Check if this call has no side effects and all its arguments are compile time.
      #If this is the case the method can be done at pe time.
      false
    end
  end

  class Alias < Call
    def initialize(identifier, arguments)
      self.identifier = identifier
      self.arguments = arguments
    end

    def nodes
      [identifier, arguments]
    end
  end
end