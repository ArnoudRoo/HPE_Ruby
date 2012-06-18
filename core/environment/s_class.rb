class SClass < BaseSSObject
  attr_accessor :specializations, :store, :isSpecialized, :inclusions, :extensions, :orgPath, :superPath

  def initialize(astNode, orgPath = nil, superPath = nil)
    super()
    @astNode = astNode
    @specializations = Hash.new
    @isSpecialized = false
    @inclusions = []
    @extensions = []
    @orgPath = orgPath if(orgPath)
    @superPath = superPath if(superPath)
  end

  def identifier
    @astNode.identifier.identifier.token
  end

  def astNode
    @astNode
  end

  def superClass
    "< #{astNode.super_class.identifier.token}" if astNode.super_class
  end

  def instantiateCode(childCode)
    code = "\nclass #{identifier} #{superClass.to_s}\n" + childCode + "\nend\n"
    ssParent.respond_to?("instantiateCode") ? ssParent.instantiateCode(code) : code
  end

  def to_ruby(prolog=true)
    superClass = self.superClass if self.superClass
    if(@isSpecialized)
      methods = []
      @elements.each{|elem|
        if elem.class == SMethod
          case elem.identifier
            when "initialize"
              methods << elem
            else
            #select all the methods that contain statements. Through partial evaluation it can occur that the method contains no statements. These methods aren't printed.
            methods << elem.specializations.select{|method| method && !method.block[1].elements.compact.empty?}
          end
        end
      }
      result = "\nclass #{identifier} #{superClass.to_s}\n" + methods.flatten.map { |item| item.to_ruby(prolog) }.join + "\nend\n"
    else
      replacePlaceHolders
      result = "\nclass #{identifier} #{superClass.to_s}\n" + @elements.map { |item| item.to_ruby(prolog) }.join + "\nend\n"
    end
    result + @specializations.map { |key, value| value.to_ruby(prolog) }.join
  end


  def specialize(newName, acs, arguments)
    clonedClass = self.deep_copy
    #delete all the existion elements
    clonedClass.elements = []
    #make the specialized class a subclass of the original class.
    clonedClass.astNode.super_class = clonedClass.astNode.identifier.deep_copy
    #set the name of the new class to the specialized name
    clonedClass.astNode.identifier.identifier.token = newName
    #remove the specializations of the cloned class, only the original class can contain specializations.
    clonedClass.specializations = Hash.new

    specializations[acs] = clonedClass
    clonedClass
  end

  def specializePoMethod(unspecializedName, specializedName, arguments, store, block)
    method = @elements.select { |elem| elem.class == SMethod && elem.identifier == unspecializedName }.last
    method.specialize(specializedName, arguments, block, store) if method
  end

  def path
    @astNode.path
  end

end