# Kweerie

Kweerie is a Ruby gem that helps you manage SQL queries in standalone files with parameter binding for PostgreSQL. It's designed to be a lightweight alternative to database views when you need to keep SQL logic separate from your Ruby code.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kweerie'
```

Then execute:

```bash
bundle install
```

## Usage

### Basic Usage

Create a new query class and its corresponding SQL file:

```ruby
# app/queries/user_search.rb
class UserSearch < Kweerie::Base
  bind :name, as: '$1'
  bind :email, as: '$2'
end
```

```sql
-- app/queries/user_search.sql
SELECT 
  users.id,
  users.name,
  users.email
FROM 
  users
WHERE 
  name ILIKE $1
  AND email ILIKE $2;
```

Execute your query:

```ruby
results = UserSearch.with(
  name: 'Eclipsoid%',
  email: '%@example.com'
)
# => [{"id"=>109981, "name"=>"Eclipsoid Doe", "email"=>"eclipsoiddoe@example.com"}]
```

### Object Mapping

While `Kweerie::Base` returns plain hashes, you can use `Kweerie::BaseObjects` to get typed Ruby objects with proper attribute methods:

```ruby
class UserSearch < Kweerie::BaseObjects
  bind :name, as: '$1'
  bind :created_at, as: '$2'
end

# Returns array of objects instead of hashes
users = UserSearch.with(
  name: 'Eclipsoid',
  created_at: '2024-01-01'
)

user = users.first
user.name         # => "Eclipsoid"
user.created_at   # => 2024-01-01 00:00:00 +0000 (Time object)
```

## Querying

Kweerie provides two main ways to execute queries based on whether they have parameters:

### Parameterized Queries

When your query needs parameters, use the `.with` method:

```ruby
class UsersByDepartment < Kweerie::Base
  bind :department, as: '$1'
  bind :active, as: '$2'
end

# app/queries/users_by_department.sql
SELECT *
FROM users
WHERE department = $1
  AND active = $2;

# Using the query
users = UsersByDepartment.with(
  department: 'Engineering',
  active: true
)
```

### Parameter-free Queries

For queries that don't require any parameters, you can use the more semantically appropriate `.all` method:

```ruby
class AllUsers < Kweerie::Base
end

# app/queries/all_users.sql
SELECT *
FROM users
WHERE active = true
ORDER BY created_at DESC;

# Using the query
users = AllUsers.all
```

The `.all` method provides a cleaner interface when you're not binding any parameters. It will raise an error if you try to use it on a query class that has parameter bindings:

```ruby
# This will raise an ArgumentError
UsersByDepartment.all  
# => ArgumentError: Cannot use .all on queries with bindings. Use .with instead.
```

### Choosing Between .all and .with

- Use `.all` when your SQL query is completely static with no parameters
- Use `.with` when you need to pass parameters to your query
- Even for parameterized queries, you can use `.with` without arguments if all parameters are optional

```ruby
# A query with no parameters
class RecentUsers < Kweerie::Base
end
RecentUsers.all  # ✓ Clean and semantic
RecentUsers.with # ✓ Works but less semantic

# A query with parameters
class UsersByStatus < Kweerie::Base
  bind :status, as: '$1'
end
UsersByStatus.all                    # ✗ Raises ArgumentError
UsersByStatus.with(status: 'active') # ✓ Correct usage
```

Both methods work with `Kweerie::Base` and `Kweerie::BaseObjects`, returning arrays of hashes or objects respectively:

```ruby
# Returns array of hashes
class AllUsers < Kweerie::Base
end
users = AllUsers.all
# => [{"id" => 1, "name" => "Eclipsoid"}, ...]

# Returns array of objects
class AllUsers < Kweerie::BaseObjects
end
users = AllUsers.all
# => [#<AllUsers id=1 name="Eclipsoid">, ...]
```

### Automatic Type Casting

BaseObjects automatically casts common PostgreSQL types to their Ruby equivalents:

```ruby
# In your SQL file
SELECT 
  name,
  created_at,                    -- timestamp
  age::integer,                  -- integer
  score::float,                  -- float
  active::boolean,               -- boolean
  metadata::jsonb,               -- jsonb
  tags::jsonb                    -- jsonb array
FROM users;

# In your Ruby code
user = UserSearch.with(name: 'Eclipsoid').first

user.created_at   # => Time object
user.age          # => Integer
user.score        # => Float
user.active       # => true/false
user.metadata     # => Hash with string keys
user.tags         # => Array

# Nested JSONB data is properly accessible
user.metadata["role"]                    # => "admin"
user.metadata["preferences"]["theme"]    # => "dark"
```

### Pattern Matching Support

BaseObjects support Ruby's pattern matching syntax:

```ruby
case user
in { name:, metadata: { role: "admin" } }
  puts "Admin user: #{name}"
in { name:, metadata: { role: "user" } }
  puts "Regular user: #{name}"
end

# Nested pattern matching
case user
in { metadata: { preferences: { theme: "dark" } } }
  puts "Dark theme user"
