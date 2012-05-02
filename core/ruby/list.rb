require_relative '../ruby/node'
require_relative '../ruby/alternation/list'

module Ruby
  class List < Aggregate
    include Conversions::List
    include Alternation::List

    child_accessor :elements

    def initialize(elements = nil)
      self.elements = Array(elements)
    end

    def nodes
      elements
    end

    def nodes=(elements)
      self.elements = elements
    end

    def method_missing(method, *args, &block)
      elements.respond_to?(method) ? elements.send(method, *args, &block) : super
    end

    def pe(env)
      #pe all the nodes
      elements.map! { |node| (node.respond_to? :pe) ? node.pe(env) : node }

      #remove the assignments where the left side is compile time
      elements.map! { |node|
        (node.class == Ruby::Assignment && node.ctAssignment?(env.store)) ? nil : node
      }

      return self
    end

  end

  class DelimitedList < List
    child_accessor :ldelim, :rdelim

    def initialize(elements = nil, ldelim = nil, rdelim = nil)
      self.ldelim = ldelim
      self.rdelim = rdelim
      super(elements)
    end

    def nodes
      ([ldelim] + super + [rdelim]).compact
    end

  end

  class Prolog < List
  end
end
