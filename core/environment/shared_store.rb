module SpecializeMethod


  def specializeMethod(unspecializedName, specializedName, arguments, store)

    methods = @methods.find_all { |method| method.identifier == unspecializedName }
    methods.each { |method| method.specialize(specializedName, arguments, store) }

    @modules.each { |item| item.specializeMethod(unspecializedName, specializedName, arguments, store) } if (defined? modules)
    @classes.each { |item| item.specializeMethod(unspecializedName, specializedName, arguments, store) } if (defined? classes)

  end


end

module AddModule
  def addModule(moduleToAdd, path = nil)
    path = moduleToAdd.getPath if (path == nil)

    if (path.length == 1)
      @modules << SModule.new(moduleToAdd, "module") if !(@modules.find_all { |item| item.identifier == path[0] }.any?)
    else
      match = @modules.find_all { |item| item.identifier == path[0] }
      if (match.any?)
        match[0].addModule(moduleToAdd, path[1..-1])
      else
        raise "Module #{moduleToAdd.const.identifier.token} could not be found"
      end
    end
  end
end

module AddClass
  def addClass(classToAdd, path = nil)
    path = classToAdd.getPath if (path == nil)

    if (path.length == 1)
      @classes << SClass.new(classToAdd) if !@classes.find_all { |item| item.identifier == path[0] }.any?
    else
      match = @modules.find_all { |item| item.identifier == path[0] }
      if (match.any?)
        match[0].addClass(classToAdd, path[1..-1])
      else
        raise "Module #{path[0]} could not be found"
      end
    end
  end
end

module AddMethod
  def addMethod(methodToAdd, path = nil)
    path = methodToAdd.getPath if path == nil

    if (path.length == 0)
      @methods << SMethod.new(methodToAdd)
    else
      matchMod = @modules.find_all { |item| item.identifier == path[0] }
      matchClass = @classes.find_all { |item| item.identifier == path[0] }
      if (matchMod.any?)
        matchMod[0].addMethod(methodToAdd, path[1..-1])
      elsif (matchClass.any?)
        matchClass[0].addMethod(methodToAdd, path[1..-1])
      else
        raise "Module #{path[0]} could not be found"
      end
    end
  end
end

require_relative 's_module'
require_relative 's_class'
require_relative 's_method'

class SharedStore
  include AddModule
  include AddClass
  include AddMethod
  include SpecializeMethod

  def initialize
    @classes = []
    @modules = []
    @methods = []
    @specializedACSS = Hash.new
  end


  def previousSpecialized?(acs)
    return @specializedACSS[acs]
  end

  def specName(orgName, acs)
    if (previousSpecialized?(acs))
      return @specializedACSS[acs]
    else
      $specializedMethodCount +=1
      return "#{orgName}_spec_#{$specializedMethodCount.to_s}"
    end
  end

  def addACS(specName, acs)
    @specializedACSS[acs] = specName
  end

  def specialize(name, arguments, store)

    #check if specialization is needed
    if (Helpers.onExclusionList?(name) || !Helpers.containsCTArgs?(arguments, store))
      return name, false
    end


    acs = Helpers.getArgumentCompareString(name, arguments, store)
    newName = specName(name, acs)


    if (!previousSpecialized?(acs))
      addACS(newName, acs)
      specializeMethod(name, newName, arguments, store)
    end


    return newName, true
  end


  def classes
    @classes
  end

  def modules
    @modules
  end

  def to_ruby
    (@classes.map { |item| item.to_ruby } + @modules.map { |item| item.to_ruby } + @methods.map { |item| item.to_ruby }).join
  end
end