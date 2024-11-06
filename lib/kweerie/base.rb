# frozen_string_literal: true

module Kweerie
  class Base
    class << self
      def inherited(subclass)
        subclass.instance_variable_set(:@bindings, {})
        super
      end

      def bind(param_name, as:)
        @bindings[param_name] = as
      end

      attr_reader :bindings

      def sql_path
        @sql_path ||= begin
          subclass_file = "#{name.underscore}.sql"
          possible_paths = Kweerie.configuration.sql_paths.call

          sql_file = possible_paths.map do |path|
            File.join(root_path, path, subclass_file)
          end.find { |f| File.exist?(f) }

          unless sql_file
            raise SQLFileNotFound,
                  "Could not find SQL file for #{name} in paths: #{possible_paths.join(", ")}"
          end

          sql_file
        end
      end

      def sql_content
        @sql_content ||= File.read(sql_path)
      end

      def with(params = {})
        validate_params!(params)
        param_values = order_params(params)

        connection = Kweerie.configuration.connection_provider.call
        result = connection.exec_params(sql_content, param_values)
        result.to_a
      end

      private

      def validate_params!(params)
        missing_params = bindings.keys - params.keys
        raise ArgumentError, "Missing required parameters: #{missing_params.join(", ")}" if missing_params.any?

        extra_params = params.keys - bindings.keys
        return unless extra_params.any?

        raise ArgumentError, "Unknown parameters provided: #{extra_params.join(", ")}"
      end

      def order_params(params)
        ordered_params = bindings.transform_values { |position| params[bindings.key(position)] }
        ordered_params.values
      end

      def root_path
        defined?(Rails) ? Rails.root : Dir.pwd
      end

      def using_activerecord?
        defined?(ActiveRecord::Base) &&
          Kweerie.configuration.connection_provider == Kweerie::Configuration.new.connection_provider
      end
    end
  end
end
