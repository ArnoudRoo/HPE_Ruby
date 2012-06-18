require_relative '../core_ext/object/meta_class'
require_relative '../core_ext/object/try'
require_relative '../ruby/node/composite'
require_relative '../ruby/node/source'
require_relative '../ruby/node/traversal'
require_relative '../ruby/node/conversions'

module Ruby
  class Node
    include Comparable
    include Composite
    include Source
    include Traversal
    include Conversions

    def row
      position[0]
    end

    def column
      position[1]
    end

    def length(prolog = false)
      to_ruby(prolog).length
    end

    def nodes
      []
    end

    def all_nodes
      nodes + nodes.map { |node| node.all_nodes }.flatten
    end

    def <=>(other)
      position <=> (other.respond_to?(:position) ? other.position : other)
    end

    #check if the node is compiletime evaluatable.
    def compileTime?
      all_nodes.all? { |node| node.compileTime? }
    end

    #evaluate the ast node and its sub nodes.
    def evaluate
      evalResult = eval("#{to_ruby}")

      #if the result is an string
      if (evalResult.class == "".class)
        return Helpers.createRipperStringFromRubyString(evalResult)
      end

      #create a ripper2ruby ast node for the evaluation result.
      result = Ripper::RubyBuilder.build("#{evalResult}")

      if (result.elements.count > 0)
        #the result is always a program, the first element is the result we need.
        return result.elements[0]
      else
        nilObject = Ruby::Nil.new
        nilObject.token = "nil"
        return nilObject
      end

    end

    def pe(env)
      return self, false
    end

    def peVarOrConst(env)
      oldProlog = self.prolog

      #check if the var is in the store and if it is ct
      inStore = env.store.inStore?(peIdentifier)
      ctVar = env.store.isCT(peIdentifier, false)

      if (ctVar)
        #if the var is ct than return the ripper value (if the var is ct than it is also in the store)
        returnExpr = env.store.astVal(peIdentifier)
        #the old prolog is used to get the right whitespace in front of the var when to_ruby is invoked
        returnExpr.prolog = oldProlog
        returnValue = returnExpr
      elsif(inStore)
        #if it is in the store but it is abstract
        returnExpr = self
        returnValue = env.store.astVal(peIdentifier)
        #if the value is a primitive type return top, else it is interpreted as a ct value
        returnValue = :top if Helpers.primitive?(returnValue)
        returnExpr.external = true if (returnExpr.respond_to?(:external) && env.store.state(peIdentifier) == :external)
      elsif (!inStore)
        #the var is not in the store. This can happen in ruby because the vars doesn't need to be declared first.
        returnExpr = self
        returnValue = :top
      end

      return returnExpr, returnValue
    end

    #this function is used to get the path of a module, class or method.
    #the path is used to place the module, class or method in the right place in the shared store.
    def getPath
      if (self.class == Ruby::Module)
        return (parent.getPath << self.const.identifier.token)
      elsif (self.class == Ruby::Class)
        return (parent.getPath << self.identifier.identifier.token)
      else
        if (parent)
          return parent.getPath
        else
          return []
        end
      end
    end

    #this function is used to check if the current node is a direct or indirect child of a node with the specified type.
    def isChildOf(type)
      if (self.parent.class == type)
        return true
      else
        return self.parent.isChildOf(type) if self.parent.respond_to? :isChildOf
      end
    end


    protected
    def update_positions(row, column, offset_column)
      pos = self.position
      pos.col += offset_column if pos && self.row == row && self.column > column
      nodes.each { |c| c.send(:update_positions, row, column, offset_column) }
    end
  end
end
