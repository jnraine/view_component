# frozen_string_literal: true

class SlotsV2WithPosArgComponent < ViewComponent::Base
  include ViewComponent::Slotable::V2

  with_slot :item, collection: true, class_name: "Item"

  class Item < ViewComponent::Slot
    attr_reader :title, :class_names

    def initialize(title, class_names:)
      @title = title
      @class_names = class_names
    end
  end
end
