# frozen_string_literal: true

module Types
  class Boolean
    TRUTHY = [true, 1, "1", "t", "T", "true", "TRUE"].freeze
    FALSEY = [false, 0, "0", "f", "F", "false", "FALSE"].freeze

    def cast(value)
      return nil if value.nil?
      return value if value.is_a?(Boolean)

      if TRUTHY.include?(value)
        true
      elsif FALSEY.include?(value)
        false
      else
        raise ArgumentError, "Invalid boolean value: #{value}"
      end
    end
  end
end
