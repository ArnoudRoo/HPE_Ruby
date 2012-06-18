require_relative '../ruby/args'


module Ruby
  class Call < Aggregate
    attr_reader
    attr_writer
    child_accessor :identifier, :separator, :target, :arguments, :block

    alias :path :getPath

    def peIdentifier
      if (@identifier.respond_to?(:token))
        @identifier.token
      elsif (@identifier.respond_to?(:identifier) && @identifier.identifier.respond_to?(:token))
        @identifier.identifier.token
      else
        #array and hash indexers are not supported in a normal way using ripper to ruby
        return @arguments.ldelim.token + @arguments.rdelim.token
      end
    end

    def peIdentifier=(value)
      if (@identifier.respond_to?(:token))
        @identifier.token = value
      elsif (@identifier.respond_to?(:identifier))
        @identifier.identifier.token = value
      end
    end

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
      if (self.peIdentifier.include?("spec_"))
        #the method is already specialized
        return self, :top
      end


      if (self.block)
        @block.orgStore = env.store
      end

      if (Helpers.onExclusionList?(peIdentifier))
        #pe the arguments, changes @age in f.e. 12 if @age is compile time.
        @arguments = @arguments.pe(env)[0]
        return self, :top
      end

      case self.peIdentifier
        when "new" then
          #case of a constructor. create a partial object.
          partialObject = handleConstructorCall(env)
          return self, partialObject
        when "yield"
          block = env.store.find(Helpers.blockIdentifier).astVal
          blockStore = Store.new(env.store)
          blockStore.blockStore = block.orgStore
          for i in 0..block.params.elements.length-1
            name = block.params.elements[i].param.token
            value = @arguments.elements[i].pe(env)[1]
            value = Helpers.convertRubyToRipperObject(value.rawObject) if value.class == CTObject
            blockStore.update(StoreVar.new(name, value, :runtime))
          end
          block.pe(env.changeStore(blockStore))[0]
          self.identifier.token += " "
          return self, :top
        when "ct" then
          return handleCTCall(env)
        when "ctIf"
          handleCTConditional(env)
        when "isCT"
          return handleIsCT(env)
        when "rt" then
          #rt is used to mark an invoke of an method as a runtime invoke (the method doesn't need to be sepcialized)
          return handleRTCall(env)
        when "ext"
          #used to mark the result of a constructor or method as external
          @arguments.elements[0].arg.prolog = self.prolog
          #Added for array initializer f.e. ct([1,3,4])
          if (@arguments.elements[0].arg.class == Ruby::Call)
            @arguments.elements[0].arguments = self.arguments.elements[0].arguments.pe(env)[0]
          elsif (@arguments.elements[0].arg.class == Ruby::Variable)
            @arguments.elements[0].arg.external = true
          else
            @arguments.elements[0] = self.arguments[0].pe(env)[0]
          end
          return self.arguments.elements[0].arg, :external
        when "break", "next", "redo"
          return handleLoopControl(env)
        when "include", "extend"
          return handleIncludeAndExtend(env)
        else
          #pe all the arguments of the call and select them into args
          args = self.arguments.elements.map { |item|
            peArgExpResult, peArgValueResult = item.arg.pe(env)
            (Helpers.partialObject?(peArgValueResult) || Helpers.compileTime?(peArgValueResult)) ? peArgValueResult : peArgExpResult
          } if arguments


          #puts self.peIdentifier

          peTargetExpResult, peTargetValueResult = @target.pe(env)
          peTargetValueResult = env.store.astVal(Helpers.selfIdentifier) if peTargetValueResult == nil

          #check if it is a static call
          if (@target && Helpers.staticMethod?(@target.peIdentifier))
            return handleCallToStaticMethod(args, env)
          elsif (Helpers.compileTime?(peTargetValueResult))
            #call to compile time object
            #execute the call and return
            return handleCallToCTObject(args, peTargetValueResult, env)
          else
            #normal call
            #partial evaluate the target
            return handleCallToNonCTObject(args, env, peTargetExpResult, peTargetValueResult)
          end


      end
    end


    def handleCallToStaticMethod(args, env)
      if (Helpers.allCompileTime?(args))
        classObject = @target.getCallPath.inject(Kernel) { |scope, const_name| scope.const_get(const_name) }
        ctArgs = args.map { |arg| arg.rawObject } if args
        result = CTObject.new(classObject.send(peIdentifier, *ctArgs, &nil))
        return result, result
      else
        self.peIdentifier, peCallValueResult = $sharedStore.specializeCTCallWithRTArgs(peIdentifier, args, @target.getCallPath, true)
        deleteCTArgs(env)
        self.arguments = self.arguments.pe(env)[0] if self.arguments
        return self, peCallValueResult ? peCallValueResult : :top
      end

    end

    def compileTime?
      false
    end

    private

    def handleIncludeAndExtend(env)
      pathOfClass = path
      pathOfModule = @arguments.elements[0].arg.getCallPath
      incOrExt = self.peIdentifier
      $sharedStore.incOrExtClass(pathOfClass, pathOfModule, incOrExt)
      return self, :top
    end

    def handleCTConditional(env)
      resultExpr, resultValue = arguments[0].arg.pe(env)
      isCT = arguments[1].pe(env)[1]
      if (!isCT.value)
        self.arguments.elements[0].arg.prolog = self.prolog
        return self.arguments.elements[0].arg, :top
      else
        raise "not an ct value" if (!(Helpers.compileTime?(resultValue) || Helpers.primitive?(resultValue)))
        return CTObject.new(resultValue), CTObject.new(resultValue)
      end
    end

    def handleCTCall(env)
      #check if the enclosed statement is a constructor
      if (arguments.elements[0].arg.respond_to?(:identifier) && arguments.elements[0].arg.identifier.token == "new")
        #partialy evaluate the arguments of the compile time constructor. A::B.new(ct(1)) => A::B.new(1)
        peArgExpResult, peArgValueResult = arguments.elements[0].arg.arguments.pe(env)
        arguments.elements[0].arg.arguments = peArgExpResult
        #create code is the code that creates the object f.e. A::B.new
        createCode = arguments.elements[0].arg.to_ruby
        #create the object with normal evaluation
        object = Object.module_eval(createCode)

        path = arguments.elements[0].arg.target.getCallPath
        #return the newly created object as an CTObject.
        return CTObject.new(object, path), CTObject.new(object, path)
      else
        #if the enclosed statement wasn't a constructor pe the argument and save it in a CTObject.
        resultExpr, resultValue = arguments[0].arg.pe(env)


        raise "not an ct value" if (!(Helpers.compileTime?(resultValue) || Helpers.primitive?(resultValue)))
        return CTObject.new(resultValue), CTObject.new(resultValue)
      end
    end

    def handleIsCT(env)
      resultExpr, resultValue = arguments[0].arg.pe(env)
      isCT = Helpers.convertRubyToRipperObject(Helpers.compileTime?(resultValue))
      return isCT, isCT
    end

    def handleRTCall(env)
      self.arguments.elements[0].arg.prolog = self.prolog
      self.arguments.elements[0].arguments = self.arguments.elements[0].arguments.pe(env)[0]
      return self.arguments.elements[0].arg, :top
    end

    def handleLoopControl(env)
      if (env.inCTLoop)
        env.loopControl = self.peIdentifier
        return self, :top
      else
        return self, :top
      end
    end


    def handleCallToCTObject(args, targetObject, env)
      if (Helpers.allCompileTime?(args)) #if all compile time evaluate the call.
        result = CTObject.new(targetObject.sendO(self.peIdentifier, args, self.block, env))
        return result, result
      else #Contains rt args, create a static method
        self.target = nil
        #starth with the class name. class methods always start with the module and class name.
        self.separator = Ruby::Token.new(" #{targetObject.rawObject.class}.")
        #partial evaluate the method. the targetObject is used as the self var while specializing.
        self.peIdentifier, peCallValueResult = $sharedStore.specializeCTCallWithRTArgs(peIdentifier, args, targetObject)
        #partial evaluate the left over arguments.
        deleteCTArgs(env)
        self.arguments = self.arguments.pe(env)[0] if self.arguments
        return self, peCallValueResult ? peCallValueResult : :top
      end
    end

    def handleCallToNonCTObject(args, env, peTargetExpResult, peTargetValueResult)
      @target = peTargetExpResult

      if (peTargetValueResult.class == PartialObject)
        #call to partial object
        self.identifier.token, specialized, peCallValueResult = peTargetValueResult.specialize(self.peIdentifier, args, self.block)
      elsif (peTargetValueResult == :kernel)
        self.peIdentifier, specialized, peCallValueResult = $sharedStore.specializeKernelMethod(self.peIdentifier, args, env.store)
      elsif (peTargetValueResult == :external || peTargetValueResult.respond_to?(:external) && peTargetValueResult.external)
        @arguments = @arguments.pe(env)[0] if @arguments
        @block = @block.pe(env)[0] if @block
        return self, :external
      else
        #specialize all the methods with the specified name
        #replace the name of the method to call with the name of the specialized method.
        self.peIdentifier, specialized = $sharedStore.specializeAll(self.peIdentifier, args, env.store, block)
      end

      #delete the compile time arguments if the method was specialized.
      if (specialized)
        deleteCTArgs(env)
      end

      #partial evaluate the left over arguments.
      self.arguments = self.arguments.pe(env)[0] if self.arguments
      return self, peCallValueResult ? peCallValueResult : :top
    end

    def handleConstructorCall(env)
      #pe all the arguments of the constructor and select them into args
      args = self.arguments.elements.map { |item| item.arg.pe(env)[0] } if arguments


      classPath = @target.getCallPath

      #replace the class name with the name that is returned by the specializer.
      @target.peIdentifier, specialized, partialObject = $sharedStore.specializeConstructor(classPath, args, env.store)

      #delete the compile time arguments if the method was specialized.
      if (specialized)
        deleteCTArgs(env)
      end

      #partial evaluate the left over arguments.
      self.arguments = self.arguments.pe(env)[0] if self.arguments
      partialObject
    end


    def deleteCTArgs(env)
      self.arguments.elements = self.arguments.elements.select { |item| !Helpers.compileTime?(item.arg.pe(env)[1]) } if arguments

      #if the first argument was a CT argument it gets deleted and the arguments 1, 2 ... contain a "," in the prolog. Remove the ","
      if (self.arguments && self.arguments.elements[0] && self.arguments.elements[0].prolog.elements[0] && self.arguments.elements[0].prolog.elements[0].token == ",")
        self.arguments.elements[0].prolog.elements[0].token = ""
      end
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