# frozen_string_literal: true

module Kweerie
  class Base
    class << self
      def inherited(subclass)
        subclass.instance_variable_set(:@bindings, {})
        subclass.instance_variable_set(:@class_location, caller_locations(1, 1)[0].path)
        super
      end

      # == Parameter Binding
      #
      # Binds a parameter to a SQL placeholder. Parameters are required by default and
      # must be provided when executing the query.
      #
      # === Options
      #
      # * <tt>:as</tt> - The SQL placeholder (e.g., '$1', '$2') that this parameter maps to
      #
      # === Examples
      #
      #   class UserSearch < Kweerie::Base
      #     # Single parameter
      #     bind :name, as: '$1'
      #
      #     # Multiple parameters
      #     bind :email, as: '$2'
      #     bind :status, as: '$3'
      #   end
      #
      #   # Using the query
      #   UserSearch.with(
      #     name: 'Eclipsoid',
      #     email: '%@example.com',
      #     status: 'active'
      #   )
      #
      # === Notes
      #
      # * Parameters must be provided in the order they appear in the SQL
      # * All bound parameters are required
      # * Use PostgreSQL's COALESCE for optional parameters
      #
      def bind(param_name, as:)
        @bindings[param_name] = as
      end

      attr_reader :bindings

      # == SQL File Location
      #
      # Specifies the location of the SQL file for this query. By default, Kweerie looks for
      # an SQL file with the same name as the query class in the same directory.
      #
      # === Options
      #
      # * <tt>:default</tt> - Use default file naming (class_name.sql in same directory)
      # * <tt>root: 'path'</tt> - Path relative to Rails.root
      # * <tt>relative: 'path'</tt> - Path relative to the query class file
      #
      # === Examples
      #
      #   class UserSearch < Kweerie::Base
      #     # Default behavior - looks for user_search.sql in same directory
      #     sql_file_location :default
      #
      #     # Use a specific file from Rails root
      #     sql_file_location root: 'db/queries/complex_user_search.sql'
      #
      #     # Use a file relative to this class
      #     sql_file_location relative: '../sql/user_search.sql'
      #   end
      #
      # === Notes
      #
      # * Root paths require Rails to be defined
      # * Paths should use forward slashes even on Windows
      # * File extensions should be included in the path
      # * Relative paths are relative to the query class file location
      #
      def sql_file_location(location = :default)
        @sql_file_location =
          case location
          when :default
            nil
          when Hash
            if location.key?(:root)
              { root: location[:root].to_s }
            elsif location.key?(:relative)
              { relative: location[:relative].to_s }
            else
              raise ArgumentError,
                    "Invalid sql_file_location option. Use :default, root: 'path', or relative: 'path'"
            end
          else
            raise ArgumentError,
                  "Invalid sql_file_location option. Use :default, root: 'path', or relative: 'path'"
          end
      end

      def sql_path
        @sql_path ||= SQLPathResolver.new(@sql_file_location, name).resolve
      end

      def sql_content
        @sql_content ||= File.read(sql_path)
      end

      # == Execute Query with Parameters
      #
      # Executes the SQL query with the provided parameters. All bound parameters must be provided
      # unless using .all for parameter-free queries.
      #
      # === Parameters
      #
      # * <tt>params</tt> - Hash of parameter names and values that match the bound parameters
      #
      # === Returns
      #
      # Array of hashes representing the query results. When using Kweerie::BaseObject,
      # returns array of typed objects instead.
      #
      # === Examples
      #
      #   # With parameters
      #   UserSearch.with(
      #     name: 'Eclipsoid',
      #     email: '%@example.com'
      #   )
      #   # => [{"id"=>1, "name"=>"Eclipsoid", "email"=>"eclipsoid@example.com"}]
      #
      #   # With type casting (BaseObject)
      #   UserSearch.with(created_after: '2024-01-01')
      #   # => [#<UserSearch id=1 created_at=2024-01-01 00:00:00 +0000>]
      #
      # === Notes
      #
      # * Raises ArgumentError if required parameters are missing
      # * Raises ArgumentError if extra parameters are provided
      # * Returns empty array if no results found
      # * Parameters are bound safely using pg-ruby's parameter binding
      #
      def with(params = {})
        validate_params!(params)
        param_values = order_params(params)

        connection = Kweerie.configuration.connection_provider.call
        result = connection.exec_params(sql_content, param_values)
        result.to_a
      end

      def all
        raise ArgumentError, "Cannot use .all on queries with bindings. Use .with instead." if bindings.any?

        with
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
