# frozen_string_literal: true

require "test_helper"

class TestObjectQuery < Kweerie::BaseObjects
  bind :name, as: '$1'
end

class BaseObjectsTest < Minitest::Test
  include KweerieTestHelpers

  def setup
    super
    create_sql_file(TestObjectQuery, <<~SQL)
      SELECT 
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
    result = TestObjectQuery.with(name: 'Test User')
    record = result.first
    
    assert_equal 'Test User', record.name
    assert_equal 'test@example.com', record.email
  end

  def test_type_casting
    record = TestObjectQuery.with(name: 'Test User').first
    
    assert_instance_of Time, record.created_at
    assert_equal 42, record.age
    assert_equal 3.14, record.score
    assert_equal true, record.active
  end

  def test_jsonb_parsing
    record = TestObjectQuery.with(name: 'Test User').first
    
    # Test hash-like JSONB
    assert_instance_of Hash, record.metadata
    assert_equal "admin", record.metadata["role"]
    assert_equal "dark", record.metadata["preferences"]["theme"]
    
    # Test array-like JSONB
    assert_instance_of Array, record.tags
    assert_equal ["ruby", "rails"], record.tags
  end

  def test_hash_like_access
    record = TestObjectQuery.with(name: 'Test User').first
    
    assert_equal 'Test User', record[:name]
    assert_equal 'test@example.com', record.fetch(:email)
    assert_equal 'default', record.fetch(:missing, 'default')
  end

  def test_comparison
    result = TestObjectQuery.with(name: 'Test User')
    record1 = result.first
    record2 = result.first
    
    assert_equal record1, record2
    assert record1.eql?(record2)
    assert_equal record1.hash, record2.hash
  end

  def test_serialization
    record = TestObjectQuery.with(name: 'Test User').first
    
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
      "tags" => ["ruby", "rails"]
    }
    
    assert_equal expected_hash, record.to_h
    assert_equal expected_hash.to_json, record.to_json
  end

  def test_pattern_matching
    record = TestObjectQuery.with(name: 'Test User').first

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
    result = TestObjectQuery.with(name: 'Nonexistent')
    assert_equal [], result
  end

  def test_comparable
    results = TestObjectQuery.with(name: 'Test User')
    sorted_results = results.sort_by(&:age)
    assert_equal results, sorted_results
  end

  def test_changes_tracking
    record = TestObjectQuery.with(name: 'Test User').first
    assert_equal record.to_h, record.original_attributes

    # Can't actually modify the record since attrs are read-only,
    # but we can test the changes interface
    record.instance_variable_set("@name", "Changed")

    assert record.changed?
    assert_equal({"name" => ["Test User", "Changed"]}, record.changes)
  end
end
