# frozen_string_literal: true

require "test_helper"

class TestQuery1 < Kweerie::Base
  bind :name, as: "$1"
end

class TestQuery2 < Kweerie::Base
  bind :email, as: "$1"
end

class KweerieBaseTest < Minitest::Test
  def setup
    Kweerie.reset_configuration!

    # Set up a mock connection provider
    @mock_connection = MockPGConnection.new
    Kweerie.configure do |config|
      config.connection_provider = -> { @mock_connection }
    end

    # Create a temporary directory for SQL files
    @temp_dir = File.join(Dir.pwd, "test/temp")
    FileUtils.mkdir_p(@temp_dir)

    # Configure Kweerie to look in our temp directory
    Kweerie.configure do |config|
      config.sql_paths = -> { [@temp_dir] }
    end
  end

  def teardown
    # Clean up temporary files
    FileUtils.rm_rf(@temp_dir)
  end

  def test_bindings_are_class_specific
    refute_equal TestQuery1.bindings, TestQuery2.bindings
    assert_equal({ name: "$1" }, TestQuery1.bindings)
    assert_equal({ email: "$1" }, TestQuery2.bindings)
  end

  def test_requires_all_parameters
    # Instead of defining a class, we'll use a test class defined at the top level
    klass = Class.new(Kweerie::Base) do
      bind :name, as: "$1"
      bind :email, as: "$2"
    end
    Object.const_set(:TestQuery3, klass)

    error = assert_raises(ArgumentError) do
      TestQuery3.with(name: "Test")
    end
    assert_match(/Missing required parameters: email/, error.message)

    Object.send(:remove_const, :TestQuery3)
  end

  # ... rest of the tests ...

  private

  def create_test_query_class(&block)
    Object.send(:remove_const, :TestQuery) if Object.const_defined?(:TestQuery)

    klass = Class.new(Kweerie::Base)
    klass.class_eval(&block) if block_given?
    Object.const_set(:TestQuery, klass)
  end

  def create_sql_file(content)
    File.write(File.join(@temp_dir, "test_query.sql"), content)
  end
end
