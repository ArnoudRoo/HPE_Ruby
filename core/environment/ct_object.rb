class CTObject
  attr_accessor :rawObject, :parent, :prolog, :path

  def initialize(rawObject, path = nil)
    @path = path
    if rawObject.kind_of?(Ruby::Node) && rawObject.respond_to?(:value)
      #case of an primitive type, still ripper object so use value
      @rawObject = rawObject.value
    elsif rawObject.class == CTObject
      #rawObject so take the raw value of the rawObject
      @rawObject = rawObject.rawObject
    else
      #normal ruby object or not primitive ripper object, can be saved directly
      @rawObject = rawObject
    end
  end

  # get the ripper value of the object
  def ctValue
    return @rawObject if (@rawObject.kind_of?(Ruby::Node))
    ctValue = Helpers.convertRubyToRipperObject(@rawObject)
    #ctValue.prolog = prolog if ctValue.respond_to?(:prolog)
    ctValue
  end

  def compileTime?
    true
  end

  def evaluate
    ctValue
  end

  def to_ruby(prolog=false)
    ctValue.to_ruby(prolog)
  end

  def pe(env)
    return self, self
  end

  def value
    ctValue.value
  end

#send a method call to the object
  def sendO(method, args, block, env = nil)
    if block
      #select all the vars in the block that are not params of the block.
      varsInBlock = block.select(Ruby::Variable).select { |var| !block.params.any? { |param| param.peIdentifier == var.peIdentifier } }
      varsInBlock << block.select(Ruby::Identifier).select { |var| !block.params.any? { |param| param.peIdentifier == var.peIdentifier } }
      varsInBlock = varsInBlock.flatten.compact.select { |var| !(var.class == Ruby::Identifier && var.parent.class == Ruby::Call) }
      #the changes hash will contain the modified vars after the block is executed. These will be placed back in the store.
      $changes = Hash.new
      #substitude the vars in the block with global variables. Changes to global variables can be tracked using race_var.
      #In this way the store can be updated after evaluation of the block.
      varsInBlock.each { |var|
        oldName = var.peIdentifier
        newName = "$#{var.peIdentifier}"
        #check if the var is in the store, if not it is a local block var which has no influence on the store.
        if (env.store.inStore?(oldName))
          raise "Used a rt var in a ct block" if !env.store.isCT(oldName)
          tempVal = env.store.astVal(oldName)
          #track changes to the variable in the changes hash.
          trace_var(newName) { |new| $changes[oldName] = new }
          if (tempVal.class == CTObject)
            eval(newName + "= tempVal.rawObject")
          else
            eval(newName + "=" + tempVal.to_ruby)
          end
        end
        #update the name of the var in the block to the global var name.
        var.peIdentifier = newName
      }

      #this var that is used for the result.
      tempResult = nil
      #the string to evaluate, this will assign the result of the bock to the tempResult. the target of the method call is @rawObject
      evalString = "tempResult = @rawObject." + method + block.to_ruby
      eval(evalString)
      #update the store with the changes made to the vars in the block.
      $changes.each { |varName, val|
        env.store.update(StoreVar.new(varName, CTObject.new(val), :compileTime))
      }
      return tempResult
    else
      #a non block call. just call the method on the object.
      ctArgs = args.map { |arg| arg.rawObject } if args
      return @rawObject.send(method, *ctArgs, &nil)
    end
  end

  def to_s
    @rawObject.to_s
  end

  def all_nodes
    ctValue
  end
end