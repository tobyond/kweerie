# frozen_string_literal: true

require_relative "kweerie/version"

module Kweerie
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class SQLFileNotFound < Error; end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

require_relative "kweerie/configuration"
require_relative "kweerie/base"
require_relative "kweerie/base_object"
require_relative "kweerie/sql_path_resolver"
require_relative "kweerie/result_class_generator"
require_relative "kweerie/types/boolean"
require_relative "kweerie/types/pg_array"
require_relative "kweerie/types/pg_jsonb"
