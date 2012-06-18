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
      #if the last element returns a partial object his is returned.
      peValueResult = nil

      #pe all the nodes
      elements.map! { |node|
        if (node.respond_to? :pe)
          peExprResult, peValueResult = node.pe(env)
          #the result of an assignment isn't needed at this point.
          ((node.class == Ruby::Call || node.class == Ruby::Assignment) && peValueResult.class == CTObject) ? nil : peExprResult
        else
          node
        end
      }

      return self, peValueResult
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
