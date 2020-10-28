# frozen_string_literal: true

require "active_support/concern"

require "view_component/slot"

module ViewComponent
  module Slotable
    ##
    # Version 2 of the Slots API
    module V2
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
        # helper method with the same name as the slot (pluralized if the slot
        # is a collection).
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
            else
              # Support instantiating collection slots with an enumerable
              # object
              slot_collection = args.shift
              slot_collection.each do |collection_item|
                set_slot(slot_name, collection_item, *args, **kwargs, &block)
              end
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
          slot_class = Class.new(ViewComponent::Slot)
          slot_class.class_eval(&block) if block_given?

          # Register the slot on the component
          self.registered_slots[slot_name] = {
            klass: slot_class,
            instance_variable_name: :"@#{slot_name}",
            collection: collection,
            callable: callable
          }
        end

        def validate_slot_name(slot_name)
          if self.registered_slots.key?(slot_name)
            # TODO remove? This breaks overriding slots when slots are inherited
            raise ArgumentError.new("#{slot_name} slot declared multiple times")
          end
        end
      end

      def get_slot(slot_name)
        unless self.class.registered_slots.keys.include?(slot_name)
          raise ArgumentError.new "Unknown slot '#{slot_name}' - expected one of '#{self.class.registered_slots.keys}'"
        end

        slot = self.class.registered_slots[slot_name]
        slot_instance_variable_name = slot[:instance_variable_name]

        if instance_variable_defined?(slot_instance_variable_name)
          return instance_variable_get(slot_instance_variable_name)
        end

        if slot[:collection]
          []
        else
          nil
        end
      end

      def set_slot(slot_name, *args, **kwargs, &block)
        unless self.class.registered_slots.keys.include?(slot_name)
          raise ArgumentError.new "Unknown slot '#{slot_name}' - expected one of '#{self.class.registered_slots.keys}'"
        end

        slot = self.class.registered_slots[slot_name]
        slot_instance_variable_name = slot[:instance_variable_name]

        slot_instance = Slot.new(self)
        slot_instance.content = view_context.capture(&block)

        if slot[:callable].is_a?(Class) && slot[:callable] < ViewComponent::Base
          result = slot[:callable].new(*args, **kwargs)
          slot_instance._component_instance = result
        elsif slot[:callable]
          result = slot_instance.instance_exec(*args, **kwargs, &slot[:callable])

          if result.class < ViewComponent::Base
            slot_instance._component_instance = result
          else
            slot_instance.content = result
          end
        end

        if slot[:collection]
          if !instance_variable_defined?(slot_instance_variable_name)
            instance_variable_set(slot_instance_variable_name, [])
          end

          instance_variable_get(slot_instance_variable_name) << slot_instance
        else
          instance_variable_set(slot_instance_variable_name, slot_instance)
        end

        nil
      end
    end
  end
end
