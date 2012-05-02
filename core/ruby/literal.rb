require_relative '../ruby/token'

module Ruby
  class Nil < Token
    def value
      nil
    end

	def compileTime?
		true
	end
  end
  
  class True < Token
    def value
      true
    end

    def compileTime?
      true
    end
  end
  
  class False < Token
    def value
      false
    end

	def compileTime?
		true
	end
  end
  
  class Integer < Token
    def value
      token.to_i
    end

	def compileTime?
		true
	end
  end

  class Float < Token
    def value
      token.to_f
    end

	def compileTime?
		true
	end
  end

  class Char < Token
    def value
      token[1]
    end

	def compileTime?
		true
	end
  end
  
  class Label < Token
    def value
      token.gsub(':').to_sym
    end

	def compileTime?
		true
	end
  end
end