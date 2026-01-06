# frozen_string_literal: true

require_relative 'json_to_toon/version'
require_relative 'json_to_toon/encoder'

module JsonToToon
  class Error < StandardError; end
  class CircularReferenceError < Error; end
  class InvalidOptionError < Error; end

  # Convert a Ruby object to TOON format
  #
  # @param value [Object] The Ruby object to encode (Hash, Array, or primitive)
  # @param options [Hash] Encoding options
  # @option options [Integer] :indent Number of spaces per indentation level (default: 2)
  # @option options [String] :delimiter Delimiter for arrays: ',' (default), "\t", or '|'
  # @option options [String, false] :length_marker Length marker character or false (default: false)
  # @return [String] TOON-formatted string with no trailing newline
  # @raise [InvalidOptionError] If options are invalid
  # @raise [CircularReferenceError] If circular references detected
  #
  # @example Basic usage
  #   JsonToToon.encode({name: 'Ada', age: 30})
  #   # => "name: Ada\nage: 30"
  #
  # @example With tab delimiter
  #   JsonToToon.encode({tags: ['a', 'b']}, delimiter: "\t")
  #   # => "tags[2\t]: a\tb"
  def self.encode(value, options = {})
    Encoder.new(options).encode(value)
  end

  # Alias for encode
  def self.convert(value, options = {})
    encode(value, options)
  end
end
