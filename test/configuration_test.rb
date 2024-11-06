# frozen_string_literal: true

require "test_helper"

class KweerieConfigurationTest < Minitest::Test
  def setup
    Kweerie.reset_configuration!
  end

  def test_default_configuration
    config = Kweerie.configuration

    assert_kind_of Proc, config.connection_provider
    assert_kind_of Proc, config.sql_paths
  end

  def test_custom_configuration
    custom_connection = Object.new
    custom_paths = ["custom/path"]

    Kweerie.configure do |config|
      config.connection_provider = -> { custom_connection }
      config.sql_paths = -> { custom_paths }
    end

    assert_equal custom_connection, Kweerie.configuration.connection_provider.call
    assert_equal custom_paths, Kweerie.configuration.sql_paths.call
  end

  def test_reset_configuration
    Kweerie.configure do |config|
      config.sql_paths = -> { ["custom/path"] }
    end

    Kweerie.reset_configuration!

    assert_includes Kweerie.configuration.sql_paths.call, "app/queries"
  end
end
