# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "kweerie"
require "minitest/autorun"
require "pg"
require "rails"
require "rails/generators"
require "rails/generators/test_case"

# Mock Rails.root for generator testing
module Rails
  def self.root
    Pathname.new(Dir.pwd)
  end
end

# Mock connection class to avoid real DB calls
class MockPGConnection
  attr_reader :exec_params_calls

  def initialize
    @exec_params_calls = []
  end

  def exec_params(sql, params)
    @exec_params_calls << { sql: sql, params: params }
    MockPGResult.new([{ "id" => 1, "name" => "Test User" }])
  end

  def close
    # No-op for testing
  end

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
