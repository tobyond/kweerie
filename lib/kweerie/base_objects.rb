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
        @generate_result_class ||= ResultClassGenerator.generate(self, attribute_names)
      end
    end
  end
end
