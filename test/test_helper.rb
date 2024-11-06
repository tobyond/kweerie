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

    # Create temp dir and set Rails.root
    @temp_dir = File.join(Dir.pwd, "test/temp")
    FileUtils.mkdir_p(@temp_dir)
    Rails.root = Pathname.new(@temp_dir)

    # Now configure sql_paths
    Kweerie.configure do |config|
      config.sql_paths = -> { [""] } # Empty string because we're already at the root
    end
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
    Rails.root = nil
  end

  def create_sql_file(class_name, content)
    filename = "#{class_name.to_s.underscore}.sql"
    File.write(File.join(@temp_dir, filename), content)
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
      "tags" => '["ruby", "rails"]'
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
