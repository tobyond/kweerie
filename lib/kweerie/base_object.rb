# frozen_string_literal: true

require_relative "object_methods/accessors"
require_relative "object_methods/comparison"
require_relative "object_methods/key_transformation"
require_relative "object_methods/serialization"
require_relative "object_methods/type_casting"

module Kweerie
  class BaseObject < Base
    class << self
      def with(params = {})
        results = super
        return [] if results.empty?

        # Create a unique result class for this query
        result_class = generate(results.first.keys)
        # Map results to objects
        results.map { |row| result_class.new(row) }
      end

      def cast_select(field, as: nil)
        cast_definitions[field] = as if as
      end

      def cast_definitions
        @cast_definitions ||= {}
      end

      def generate(attribute_names)
        cast_definitions = self.cast_definitions
        Class.new(self) do
          include Comparable
          include ObjectMethods::Accessors
          include ObjectMethods::Comparison
          include ObjectMethods::KeyTransformation
          include ObjectMethods::Serialization
          include ObjectMethods::TypeCasting

          # Define attr_readers for all columns
          attribute_names.each { |name| attr_reader name }

          define_method :initialize do |attrs|
            # Store both raw and casted versions
            @_raw_original_attributes = attrs.dup
            @_original_attributes = attrs.each_with_object({}) do |(key, value), hash|
              type_definition = cast_definitions[key.to_sym]
              casted_value = type_cast_value(value, type_definition)
              hash[key.to_s] = casted_value
              instance_variable_set("@#{key}", casted_value)
            end

            super() if defined?(super)
          end

          # Nice inspect output
          define_method :inspect do
            attrs = attribute_names.map do |name|
              "#{name}=#{instance_variable_get("@#{name}").inspect}"
            end.join(" ")
            "#<#{self.class.superclass.name} #{attrs}>"
          end

          # Make attribute_names available to instance methods
          define_method(:attribute_names) { attribute_names }
        end
      end
    end
  end
end
