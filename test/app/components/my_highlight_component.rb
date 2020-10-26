class MyHighlightComponent < ViewComponent::Base
  def initialize(highlighted: false)
    @highlighted = highlighted
  end

  def call
    content
  end

  def class_names
    @highlighted ? "highlighted" : "normal"
  end
end
