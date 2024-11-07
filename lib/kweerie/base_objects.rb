# frozen_string_literal: true

require "active_support/core_ext/string"
require "json"

module Kweerie
  class BaseObjects < Base
    class << self
      def with(params = {})
        results = super
        return [] if results.empty?

        # Create a unique result class for this query
        result_class = generate_result_class(results.first.keys)

        # Map results to objects
        results.map { |row| result_class.new(row) }
      end

      private

      def generate_result_class(attribute_names)
        @generate_result_class ||= Class.new(self) do
          # Include comparison and serialization modules
          include Comparable

          # Define attr_readers for all columns
          attribute_names.each do |name|
            attr_reader name
          end

          define_method :initialize do |attrs|
            # Store both raw and casted versions
            @_raw_original_attributes = attrs.dup
            @_original_attributes = attrs.transform_keys(&:to_s).transform_values do |value|
              type_cast_value(value)
            end

            attrs.each do |name, value|
              casted_value = type_cast_value(value)
              instance_variable_set("@#{name}", casted_value)
            end
            super() if defined?(super)
          end

          define_method :type_cast_value do |value|
            case value
            when /^\d{4}-\d{2}-\d{2}( \d{2}:\d{2}:\d{2})?$/ # DateTime check
              Time.parse(value)
            when /^\d+$/ # Integer check
              value.to_i
            when /^\d*\.\d+$/ # Float check
              value.to_f
            when /^(true|false)$/i # Boolean check
              value.downcase == "true"
            when /^{.*}$/ # Could be PG array or JSON
              if value.start_with?("{") && value.end_with?("}") && !value.include?('"=>') && !value.include?(": ")
                # PostgreSQL array (simple heuristic: no "=>" or ":" suggests it's not JSON)
                parse_pg_array(value)
              else
                # Attempt JSON parse
                begin
                  parsed = JSON.parse(value)
                  deep_stringify_keys(parsed)
                rescue JSON::ParserError
                  value
                end
              end
            when /^[\[{]/ # Pure JSON (arrays starting with [ or other JSON objects)
              begin
                parsed = JSON.parse(value)
                deep_stringify_keys(parsed)
              rescue JSON::ParserError
                value
              end
            else
              value
            end
          end

          define_method :parse_pg_array do |value|
            # Remove the curly braces
            clean_value = value.gsub(/^{|}$/, "")
            return [] if clean_value.empty?

            # Split on comma, but not within quoted strings
            elements = clean_value.split(/,(?=(?:[^"]*"[^"]*")*[^"]*$)/)

            elements.map do |element|
              case element
              when /^\d+$/ # Integer
                element.to_i
              when /^\d*\.\d+$/ # Float
                element.to_f
              when /^(true|false)$/i # Boolean
                element.downcase == "true"
              when /^"(.*)"$/ # Quoted string
                ::Regexp.last_match(1)
              else
                element
              end
            end
          end

          define_method :deep_symbolize_keys do |obj|
            case obj
            when Hash
              obj.transform_keys(&:to_sym).transform_values { |v| deep_symbolize_keys(v) }
            when Array
              obj.map { |item| item.is_a?(Hash) ? deep_symbolize_keys(item) : item }
            else
              obj
            end
          end

          # Nice inspect output
          define_method :inspect do
            attrs = attribute_names.map do |name|
              "#{name}=#{instance_variable_get("@#{name}").inspect}"
            end.join(" ")
            "#<#{self.class.superclass.name} #{attrs}>"
          end

          # Hash-like access
          define_method :[] do |key|
            instance_variable_get("@#{key}")
          end

          define_method :fetch do |key, default = nil|
            instance_variable_defined?("@#{key}") ? instance_variable_get("@#{key}") : default
          end

          # Comparison methods
          define_method :<=> do |other|
            return nil unless other.is_a?(self.class)

            to_h <=> other.to_h
          end

          define_method :== do |other|
            return false unless other.is_a?(self.class)

            to_h == other.to_h
          end

          define_method :eql? do |other|
            self == other
          end

          define_method :hash do
            to_h.hash
          end

          # Add helper method for deep string keys
          define_method :deep_stringify_keys do |obj|
            case obj
            when Hash
              obj.transform_keys(&:to_s).transform_values { |v| deep_stringify_keys(v) }
            when Array
              obj.map { |item| item.is_a?(Hash) ? deep_stringify_keys(item) : item }
            else
              obj
            end
          end

          # Serialization
          define_method :to_h do
            attribute_names.each_with_object({}) do |name, hash|
              value = instance_variable_get("@#{name}")
              # Ensure string keys in output
              hash[name.to_s] = value.is_a?(Hash) ? deep_stringify_keys(value) : value
            end
          end

          define_method :to_json do |*args|
            to_h.to_json(*args)
          end

          # Pattern matching support (Ruby 2.7+)
          define_method :deconstruct_keys do |keys|
            symbolized = deep_symbolize_keys(to_h)
            keys ? symbolized.slice(*keys) : symbolized
          end

          # Original attributes access
          define_method :original_attributes do
            @_original_attributes
          end

          # Raw attributes access
          define_method :raw_original_attributes do
            @_raw_original_attributes
          end

          # ActiveModel-like changes tracking
          define_method :changed? do
            to_h != @_original_attributes
          end

          define_method :changes do
            to_h.each_with_object({}) do |(key, value), changes|
              original = @_original_attributes[key]
              changes[key] = [original, value] if original != value
            end
          end
        end
      end
    end
  end
end
