# frozen_string_literal: true

module ResultClassComponents
  module Serialization
    def to_h
      attribute_names.each_with_object({}) do |name, hash|
        value = instance_variable_get("@#{name}")
        hash[name.to_s] = serialize_value(value)
      end
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def deconstruct_keys(keys)
      symbolized = deep_symbolize_keys(to_h)
      keys ? symbolized.slice(*keys) : symbolized
    end

    private

    def serialize_value(value)
      value.is_a?(Hash) ? deep_stringify_keys(value) : value
    end
  end
end
