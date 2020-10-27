# frozen_string_literal: true

class SlotsV2WithPosArgComponent < ViewComponent::Base
  include ViewComponent::Slotable::V2

  renders_many :items, ->(title, class_names) do
    Item.new(title: title, class_names: class_names)
  end

  class Item < ViewComponent::Base
    attr_reader :title, :class_names

    def initialize(title:, class_names:)
      @title = title
      @class_names = class_names
    end

    def call
      content
    end
  end
end
