# frozen_string_literal: true

class SlotsV2WithPosArgComponent < ViewComponent::Base
  include ViewComponent::Slotable::V2

  renders_many :items, ->(title, class_names) do
    @title = title
    @class_names = class_names
  end
end
