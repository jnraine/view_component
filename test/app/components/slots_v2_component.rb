# frozen_string_literal: true

class SlotsV2Component < ViewComponent::Base
  include ViewComponent::Slotable::V2

  with_slot :title
  with_slot :subtitle
  with_slot :footer do
    attr_reader :class_names

    def initialize(class_names: "")
      @class_names = class_names
    end
  end

  with_slot :tab, collection: true

  with_slot :item, collection: true do
    def initialize(highlighted: false)
      @highlighted = highlighted
    end

    def class_names
      @highlighted ? "highlighted" : "normal"
    end
  end

  def initialize(class_names: "")
    @class_names = class_names
  end
end
