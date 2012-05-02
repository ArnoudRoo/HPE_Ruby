require 'ripper'
require 'pp'
require 'facets'
require_relative 'Core/ripper/ruby_builder'
require_relative 'Core/ripper/event_log'
require_relative 'core/environment/store'
require_relative 'core/environment/shared_store'
require_relative 'core/environment/pe_env'
require_relative 'core/environment/helpers'



class NilClass
  def pe(env)

  end
end

class PE
  def run(src, fileName)

    #This global var is used to determine the name for the specialized methods
    $specializedMethodCount = 0

    #the shared store is used to keep track of the classes and methods that are available
    $sharedStore = SharedStore.new

    #create the ast
    ast = Ripper::RubyBuilder.build(src, fileName)

    #init the state
    env = PeEnv.new
    env.store = Store.new(nil)
    env.markAsRuntime = false

    #partial evaluate the ast.
    ast.pe(env)

    #return the residual code.
    ([$sharedStore.to_ruby] + [ast.to_ruby]).join

  end
end