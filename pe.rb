require 'ripper'
require 'pp'
require 'facets'
require_relative 'Core/ripper/ruby_builder'
require_relative 'Core/ripper/event_log'
require_relative 'core/environment/store'
require_relative 'core/environment/shared_store'
require_relative 'core/environment/pe_env'
require_relative 'core/environment/helpers'
require_relative 'core/environment/ct_object'
require_relative 'core/environment/store_var'
require_relative 'core/environment/partial_object'


class NilClass
  def pe(env)

  end
end

class PE

  #replace accessors
  def replace(filePath)
    result = ""
    File.open(filePath) do |f|
      f.each_line do |line|
        if(line.match /attr_accessor/)

          result += line.scan(/:([a-zA-Z_]*)/).map{|field,a| "\ndef #{field}\n@#{field}\nend\ndef #{field}= (value)\n@#{field} = value\nend\n"}.join
        else
          result += line
        end
      end
    end
    result
  end

  def run(src, fileName)

    #This global var is used to determine the name for the specialized methods
    $specializedMethodCount = 0

    #the shared store is used to keep track of the classes and methods that are available
    $sharedStore = SharedStore.new


    text = replace("..\\input\\#{fileName}")
    File.open("..\\temp\\#{fileName}", "w") { |file| file.puts text }


    #create the ast
    ast = Ripper::RubyBuilder.build(src, "..\\temp\\#{fileName}")

    #init the state
    env = PeEnv.new
    env.store = Store.new(nil)
    env.store.update(StoreVar.new(Helpers.selfIdentifier, :kernel, :runtime))

    #partial evaluate the ast.
    $sharedStore.addSSObject(ast.pe(env)[0], "")

    #return the residual code.
    residualCode = ([$sharedStore.to_ruby]).join

    #print the residual code to file.
    File.open("..\\output\\#{fileName}", "w") do |f|
      f.write residualCode
    end

  end
end

if (ARGV && ARGV[0])
  a = PE.new
  a.run(nil, ARGV[0])
end
