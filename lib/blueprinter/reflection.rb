# frozen_string_literal: true

module Blueprinter
  #
  # Public methods for reflecting on a Blueprint.
  #
  module Reflection
    Field = Struct.new(:name, :display_name, :options)
    Association = Struct.new(:name, :display_name, :blueprint, :view, :options)

    #
    # Returns a Hash of views keyed by name.
    #
    # Example:
    #
    #   widget_view = WidgetBlueprint.reflections[:default]
    #   category = widget_view.associations[:category]
    #   category.blueprint
    #   => CategoryBlueprint
    #   category.view
    #   => :default
    #
    # @return [Hash<Symbol, Blueprinter::Reflection::View>]
    #
    def reflections
      @reflections ||= view_collection.views.transform_values do |view|
        View.new(self, view)
      end
    end

    #
    # Represents a view within a Blueprint.
    #
    class View
      def initialize(blueprint, view)
        @blueprint = blueprint
        @view = view
      end

      # @return [String] The view's name
      def name
        @view.name
      end

      #
      # Returns a Hash of fields in this view (recursive) keyed by method name.
      #
      # @return [Hash<Symbol, Blueprinter::Reflection::Field>]
      #
      def fields
        @fields ||= @view.fields.each_with_object(included(:fields)) do |(_name, field), obj|
          next if field.options[:association]

          obj[field.method] = Field.new(field.method, field.name, field.options)
        end
      end

      #
      # Returns a Hash of associations in this view (recursive) keyed by method name.
      #
      # @return [Hash<Symbol, Blueprinter::Reflection::Association>]
      #
      def associations
        @associations ||= @view.fields.each_with_object(included(:associations)) do |(_name, field), obj|
          next unless field.options[:association]

          blueprint = field.options.fetch(:blueprint)
          view = field.options[:view] || :default
          obj[field.method] = Association.new(field.method, field.name, blueprint, view, field.options)
        end
      end

      private

      # Returns all fields or associations from included views
      def included(type)
        view_names = @view.included_view_names
        view_names.unshift :default unless name == :default

        view_names.reduce({}) do |acc, view_name|
          view = @blueprint.reflections.fetch(view_name)
          acc.merge view.send(type)
        end
      end
    end
  end
end
