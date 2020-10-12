# frozen_string_literal: true

require "test_helper"

class SlotableV2Test < ViewComponent::TestCase
  def test_renders_slots
    render_inline(SlotsV2Component.new(class_names: "mt-4")) do |component|
      component.title do
        "This is my title!"
      end
      component.subtitle do
        "This is my subtitle!"
      end

      component.tab do
        "Tab A"
      end
      component.tab do
        "Tab B"
      end

      component.item do
        "Item A"
      end
      component.item(highlighted: true) do
        "Item B"
      end
      component.item do
        "Item C"
      end

      component.footer(class_names: "text-blue") do
        "This is the footer"
      end
    end


    assert_selector(".card.mt-4")

    assert_selector(".title", text: "This is my title!")

    assert_selector(".subtitle", text: "This is my subtitle!")

    assert_selector(".tab", text: "Tab A")
    assert_selector(".tab", text: "Tab B")

    assert_selector(".item", count: 3)
    assert_selector(".item.highlighted", count: 1)
    assert_selector(".item.normal", count: 2)

    assert_selector(".footer.text-blue", text: "This is the footer")
  end

  def test_invalid_slot_class_raises_error
    exception = assert_raises ArgumentError do
      render_inline(BadSlotV2Component.new) do |component|
        component.title { "hello" }
      end
    end

    assert_includes exception.message, "Title must inherit from ViewComponent::Slot"
  end

  def test_renders_slots_with_empty_collections
    render_inline(SlotsV2Component.new) do |component|
      component.title do
        "This is my title!"
      end

      component.subtitle do
        "This is my subtitle!"
      end

      component.footer do
        "This is the footer"
      end
    end

    assert_text "No tabs provided"
    assert_text "No items provided"
  end

  def test_renders_slots_template_raise_with_unknown_content_areas
    assert_raises NoMethodError do
      render_inline(SlotsV2Component.new) do |component|
        component.foo { "Hello!" }
      end
    end
  end

  def test_with_slot_raise_with_duplicate_slot_name
    exception = assert_raises ArgumentError do
      SlotsV2Component.with_slot :title
    end

    assert_includes exception.message, "title slot declared multiple times"
  end

  def test_with_slot_raise_with_content_keyword
    exception = assert_raises ArgumentError do
      SlotsV2Component.with_slot :content
    end

    assert_includes exception.message, ":content is a reserved slot name"
  end

  def test_with_slot_with_content_arg
    render_inline(SlotsV2Component.new(class_names: "mt-4")) do |component|
      component.title(content: "This is my title!")
      component.subtitle(content: "This is my subtitle!")

      component.footer(content: "This is the footer", class_names: "text-blue")
    end

    assert_selector(".title", text: "This is my title!")
    assert_selector(".subtitle", text: "This is my subtitle!")

    assert_selector(".footer.text-blue", text: "This is the footer")
  end

  def test_with_slot_raises_with_both_content_arg_and_block
    exception = assert_raises ArgumentError do
      render_inline(SlotsV2Component.new(class_names: "mt-4")) do |component|
        component.title(content: "This is my title!") { "This is my title!" }
      end
    end

    assert_includes exception.message, "Slots can not be passed both a content argument and a block"
  end

  def test_with_slot_with_positional_args
    render_inline(SlotsV2WithPosArgComponent.new(class_names: "mt-4")) do |component|
      component.item("my item", class_names: "hello") { "My rad item" }
    end

    assert_selector(".item", text: "my item")
    assert_selector(".item-content", text: "My rad item")
  end

  def test_with_slot_with_collection
    render_inline(SlotsV2WithPosArgComponent.new(class_names: "mt-4")) do |component|
      component.items(["red", "yellow", "green"], class_names: "stop-light") { "my content" }
    end

    assert_selector(".item .stop-light", text: "red")
    assert_selector(".item .stop-light", text: "yellow")
    assert_selector(".item .stop-light", text: "green")
  end

  # In a previous implementation of slots,
  # the list of slots registered to a component
  # was accidentally assigned to all components!
  def test_slots_pollution
    new_component_class = Class.new(ViewComponent::Base)
    new_component_class.include(ViewComponent::Slotable)
    # this returned:
    # [SlotsV2Component::Subtitle, SlotsV2Component::Tab...]
    assert_empty new_component_class.slots
  end
end
