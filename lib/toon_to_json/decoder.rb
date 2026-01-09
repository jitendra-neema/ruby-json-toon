# frozen_string_literal: true

module ToonToJson
  # Efficiently converts TOON format directly to JSON string
  class Decoder
    def decode(str)
      return 'null' if str.nil? || str.empty?

      lines = str.to_s.split("\n")

      # Single-line primitive detection
      if lines.length == 1
        line = lines.first.strip

        # Check if it's a primitive (not a TOON structure)
        # TOON structures have:
        # - Colons (key:value or key:)
        # - List items (starts with "- " - note the space!)
        # - Array headers (starts with [)

        is_structure = line.include?(':') ||
                       line.match?(/\A-\s/) ||  # "- " with space (list item)
                       line.match?(/\A\[/)      # Array header

        return primitive_to_json(line) unless is_structure
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
      return parse_object_block(min_indent) if @i >= @lines.length

      # Check if first line is array header
      first_line = @lines[@i][:text]
      if first_line.match?(/\A\[/)
        array_header = parse_array_header(first_line)
        if array_header && array_header[:key].nil?
          # Root-level array
          @i += 1
          parse_array_body(array_header, @lines[@i - 1][:indent] + @indent_unit)
          return
        end
      end

      # Check if list format (starts with "- " with space)
      start_i = @i
      while start_i < @lines.length
        ln = @lines[start_i]
        break if ln[:raw].strip.empty?
        break if ln[:indent] < min_indent

        return parse_list_block(min_indent) if ln[:indent] >= min_indent && ln[:text].match?(/\A-\s/)

        break if ln[:text].include?(':')

        start_i += 1
      end

      parse_object_block(min_indent)
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
        break unless ln[:text].match?(/\A-\s/) # "- " with space

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

          # Parse additional fields directly
          if @i < @lines.length && @lines[@i][:indent] > ln[:indent]
            child_indent = @lines[@i][:indent]

            while @i < @lines.length && @lines[@i][:indent] >= child_indent
              field_ln = @lines[@i]
              break if field_ln[:text].match?(/\A-\s/)

              if field_kv = parse_key_value_line(field_ln[:text])
                @output << ','
                @output << json_string(field_kv[:key])
                @output << ':'
                @output << field_kv[:value]
                @i += 1
              elsif field_key = parse_key_only(field_ln[:text])
                @output << ','
                @output << json_string(field_key)
                @output << ':'
                @i += 1
                parse_block(field_ln[:indent] + @indent_unit)
              else
                break
              end
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
        values = split_with_quotes(header[:inline], delim)

        values.each_with_index do |v, idx|
          @output << ',' if idx > 0
          @output << value_to_json(v.strip)
        end

        @output << ']'
        return
      end

      # Tabular format
      if header[:fields]
        delim = detect_delimiter(header[:marker], header[:fields])
        fields = split_with_quotes(header[:fields], delim)
        first = true

        while @i < @lines.length && @lines[@i][:indent] >= child_indent
          row_text = @lines[@i][:text]
          break if row_text.strip.empty?

          @output << ',' unless first
          first = false

          values = split_with_quotes(row_text, delim)

          @output << '{'
          fields.each_with_index do |f, idx|
            @output << ',' if idx > 0
            @output << json_string(unquote_if_quoted(f.strip))
            @output << ':'
            @output << value_to_json(values[idx]&.strip || 'null')
          end
          @output << '}'

          @i += 1
        end

        @output << ']'
        return
      end

      # List format - parse items directly
      if @i < @lines.length && @lines[@i][:indent] >= child_indent &&
         @lines[@i][:text].match?(/\A-\s/)
        first = true
        while @i < @lines.length
          ln = @lines[@i]
          break if ln[:raw].strip.empty?
          break if ln[:indent] < child_indent
          break unless ln[:text].match?(/\A-\s/)

          @output << ',' unless first
          first = false

          after = ln[:text][2..]&.strip || ''

          if after.empty?
            @i += 1
            if @i < @lines.length && @lines[@i][:indent] > ln[:indent]
              parse_block(@lines[@i][:indent])
            else
              @output << '{}'
            end
            next
          end

          if (kv = parse_key_value_line(after))
            @output << '{'
            @output << json_string(kv[:key])
            @output << ':'
            @output << kv[:value]

            @i += 1

            if @i < @lines.length && @lines[@i][:indent] > ln[:indent]
              child_ind = @lines[@i][:indent]

              while @i < @lines.length && @lines[@i][:indent] >= child_ind
                field_ln = @lines[@i]
                break if field_ln[:text].match?(/\A-\s/)

                if field_kv = parse_key_value_line(field_ln[:text])
                  @output << ','
                  @output << json_string(field_kv[:key])
                  @output << ':'
                  @output << field_kv[:value]
                  @i += 1
                elsif field_key = parse_key_only(field_ln[:text])
                  @output << ','
                  @output << json_string(field_key)
                  @output << ':'
                  @i += 1
                  parse_block(field_ln[:indent] + @indent_unit)
                else
                  break
                end
              end
            end

            @output << '}'
            next
          end

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

          @output << value_to_json(after)
          @i += 1
        end

        @output << ']'
        return
      end

      # Empty array
      @output << ']'
    end

    def split_with_quotes(text, delimiter)
      return [text] if text.nil? || text.empty?

      values = []
      current = +''
      in_quotes = false
      i = 0

      while i < text.length
        c = text[i]

        if c == '\\' && i + 1 < text.length
          current << c << text[i + 1]
          i += 2
          next
        end

        if c == '"'
          in_quotes = !in_quotes
          current << c
          i += 1
          next
        end

        if c == delimiter && !in_quotes
          values << current
          current = +''
          i += 1
          next
        end

        current << c
        i += 1
      end

      values << current unless current.empty?
      values.map(&:strip)
    end

    def detect_delimiter(marker, fields)
      return "\t" if marker == "\t"
      return '|' if marker == '|'
      return "\t" if fields&.include?("\t")
      return '|' if fields&.include?('|')

      ','
    end

    def parse_key_value_line(text)
      key = nil
      rest = nil

      if text.start_with?('"')
        idx = 1
        while idx < text.length
          if text[idx] == '\\' && idx + 1 < text.length
            idx += 2
            next
          end
          break if text[idx] == '"'

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

    def value_to_json(text)
      return 'null' if text.nil? || text == 'null'

      t = text.strip

      return json_string(unescape_string(t[1...-1])) if t.start_with?('"') && t.end_with?('"')

      return 'true' if t.casecmp('true').zero?
      return 'false' if t.casecmp('false').zero?
      return 'null' if t.casecmp('null').zero?

      # Numbers
      return t if t.match?(/\A-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\z/)

      json_string(t)
    end

    def primitive_to_json(token)
      return 'null' if token.nil? || token.casecmp?('null')
      return 'true' if token.casecmp?('true')
      return 'false' if token.casecmp?('false')
      return token if token.match?(/\A-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\z/)

      json_string(token)
    end

    def json_string(str)
      return '""' if str.nil? || str.empty?

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
      result = +''
      i = 0

      while i < s.length
        if s[i] == '\\' && i + 1 < s.length
          case s[i + 1]
          when 'n'  then result << "\n"
          when 'r'  then result << "\r"
          when 't'  then result << "\t"
          when '"'  then result << '"'
          when '\\' then result << '\\'
          when 'b'  then result << "\b"
          when 'f'  then result << "\f"
          when 'u'
            if i + 5 < s.length
              hex = s[i + 2..i + 5]
              begin
                result << [hex.to_i(16)].pack('U')
              rescue StandardError
                result << s[i..i + 5]
              end
              i += 6
              next
            else
              result << s[i] << s[i + 1]
            end
          else
            result << s[i] << s[i + 1]
          end
          i += 2
        else
          result << s[i]
          i += 1
        end
      end

      result
    end
  end
end
