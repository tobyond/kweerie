# frozen_string_literal: true

require "test_helper"

class TestObjectQuery < Kweerie::BaseObjects
  bind :name, as: "$1"

  attr_accessor :custom_attr
end

class NoBindingsObjectQuery < Kweerie::BaseObjects
end

class BaseObjectsTest < Minitest::Test
  include KweerieTestHelpers

  def setup
    super
    create_sql_file(TestObjectQuery, <<~SQL)
      SELECT#{" "}
        'Test User' as name,
        'test@example.com' as email,
        '2024-01-01 10:00:00' as created_at,
        '42' as age,
        '3.14' as score,
        'true' as active,
        '{"role": "admin", "preferences": {"theme": "dark"}}' as metadata,
        '["ruby", "rails"]' as tags
      FROM users
      WHERE name = $1
    SQL
  end

  def test_returns_objects_with_attribute_readers
    result = TestObjectQuery.with(name: "Test User")
    record = result.first

    assert_equal "Test User", record.name
    assert_equal "test@example.com", record.email
  end

  def test_type_casting
    @mock_connection.results = [{
      "name" => "Test User",
      "email" => "test@example.com",
      "created_at" => "2024-01-01 10:00:00",
      "age" => "42",
      "score" => "3.14",
      "active" => "true",
      "metadata" => '{"role": "admin", "preferences": {"theme": "dark"}}',
      "tags" => '["ruby", "rails"]',
      "pg_int_array" => "{1,2,3}",
      "pg_string_array" => "{foo,bar}",
      "empty_array" => "{}"
    }]

    record = TestObjectQuery.with(name: "Test User").first

    # Test basic types
    assert_instance_of Time, record.created_at
    assert_equal 42, record.age
    assert_equal 3.14, record.score
    assert_equal true, record.active

    # Test JSONB
    assert_instance_of Hash, record.metadata
    assert_equal "admin", record.metadata["role"]
    assert_equal "dark", record.metadata["preferences"]["theme"]

    # Test JSON array
    assert_instance_of Array, record.tags
    assert_equal %w[ruby rails], record.tags

    # Test PostgreSQL arrays
    assert_equal [1, 2, 3], record.pg_int_array
    assert_equal %w[foo bar], record.pg_string_array
    assert_equal [], record.empty_array
  end

  def test_jsonb_parsing
    record = TestObjectQuery.with(name: "Test User").first

    # Test hash-like JSONB
    assert_instance_of Hash, record.metadata
    assert_equal "admin", record.metadata["role"]
    assert_equal "dark", record.metadata["preferences"]["theme"]

    # Test array-like JSONB
    assert_instance_of Array, record.tags
    assert_equal %w[ruby rails], record.tags
  end

  def test_hash_like_access
    record = TestObjectQuery.with(name: "Test User").first

    assert_equal "Test User", record[:name]
    assert_equal "test@example.com", record.fetch(:email)
    assert_equal "default", record.fetch(:missing, "default")
  end

  def test_comparison
    result = TestObjectQuery.with(name: "Test User")
    record1 = result.first
    record2 = result.first

    assert_equal record1, record2
    assert record1.eql?(record2)
    assert_equal record1.hash, record2.hash
  end

  def test_serialization
    record = TestObjectQuery.with(name: "Test User").first

    expected_hash = {
      "name" => "Test User",
      "email" => "test@example.com",
      "created_at" => record.created_at,
      "age" => 42,
      "score" => 3.14,
      "active" => true,
      "metadata" => {
        "role" => "admin",
        "preferences" => {
          "theme" => "dark"
        }
      },
      "tags" => %w[ruby rails],
      "pg_int_array" => [1, 2, 3],
      "pg_float_array" => [1.5, 2.5, 3.5],
      "pg_string_array" => %w[foo bar],
      "pg_boolean_array" => [true, false, true],
      "empty_array" => []
    }

    assert_equal expected_hash, record.to_h
    assert_equal expected_hash.to_json, record.to_json

    # Extra assertions to verify specific parts
    assert_equal [1, 2, 3], record.to_h["pg_int_array"]
    assert_equal %w[foo bar], record.to_h["pg_string_array"]
    assert_instance_of Array, record.to_h["empty_array"]
    assert_empty record.to_h["empty_array"]
  end

  def test_pattern_matching
    record = TestObjectQuery.with(name: "Test User").first

    # Test basic pattern matching
    case record
    in { name: "Test User", email: email }
      assert_equal "test@example.com", email
    else
      flunk "Pattern matching failed"
    end

    # Test nested pattern matching with JSONB
    case record
    in { metadata: { role: "admin", preferences: { theme: theme } } }
      assert_equal "dark", theme
    else
      flunk "Nested pattern matching failed"
    end

    # Test array pattern matching
    case record
    in { tags: [first, second] }
      assert_equal "ruby", first
      assert_equal "rails", second
    else
      flunk "Array pattern matching failed"
    end

    # Add a more complex pattern matching test
    case record
    in { name: String => name, metadata: { role: "admin" => role } }
      assert_equal "Test User", name
      assert_equal "admin", role
    else
      flunk "Complex pattern matching failed"
    end
  end

  def test_empty_results
    @mock_connection.results = []
    result = TestObjectQuery.with(name: "Nonexistent")
    assert_equal [], result
  end

  def test_comparable
    results = TestObjectQuery.with(name: "Test User")
    sorted_results = results.sort_by(&:age)
    assert_equal results, sorted_results
  end

  def test_changes_tracking
    record = TestObjectQuery.with(name: "Test User").first
    assert_equal record.to_h, record.original_attributes

    # Can't actually modify the record since attrs are read-only,
    # but we can test the changes interface
    record.instance_variable_set("@name", "Changed")

    assert record.changed?
    assert_equal({ "name" => ["Test User", "Changed"] }, record.changes)
  end

  def test_pg_array_parsing
    @mock_connection.results = [{
      "name" => "Test User",
      "pg_int_array" => "{1,2,3}",
      "pg_float_array" => "{1.5,2.5,3.5}",
      "pg_string_array" => '{foo,bar,"baz,qux"}',
      "empty_array" => "{}",
      "pg_boolean_array" => "{true,false,true}"
    }]

    record = TestObjectQuery.with(name: "Test User").first

    assert_equal [1, 2, 3], record.pg_int_array
    assert_equal [1.5, 2.5, 3.5], record.pg_float_array
    assert_equal ["foo", "bar", "baz,qux"], record.pg_string_array
    assert_equal [], record.empty_array
    assert_equal [true, false, true], record.pg_boolean_array
  end

  def test_returns_instances_of_calling_class
    record = TestObjectQuery.with(name: "Nayme").first

    assert record.is_a?(TestObjectQuery)
    assert record.respond_to?(:custom_attr)

    # Test that we can use the attr_accessor
    record.custom_attr = "test"
    assert_equal "test", record.custom_attr
  end

  def test_class_name_in_inspect
    record = TestObjectQuery.with(name: "Nayme").first
    assert_match(/^#<TestObjectQuery /, record.inspect)
  end

  def test_all_method_for_no_bindings
    create_sql_file(NoBindingsObjectQuery, <<~SQL)
      SELECT#{" "}
      'Test User' as name,
        'test@example.com' as email
    SQL

    results = NoBindingsObjectQuery.all
    assert_instance_of Array, results
    assert results.first.is_a?(NoBindingsObjectQuery)
    assert_equal "Test User", results.first.name
  end

  def test_all_raises_error_with_bindings
    error = assert_raises(ArgumentError) do
      TestObjectQuery.all
    end
    assert_match(/Cannot use .all on queries with bindings/, error.message)
  end
end
