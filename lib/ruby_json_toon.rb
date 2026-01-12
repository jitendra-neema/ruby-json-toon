# frozen_string_literal: true

require_relative 'ruby_json_toon/version'
require_relative 'json_to_toon'
require_relative 'toon_to_json'

module RubyJsonToon
  def self.encode(value, options = {})
    JsonToToon.encode(value, options)
  end

  def self.decode(toon_string)
    ToonToJson.decode(toon_string)
  end
end
