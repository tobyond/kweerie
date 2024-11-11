# frozen_string_literal: true

module ResultClassComponents
  module TypeCasting
    def type_cast_value(value)
      case value
      when /^\d{4}-\d{2}-\d{2}( \d{2}:\d{2}:\d{2})?$/
        Time.parse(value)
      when /^\d+$/
        value.to_i
      when /^\d*\.\d+$/
        value.to_f
      when /^(true|false)$/i
        value.downcase == "true"
      when /^{.*}$/
        cast_complex_type(value)
      when /^[\[{]/
        cast_json(value)
      else
        value
      end
    end

    private

    def cast_complex_type(value)
      if postgresql_array?(value)
        parse_pg_array(value)
      else
        cast_json(value)
      end
    end

    def postgresql_array?(value)
      value.start_with?("{") &&
        value.end_with?("}") &&
        !value.include?('"=>') &&
        !value.include?(": ")
    end

    def cast_json(value)
      JSON.parse(value).then { |parsed| deep_stringify_keys(parsed) }
    rescue JSON::ParserError
      value
    end

    def parse_pg_array(value)
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
