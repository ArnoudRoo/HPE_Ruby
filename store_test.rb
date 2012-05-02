class StoreTest
  def initialize
  end

  def run
    testStoreSet
    testStoreReSet
    testFindNoNestedScopeAndVarInStore
    testFindNoNestedScopeAndVarNotInStore
    testFindVarWithNestedScope
    testNestedStorePrecedence
    testInStoreWithVarInStore
    testInStoreWithVarNotInStore
    testInStoreWithVarInParentStoreAndIncludeParentFalse
    testMark
  end

  def testStoreSet
    store = Store.new(nil)
    storeVar = StoreVar.new("testVar", nil, true, :runtime)
    store.add(storeVar)
    puts "Ok #{__method__}" if store.varCount == 1
    puts "FAIL #{__method__} varCount == #{store.varCount}" if store.varCount != 1
  end

  def testStoreReSet
    store = Store.new(nil)
    storeVar = StoreVar.new("testVar", nil, true, :runtime)
    storeVar2 = StoreVar.new("testVar", nil, 4, :runtime)
    store.add(storeVar)
    store.add(storeVar2)
    if store.varCount == 1 && store.find("testVar").val == 4
      puts "Ok #{__method__}"
    else
      puts "FAIL #{__method__}"
    end
  end

  def testFindNoNestedScopeAndVarInStore
    store = Store.new(nil)
    storeVar = StoreVar.new("testVar", nil, true, :runtime)
    store.add(storeVar)
    puts "Ok #{__method__}" if store.find("testVar")
    puts "FAIL #{__method__}" if !store.find("testVar")
  end

  def testFindNoNestedScopeAndVarNotInStore
    store = Store.new(nil)
    storeVar = StoreVar.new("testVar", nil, true, :runtime)
    store.add(storeVar)
    puts "Ok #{__method__}" if !store.find("testVarNotInStore")
    puts "FAIL #{__method__}" if store.find("testVarNotInStore")
  end

  def testFindVarWithNestedScope
    store1 = Store.new(nil)
    store2 = Store.new(store1)
    storeVar = StoreVar.new("testVar", nil, true, :runtime)
    store1.add(storeVar)
    puts "Ok #{__method__}" if store2.find("testVar")
    puts "FAIL #{__method__}" if !store2.find("testVar")
  end

  def testNestedStorePrecedence
    store1 = Store.new(nil)
    store2 = Store.new(store1)
    storeVar1 = StoreVar.new("testVar", nil, true, :runtime)
    storeVar2 = StoreVar.new("testVar", nil, false, :compileTime)
    store1.add(storeVar1)
    store2.add(storeVar2)
    puts "Ok #{__method__}" if store2.find("testVar").val == false
    puts "FAIL #{__method__}" if store2.find("testVar").val == true
  end

  def testInStoreWithVarInStore
    store = Store.new(nil)
    storeVar = StoreVar.new("testVar", nil, true, :runtime)
    store.add(storeVar)
    puts "Ok #{__method__}" if store.inStore?("testVar")
    puts "FAIL #{__method__}" if !store.inStore?("testVar")
  end

  def testInStoreWithVarNotInStore
    store = Store.new(nil)
    storeVar = StoreVar.new("testVar", nil, true, :runtime)
    store.add(storeVar)
    puts "Ok #{__method__}" if !store.inStore?("testVarNotInStore")
    puts "FAIL #{__method__}" if store.inStore?("testVarNotInStore")
  end

  def testInStoreWithVarInParentStoreAndIncludeParentFalse
    store = Store.new(nil)
    store2 = Store.new(store)
    storeVar = StoreVar.new("testVar", nil, true, :runtime)
    store.add(storeVar)
    if (!store2.inStore?("testVar", false) && store2.inStore?("testVar",true))
      puts "Ok #{__method__}"
    else
      puts "FAIL #{__method__}"
    end
  end

  def testMark
    store = Store.new(nil)
    storeVar = StoreVar.new("testVar", nil, true, :runtime)
    store.add(storeVar)

    #check if the var is really runtime.
    if (store.find("testVar").isCT)
      puts "FAIL #{__method__}"
      return
    end

    #mark the var as compile time
    store.mark("testVar", :compileTime)

    #check if the var is really compile time.
    if (store.find("testVar").isCT)
      puts "Ok #{__method__}"
    else
      puts "FAIL #{__method__}"
    end
  end
end