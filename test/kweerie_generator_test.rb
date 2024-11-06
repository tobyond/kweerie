# frozen_string_literal: true

require "test_helper"
require "generators/kweerie/kweerie_generator"

class KweerieGeneratorTest < Rails::Generators::TestCase
  tests KweerieGenerator
  destination Rails.root.join("tmp/generators")
  setup :prepare_destination

  test "generator creates query files" do
    run_generator %w[user_search name email]

    # Check if files are created
    assert_file "app/queries/user_search.rb"
    assert_file "app/queries/user_search.sql"

    # Check Ruby file content
    assert_file "app/queries/user_search.rb" do |content|
      assert_match(/class UserSearch < Kweerie::Base/, content)
      assert_match(/bind :name, as: '\$1'/, content)
      assert_match(/bind :email, as: '\$2'/, content)
    end

    # Check SQL file content
    assert_file "app/queries/user_search.sql" do |content|
      assert_match(/-- Available parameters: \$1 \(name\), \$2 \(email\)/, content)
    end
  end

  test "handles CamelCase names" do
    run_generator %w[UserSearch name email]

    assert_file "app/queries/user_search.rb" do |content|
      assert_match(/class UserSearch < Kweerie::Base/, content)
    end
  end

  test "creates files without parameters" do
    run_generator ["empty_query"]

    assert_file "app/queries/empty_query.rb" do |content|
      assert_match(/class EmptyQuery < Kweerie::Base/, content)
      refute_match(/bind/, content)
    end
  end
end
