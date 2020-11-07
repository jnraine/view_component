# frozen_string_literal: true

class SlotsV2Component < ViewComponent::Base
  include ViewComponent::Slotable::V2

  renders_one :title
  renders_one :subtitle
  renders_one :footer, -> (class_names: "", &block) do
    content_tag :footer, class: "footer #{class_names}" do
      block.call if block
    end
  end

  renders_many :tabs

  renders_many :items, -> (highlighted: false) do
    MyHighlightComponent.new(highlighted: highlighted)
  end

  def initialize(class_names: "")
    @class_names = class_names
  end
end
