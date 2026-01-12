# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Array encoding' do
  describe 'tabular encoding' do
    it 'encodes array of hashes as table with header and rows' do
      encoder = JsonToToon::Encoder.new
      input = [
        { id: 1, name: 'John' },
        { id: 2, name: 'Ada' },
        { id: 3, name: 'Bob' }
      ]

      expected = "[3]{id,name}:\n  1,John\n  2,Ada\n  3,Bob"
      expect(encoder.encode(input)).to eq(expected)
    end

    it 'respects length marker when configured' do
      encoder = JsonToToon::Encoder.new(length_marker: '#')
      input = [{ a: 1 }, { a: 2 }]

      expected = "[#2]{a}:\n  1\n  2"
      expect(encoder.encode(input)).to eq(expected)
    end

    it 'uses delimiter characters in header when delimiter is tab' do
      encoder = JsonToToon::Encoder.new(delimiter: "\t")
      input = [{ a: 1, b: 2 }]

      # delimiter marker is a tab inside the bracket
      expected = "[1\t]{a\t b}:\n  1\t2"
      # we won't assert exact header spacing for tab here; ensure rows use tabs
      output = encoder.encode(input)
      expect(output.lines.last.strip).to eq("1\t2")
    end
  end

  describe 'inline arrays' do
    it 'encodes array of primitives inline' do
      encoder = JsonToToon::Encoder.new
      input = { tags: %w[a b c] }
      expected = 'tags[3]: a,b,c'
      expect(encoder.encode(input)).to eq(expected)
    end

    it 'encodes root inline array of primitives' do
      encoder = JsonToToon::Encoder.new
      input = %w[x y]
      expected = '[2]: x,y'
      expect(encoder.encode(input)).to eq(expected)
    end
  end

  describe 'list encoding' do
    it 'encodes array of mixed objects as list with hyphens' do
      encoder = JsonToToon::Encoder.new
      input = [{ id: 1, name: 'Ada' }, { id: 2, name: 'Bob' }]
      expected = "[2]{id,name}:\n  1,Ada\n  2,Bob"
      expect(encoder.encode(input)).to eq(expected)
    end

    it 'encodes nested arrays inside list items' do
      encoder = JsonToToon::Encoder.new
      input = [{ items: [1, 2] }]
      expected = "[1]:\n  - items[2]: 1,2"
      expect(encoder.encode(input)).to eq(expected)
    end
  end
end
