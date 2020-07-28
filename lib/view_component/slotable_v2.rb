# frozen_string_literal: true

require "active_support/concern"

require "view_component/slot"

module ViewComponent
  module Slotable
    module V2
      extend ActiveSupport::Concern

      # Setup component slot state
      included do
        # Hash of registered Slots
        class_attribute :registered_slots
        self.registered_slots = {}
      end

      class_methods do
        # Registers a slot on a component
        #
        # with_slot(
        #   :header,
        #   collection: true|false,
        #   class_name: "Header" # class name string, used to instantiate Slot
        # )
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

          # Used to get, and set values
          define_method accessor_name do |**args, &block|
            slot_for!(slot_name, **args, &block)
          end

          # Define setter for singular names
          # e.g. `with_slot :tab` allows fetching all tabs with
          # `component.tabs` and setting a tab with `component.tab`
          if collection
            define_method slot_name do |**args, &block|
              set_slot_for(slot_name, **args, &block)
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

      def slot_for(slot_name, **args, &block)
        unless self.class.registered_slots.keys.include?(slot_name)
          raise ArgumentError.new "Unknown slot '#{slot_name}' - expected one of '#{self.class.registered_slots.keys}'"
        end

        slot_for!(slot_name, **args, &block)
      end

      def slot_for!(slot_name, **args, &block)
        # Get registered slot
        slot = self.class.registered_slots[slot_name]

        slot_instance_variable_name = slot[:instance_variable_name]

        # If the variable is already set, and there is no block given, we can
        # safely assume that the slot is NOT being set in the view and can
        # return the slot
        if instance_variable_defined?(slot_instance_variable_name) && !block_given? && args.empty?
          return instance_variable_get(slot_instance_variable_name)
        end

        set_slot_for(slot_name, **args, &block)

        value = instance_variable_get(slot_instance_variable_name)

        # Ensure collections always return an array type
        if !value && slot[:collection]
          []
        else
          value
        end
      end

      def set_slot_for(slot_name, **args, &block)
        # TODO raise if no block given

        # Get registered slot
        slot = self.class.registered_slots[slot_name]
        slot_instance_variable_name = slot[:instance_variable_name]

        slot_class_name = slot[:class_name]
        slot_class = self.class.const_get(slot_class_name)

        unless slot_class <= ViewComponent::Slot
          raise ArgumentError.new "#{slot[:class_name]} must inherit from ViewComponent::Slot"
        end

        # Initialize slot
        slot_instance = if args.present?
          slot_class.new(**args)
        else
          slot_class.new
        end

        if block_given?
          slot_instance.content = view_context.capture(&block)

          if slot[:collection]
            if !instance_variable_defined?(slot_instance_variable_name)
              instance_variable_set(slot_instance_variable_name, [])
            end

            instance_variable_get(slot_instance_variable_name) << slot_instance
          else
            instance_variable_set(slot_instance_variable_name, slot_instance)
          end
        end

        nil
      end
    end
  end
end
