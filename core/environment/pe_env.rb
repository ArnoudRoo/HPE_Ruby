class PeEnv
  attr_accessor :store, :markAsRuntime
  #markRuntime is used to mark compile time vars in the store as runtime when they are reassigned a value in an if else of for that is not complete compile time.
  #this is needed because if the expression of the if/else can't be determined compile time both all the branches need to be partial evaluated
  #and if one branch change the value of a compile time var and the other branch is used at runtime the compile time var has a wrong value.

  def changeStore(store)
    newEnv = PeEnv.new
    newEnv.store = store
    newEnv.markAsRuntime = @markAsRuntime
    newEnv
  end

end