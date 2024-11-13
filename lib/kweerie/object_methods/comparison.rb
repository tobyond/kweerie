# frozen_string_literal: true

module ObjectMethods
  module Comparison
    def <=>(other)
      return nil unless other.is_a?(self.class)

      to_h <=> other.to_h
    end

    def ==(other)
      return false unless other.is_a?(self.class)

      to_h == other.to_h
    end

    def eql?(other)
      self == other
    end

    def hash
      to_h.hash
    end
  end
end
