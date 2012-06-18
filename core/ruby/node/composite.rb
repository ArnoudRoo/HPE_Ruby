module Ruby
  class Node
    module Composite

      class Array < ::Array
        include Composite

        def to_ruby(prolog)
          (self.shift.try(:to_ruby, prolog) || '') + self.map { |node|
            if node.respond_to?('to_ruby') then
              node.to_ruby(true)
            end }.join
        end

        def all_nodes
          self.map { |node| node.all_nodes if node && node.class != :temp.class }.flatten
        end

        def nodes
          puts "haahaa"
          self
        end

        def initialize(objects = [])
          objects.each { |object| self << object }
        end

        def detect
          each { |element| return element if yield(element) }
        end

        def <<(object)
          if object.respond_to?(:parent=)
            object.parent = self.parent
          elsif object.respond_to?(:each)
            object.each { |o| o.try(:parent=, parent) }
          end
          super
        end

        def []=(ix, object)
          object.parent = parent if (object)
          super
        end

        def parent=(parent)
          each { |object| object.try(:parent=, parent) }
          @parent = parent
        end

        def +(other)
          self.dup.tap { |dup| other.each { |object| dup << object } }
        end
      end

      def self.included(target)
        target.class_eval do
          class << self
            def child_accessor(*names, &block)
              names.each do |name|
                attr_reader name
                define_method("#{name}=") do |value|
                  value = Composite::Array.new(value) if value.is_a?(::Array)
                  value.parent = self if (value && value.respond_to?(:parent)) #OWN && value.respond_to?(:parent))
                  instance_variable_set(:"@#{name}", value)
                  yield(value) if block_given?
                end
              end
            end
          end
        end
      end

      attr_accessor :parent

      def root?
        parent.nil?
      end

      def root
        root? ? self : parent.root
      end

      def pe(env)
        #if the last element returns a partial object his is returned.
        peValueResult = nil

        self.compact!
        #pe all the nodes
        self.map! { |node|
          if (node.respond_to? :pe)
            if (env.loopControl && env.inCTLoop)
              nil
            else
              peExprResult, peValueResult = node.pe(env)
              #the result of an assignment isn't needed at this point.
              ((node.class == Ruby::Call || node.class == Ruby::Assignment) && peValueResult.class == CTObject) ? nil : peExprResult
            end
          else
            node
          end
        }

        return self, peValueResult
      end


    end
  end
end