require_relative 'base_s_object'
require_relative 's_class'
require_relative 's_method'
require_relative 's_module'

class SharedStore < BaseSSObject
  attr_accessor :partialObjects, :orgPath

  def initialize
    super()
    @specializedACSS = Hash.new
    @partialObjects = []
    @orgPath = nil
  end

  def previousSpecialized?(acs)
    return @specializedACSS[acs]
  end

  def specName(orgName, acs)
    if (previousSpecialized?(acs))
      return @specializedACSS[acs]
    else
      $specializedMethodCount += 1
      newName ="#{orgName[0]}spec_#{$specializedMethodCount}_#{orgName}"
      newName.gsub!(/\=|\*|\[|\]|\-/, '')
      newName
    end
  end

  def addACS(specName, acs)
    @specializedACSS[acs] = specName
  end

  def specializeAll(name, arguments, store, block)
    return name, false if (name == "[]")
    acs = Helpers.getArgumentCompareString(name, arguments, store)
    newName = specName(name, acs)

    #try to specialize all the methods of the po objects. if inconsistent store changes are done, an error is raised.
    @partialObjects.each { |po| po.specializeAndCheckStore(name, newName, arguments, block) }

    if (!previousSpecialized?(acs))
      addACS(newName, acs)
      specializeAllMethods(name, newName, arguments, block)
    end
    return newName, true
  end

  def specializeConstructor(path, arguments, store)
    acs = Helpers.getArgumentCompareString(path, arguments, store)
    newName = specName(path.last, acs)
    if (!previousSpecialized?(acs))
      addACS(newName, acs)
      classToSpecialize = specializeClass(path, newName, arguments, acs)
    else
      classToSpecialize = getSpecializedClass(path, acs)[0]
    end

    po = PartialObject.new(classToSpecialize, arguments)
    @partialObjects << po
    return newName, true, po
  end

  def specializeKernelMethod(name, args, store)
    acs = Helpers.getArgumentCompareString(name, args, store)
    newName = specName(name, acs)

    if (!previousSpecialized?(acs))
      addACS(newName, acs)
      methodToSpecialize = @elements.select { |method| method.class == SMethod && method.identifier == name }.last
      peBodyValueResult = methodToSpecialize.specialize(newName, args, store)
      return newName, true, peBodyValueResult
    end

    return newName, true, :top
  end

  #function is also used for specialization static method calls with rt arguments.
  def specializeCTCallWithRTArgs(name, args, selfObject, staticCall = false)
    store = Store.new
    store.update(StoreVar.new(Helpers.selfIdentifier, selfObject, :compileTime)) if selfObject.class == CTObject

    acsData = ""
    selfObject.rawObject.instance_variables.each { |var|
      object = selfObject.rawObject.instance_variable_get(var)
      store.update(StoreVar.new(var.to_s, CTObject.new(object, Helpers.getPathOfRubyObject(object)), :compileTime))
      acsData += Marshal.dump(object)
    } if selfObject.class == CTObject


    #the path is stored in the CTObject class if the ct object is created through ct(Class1.new(...))
    path = selfObject.class == CTObject ? Helpers.getPathOfRubyObject(selfObject.rawObject).join : selfObject.join
    pathArray = selfObject.class == CTObject ? Helpers.getPathOfRubyObject(selfObject.rawObject) : selfObject

    acsString = name + path + acsData
    #create new name and argument compare string.
    acs = Helpers.getArgumentCompareString(acsString, args)
    newName = specName(name, acs)

    if (!previousSpecialized?(acs))
      addACS(newName, acs)
      classOfMethod = getElements(pathArray).last
      methodToSpecialize = classOfMethod.elements.select { |method| method.class == SMethod && method.identifier == name }.last
      nameWithSelfPrefix = staticCall ? newName : "self.#{newName}"
      peBodyValueResult = methodToSpecialize.specialize(nameWithSelfPrefix, args, nil, store)
      return newName, true, peBodyValueResult
    end
    return newName, peBodyValueResult
  end

  def incOrExtClass(classPath, modulePath, incOrExt)
    classToAddMethodsTo = getElements(classPath)
    classToAddMethodsTo += @partialObjects.select { |po| po.sClass.orgPath == classPath }.map { |po| po.sClass }

    moduleToAdd = getElements(modulePath)
    if (incOrExt == "include")
      classToAddMethodsTo.each { |tClass| tClass.inclusions << modulePath }
      moduleToAdd.each { |tMod| tMod.elements.select { |elem| elem.class == SMethod }.each { |method| $sharedStore.addSSObject(method, classPath) } }
    elsif (incOrExt == "extend")
      raise "module extensions are not supported by the partial evaluator"
    end
  end

  def to_ruby(filter = nil)
    replacePlaceHolders
    elements.map { |item| item.to_ruby }
  end


  private

  #this function specializes the class for the given path and uses the given newName and arguments.
  def specializeClass(path, newName, arguments, acs)
    classesToSpecialize = getElements(path)
    #take the original class to specialize
    classToSpecialize = classesToSpecialize[0]
    #specialize the class, this returns a class with a new name and an empty elements array, the elements (only methods) are added below.
    specializedClass = classToSpecialize.specialize(newName, acs, arguments)

    #get all the methods of all the classes with the same name, classes can get reopened so 2 instances of the same class can occur.
    #only add the latest version of a method with a given name. older versions stay in the store to create residual code for the original classes.
    #partial objects that use specialized classes always use the latest version of the methods.
    methodsToAdd = classesToSpecialize.map { |tClass| tClass.elements.select { |method| method.class == SMethod } }.flatten
    methodsToAdd.sort_by! { |method| method.created }.reverse!.uniq! { |method| method.identifier }
    methodsToAdd.each { |method| specializedClass.elements << method.deep_copy }

    specializedClass
  end

  #this function returns the specialized class for the given acs and path.
  #this is used when a new partion object is created. If the same ct arguments are passed in the same specialized class gets used
  def getSpecializedClass(path, acs)
    getElements(path).map { |orgClass| orgClass.specializations[acs] }
  end
end