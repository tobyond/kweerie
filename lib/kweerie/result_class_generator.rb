# frozen_string_literal: true

require_relative "result_class_components/accessors"
require_relative "result_class_components/comparison"
require_relative "result_class_components/key_transformation"
require_relative "result_class_components/serialization"
require_relative "result_class_components/type_casting"

module Kweerie
  class ResultClassGenerator
    def self.generate(parent_class, attribute_names)
      Class.new(parent_class) do
        include Comparable
        include ResultClassComponents::Accessors
        include ResultClassComponents::Comparison
        include ResultClassComponents::KeyTransformation
        include ResultClassComponents::Serialization
        include ResultClassComponents::TypeCasting

        # Define attr_readers for all columns
        attribute_names.each { |name| attr_reader name }

        define_method :initialize do |attrs|
          # Store both raw and casted versions
          cast_definitions = parent_class.cast_definitions

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
