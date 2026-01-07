# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe ToonToJson::Decoder do
  describe '.decode' do
    context 'with primitives' do
      it 'decodes null' do
        expect(described_class.decode('null')).to eq('null')
      end

      it 'decodes true' do
        expect(described_class.decode('true')).to eq('true')
      end

      it 'decodes false' do
        expect(described_class.decode('false')).to eq('false')
      end

      it 'decodes integers' do
        expect(described_class.decode('42')).to eq('42')
        expect(described_class.decode('-17')).to eq('-17')
      end

      it 'decodes floats' do
        expect(described_class.decode('3.14')).to eq('3.14')
        expect(described_class.decode('-2.5')).to eq('-2.5')
      end

      it 'decodes strings' do
        result = described_class.decode('hello')
        expect(result).to eq('"hello"')
      end
    end

    context 'with simple objects' do
      it 'decodes simple object' do
        toon = <<~TOON.chomp
          id: 123
          name: Ada
          active: true
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'id' => 123,
                               'name' => 'Ada',
                               'active' => true
                             })
      end

      it 'decodes object with quoted values' do
        toon = <<~TOON.chomp
          name: "hello world"
          value: "true"
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'name' => 'hello world',
                               'value' => 'true'
                             })
      end

      it 'decodes object with quoted keys' do
        toon = <<~TOON.chomp
          "full name": Ada
          "user-id": 123
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'full name' => 'Ada',
                               'user-id' => 123
                             })
      end
    end

    context 'with nested objects' do
      it 'decodes nested object' do
        toon = <<~TOON.chomp
          user:
            id: 123
            name: Ada
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'user' => {
                                 'id' => 123,
                                 'name' => 'Ada'
                               }
                             })
      end

      it 'decodes deeply nested objects' do
        toon = <<~TOON.chomp
          a:
            b:
              c: 1
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'a' => {
                                 'b' => {
                                   'c' => 1
                                 }
                               }
                             })
      end
    end

    context 'with empty structures' do
      it 'decodes empty root object' do
        result = described_class.decode('')
        expect(result).to eq('null')
      end

      it 'decodes nested empty object' do
        toon = 'config:'
        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'config' => {} })
      end

      it 'decodes empty array' do
        toon = 'items[0]:'
        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'items' => [] })
      end
    end

    context 'with inline arrays' do
      it 'decodes inline primitive array' do
        toon = 'tags[3]: admin,ops,dev'
        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'tags' => %w[admin ops dev]
                             })
      end

      it 'decodes inline array with numbers' do
        toon = 'nums[3]: 1,2,3'
        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'nums' => [1, 2, 3]
                             })
      end

      it 'decodes inline array with quoted strings' do
        toon = 'items[2]: "a,b","c,d"'
        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'items' => ['a,b', 'c,d']
                             })
      end
    end

    context 'with tabular arrays' do
      it 'decodes tabular array with comma delimiter' do
        toon = <<~TOON.chomp
          users[2]{id,name}:
            1,Alice
            2,Bob
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'users' => [
                                 { 'id' => 1, 'name' => 'Alice' },
                                 { 'id' => 2, 'name' => 'Bob' }
                               ]
                             })
      end

      it 'decodes tabular array with tab delimiter' do
        toon = "items[2\t]{sku\tqty}:\n  A1\t5\n  B2\t3"
        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'items' => [
                                 { 'sku' => 'A1', 'qty' => 5 },
                                 { 'sku' => 'B2', 'qty' => 3 }
                               ]
                             })
      end

      it 'decodes tabular array with pipe delimiter' do
        toon = <<~TOON.chomp
          data[2|]{a|b}:
            1|2
            3|4
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'data' => [
                                 { 'a' => 1, 'b' => 2 },
                                 { 'a' => 3, 'b' => 4 }
                               ]
                             })
      end
    end

    context 'with list arrays' do
      it 'decodes list of primitives' do
        toon = <<~TOON.chomp
          items[3]:
            - 1
            - 2
            - 3
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'items' => [1, 2, 3]
                             })
      end

      it 'decodes list of objects' do
        toon = <<~TOON.chomp
          users[2]:
            - id: 1
              name: Alice
            - id: 2
              name: Bob
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'users' => [
                                 { 'id' => 1, 'name' => 'Alice' },
                                 { 'id' => 2, 'name' => 'Bob' }
                               ]
                             })
      end

      it 'decodes mixed type list' do
        toon = <<~TOON.chomp
          items[3]:
            - 1
            - text
            - id: 1
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'items' => [1, 'text', { 'id' => 1 }]
                             })
      end
    end

    context 'with root-level arrays' do
      it 'decodes root inline array' do
        toon = '[3]: a,b,c'
        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq(%w[a b c])
      end

      it 'decodes root tabular array' do
        toon = <<~TOON.chomp
          [2]{id,name}:
            1,Alice
            2,Bob
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq([
                               { 'id' => 1, 'name' => 'Alice' },
                               { 'id' => 2, 'name' => 'Bob' }
                             ])
      end

      it 'decodes root list array' do
        toon = <<~TOON.chomp
          [2]:
            - id: 1
            - id: 2
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq([
                               { 'id' => 1 },
                               { 'id' => 2 }
                             ])
      end
    end

    context 'with escape sequences' do
      it 'decodes escaped quotes' do
        toon = 'text: "say \\"hi\\""'
        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'text' => 'say "hi"' })
      end

      it 'decodes escaped backslashes' do
        toon = 'path: "C:\\\\Users"'
        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'path' => 'C:\\Users' })
      end

      it 'decodes escaped newlines' do
        toon = 'text: "line1\\nline2"'
        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'text' => "line1\nline2" })
      end
    end

    context 'with complex nested structures' do
      it 'decodes complex structure' do
        toon = <<~TOON.chomp
          users[2]:
            - id: 1
              name: Alice
              meta:
                active: true
            - id: 2
              name: Bob
              meta:
                active: false
        TOON

        result = described_class.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'users' => [
                                 {
                                   'id' => 1,
                                   'name' => 'Alice',
                                   'meta' => { 'active' => true }
                                 },
                                 {
                                   'id' => 2,
                                   'name' => 'Bob',
                                   'meta' => { 'active' => false }
                                 }
                               ]
                             })
      end
    end
  end
end
