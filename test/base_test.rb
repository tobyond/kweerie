# frozen_string_literal: true

require "test_helper"

class TestQuery < Kweerie::Base
  bind :name, as: "$1"
  bind :email, as: "$2"
end

class BaseTest < Minitest::Test
  include KweerieTestHelpers

  def setup
    super
    create_sql_file(TestQuery, <<~SQL)
      SELECT *
      FROM users
      WHERE name = $1
        AND email = $2
    SQL
  end

  def test_bindings_are_class_specific
    # Create a second test class
    klass = Class.new(Kweerie::Base) do
      bind :title, as: "$1"
    end
    Object.const_set(:AnotherTestQuery, klass)

    refute_equal TestQuery.bindings, AnotherTestQuery.bindings
    assert_equal({ name: "$1", email: "$2" }, TestQuery.bindings)
    assert_equal({ title: "$1" }, AnotherTestQuery.bindings)
  ensure
    Object.send(:remove_const, :AnotherTestQuery)
  end

  def test_requires_all_parameters
    error = assert_raises(ArgumentError) do
      TestQuery.with(name: "Test")
    end
    assert_match(/Missing required parameters: email/, error.message)
  end

  def test_rejects_extra_parameters
    error = assert_raises(ArgumentError) do
      TestQuery.with(name: "Test", email: "test@example.com", extra: "param")
    end
    assert_match(/Unknown parameters provided: extra/, error.message)
  end

  def test_executes_query_with_correct_parameters
    TestQuery.with(name: "Test User", email: "test@example.com")

    last_query = @mock_connection.exec_params_calls.last
    assert_equal ["Test User", "test@example.com"], last_query[:params]
  end
end
