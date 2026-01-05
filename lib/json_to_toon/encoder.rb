# frozen_string_literal: true

require 'bigdecimal'

module JsonToToon
  class Encoder
    DEFAULT_INDENT = 2
    DELIMITER_COMMA = ','
    DELIMITER_TAB = "\t"
    DELIMITER_PIPE = '|'
    VALID_DELIMITERS = [DELIMITER_COMMA, DELIMITER_TAB, DELIMITER_PIPE].freeze

    attr_reader :indent_size, :delimiter, :length_marker

    def initialize(options = {})
      @indent_size = options[:indent] || DEFAULT_INDENT
      @delimiter = options[:delimiter] || DELIMITER_COMMA
      @length_marker = options[:length_marker] || false

      validate_options!

      @output = []
      @visited = {}
    end

    def encode(value)
      @output = []
      @visited = {}
      result = encode_value(value, 0)

      # If encoding a primitive value at root, encode_value returns the
      # formatted string but nothing is emitted to @output. In that case
      # return the direct result.
      return result.to_s if @output.empty? && result

      @output.join("\n")
    end

    def delimiter_marker
      case @delimiter
      when DELIMITER_COMMA then ''
      when DELIMITER_TAB then "\t"
      when DELIMITER_PIPE then '|'
      end
    end

    def length_prefix
      @length_marker == '#' ? '#' : ''
    end

    private

    def validate_options!
      unless @indent_size.is_a?(Integer) && @indent_size.positive?
        raise InvalidOptionError, "indent must be a positive integer, got: #{@indent_size.inspect}"
      end

      unless VALID_DELIMITERS.include?(@delimiter)
        raise InvalidOptionError, 
          "delimiter must be one of #{VALID_DELIMITERS.map(&:inspect).join(', ')}, got: #{@delimiter.inspect}"
      end

      unless @length_marker == '#' || @length_marker == false
        raise InvalidOptionError, "length_marker must be '#' or false, got: #{@length_marker.inspect}"
      end
    end

    def encode_value(value, depth, key = nil)
      check_circular_reference(value)

      result = case value
               when Hash then encode_hash(value, depth)
               when Array then encode_array_with_key(value, depth, key)
               else format_value(value)
               end

      unmark_visited(value)
      result
    end

    def check_circular_reference(value)
      return unless value.is_a?(Hash) || value.is_a?(Array)

      object_id = value.object_id
      raise CircularReferenceError, 'Circular reference detected' if @visited[object_id]

      @visited[object_id] = true
    end

    def unmark_visited(value)
      @visited.delete(value.object_id) if value.is_a?(Hash) || value.is_a?(Array)
    end

    def encode_hash(hash, depth)
      return if hash.empty? && depth.zero?

      hash.each do |key, value|
        formatted_key = format_key(key)

        if primitive?(value)
          formatted_value = format_value(value)
          emit_line(indent(depth) + "#{formatted_key}: #{formatted_value}")
        elsif value.is_a?(Hash)
          if value.empty?
            emit_line(indent(depth) + "#{formatted_key}:")
          else
            emit_line(indent(depth) + "#{formatted_key}:")
            encode_value(value, depth + 1)
          end
        elsif value.is_a?(Array)
          encode_value(value, depth, formatted_key)
        end
      end
    end

    def encode_array_with_key(array, depth, key)
      if array.empty?
        header = key ? "#{key}[#{length_prefix}0]:" : "[#{length_prefix}0]:"
        emit_line(indent(depth) + header)
        return
      end

      if tabular_eligible?(array)
        encode_tabular(array, depth, key)
      elsif all_primitives?(array)
        encode_inline(array, depth, key)
      else
        encode_list(array, depth, key)
      end
    end

    # FIXED: Tabular eligibility with proper key checking
    def tabular_eligible?(array)
      return false if array.empty?
      return false unless array.all? { |item| item.is_a?(Hash) && !item.empty? }

      # Get first object's key set (sorted for comparison)
      first_keys = array.first.keys.sort

      # All objects must have exactly the same keys
      return false unless array.all? { |item| item.keys.sort == first_keys }

      # All values must be primitives
      array.all? { |item| item.values.all? { |v| primitive?(v) } }
    end

    def all_primitives?(array)
      array.all? { |item| primitive?(item) }
    end

    # FIXED: Tabular encoding with correct field order from first object
    def encode_tabular(array, depth, key)
      # Use first object's key order for header
      field_order = array.first.keys
      field_header = field_order.map { |k| format_key(k) }.join(delimiter)

      length_str = "#{length_prefix}#{array.length}"
      marker = delimiter_marker
      header = key ? "#{key}[#{length_str}#{marker}]{#{field_header}}:" : 
                     "[#{length_str}#{marker}]{#{field_header}}:"

      emit_line(indent(depth) + header)

      array.each do |item|
        # CRITICAL: Use field_order, not item's key order!
        values = field_order.map { |k| format_value(item[k]) }
        row = values.join(@delimiter)
        emit_line(indent(depth + 1) + row)
      end
    end

    def encode_inline(array, depth, key)
      length_str = "#{length_prefix}#{array.length}"
      marker = delimiter_marker
      header = key ? "#{key}[#{length_str}#{marker}]:" : "[#{length_str}#{marker}]:"

      values = array.map { |item| format_value(item) }
      line = "#{indent(depth)}#{header} #{values.join(@delimiter)}"

      emit_line(line)
    end

    # FIXED: List encoding with proper indentation
    def encode_list(array, depth, key)
      length_str = "#{length_prefix}#{array.length}"
      header = key ? "#{key}[#{length_str}]:" : "[#{length_str}]:"
      emit_line(indent(depth) + header)

      array.each do |item|
        encode_list_item(item, depth + 1)
      end
    end

    # FIXED: Proper list item indentation
    def encode_list_item(item, depth)
      base_indent = indent(depth)
      hyphen_line = "#{base_indent}- "
      field_indent = base_indent + '  '

      case item
      when Hash
        if item.empty?
          emit_line(hyphen_line)
        else
          keys = item.keys
          first_key = keys.first
          formatted_key = format_key(first_key)

          # Check if first value is an array (special case)
          if item[first_key].is_a?(Array)
            # TODO: Handle nested array as first field
            # This is complex - needs special handling
            encode_list_item_with_array_first(item, depth)
          elsif item[first_key].is_a?(Hash)
            # First field is nested object
            emit_line("#{hyphen_line}#{formatted_key}:")
            encode_value(item[first_key], depth + 1)

            # Remaining fields
            keys[1..-1].each do |k|
              fk = format_key(k)
              fv = format_value(item[k])
              emit_line("#{field_indent}#{fk}: #{fv}")
            end
          else
            # First field is primitive
            fv = format_value(item[first_key])
            emit_line("#{hyphen_line}#{formatted_key}: #{fv}")

            # Remaining fields at same indent level
            keys[1..-1].each do |k|
              fk = format_key(k)
              v = item[k]

              if v.is_a?(Hash)
                emit_line("#{field_indent}#{fk}:")
                encode_value(v, depth + 2)
              elsif v.is_a?(Array)
                encode_value(v, depth + 1, fk)
              else
                fv = format_value(v)
                emit_line("#{field_indent}#{fk}: #{fv}")
              end
            end
          end
        end
      when Array
        # Nested array in list - go through encode_value for circular checks
        encode_value(item, depth, nil)
      else
        # Primitive
        emit_line("#{hyphen_line}#{format_value(item)}")
      end
    end

    # COMPLEX: Handle list item where first field is an array
    def encode_list_item_with_array_first(item, depth)
      # This is a complex edge case from the spec
      # TODO: Implement proper handling per spec
      keys = item.keys
      first_key = keys.first

      base_indent = indent(depth)
      hyphen_line = "#{base_indent}- "
      field_indent = base_indent + '  '

      formatted_key = format_key(first_key)
      emit_line("#{hyphen_line}#{formatted_key}:")
      encode_value(item[first_key], depth + 1, nil)

      keys[1..-1].each do |k|
        fk = format_key(k)
        fv = format_value(item[k])
        emit_line("#{field_indent}#{fk}: #{fv}")
      end
    end

    def primitive?(value)
      value.nil? ||
        value.is_a?(String) ||
        value.is_a?(Numeric) ||
        value == true ||
        value == false ||
        value.is_a?(Symbol)
    end

    def format_key(key)
      key_str = key.to_s
      needs_key_quotes?(key_str) ? quote_string(key_str) : key_str
    end

    def needs_key_quotes?(str)
      return true if str.empty?
      return true if str.start_with?('-')
      return true if str.match?(/\A\d+\z/)
      return true if str.match?(/[\s,:"\[\]{}\\]/)
      return true if str.match?(/[\n\r\t]/)

      false
    end

    def format_value(value)
      case value
      when nil then 'null'
      when true then 'true'
      when false then 'false'
      when Integer then value.to_s
      when Float then format_float(value)
      when String then format_string(value)
      when Symbol then format_string(value.to_s)
      when Time, DateTime then quote_string(value.iso8601(3))
      else 'null'
      end
    end

    # FIXED: Better float formatting
    def format_float(float)
      return 'null' if float.nan? || float.infinite?
      return '0' if float.zero?

      # Handle scientific notation and very small/large numbers
      str = if float.abs < 1e-10 || float.abs >= 1e15
              BigDecimal(float, 10).to_s('F')
            else
              float.to_s
            end

      # Remove scientific notation if present
      str = BigDecimal(str).to_s('F') if str.include?('e') || str.include?('E')

      # Remove trailing zeros after decimal point
      str = str.sub(/\.?0+\z/, '') if str.include?('.')

      # Ensure no lone decimal point
      str = str.sub(/\.\z/, '')

      # Final -0 check
      str = '0' if str == '-0' || str == '-0.0'

      str
    end

    # FIXED: Correct string quoting - only leading/trailing spaces!
    def format_string(str)
      needs_string_quotes?(str) ? quote_string(str) : str
    end

    def needs_string_quotes?(str)
      return true if str.empty?
      return true if str.include?(@delimiter)
      return true if str.include?(':')
      return true if str.include?('"') || str.include?('\\')
      return true if str.match?(/[\n\r\t]/)

      # Quote strings that contain spaces (inner or leading/trailing)
      return true if str.include?(' ')

      return true if str == '-' || str.start_with?('- ')
      return true if looks_like_boolean?(str)
      return true if looks_like_null?(str)
      return true if looks_like_number?(str)
      return true if looks_like_structural?(str)

      false
    end

    def looks_like_boolean?(str)
      str.match?(/\A(true|false)\z/i)
    end

    def looks_like_null?(str)
      str.match?(/\Anull\z/i)
    end

    def looks_like_number?(str)
      str.match?(/\A-?\d+(\.\d+)?([eE][+-]?\d+)?\z/)
    end

    def looks_like_structural?(str)
      str.match?(/\A\[.*\]\z/) || str.match?(/\A\{.*\}\z/)
    end

    def quote_string(str)
      escaped = str.gsub('\\', '\\\\\\\\')
                   .gsub('"', '\"')
                   .gsub("\n", '\n')
                   .gsub("\r", '\r')
                   .gsub("\t", '\t')
      "\"#{escaped}\""
    end

    def indent(depth)
      ' ' * (depth * @indent_size)
    end

    def emit_line(content)
      @output << content.rstrip
    end
  end
end
