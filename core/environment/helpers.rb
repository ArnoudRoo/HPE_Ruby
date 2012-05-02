class Helpers
  def self.containsCTArgs?(args, store)

    return false if !args
    args.any? { |arg| Helpers.compileTime?(arg, store)
    }

  end

  def self.compileTime?(argument, store)
    if argument.class == Ruby::Const
      store.isCT(argument.getNameOfVarOrConst(argument))
    else
      argument.compileTime?
    end
  end

  def self.getArgumentCompareString(orgName, arguments, store)

    compareString = "#{orgName}_#{arguments.count}"

    arguments.each { |arg|
      if (Helpers.compileTime?(arg, store))
        if (arg.class == Ruby::Const)
          compareString += store.val(arg.getNameOfVarOrConst(arg)).to_s
        else
          if (defined? arg.elements)
            compareString += arg.elements.to_s
          else
            compareString += arg.to_s
          end
        end
      end
    }

    compareString
  end

  def self.onExclusionList?(methodName)
    case methodName
      when "return", "puts"
        return true
    end
    return false
  end
end