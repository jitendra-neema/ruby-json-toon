# JSON to TOON

Lightweight Ruby library for converting JSON data to TOON (Token-Oriented Object Notation), achieving 30–60% token reduction for LLM applications.

## Summary

Convert JSON to TOON (Token-Oriented Object Notation)

Requires Ruby >= 2.7.0

# RubyJsonToon

Lightweight, high-performance Ruby library for converting between JSON and **TOON (Token-Oriented Object Notation)**. 

TOON is an indentation-based data format optimized for **LLM token efficiency**, achieving **30–60% token reduction** compared to JSON while remaining fully human-readable and machine-parseable.

## What is TOON?

TOON is designed to strip away the structural overhead of JSON (braces, quotes, repetitive keys) without losing data integrity. 

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

```text
users[2]{id,name,role}:
  1,Alice,admin
  2,Bob,user

```

## Features

* **Bidirectional:** Round-trip support for encoding (Ruby to TOON) and decoding (TOON to JSON).
* **Tabular Optimization:** Automatically detects repetitive object structures in lists to create high-density tables.
* **Compact Inlining:** Intelligently inlines arrays and "first-field" object data to minimize vertical lines.
* **LLM Optimized:** Specifically designed to maximize the context window of Large Language Models.
* **Performant:** Built with frozen string literals and efficient recursion; handles 10,000 records in ~50ms.

## Installation

Add to your Gemfile:

```ruby
gem 'ruby-json-toon'

```

And then execute:

```bash
bundle install

```

## Quick Start

```ruby
require 'ruby_json_toon'

# 1. Encode Ruby Hash to TOON
data = { 
  project: 'SecureAPI', 
  tags: ['ruby', 'auth'],
  users: [
    { id: 101, name: 'Alice', access: ['read', 'write'] },
    { id: 102, name: 'Bob', access: ['read'] }
  ]
}

toon = RubyJsonToon.encode(data)
puts toon
# Output:
# project: SecureAPI
# tags[2]: ruby,auth
# users[2]:
#   - id: 101
#     name: Alice
#     access[2]: read,write
#   - id: 102
#     name: Bob
#     access[1]: read

# 2. Decode TOON back to JSON/Ruby
json_string = RubyJsonToon.decode(toon)

```

## Options

The `encode` method accepts the following options:

| Option | Default | Description |
| --- | --- | --- |
| `indent` | `2` | Number of spaces per indentation level. |
| `delimiter` | `,` | Separator for arrays/tables (`,` , `\t`, or `|`). |
| `length_marker` | `false` | Set to `'#'` to prefix lengths (e.g., `[#2]`). |

## Performance

Results for 10,000 complex records (Ruby 3.2.3):

* **Encoding:** 0.050s (~200,000 records/sec)
* **Decoding:** 0.173s (~57,000 records/sec)
* **TOON Size:** ~242 KB (approx. 30-40% smaller than JSON)

## Development

Clone the repo and run the suite:

```bash
git clone [https://github.com/jitendra-neema/ruby-json-toon](https://github.com/jitendra-neema/ruby-json-toon)
cd ruby-json-toon

bundle install
bundle exec rspec   # Runs 150+ tests including round-trip validation
bundle exec rubocop

```
Development dependencies (from the gemspec): benchmark-ips, memory_profiler, rake, rspec, rubocop, rubocop-rake, rubocop-rspec, simplecov.

Authors: Jitendra Neema  
Contact: jitendra.neema.8@gmail.com

## License

MIT License — see see LICENSE file for details.

## Links

* **TOON Specification:** [https://toonformat.dev](https://toonformat.dev)
* **Homepage:** [https://github.com/jitendra-neema/ruby-json-toon](https://github.com/jitendra-neema/ruby-json-toon)
* **Bug Tracker:** [https://github.com/jitendra-neema/ruby-json-toon/issues](https://github.com/jitendra-neema/ruby-json-toon/issues)
* **Rubygems:** [https://rubygems.org/gems/ruby-json-toon](ruby-json-toon)
