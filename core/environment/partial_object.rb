class PartialObject
  attr_accessor :sClass, :store

  def initialize(specializedClass, arguments)
    @sClass = specializedClass
    if (!@sClass.isSpecialized)
      specializeConstructor(arguments)
      @sClass.isSpecialized = true
    end
    @store = @sClass.store.deep_copy
    @store.update(StoreVar.new(Helpers.selfIdentifier, self, :runtime))
  end

  def addNewMethod(method)
    method = method.deep_copy
    method.ssParent = @sClass
    @sClass.elements << method
  end

  def specializeConstructor(arguments)
    store = Store.new
    store.update(StoreVar.new(Helpers.selfIdentifier, self, :runtime))
    #find the constructor
    constructor = @sClass.elements.select { |element| element.respond_to?(:identifier) && element.identifier == "initialize" }
    if (constructor.any?)
      #specialize the constructor.
      specializedConstructor, peBodyValueResult = constructor[0].specializeMethodOrConstructor("initialize", arguments, store)
      #remove the non fields of the store, so only the class variables remain.
      store.removeNonFields
      #wrap the specialized constructor in a Store method object, so it later is inserted in the right location using place holders.
      specConsMethod = SMethod.new(specializedConstructor, nil)
      #replace the old constructor with the specialized constructor
      @sClass.elements.map! { |element| (element.respond_to?(:identifier) && element.identifier == "initialize") ? specConsMethod : element }
    end
    @sClass.store = store
    store.deep_copy
  end

  def specialize(name, args, block, newName = nil)
    if (!newName)
      $specializedMethodCount += 1
      temp = name.gsub(/\W+/, '')
      newName = "#{temp[0]}spec_#{$specializedMethodCount}_#{temp}"
      newName.gsub!(/\=|\*|\[|\]|\-/, '')
    end

    peSpecializeValueResult = sClass.specializePoMethod(name, newName, args, @store, block)
    @store.removeNonFields
    return newName, true, :top
  end

  def specializeAndCheckStore(orgName, newName, args, block)
    orgStore = @store.deep_copy
    orgStore.removeNonFields
    newName, specialized, peSpecializeValueResult = specialize(orgName, args, block, newName)
    raise "inconsistent store change while specializing method #{orgName} on a unknown partial object." if !orgStore.eql?(store)
    return newName, specialized, peSpecializeValueResult
  end

  def compileTime?
    false
  end
end