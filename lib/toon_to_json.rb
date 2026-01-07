require_relative 'toon_to_json/decoder'

module ToonToJson
  class Error < StandardError; end

  # Decode a TOON-formatted string into a Ruby object
  #
  # @param toon_str [String] The TOON-formatted string to decode
  # @return [Object] The decoded Ruby object (Hash, Array, or primitive)

  def self.decode(toon_str)
    Decoder.new.decode(toon_str)
  end
end
