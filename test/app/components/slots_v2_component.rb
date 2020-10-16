# frozen_string_literal: true

class SlotsV2Component < ViewComponent::Base
  include ViewComponent::Slotable::V2

  renders_one :title
  renders_one :subtitle
  renders_one :footer do
    attr_reader :class_names

    def initialize(class_names: "")
      @class_names = class_names
    end
  end

  renders_many :tabs

  renders_many :items do
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
