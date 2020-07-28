# frozen_string_literal: true

class BadSlotV2Component < ViewComponent::Base
  include ViewComponent::Slotable::V2

  with_slot :title, class_name: "Title"

  # slots must inherit from ViewComponent::Slot!
  class Title; end
end
