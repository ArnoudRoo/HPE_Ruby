require_relative '../ruby/token'

module Ruby
  class Nil < Token
    def primitive?
      true
    end

    def value
      nil
    end
  end

  class True < Token
    def primitive?
      true
    end

    def value
      true
    end
  end

  class False < Token
    def primitive?
      true
    end

    def value
      false
    end
  end

  class Integer < Token
    def primitive?
      true
    end

    def value
      token.to_i
    end
  end

  class Float < Token
    def primitive?
      true
    end

    def value
      token.to_f
    end
  end

  class Char < Token
    def primitive?
      true
    end

    def value
      token[1]
    end
  end

  class Label < Token
    def primitive?
      true
    end

    def value
      token.gsub(':').to_sym
    end
  end
end