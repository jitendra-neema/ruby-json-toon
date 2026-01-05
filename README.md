# JSON to TOON

A lightweight, zero-dependency Ruby library for converting JSON data to TOON (Token-Oriented Object Notation) format, achieving 30-60% token reduction for LLM applications.

## What is TOON?

TOON (Token-Oriented Object Notation) is a compact, indentation-based data format optimized for LLM token efficiency. It uses 30-60% fewer tokens than JSON while remaining human-readable.

### Comparison

**JSON (87 tokens):**
```json
{
  "users": [
    {"id": 1, "name": "Alice", "role": "admin"},
    {"id": 2, "name": "Bob", "role": "user"}
  ]
}
```

**TOON (31 tokens):**
```
users[2]{id,name,role}:
  1,Alice,admin
  2,Bob,user
```

## Installation

Add to your Gemfile:

```ruby
gem 'json_to_toon'
```

Or install directly:

```bash
gem install json_to_toon
```

## Quick Start

```ruby
require 'json_to_toon'

# Convert Ruby hash to TOON
data = { name: 'Ada', role: 'admin', active: true }
toon = JsonToToon.encode(data)
# Output:
# name: Ada
# role: admin
# active: true

# Convert JSON string to TOON
json_data = JSON.parse('{"users":[{"id":1,"name":"Alice"}]}')
toon = JsonToToon.encode(json_data)
```

## Documentation

See full documentation at [rubydoc.info](https://rubydoc.info/gems/json_to_toon)

## Options

```ruby
JsonToToon.encode(data,
  indent: 2,         # Spaces per indentation level (default: 2)
  delimiter: ',',    # Delimiter: ',' (default), "\t", or '|'
  length_marker: '#' # Length marker or false (default: false)
)
```

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Build gem
gem build json_to_toon.gemspec
```

## License

MIT License - see LICENSE file for details

## Links

- [TOON Specification](https://toonformat.dev)
- [GitHub Repository](https://github.com/jitendra-neema/json_to_toon)
- [Bug Tracker](https://github.com/jitendra-neema/json_to_toon/issues)
