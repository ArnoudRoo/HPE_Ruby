class BaseSSObject
  attr_accessor :elements, :ssParent

  def initialize
    @elements = []
  end

  def getAllOfType(type)
    ((self.kind_of?(type) ? [self] : [nil]) + @elements.map { |elem| elem.getAllOfType(type) if elem.respond_to?(:getAllOfType) }).flatten.compact
  end

  #this function is used to put the methods and classes in the right place in the residual code
  def replacePlaceHolders
    ssElements = @elements.select { |elem| elem.class == SMethod || (elem.kind_of? BaseSSObject) }
    if self.class == SharedStore
      # if the class = SharedStore this means that it is the main program.
      body = @elements.select { |elem| elem.class == Ruby::Program }[0]
      # loop through all the elements and replace the placeholders with the real methods, classes and modules.
      body.elements.map! { |node|
        replacePlaceHolderIfNeeded(node, ssElements)
      }
      @elements = [body]
    else
      # if the class is something else as SharedStore, for example SModule, SClass then select all the Ruby::Node::Composite::Array elements and replace the placeholders within the sub arrays
      body = @elements.select { |elem| elem.class == Ruby::Node::Composite::Array }
      # loop through all the elements and replace the placeholders with the real methods, classes and modules.
      body.each { |arrayNode| arrayNode.select { |a| a.class == Ruby::Statements }.each { |b| b.elements.map! { |node|
        replacePlaceHolderIfNeeded(node, ssElements)
      } } }
      @elements = body
    end
  end

  #add an object to the shared store. Used to add methods, modules, classes and statement sections.
  def addSSObject(object, path)

    #for classes and modules a pathlength of 1 is needed. for methods and statements 0. By classes and modules the last part of the path is the module or class itself.
    neededPathLength =(object.class == SModule || object.class == SClass) ? 1 : 0

    if (path.length == neededPathLength)

      object = enrichWithMethodsOfSuperClasses(object) if (object.class == SClass)

      #try to set the parent of the object, this is needed to get the namespace on some point to instantiate the code for ct variables.
      object.ssParent = self if (defined? object.ssParent)
      @elements.delete_if{|method| method.class == SMethod && object.class == SMethod && method.identifier == object.identifier && method.orgPath != path}
      @elements << object
      #if the object is an method instantiate the method
      if (object.class == SMethod)
        Object.module_eval(object.instantiateCode) if object.instantiateCode
        #also add method the method to partial classes of the same type, classes of the same type contains a identifier that ends on _{org class name}.
        $sharedStore.partialObjects.select { |po| po.sClass.identifier =~ /_#{self.identifier}$/ }.each { |po| po.addNewMethod(object) }

        # check if there are classes that include or extend this module
        if (self.class == SModule)
          allClassesToIncludeMethod = $sharedStore.getAllOfType(SClass).select { |tClass| tClass.inclusions.include?(self.path) }
          pathsOfClassesToIncludeMethod = allClassesToIncludeMethod.map { |tClass| tClass.path }.uniq
          pathsOfClassesToIncludeMethod.each { |path| $sharedStore.addSSObject(object, path) }
        end

        if (self.class == SClass)
          # Add the method to all the classes that inherit from this class
          addToInheritingClasses(object,self)
        end

      end
    else
      match = @elements.find_all { |item| item.respond_to?(:identifier) && item.identifier == path[0] }
      if (match.any?)
        match.last.addSSObject(object, path[1..-1])
      else
        raise "Error adding object to the shared store, wrong path (#{path.to_s})"
      end
    end
  end

  #if a new class is created all the methods of the super classes are added. At this point the class is always empty, doesn't contain methods.
  def enrichWithMethodsOfSuperClasses(object)
    superClasses = getSuperClasses(object.superPath)
    superClasses.each{|tClass|
      tClass.elements.select{|elem| elem.class == SMethod}.each{|method| object.elements << method.deep_copy}
    }
    object
  end

  def addToInheritingClasses(method, orgClass)
    #get all the inheriting classes.
    inheritingClasses = $sharedStore.getAllOfType(SClass).select { |tClass| tClass.superPath == orgClass.orgPath }
    inheritingClasses.each { |tClass|
      #check if the method isn't already implemented in the class itself, if so this takes precedence over the method of a super class
      needToAdd = tClass.elements.any?{|elem| elem.class == SMethod && elem.orgPath != method.orgPath}
      $sharedStore.addSSObject(method, tClass.path) if(needToAdd)
    }
  end

  #specialize all the methods with the unspecializedName. The real specialization is implemented in the SMethod class.
  def specializeAllMethods(unspecializedName, specializedName, arguments, block)
    methodsToSpecialize = $sharedStore.getAllOfType(SMethod).select { |method| method.identifier == unspecializedName }
    methodsToSpecialize.each { |method| method.specialize(specializedName, arguments, block) }
  end

  protected
  def getElements(path)
    if (path.length == 0)
      return self
    else
      match = @elements.find_all { |item| item.respond_to?(:identifier) && item.identifier == path[0] }
      if (match.any?)
        match.map { |item| item.getElements(path[1..-1]) }.flatten
      else
        raise "Element could not be found, wrong path (#{path.to_s})"
      end
    end
  end

  private
  #this function is used by replacePlaceHolders to replace a placeholder with the real method, module or class. Used multiple times.
  def replacePlaceHolderIfNeeded(node, ssElement)
    if (node.class == Ruby::PlaceHolder)
      replaceValue = ssElement.select { |element| element.identifier == node.token }[0]
      ssElement.delete(replaceValue)
      replaceValue
    else
      node
    end
  end

  def getSuperClasses(superPath)
    directSuperClasses = $sharedStore.getAllOfType(SClass).select{|tClass| tClass.orgPath == superPath}
    (directSuperClasses + directSuperClasses.each{|tClass| getSuperClasses(tClass.superPath)}).flatten.compact.uniq
  end


end





