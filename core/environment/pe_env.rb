class PeEnv
  attr_accessor :store, :loopControl, :inCTLoop
  #loopControl is used to remember break, next and redo statements

  def changeStore(store)
    newEnv = PeEnv.new
    newEnv.store = store
    newEnv.loopControl = @loopControl
    newEnv.inCTLoop=@inCTLoop
    newEnv
  end

  def changeInCTLoop(value)
    newEnv = PeEnv.new
    newEnv.store = @store
    newEnv.loopControl = @loopControl
    newEnv.inCTLoop = value
    newEnv
  end



end