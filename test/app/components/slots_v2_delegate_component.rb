# frozen_string_literal: true

class SlotsV2DelegateComponent < ViewComponent::Base
  include ViewComponent::Slotable::V2

  renders_many :items, MyHighlightComponent

  def initialize
  end
end
