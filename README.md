# JSON to TOON

Lightweight Ruby library for converting JSON data to TOON (Token-Oriented Object Notation), achieving 30–60% token reduction for LLM applications.

## Summary

Convert JSON to TOON (Token-Oriented Object Notation)

Authors: Jitendra Neema  
Contact: jitendra.neema.8@gmail.com

Homepage: https://github.com/jitendra-neema/ruby-json-toon  
Documentation: https://rubydoc.info/gems/ruby-json-toon  
Changelog: https://github.com/jitendra-neema/ruby-json-toon/blob/main/CHANGELOG.md  
Bug tracker: https://github.com/jitendra-neema/ruby-json-toon/issues  
Rubygems: https://rubygems.org/gems/ruby-json-toon

Requires Ruby >= 2.7.0

## What is TOON?

TOON (Token-Oriented Object Notation) is a compact, indentation-based data format optimized for LLM token efficiency. It uses roughly 30–60% fewer tokens than JSON while remaining human-readable.

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

Install the gem:

```bash
gem install ruby-json-toon
```

Or add to your Gemfile:

```ruby
gem 'ruby-json-toon'
```

Require the library in your code (require path follows the library files):

```ruby
require 'json_to_toon'
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

## Options

```ruby
JsonToToon.encode(data,
  indent: 2,         # Spaces per indentation level (default: 2)
  delimiter: ',',    # Delimiter: ',' (default), "\t", or '|'
  length_marker: '#' # Length marker or false (default: false)
)
```

## Development

Clone the repo, install dependencies, run tests, and build the gem:

```bash
git clone https://github.com/jitendra-neema/ruby-json-toon
cd ruby-json-toon

# Install development dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Build gem
gem build ruby-json-toon.gemspec
```

Development dependencies (from the gemspec): benchmark-ips, memory_profiler, rake, rspec, rubocop, rubocop-rake, rubocop-rspec, simplecov.

## License

MIT License — see LICENSE file for details.

## Links

- TOON Specification: https://toonformat.dev
- Homepage / source: https://github.com/jitendra-neema/ruby-json-toon
- Documentation: https://rubydoc.info/gems/ruby-json-toon
- Bug tracker: https://github.com/jitendra-neema/ruby-json-toon/issues