end
```

### Object Interface

BaseObjects provide several useful methods:

```ruby
# Hash-like access
user[:name]                    # => "Eclipsoid"
user.fetch(:email, 'N/A')      # => Returns 'N/A' if email is nil

# Serialization
user.to_h                      # => Hash with string keys
user.to_json                   # => JSON string

# Comparison
user1 == user2                 # Compare all attributes
users.sort_by(&:created_at)    # Sortable

# Change tracking
user.changed?                  # => Check if any attributes changed
user.changes                   # => Hash of changes with [old, new] values
user.original_attributes       # => Original attributes from DB
```

### PostgreSQL Array Support

BaseObjects handles PostgreSQL arrays by converting them to Ruby arrays with proper type casting:

```ruby
# In your PostgreSQL schema
create_table :users do |t|
  t.integer :preferred_ordering, array: true, default: []
  t.string :tags, array: true
  t.float :scores, array: true
end

# In your query
user = UserSearch.with(name: 'Eclipsoid').first

user.preferred_ordering  # => [1, 3, 2]
user.tags                 # => ["ruby", "rails"]
user.scores              # => [98.5, 87.2, 92.0]
```

### SQL File Location

By default, Kweerie looks for SQL files adjacent to their Ruby query classes. You can customize this behavior:

```ruby
# Default behavior - looks for user_search.sql next to this file
class UserSearch < Kweerie::Base
end

# Specify absolute path from Rails root
class UserSearch < Kweerie::Base
  sql_file_location root: 'db/queries/complex_user_search.sql'
end

# Specify path relative to the Ruby file
class UserSearch < Kweerie::Base
  sql_file_location relative: '../sql/user_search.sql'
end

# Explicitly use default behavior
class UserSearch < Kweerie::Base
  sql_file_location :default
end
```

### Performance Considerations

BaseObjects creates a unique class for each query result set, with the following optimizations:

- Classes are cached and reused for subsequent queries
- Attribute readers are defined upfront
- Type casting happens once during initialization
- No method_missing or dynamic method definition per instance
- Efficient pattern matching support

For queries where you don't need the object interface, use `Kweerie::Base` instead for slightly better performance.

## Rails Generator

If you're using Rails, you can use the generator to create new query files:

```bash
# Using underscored name
rails generate kweerie user_search email name

# Using CamelCase name
rails generate kweerie UserSearch email name
```

This will create both the Ruby class and SQL file with the appropriate structure.

## Configuration

By default, Kweerie uses ActiveRecord's connection if available. You can configure this and other options:

```ruby
# config/initializers/kweerie.rb
Kweerie.configure do |config|
  # Use a custom connection provider
  config.connection_provider = -> { MyCustomConnectionPool.connection }
  
  # Configure where to look for SQL files
  config.sql_paths = -> { ['db/queries', 'app/sql'] }
end
```

## Requirements

- Ruby 2.7 or higher
- PostgreSQL (this gem is PostgreSQL-specific and uses the `pg` gem)
- Rails 6+ (optional, needed for the generator and default ActiveRecord integration)

## Features

- ✅ Separate SQL files from Ruby code
- ✅ Strong parameter binding for SQL injection protection
- ✅ Rails generator for quick file creation
- ✅ Configurable connection handling
- ✅ Parameter validation

### Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests.

### Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

### License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## FAQ

**Q: Why does Kweerie exist?**  
A: PostgreSQL DB views are powerful and (honestly) preferred for what kweerie offers, but they need migrations to change, which isn't always practical when you just need a query. Kweerie provides that flexibility. Plus, SQL is more readable in a single file than when nested in Ruby code. SQL is powerful and doesn’t always need to be hidden behind abstractions.

**Q: Why PostgreSQL only?**  
A: Kweerie uses PostgreSQL-specific features for parameter binding and result handling. Supporting other databases would require different parameter binding syntax and result handling.

**Q: Do I need Rails?**  
A: No, Kweerie works with any Ruby application. Rails is only required if you want to use the generator or the automatic ActiveRecord integration.

**Q: Can I use this with views?**  
A: Yes! You can write any valid PostgreSQL query, including queries that use views.

**Q: How do I handle optional parameters?**  
A: Currently, all bound parameters are required. For optional parameters, you'll need to handle the conditionals in your SQL using COALESCE or similar PostgreSQL functions.

**Q: How do I convert types in parameters?**  
A: PostgreSQL has robust type handling built-in, so you can handle type conversion directly in your SQL. Here are some examples:

```sql
-- Convert string to integer
WHERE id = $1::integer

-- Convert string to date
WHERE created_at > $1::date

-- Convert string to array
WHERE tags && $1::text[]

-- Convert to timestamp with timezone
WHERE created_at > $1::timestamptz

-- Multiple conversions in one query
SELECT *
FROM users
WHERE 
  created_at > $1::timestamptz
  AND age > $2::integer
  AND tags && $3::text[]
  AND metadata @> $4::jsonb
```

This approach leverages PostgreSQL's native type casting system, which is both more efficient and more reliable than converting types in Ruby.
