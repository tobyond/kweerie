# frozen_string_literal: true

require_relative "result_class_components/accessors"
require_relative "result_class_components/attributes"
require_relative "result_class_components/changes"
require_relative "result_class_components/comparison"
require_relative "result_class_components/key_transformation"
require_relative "result_class_components/serialization"
require_relative "result_class_components/type_casting"

module Kweerie
  class ResultClassGenerator
    def self.generate(parent_class, attribute_names)
      Class.new(parent_class) do
        include Comparable
        include ResultClassComponents::Attributes
        include ResultClassComponents::Serialization
        include ResultClassComponents::Comparison
        include ResultClassComponents::Changes
        include ResultClassComponents::Accessors

        # Define attr_readers for all columns
        attribute_names.each { |name| attr_reader name }

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
