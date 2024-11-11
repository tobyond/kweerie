# frozen_string_literal: true

module ResultClassComponents
  module Changes
    def changed?
      to_h != @_original_attributes
    end

    def changes
      to_h.each_with_object({}) do |(key, value), changes|
        original = @_original_attributes[key]
        changes[key] = [original, value] if original != value
      end
    end
  end
end
