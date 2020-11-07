# frozen_string_literal: true

require "active_support/concern"

require "view_component/slot"

module ViewComponent
  module SubComponents
    extend ActiveSupport::Concern

    # Setup component slot state
    included do
      # Hash of registered Slots
      class_attribute :registered_slots
      self.registered_slots = {}
    end

    class_methods do
      ##
      # Registers a slot on the component.
      #
      # = Example
      #
      #   renders_one :header do
      #     def initialize(classes:)
      #       @name = name
      #     end
      #   end
      #
      # = Rendering slot content
      #
      # The component's sidecar template can access the slot by calling a
      # helper method with the same name as the slot (pluralized if the slot
      # is a collection).
      #
      #   <h1>
      #     <%= header %>
      #   </h1>
      #
      # = Setting slot content
      #
      # Renderers of the component can set the content of a slot by calling a
      # helper method with the same name as the slot. For collection
      # components, the method can be called multiple times to append to the
      # slot.
      #
      #   <%= render_inline(MyComponent.new) do |component| %>
      #     <%= component.header(classes: "Foo") do %>
      #       <p>Bar</p>
      #     <% end %>
      #   <% end %>
      def renders_one(slot_name, callable = nil)
        validate_slot_name(slot_name)

        define_method slot_name do |*args, **kwargs, &block|
          if args.empty? && kwargs.empty? && block.nil?
            get_slot(slot_name)
          else
            set_slot(slot_name, *args, **kwargs, &block)
          end
        end

        register_slot(slot_name, collection: false, callable: callable)
      end

      ##
      # Registers a collection slot on the component.
      #
      # = Example
      #
      #   render_many :items do
      #     def initialize(name:)
      #       @name = name
      #     end
      #   end
      #
      # = Rendering slot content
      #
      # The component's sidecar template can access the slot by calling a
      # helper method with the same name as the slot.
      #
      #   <h1>
      #     <%= items.each do |item| %>
      #       <%= item %>
      #     <% end %>
      #   </h1>
      #
      # = Setting slot content
      #
      # Renderers of the component can set the content of a slot by calling a
      # helper method with the same name as the slot. The method can be
      # called multiple times to append to the slot.
      #
      #   <%= render_inline(MyComponent.new) do |component| %>
      #     <%= component.item(name: "Foo") do %>
      #       <p>One</p>
      #     <% end %>
      #
      #     <%= component.item(name: "Bar") do %>
      #       <p>two</p>
      #     <% end %>
      #   <% end %>
      def renders_many(slot_name, callable = nil)
        validate_slot_name(slot_name)

        singular_name = ActiveSupport::Inflector.singularize(slot_name)

        # Define setter for singular names
        # e.g. `with_slot :tab, collection: true` allows fetching all tabs with
        # `component.tabs` and setting a tab with `component.tab`
        define_method singular_name do |*args, **kwargs, &block|
          # TODO raise here if attempting to get a collection slot using a singular method name?
          # e.g. `component.item` with `with_slot :item, collection: true`
          set_slot(slot_name, *args, **kwargs, &block)
        end

        # Instantiates and and adds multiple slots forwarding the first
        # argument to each slot constructor
        define_method slot_name do |*args, **kwargs, &block|
          if args.empty? && kwargs.empty? && block.nil?
            get_slot(slot_name)
          end
        end

        register_slot(slot_name, collection: true, callable: callable)
      end

      # Clone slot configuration into child class
      # see #test_slots_pollution
      def inherited(child)
        child.registered_slots = self.registered_slots.clone
        super
      end

      private

      def register_slot(slot_name, collection:, callable:)
        # Setup basic slot data
        slot = {
          collection: collection,
        }
        # If callable responds to `render_in`, we set it on the slot as a renderable
        if callable && callable.respond_to?(:method_defined?) && callable.method_defined?(:render_in)
          slot[:renderable] = callable
        elsif callable.is_a?(String)
          # If callable is a string, we assume it's referencing an internal class
          slot[:renderable_class_name] = callable
        elsif callable
          # If slot does not respond to `render_in`, we assume it's a proc,
          # define a method, and save a reference to it to call when setting
          method_name = :"_call_#{slot_name}"
          define_method method_name, &callable
          slot[:renderable_function] = instance_method(method_name)
        end

        # Register the slot on the component
        self.registered_slots[slot_name] = slot
      end

      def validate_slot_name(slot_name)
        if self.registered_slots.key?(slot_name)
          # TODO remove? This breaks overriding slots when slots are inherited
          raise ArgumentError.new("#{slot_name} slot declared multiple times")
        end
      end
    end

    def get_slot(slot_name)
      slot = self.class.registered_slots[slot_name]
      @_set_slots ||= {}

      if @_set_slots[slot_name]
        return @_set_slots[slot_name]
      end

      if slot[:collection]
        []
      else
        nil
      end
    end

    def set_slot(slot_name, *args, **kwargs, &block)
      slot = self.class.registered_slots[slot_name]

      slot_instance = SubComponentWrapper.new(self)
      slot_instance._content_block = block if block_given?

      if slot[:renderable]
        slot_instance._component_instance = slot[:renderable].new(*args, **kwargs)
      elsif slot[:renderable_class_name]
        slot_instance._component_instance = self.class.const_get(slot[:renderable_class_name]).new(*args, **kwargs)
      elsif slot[:renderable_function]
        renderable_value = slot[:renderable_function].bind(self).call(*args, **kwargs, &block)

        # Function calls can return components, so if it's a component handle it specially
        if renderable_value.respond_to?(:render_in)
          slot_instance._component_instance = renderable_value
        else
          slot_instance._content = renderable_value
        end
      end

      @_set_slots ||= {}

      if slot[:collection]
        @_set_slots[slot_name] ||= []
        @_set_slots[slot_name].push(slot_instance)
      else
        @_set_slots[slot_name] = slot_instance
      end

      nil
    end
  end
end
