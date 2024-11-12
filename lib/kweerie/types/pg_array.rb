# frozen_string_literal: true

module Types
  class PgArray
    def cast(value)
      clean_value = value.gsub(/^{|}$/, "")
      return [] if clean_value.empty?

      elements = clean_value.split(/,(?=(?:[^"]*"[^"]*")*[^"]*$)/)
      elements.map { |element| cast_array_element(element) }
    end

    def cast_array_element(element)
      case element
      when /^\d+$/ then element.to_i
      when /^\d*\.\d+$/          then element.to_f
      when /^(true|false)$/i     then element.downcase == "true"
      when /^"(.*)"$/            then ::Regexp.last_match(1)
      else element
      end
    end
  end
end
