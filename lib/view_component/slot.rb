# frozen_string_literal: true

module ViewComponent
  class Slot
    # Necessary for Slots v1
    attr_accessor :content

    def _view_component_internal_content=(content)
      @_view_component_internal_content = content
    end

    def to_s
      @_view_component_internal_content
    end
  end
end
