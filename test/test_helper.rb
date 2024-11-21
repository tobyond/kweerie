# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "kweerie"
require "minitest/autorun"
require "pg"
require "rails"
require "rails/generators"
require "rails/generators/test_case"

# Define Rails mock at the top level
module Rails
  @root = nil

  def self.root
    @root
  end

  def self.root=(path)
    @root = path
  end
end

module KweerieTestHelpers
  def setup
    Kweerie.reset_configuration!
    @mock_connection = MockPGConnection.new
    Kweerie.configure do |config|
      config.connection_provider = -> { @mock_connection }
    end

    @temp_dir = File.join(Dir.pwd, "test/temp")
    @queries_dir = File.join(@temp_dir, "queries")
    FileUtils.mkdir_p(@queries_dir)

    Rails.root = Pathname.new(@temp_dir)
    Kweerie.configure do |config|
      config.default_path = @queries_dir
    end
  end

  def create_sql_file(class_name, content, location = :default)
    case location
    when :root
      path = File.join(@temp_dir, class_name)
    when :relative
      path = File.join(@queries_dir, class_name)
    else
      filename = "#{class_name.to_s.underscore}.sql"
      path = File.join(@queries_dir, filename)
    end
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    path
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
    Rails.root = nil
  end
end

class MockPGConnection
  attr_accessor :results, :exec_params_calls

  def initialize
    @exec_params_calls = []
    @results = [{
      "name" => "Test User",
      "email" => "test@example.com",
      "created_at" => "2024-01-01 10:00:00",
      "age" => "42",
      "score" => "3.14",
      "active" => "true",
      "metadata" => '{"role": "admin", "preferences": {"theme": "dark"}}',
      "tags" => '["ruby", "rails"]',
      "pg_int_array" => "{1,2,3}",
      "pg_float_array" => "{1.5,2.5,3.5}",
      "pg_string_array" => "{foo,bar}",
      "pg_boolean_array" => "{true,false,true}",
      "empty_array" => "{}"
    }]
  end

  def exec_params(sql, params)
    @exec_params_calls << { sql: sql, params: params }
    MockPGResult.new(@results)
  end

  def close; end

  def finished?
    false
  end
end

class MockPGResult
  def initialize(results)
    @results = results
  end

  def to_a
    @results
  end
end
