# frozen_string_literal: true

module ViewComponent
  class Slot
    attr_accessor :content
    attr_writer :_component_instance

    def to_s
      content
    end

    def method_missing(symbol, *args, **kwargs, &block)
      if defined?(@_component_instance)
        @_component_instance.public_send(symbol, *args, **kwargs, &block)
      elsif defined?(:"@#{symbol}")
        instance_variable_get(:"@#{symbol}")
      else
        super
      end
    end
  end
end
