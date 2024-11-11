# frozen_string_literal: true

module ResultClassComponents
  module Attributes
    def self.included(base)
      base.include(TypeCasting)
      base.include(KeyTransformation)
    end

    def initialize(attrs)
      store_original_attributes(attrs)
      set_instance_variables(attrs)
      super() if defined?(super)
    end

    private

    def store_original_attributes(attrs)
      @_raw_original_attributes = attrs.dup
      @_original_attributes = attrs.transform_keys(&:to_s)
                                   .transform_values { |v| type_cast_value(v) }
    end

    def set_instance_variables(attrs)
      attrs.each do |name, value|
        instance_variable_set("@#{name}", type_cast_value(value))
      end
    end
  end
end
