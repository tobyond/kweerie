# frozen_string_literal: true

module ResultClassComponents
  module TypeCasting
    def type_cast_value(value, type_definition)
      return value if type_definition.nil?

      case type_definition
      when Symbol
        public_send(type_definition, value)
      when Proc
        type_definition.call(value)
      when Class
        type_definition.new.cast(value)
      else
        raise ArgumentError, "Unsupported type definition: #{type_definition}"
      end
    end
  end
end
