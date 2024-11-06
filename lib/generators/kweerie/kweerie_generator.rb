# frozen_string_literal: true

require "rails/generators"

class KweerieGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)
  argument :parameters, type: :array, default: []

  def create_query_file
    # Convert parameters into bind statements
    bind_statements = parameters.map.with_index(1) do |param, index|
      "  bind :#{param.underscore}, as: '$#{index}'"
    end.join("\n")

    # Create the query class
    template_content = <<~RUBY
      # frozen_string_literal: true

      class #{class_name} < Kweerie::Base
        #{bind_statements}
      end
    RUBY

    # Ensure the queries directory exists
    FileUtils.mkdir_p("app/queries")

    # Create the Ruby file
    create_file "app/queries/#{file_name}.rb", template_content

    # Create the SQL file
    create_file "app/queries/#{file_name}.sql", <<~SQL
      -- Write your SQL query here
      -- Available parameters: #{parameters.map { |p| "$#{parameters.index(p) + 1} (#{p})" }.join(", ")}

      -- SELECT
        -- your columns here
      -- FROM
        -- your tables here
      -- WHERE
        -- your conditions here
    SQL
  end

  private

  def file_name
    name.underscore
  end

  def class_name
    name.classify
  end
end
