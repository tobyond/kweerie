# frozen_string_literal: true

module ResultClassComponents
  module Accessors
    def [](key)
      instance_variable_get("@#{key}")
    end

    def fetch(key, default = nil)
      instance_variable_defined?("@#{key}") ? instance_variable_get("@#{key}") : default
    end

    def original_attributes
      @_original_attributes
    end

    def raw_original_attributes
      @_raw_original_attributes
    end
  end
end
