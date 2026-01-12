# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyJsonToon do
  describe '.encode' do
    it 'encodes JSON to TOON format' do
      input = { name: 'Alice', age: 30, tags: %w[developer ruby] }
      expected = "name: Alice\nage: 30\ntags[2]: developer,ruby"

      output = RubyJsonToon.encode(input)
      expect(output).to eq(expected)
    end
  end

  describe '.decode' do
    it 'decodes TOON format to JSON' do
      toon_string = "name: Bob\nage: 25\ntags[3]: python,java,go"
      expected = { 'name' => 'Bob', 'age' => 25, 'tags' => %w[python java go] }

      json_string = RubyJsonToon.decode(toon_string)
      output = JSON.parse(json_string)
      expect(output).to eq(expected)
    end
  end
end
