class Helpers

  def self.selfIdentifier
    "@@@self"
  end

  def self.blockIdentifier
    "@@@block"
  end

  def self.instanceVar?(name)
    name.start_with?("@")
  end

  def self.containsCTArgs?(args)
    if (args.respond_to?(:any?))
      args.any? { |arg| Helpers.compileTime?(arg) }
    else
      false
    end
  end

  def self.staticMethod?(name)
    name[0] =~ /[A-Z]/
  end

  def self.allCompileTime?(args)
    return true if (!args)
    args.all? { |arg| Helpers.compileTime?(arg) }
  end

  def self.compileTime?(argument)
    argument.class == CTObject
  end

  def self.partialObject?(argument)
    argument.class == PartialObject
  end

  def self.primitive?(argument)
    argument.respond_to?(:primitive?) ? argument.primitive? : false
  end

  def self.getArgumentCompareString(orgName, arguments, poStore = nil)
    compareString = "#{orgName}_#{arguments ? arguments.count : 0}"
    arguments.select { |arg| Helpers.compileTime?(arg) }.each { |arg| compareString += Marshal.dump(arg) } if arguments
    poStore.vars.select { |name, var| var.isCT }.each { |name, var| compareString += Marshal.dump(var.val) } if (poStore)
    compareString
  end

  def self.onExclusionList?(methodName)
    exclusionList = ["return", "puts", "attr_accessor"]
    exclusionList.include? methodName
  end

  def self.getNameOfVarOrConst(x)
    if x.class == Ruby::Const
      return x.identifier.token
    else
      return x.token
    end
  end

  def self.convertRubyToRipperObject(rubyObject)
    return Helpers.createRipperStringFromRubyString(rubyObject) if (rubyObject.kind_of?(String))
    return Ruby::Nil.new("nil") if (rubyObject == nil)
    return Ripper::RubyBuilder.build("#{rubyObject}").elements[0]
  end

  def self.createRipperStringFromRubyString(rubyString)
    #a string is converted to a class by ripper2ruby. replace it with a string
    stringContent = Ruby::StringContent.new
    #escape the " chars in the original string
    stringContent.token = rubyString.gsub(/\"/, "\\\"")
    leftToken = Ruby::Token.new('"')
    rightToken = Ruby::Token.new('"')
    Ruby::String.new(stringContent, leftToken, rightToken)
  end

  @@unaryOps = Hash["+" => "+@", "-" => "-@"]

  def self.getOperator(operator, type)
    raise "Error wrong operator type" if (!(type == :binary || type == :unary))
    if (type == :unary)
      return @@unaryOps[operator] if @@unaryOps.include?(operator)
    end
    return operator
  end

   def self.getPathOfRubyObject(object)
     object.class.to_s.split("::")
   end

end