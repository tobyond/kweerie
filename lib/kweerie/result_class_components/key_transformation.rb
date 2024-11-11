# frozen_string_literal: true

module ResultClassComponents
  module KeyTransformation
    def deep_stringify_keys(obj)
      case obj
      when Hash
        obj.transform_keys(&:to_s)
           .transform_values { |v| deep_stringify_keys(v) }
      when Array
        obj.map { |item| item.is_a?(Hash) ? deep_stringify_keys(item) : item }
      else
        obj
      end
    end

    def deep_symbolize_keys(obj)
      case obj
      when Hash
        obj.transform_keys(&:to_sym)
           .transform_values { |v| deep_symbolize_keys(v) }
      when Array
        obj.map { |item| item.is_a?(Hash) ? deep_symbolize_keys(item) : item }
      else
        obj
      end
    end
  end
end
