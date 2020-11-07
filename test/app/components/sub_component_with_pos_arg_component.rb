# frozen_string_literal: true

class SubComponentWithPosArgComponent < ViewComponent::Base
  include ViewComponent::SubComponents

  renders_many :items, "Item"

  class Item < ViewComponent::Base
    attr_reader :title, :class_names

    def initialize(title, class_names:)
      @title = title
      @class_names = class_names
    end

    def call
      content
    end
  end
end
