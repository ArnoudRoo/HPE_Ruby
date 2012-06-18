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

    def peIdentifier
      if @identifier.respond_to?(:token)
        @identifier.token
      else
        @identifier.identifier.token
      end
    end

    def peIdentifier=(value)
      if (@identifier.respond_to?(:token))
        @identifier.token = value
      else
        @identifier.identifier.token = value
      end
    end

    def nodes
      [ldelim, target, separator, identifier, params, block, rdelim].compact
    end

    def pe(env)
      #if this method is defined within another method we don't need to add it to the shared store.
      #the parent of this method will contain the code to define this method.
      raise "Nested methods are not supported" if (isChildOf(Ruby::Method))

      $sharedStore.addSSObject(SMethod.new(self, path), path)
      return Ruby::PlaceHolder.new(peIdentifier), :top
    end

    alias :path :getPath

    def peBody(env)
      return block.pe(env)
    end
  end
end

