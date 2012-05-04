require_relative 'ss_objects'

class SharedStore < BaseSSObject

  def initialize
    super()
    @specializedACSS = Hash.new
  end

  def previousSpecialized?(acs)
    return @specializedACSS[acs]
  end

  def specName(orgName, acs)
    if (previousSpecialized?(acs))
      return @specializedACSS[acs]
    else
      $specializedMethodCount += 1
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

  def to_ruby
    replacePlaceHolders
    elements.map { |item| item.to_ruby }
  end
end