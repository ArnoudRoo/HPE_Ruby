require_relative '../ruby/assoc'
require_relative '../ruby/alternation/hash'

module Ruby
  class Hash < DelimitedList
    include Alternation::Hash
    
    def value
      code = to_ruby(false)
      code = "{#{code}}" unless ldelim
      eval(code) rescue {}
    end
  end
end