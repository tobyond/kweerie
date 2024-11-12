# frozen_string_literal: true

module Types
  class PgJsonb
    def cast(value)
      return {} if value.nil?
      return value if value.is_a?(Hash)

      JSON.parse(value.to_s)
    rescue JSON::ParserError
      raise ArgumentError, "Invalid JSON value: #{value}"
    end
  end
end
