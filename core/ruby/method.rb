require_relative '../ruby/node'

module Ruby

  class Method < NamedAggregate
    child_accessor :target, :separator, :params, :block # TODO rename block to body

    def initialize(target, separator, identifier, params, block, ldelim, rdelim)
      self.target = target
      self.separator = separator
      self.params = params
      self.block = block
      super(identifier, ldelim, rdelim)
    end

    def nodes
      [ldelim, target, separator, identifier, params, block, rdelim].compact
    end

    def pe(env)
      #if this method is defined within another method we don't need to add it to the shared store.
      #the parent of this method will contain the code to define this method.
      if (isChildOf(Ruby::Method))
        self.nodes.map! { |node| (node.respond_to? :pe) ? node.pe(env.changeStore(Store.new())) : node }
        return self
      else
        path = self.getPath
        $sharedStore.addSSObject(SMethod.new(self),path)
        return Ruby::PlaceHolder.new(self.identifier.token)
      end

    end
  end


end