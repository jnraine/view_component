# frozen_string_literal: true

module ViewComponent
  class Slot
    attr_accessor :content, :parent
    attr_writer :_component_instance

    # Parent must be `nil` for v1
    def initialize(parent = nil)
      @parent = parent
    end

    def to_s
      if defined?(@_component_instance)
        parent.render(@_component_instance) { content }
      else
        content
      end
    end

    def method_missing(symbol, *args, &block)
      if defined?(@_component_instance)
        @_component_instance.public_send(symbol, *args, &block)
      else
        parent.send(symbol, *args, &block)
      end
    end
  end
end
