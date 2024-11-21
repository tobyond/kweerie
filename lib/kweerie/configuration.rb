# frozen_string_literal: true

module Kweerie
  class Configuration
    attr_accessor :connection_provider, :sql_paths, :default_path

    def initialize
      # Default to using ActiveRecord's connection if available
      @connection_provider = lambda {
        unless defined?(ActiveRecord::Base)
          raise ConfigurationError, "No connection provider configured and ActiveRecord is not available"
        end

        ActiveRecord::Base.connection.raw_connection
      }

      # Default SQL paths
      @sql_paths = lambda {
        paths = ["app/queries"]
        paths.unshift("lib/queries") unless defined?(Rails)
        paths
      }

      @default_path = defined?(Rails) ? "app/queries" : "lib/queries"
    end
  end
end
