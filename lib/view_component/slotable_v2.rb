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
        #   with_slot(
        #     :item,
        #     collection: true,
        #     class_name: "Item" # class name string, used to instantiate Slot
        #   )
        #
        #   class Item < ViewComponent::Slot
        #     def initialize;end
        #   end
        #
        # The component's sidecar template can access the slot by calling a
        # helper method with the same name as the slot (pluralized if the slot
        # is a collection).
        #
        #   <h1>
        #     <%= items.each do |item| %>
        #       <%= item.content %>
        #     <% end %>
        #   </h1>
        #
        # Renderers of the component can set the content of a slot by calling a
        # helper method with the same name as the slot. For collection
        # components, the method can be called multiple times to append to the
        # slot.
        #
        #   <%= render_inline(MyComponent.new) do |component| %>
        #     <%= component.item do %>
        #       <p>One</p>
        #     <% end %>
        #
        #     <%= component.item do %>
        #       <p>two</p>
        #     <% end %>
        #   <% end %>
        def with_slot(slot_name, collection: false, class_name: nil)
          if self.registered_slots.key?(slot_name)
            raise ArgumentError.new("#{slot_name} slot declared multiple times")
          end

          # Ensure slot name is not :content
          if slot_name == :content
            raise ArgumentError.new ":content is a reserved slot name. Please use another name, such as ':body'"
          end

          accessor_name = if collection
            ActiveSupport::Inflector.pluralize(slot_name)
          else
            slot_name
          end

          # Defines the method to access slots and set slot values
          define_method accessor_name do |**args, &block|
            if args.empty? && block.nil?
              get_slot(slot_name)
            else
              set_slot(slot_name, **args, &block)
            end
          end

          # Define setter for singular names
          # e.g. `with_slot :tab` allows fetching all tabs with
          # `component.tabs` and setting a tab with `component.tab`
          if collection
            define_method slot_name do |**args, &block|
              set_slot(slot_name, **args, &block)
            end
          end

          # Default class_name to ViewComponent::Slot
          class_name = "ViewComponent::Slot" unless class_name.present?

          # Register the slot on the component
          self.registered_slots[slot_name] = {
            class_name: class_name,
            instance_variable_name: :"@#{slot_name}",
            collection: collection
          }
        end

        # Clone slot configuration into child class
        # see #test_slots_pollution
        def inherited(child)
          child.registered_slots = self.registered_slots.clone
          super
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

      def set_slot(slot_name, **args, &block)
        unless self.class.registered_slots.keys.include?(slot_name)
          raise ArgumentError.new "Unknown slot '#{slot_name}' - expected one of '#{self.class.registered_slots.keys}'"
        end

        slot = self.class.registered_slots[slot_name]
        slot_instance_variable_name = slot[:instance_variable_name]
        slot_class = slot_class_for(slot_name)

        slot_instance = if args.present?
          slot_class.new(**args)
        else
          slot_class.new
        end

        if block_given?
          slot_instance.content = view_context.capture(&block) if block_given?
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

      def slot_class_for(slot_name)
        slot = self.class.registered_slots[slot_name]
        slot_instance_variable_name = slot[:instance_variable_name]

        slot_class_name = slot[:class_name]
        slot_class = self.class.const_get(slot_class_name)

        unless slot_class <= ViewComponent::Slot
          raise ArgumentError.new "#{slot[:class_name]} must inherit from ViewComponent::Slot"
        end

        slot_class
      end
    end
  end
end
