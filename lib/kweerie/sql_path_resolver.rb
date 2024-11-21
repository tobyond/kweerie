# frozen_string_literal: true

class SQLPathResolver
  class ConfigurationError < StandardError; end
  class SQLFileNotFound < StandardError; end

  def initialize(sql_file_location, name = nil)
    @sql_file_location = sql_file_location
    @name = name
  end

  def resolve
    return resolve_root_path if root_path?
    return resolve_relative_path if relative_path?

    resolve_default_path
  end

  private

  attr_reader :sql_file_location, :name

  def root_path?
    sql_file_location&.key?(:root)
  end

  def relative_path?
    sql_file_location&.key?(:relative)
  end

  def resolve_root_path
    raise ConfigurationError, "Root path requires Rails to be defined" unless defined?(Rails)

    path = Rails.root.join(sql_file_location[:root]).to_s
    validate_file_exists!(path)
    path
  end

  def resolve_relative_path
    relative_file = sql_file_location[:relative]
    find_in_configured_paths(relative_file) or
      raise SQLFileNotFound, "Could not find SQL file #{relative_file}"
  end

  def resolve_default_path
    raise ArgumentError, "Name must be provided for default path resolution" unless name

    sql_filename = "#{name.underscore}.sql"
    find_in_configured_paths(sql_filename) or
      raise SQLFileNotFound, "SQL file not found for #{name}"
  end

  def find_in_configured_paths(filename)
    full_path = File.join(path, filename)

    full_path if File.exist?(full_path)
  end

  def path
    Kweerie.configuration.default_path
  end

  def validate_file_exists!(path)
    raise SQLFileNotFound, "Could not find SQL file at #{path}" unless File.exist?(path)
  end
end
