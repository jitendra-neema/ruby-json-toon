# frozen_string_literal: true

module ToonToJson
  # Efficiently converts TOON format directly to JSON string
  class Decoder
    # Public: Decode a TOON formatted string directly into a JSON string.
    # str - String TOON input

    def decode(str)
      return 'null' if str.nil? || str.empty?

      lines = str.to_s.split("\n")

      # Single-line primitive
      if lines.length == 1 && !lines.first.include?(':') &&
         !lines.first.strip.start_with?('-') && !lines.first.include?('[')
        return primitive_to_json(lines.first.strip)
      end

      @lines = lines.map { |l| { raw: l, indent: leading_spaces(l), text: l.lstrip } }
      @i = 0
      @indent_unit = detect_indent_unit
      @output = []

      parse_block(0)
      @output.join
    end

    private

    def leading_spaces(line)
      line[/^\s*/].size
    end

    def detect_indent_unit
      prev = 0
      @lines.each do |ln|
        next if ln[:raw].strip.empty?
        return ln[:indent] - prev if ln[:indent] > prev

        prev = ln[:indent]
      end
      2
    end

    def parse_block(min_indent)
      # Peek to determine if this is an array or object
      start_i = @i
      is_array = false

      # Check if first non-empty line is a list item
      while start_i < @lines.length
        ln = @lines[start_i]
        break if ln[:raw].strip.empty?

        if ln[:indent] >= min_indent && ln[:text].start_with?('- ')
          is_array = true
          break
        end
        break if ln[:indent] >= min_indent

        start_i += 1
      end

      if is_array
        parse_list_block(min_indent)
      else
        parse_object_block(min_indent)
      end
    end

    def parse_object_block(min_indent)
      @output << '{'
      first = true

      while @i < @lines.length
        ln = @lines[@i]
        break if ln[:raw].strip.empty?
        break if ln[:indent] < min_indent

        # Array header
        if (array_header = parse_array_header(ln[:text]))
          @output << ',' unless first
          first = false

          key = array_header[:key]
          @i += 1

          if key
            @output << json_string(key)
            @output << ':'
          end

          parse_array_body(array_header, ln[:indent] + @indent_unit)
          next
        end

        # List without explicit header
        if ln[:text].start_with?('- ')
          # This shouldn't happen in object context, but handle it
          @output << ',' unless first
          parse_list_block(min_indent)
          break
        end

        # Key-value pair
        if (kv = parse_key_value_line(ln[:text]))
          @output << ',' unless first
          first = false

          @output << json_string(kv[:key])
          @output << ':'
          @output << kv[:value]
          @i += 1
          next
        end

        # Key-only (nested object)
        if (key = parse_key_only(ln[:text]))
          @output << ',' unless first
          first = false

          @output << json_string(key)
          @output << ':'
          @i += 1
          parse_block(ln[:indent] + @indent_unit)
          next
        end

        @i += 1
      end

      @output << '}'
    end

    def parse_list_block(min_indent)
      @output << '['
      first = true

      while @i < @lines.length
        ln = @lines[@i]
        break if ln[:raw].strip.empty?
        break if ln[:indent] < min_indent
        break unless ln[:text].start_with?('-')

        @output << ',' unless first
        first = false

        after = ln[:text][2..]&.strip || ''

        if after.empty?
          # Empty object or nested block
          @i += 1
          if @i < @lines.length && @lines[@i][:indent] > ln[:indent]
            parse_block(@lines[@i][:indent])
          else
            @output << '{}'
          end
          next
        end

        # Key-value on same line
        if (kv = parse_key_value_line(after))
          @output << '{'
          @output << json_string(kv[:key])
          @output << ':'
          @output << kv[:value]

          @i += 1

          # Check for additional fields
          if @i < @lines.length && @lines[@i][:indent] > ln[:indent]
            saved_output = @output.dup
            saved_i = @i

            @output = []
            parse_object_block(@lines[@i][:indent])
            additional = @output.join

            @output = saved_output

            # Merge additional fields
            if additional != '{}'
              @output << ','
              @output << additional[1...-1] # Strip { }
            end
          end

          @output << '}'
          next
        end

        # Key-only
        if after.end_with?(':')
          key = unquote_if_quoted(after[0...-1].strip)
          @i += 1

          @output << '{'
          @output << json_string(key)
          @output << ':'

          if @i < @lines.length && @lines[@i][:indent] > ln[:indent]
            parse_block(@lines[@i][:indent])
          else
            @output << '{}'
          end

          @output << '}'
          next
        end

        # Primitive value
        @output << value_to_json(after)
        @i += 1
      end

      @output << ']'
    end

    def parse_array_header(text)
      m = text.match(/\A(?:(?<key>.+?)?)?\[(?<len>#?\d+)(?<marker>[\t|]?)\](?:\{(?<fields>[^}]*)\})?:(?:\s*(?<rest>.*))?\z/)
      return nil unless m

      key = m[:key]&.strip
      key = parse_quoted_key(key) if key && !key.empty?

      {
        key: key,
        length: m[:len].sub(/^#/, '').to_i,
        fields: m[:fields],
        inline: m[:rest],
        marker: m[:marker]
      }
    end

    def parse_array_body(header, child_indent)
      @output << '['

      # Inline values
      if header[:inline] && !header[:inline].strip.empty?
        delim = detect_delimiter(header[:marker], header[:fields])
        values = header[:inline].split(delim)

        values.each_with_index do |v, idx|
          @output << ',' if idx > 0
          @output << value_to_json(v.strip)
        end

        @output << ']'
        return
      end

      # Tabular format
      if header[:fields]
        fields = split_fields(header[:fields], header[:marker])
        first = true

        while @i < @lines.length && @lines[@i][:indent] >= child_indent
          row_text = @lines[@i][:text]
          break if row_text.strip.empty?

          @output << ',' unless first
          first = false

          delim = detect_delimiter(header[:marker], header[:fields])
          values = row_text.split(delim).map(&:strip)

          @output << '{'
          fields.each_with_index do |f, idx|
            @output << ',' if idx > 0
            @output << json_string(unquote_if_quoted(f))
            @output << ':'
            @output << value_to_json(values[idx] || 'null')
          end
          @output << '}'

          @i += 1
        end

        @output << ']'
        return
      end

      # List format
      if @i < @lines.length && @lines[@i][:indent] >= child_indent &&
         @lines[@i][:text].start_with?('-')
        parse_list_block(child_indent)
        @output << ']'
        return
      end

      # Empty array
      @output << ']'
    end

    def split_fields(fields_str, marker)
      delim = detect_delimiter(marker, fields_str)
      fields_str.split(delim).map(&:strip)
    end

    def detect_delimiter(marker, sample)
      return "\t" if marker == "\t"
      return '|' if marker == '|'
      return "\t" if sample&.include?("\t")
      return '|' if sample&.include?('|')

      ','
    end

    def parse_key_value_line(text)
      key = nil
      rest = nil

      # Quoted key
      if text.start_with?('"')
        idx = 1
        while idx < text.length
          break if text[idx] == '"' && text[idx - 1] != '\\'

          idx += 1
        end
        return nil if idx >= text.length

        key = unescape_string(text[1...idx])
        after = text[(idx + 1)..]&.lstrip
        return nil unless after&.start_with?(':')

        rest = after[1..]&.lstrip
      elsif (cpos = text.index(':'))
        key = text[0...cpos].strip
        rest = text[(cpos + 1)..]&.lstrip
      else
        return nil
      end

      return nil if rest.nil? || rest.empty?

      { key: unquote_if_quoted(key), value: value_to_json(rest) }
    end

    def parse_key_only(text)
      return nil unless text.end_with?(':')

      key_part = text[0...-1].strip
      return nil if key_part.empty?

      unquote_if_quoted(key_part)
    end

    def unquote_if_quoted(str)
      return str unless str&.start_with?('"') && str.end_with?('"')

      unescape_string(str[1...-1])
    end

    def parse_quoted_key(key)
      key = key.strip
      if key.start_with?('"') && key.end_with?('"')
        unescape_string(key[1...-1])
      else
        key
      end
    end

    # Convert value text directly to JSON string
    def value_to_json(text)
      return 'null' if text.nil?

      t = text.strip

      # Quoted string
      return json_string(unescape_string(t[1...-1])) if t.start_with?('"') && t.end_with?('"')

      # Primitives that don't need transformation
      return t if %w[null true false].include?(t)

      # Numbers (pass through as-is)
      if t.match?(/\A-?\d+\z/) ||
         t.match?(/\A-?\d+\.\d+(?:[eE][+-]?\d+)?\z/) ||
         t.match?(/\A-?\d+(?:[eE][+-]?\d+)\z/)
        return t
      end

      # Fallback: treat as unquoted string
      json_string(t)
    end

    def primitive_to_json(token)
      return 'null' if token.nil? || token == 'null'
      return token if %w[true false].include?(token)
      return token if token.match?(/\A-?\d+\z/) ||
                      token.match?(/\A-?\d+\.\d+(?:[eE][+-]?\d+)?\z/)

      json_string(token)
    end

    # Efficiently escape and quote a string for JSON
    def json_string(str)
      return '""' if str.nil? || str.empty?

      # Pre-allocate with quotes
      result = +'"'

      str.each_char do |c|
        result << case c
                  when '"'  then '\\"'
                  when '\\' then '\\\\'
                  when "\n" then '\\n'
                  when "\r" then '\\r'
                  when "\t" then '\\t'
                  when "\b" then '\\b'
                  when "\f" then '\\f'
                  else
                    # Handle control characters
                    if c.ord < 32
                      format('\\u%04x', c.ord)
                    else
                      c
                    end
                  end
      end

      result << '"'
      result
    end

    def unescape_string(s)
      s.gsub('\\\\', '\\')
       .gsub('\\n', "\n")
       .gsub('\\r', "\r")
       .gsub('\\t', "\t")
       .gsub('\\"', '"')
    end
  end
end
