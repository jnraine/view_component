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
        # = Rendering slot content
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
        # = Setting slot content
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
        def with_slot(slot_name, collection: false, &block)
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

          if collection
            # Define setter for singular names
            # e.g. `with_slot :tab, collection: true` allows fetching all tabs with
            # `component.tabs` and setting a tab with `component.tab`
            define_method slot_name do |*args, **kwargs, &block|
              # TODO raise here if attempting to get a collection slot using a singular method name?
              # e.g. `component.item` with `with_slot :item, collection: true`
              set_slot(slot_name, *args, **kwargs, &block)
            end

            # Instantiates and and adds multiple slots forwarding the first
            # argument to each slot constructor
            define_method accessor_name do |*args, **kwargs, &block|
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
          else
            # non-collection methods
            define_method accessor_name do |*args, **kwargs, &block|
              if args.empty? && kwargs.empty? && block.nil?
                get_slot(slot_name)
              else
                set_slot(slot_name, *args, **kwargs, &block)
              end
            end
          end

          slot_class = Class.new(ViewComponent::Slot)
          slot_class.class_eval(&block) if block_given?

          # Register the slot on the component
          self.registered_slots[slot_name] = {
            klass: slot_class,
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

      def set_slot(slot_name, *args, **kwargs, &block)
        unless self.class.registered_slots.keys.include?(slot_name)
          raise ArgumentError.new "Unknown slot '#{slot_name}' - expected one of '#{self.class.registered_slots.keys}'"
        end

        content_arg = nil

        if kwargs.has_key?(:content)
          content_arg = kwargs[:content]
          kwargs.except!(:content)
        end

        slot = self.class.registered_slots[slot_name]
        slot_instance_variable_name = slot[:instance_variable_name]
        slot_class = slot[:klass]

        slot_instance = if args.present? ||kwargs.present?
          slot_class.new(*args, **kwargs)
        else
          slot_class.new
        end

        if block_given? && content_arg
          raise ArgumentError.new "Slots can not be passed both a content argument and a block."
        end

        if block_given?
          slot_instance.content = view_context.capture(&block)
        end

        # TODO ensure slots don't have content methods
        if content_arg
          slot_instance.content = content_arg
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
