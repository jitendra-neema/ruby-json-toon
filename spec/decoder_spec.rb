# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe ToonToJson::Decoder do
  let(:decoder) { described_class.new }

  describe '.decode' do
    context 'with primitives' do
      it 'decodes null' do
        expect(decoder.decode('null')).to eq('null')
      end

      it 'decodes true' do
        expect(decoder.decode('true')).to eq('true')
      end

      it 'decodes false' do
        expect(decoder.decode('false')).to eq('false')
      end

      it 'decodes integers' do
        expect(decoder.decode('42')).to eq('42')
        expect(decoder.decode('-17')).to eq('-17')
      end

      it 'decodes floats' do
        expect(decoder.decode('3.14')).to eq('3.14')
        expect(decoder.decode('-2.5')).to eq('-2.5')
      end

      it 'decodes strings' do
        result = decoder.decode('hello')
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

        result = decoder.decode(toon)
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

        result = decoder.decode(toon)
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

        result = decoder.decode(toon)
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

        result = decoder.decode(toon)
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

        result = decoder.decode(toon)
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
        result = decoder.decode('')
        expect(result).to eq('null')
      end

      it 'decodes nested empty object' do
        toon = 'config:'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'config' => {} })
      end

      it 'decodes empty array' do
        toon = 'items[0]:'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'items' => [] })
      end
    end

    context 'with inline arrays' do
      it 'decodes inline primitive array' do
        toon = 'tags[3]: admin,ops,dev'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'tags' => %w[admin ops dev]
                             })
      end

      it 'decodes inline array with numbers' do
        toon = 'nums[3]: 1,2,3'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'nums' => [1, 2, 3]
                             })
      end

      it 'decodes inline array with quoted strings' do
        toon = 'items[2]: "a,b","c,d"'
        result = decoder.decode(toon)
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

        result = decoder.decode(toon)
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
        result = decoder.decode(toon)
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

        result = decoder.decode(toon)
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

        result = decoder.decode(toon)
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

        result = decoder.decode(toon)
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

        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'items' => [1, 'text', { 'id' => 1 }]
                             })
      end
    end

    context 'with root-level arrays' do
      it 'decodes root inline array' do
        toon = '[3]: a,b,c'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq(%w[a b c])
      end

      it 'decodes root tabular array' do
        toon = <<~TOON.chomp
          [2]{id,name}:
            1,Alice
            2,Bob
        TOON

        result = decoder.decode(toon)
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

        result = decoder.decode(toon)
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
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'text' => 'say "hi"' })
      end

      it 'decodes escaped backslashes' do
        toon = 'path: "C:\\\\Users"'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'path' => 'C:\\Users' })
      end

      it 'decodes escaped newlines' do
        toon = 'text: "line1\\nline2"'
        result = decoder.decode(toon)
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

        result = decoder.decode(toon)
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

    # ============================================
    # DELIMITER VARIATIONS
    # ============================================
    context 'with different delimiters' do
      it 'handles length markers with delimiters' do
        toon = 'items[#3]: a,b,c'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)
        expect(parsed).to eq({ 'items' => %w[a b c] })
      end

      it 'handles tab delimiter in inline and tabular' do
        toon = "inline[2\t]: a\tb\ntabular[2\t]{x\ty}:\n  1\t2\n  3\t4"
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed['inline']).to eq(%w[a b])
        expect(parsed['tabular']).to eq([{ 'x' => 1, 'y' => 2 }, { 'x' => 3, 'y' => 4 }])
      end

      it 'handles pipe delimiter in inline and tabular' do
        toon = <<~TOON.chomp
          inline[2|]: a|b
          tabular[2|]{x|y}:
            1|2
            3|4
        TOON

        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed['inline']).to eq(%w[a b])
        expect(parsed['tabular']).to eq([{ 'x' => 1, 'y' => 2 }, { 'x' => 3, 'y' => 4 }])
      end
    end

    # ============================================
    # ESCAPE SEQUENCES
    # ============================================
    context 'with escape sequences' do
      it 'decodes escaped newlines' do
        toon = 'text: "line1\\nline2"'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'text' => "line1\nline2" })
      end

      it 'decodes escaped quotes' do
        toon = 'quote: "say \\"hi\\""'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'quote' => 'say "hi"' })
      end

      it 'decodes escaped backslashes' do
        toon = 'path: "C:\\\\Users\\\\test"'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'path' => 'C:\\Users\\test' })
      end

      it 'decodes escaped tabs' do
        toon = 'data: "col1\\tcol2"'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'data' => "col1\tcol2" })
      end

      it 'decodes escaped carriage returns' do
        toon = 'text: "line1\\rline2"'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'text' => "line1\rline2" })
      end

      it 'decodes multiple escape sequences' do
        toon = 'msg: "line1\\npath: C:\\\\test\\ttab"'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'msg' => "line1\npath: C:\\test\ttab" })
      end

      it 'does not double-unescape' do
        toon = 'text: "\\\\n"'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({ 'text' => '\\n' })
      end
    end

    # ============================================
    # COMPLEX NESTED STRUCTURES
    # ============================================
    context 'with complex nested structures' do
      it 'decodes complex e-commerce order' do
        toon = <<~TOON.chomp
          order:
            id: 12345
            customer:
              name: John Doe
              email: john@example.com
            items[2]{sku,name,qty,price}:
              A1,Widget,2,9.99
              B2,Gadget,1,14.5
            shipping:
              address: "123 Main St, City"
              method: express
            total: 34.48
        TOON

        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed['order']['id']).to eq(12_345)
        expect(parsed['order']['items'].length).to eq(2)
        expect(parsed['order']['customer']['name']).to eq('John Doe')
        expect(parsed['order']['total']).to eq(34.48)
      end

      it 'decodes deeply nested with mixed formats' do
        toon = <<~TOON.chomp
          root:
            level1:
              inline[3]: a,b,c
              tabular[2]{x,y}:
                1,2
                3,4
              list[2]:
                - item1
                - item2
            level2:
              nested:
                deep: value
        TOON

        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed['root']['level1']['inline']).to eq(%w[a b c])
        expect(parsed['root']['level1']['tabular'].length).to eq(2)
        expect(parsed['root']['level1']['list']).to eq(%w[item1 item2])
        expect(parsed['root']['level2']['nested']['deep']).to eq('value')
      end
    end

    # ============================================
    # EDGE CASES
    # ============================================
    context 'with edge cases' do
      it 'handles empty string vs null' do
        toon = <<~TOON.chomp
          empty: ""
          null_val: null
          text: value
        TOON

        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed['empty']).to eq('')
        expect(parsed['null_val']).to be_nil
        expect(parsed['text']).to eq('value')
      end

      it 'handles numbers in various formats' do
        toon = <<~TOON.chomp
          int: 42
          negative: -17
          float: 3.14
          negative_float: -2.5
          scientific: 1.5e10
          zero: 0
        TOON

        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed['int']).to eq(42)
        expect(parsed['negative']).to eq(-17)
        expect(parsed['float']).to eq(3.14)
        expect(parsed['negative_float']).to eq(-2.5)
        expect(parsed['scientific']).to eq(1.5e10)
        expect(parsed['zero']).to eq(0)
      end

      it 'handles unicode characters' do
        toon = 'emoji: "Hello 👋 World 🌍"'
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed['emoji']).to eq('Hello 👋 World 🌍')
      end

      it 'handles very long strings' do
        long_string = 'a' * 1000
        toon = "text: \"#{long_string}\""
        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed['text'].length).to eq(1000)
      end

      it 'handles arrays of arrays' do
        toon = <<~TOON.chomp
          matrix[3]:
            [2]: 1,2
            [2]: 3,4
            [2]: 5,6
        TOON

        result = decoder.decode(toon)
        parsed = JSON.parse(result)

        expect(parsed).to eq({
                               'matrix' => [[1, 2], [3, 4], [5, 6]]
                             })
      end

      it 'produces valid JSON for all test cases' do
        test_cases = [
          'value: 123',
          'items[2]: a,b',
          '[1]: test',
          'key: "quoted"',
          'list[1]:\n  - item',
          'obj:\n  nested: true',
          '-42',
          'true',
          '""'
        ]

        test_cases.each do |toon|
          result = decoder.decode(toon)
          expect { JSON.parse(result) }.not_to raise_error, "Failed on: #{toon}"
        end
      end
    end
  end

  context 'with list block edge cases' do
    it 'decodes list with empty item followed by nested block' do
      toon = <<~TOON.chomp
        items[2]:
          -#{' '}
            name: nested
          - value: simple
      TOON

      result = decoder.decode(toon)
      parsed = JSON.parse(result)
      expect(parsed).to eq({
                             'items' => [
                               { 'name' => 'nested' },
                               { 'value' => 'simple' }
                             ]
                           })
    end

    it 'decodes list item with key-value and additional nested fields' do
      toon = <<~TOON.chomp
        users[2]:
          - id: 1
            name: Alice
            active: true
          - id: 2
            name: Bob
      TOON

      result = decoder.decode(toon)
      parsed = JSON.parse(result)
      expect(parsed).to eq({
                             'users' => [
                               { 'id' => 1, 'name' => 'Alice', 'active' => true },
                               { 'id' => 2, 'name' => 'Bob' }
                             ]
                           })
    end

    it 'decodes list item with key-only and nested object' do
      toon = <<~TOON.chomp
        items[2]:
          - config:
              debug: true
              port: 8080
          - simple: value
      TOON

      result = decoder.decode(toon)
      parsed = JSON.parse(result)
      expect(parsed).to eq({
                             'items' => [
                               { 'config' => { 'debug' => true, 'port' => 8080 } },
                               { 'simple' => 'value' }
                             ]
                           })
    end

    it 'decodes list item with key-only and no nested content' do
      toon = <<~TOON.chomp
        items[1]:
          - empty:
      TOON

      result = decoder.decode(toon)
      parsed = JSON.parse(result)
      expect(parsed).to eq({
                             'items' => [{ 'empty' => {} }]
                           })
    end

    it 'decodes list with nested field that has key-only and nested block' do
      toon = <<~TOON.chomp
        items[1]:
          - id: 1
            meta:
              active: true
      TOON

      result = decoder.decode(toon)
      parsed = JSON.parse(result)
      expect(parsed).to eq({
                             'items' => [
                               {
                                 'id' => 1,
                                 'meta' => { 'active' => true }
                               }
                             ]
                           })
    end
  end
end
