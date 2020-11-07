# frozen_string_literal: true

module ViewComponent
  class Slot
    attr_accessor :parent, :content
    attr_accessor :_component_instance, :_content_block

    # Parent must be `nil` for v1
    def initialize(parent = nil)
      @parent = parent
    end

    def to_s
      if defined?(@_component_instance)
        # render_in is faster than `parent.render`
        @_component_instance.render_in(
          parent.send(:view_context),
          &@_content_block
        )
      elsif defined?(@content)
        @content
      elsif defined?(@_content_block)
        @_content_block.call
      else
        ""
      end
    end

    def method_missing(symbol, *args, &block)
      @_component_instance.public_send(symbol, *args, &block)
    end
  end
end
