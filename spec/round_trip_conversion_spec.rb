# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe 'Round trip conversion' do
  let(:encoder) { JsonToToon::Encoder.new }
  let(:decoder) { ToonToJson::Decoder.new }

  describe 'round-trip encoding and decoding' do
    it 'handles arrays within list item objects' do
      original_data = {
        'users' => [
          { 'id' => 101, 'name' => 'Alice', 'access' => %w[read write] },
          { 'id' => 102, 'name' => 'Bob', 'access' => ['read'] }
        ]
      }

      # Encode to TOON
      toon = encoder.encode(original_data)

      # Expected TOON format:
      # users[2]:
      #   - id: 101
      #     name: Alice
      #     access[2]: read,write
      #   - id: 102
      #     name: Bob
      #     access[1]: read

      expect(toon).to include('users[2]:')
      expect(toon).to include('access[2]: read,write')
      expect(toon).to include('access[1]: read')

      # Decode back to JSON
      decoded_json = decoder.decode(toon)
      decoded_data = JSON.parse(decoded_json)

      # Verify structure
      expect(decoded_data).to have_key('users')
      expect(decoded_data['users']).to be_an(Array)
      expect(decoded_data['users'].length).to eq(2)

      # CRITICAL: Verify 'access' is an array, not a string with key 'access[2]'
      alice = decoded_data['users'][0]
      expect(alice).to have_key('access')
      expect(alice['access']).to be_an(Array)
      expect(alice['access']).to eq(%w[read write])
      expect(alice).not_to have_key('access[2]') # This was the bug!

      bob = decoded_data['users'][1]
      expect(bob).to have_key('access')
      expect(bob['access']).to be_an(Array)
      expect(bob['access']).to eq(['read'])
      expect(bob).not_to have_key('access[1]') # This was the bug!
    end

    it 'handles complex nested structure' do
      complex_data = {
        'project' => 'SecureAPI',
        'meta' => { 'version' => '1.0', 'active' => true },
        'users' => [
          { 'id' => 101, 'name' => 'Alice', 'access' => %w[read write] },
          { 'id' => 102, 'name' => 'Bob', 'access' => ['read'] }
        ],
        'logs' => [
          { 'event' => 'login', 'status' => 200 },
          { 'event' => 'query', 'status' => 200 },
          { 'event' => 'logout', 'status' => 204 }
        ]
      }

      # Encode
      toon_output = encoder.encode(complex_data)

      # Decode
      decoded_json = decoder.decode(toon_output)
      decoded_data = JSON.parse(decoded_json)

      # Verify round-trip
      expect(decoded_data['project']).to eq('SecureAPI')
      expect(decoded_data['meta']['version']).to eq('1.0')
      expect(decoded_data['meta']['active']).to eq(true)

      # Verify users array
      expect(decoded_data['users'].length).to eq(2)

      alice = decoded_data['users'][0]
      expect(alice['id']).to eq(101)
      expect(alice['name']).to eq('Alice')
      expect(alice['access']).to be_an(Array)
      expect(alice['access']).to eq(%w[read write])

      bob = decoded_data['users'][1]
      expect(bob['id']).to eq(102)
      expect(bob['name']).to eq('Bob')
      expect(bob['access']).to be_an(Array)
      expect(bob['access']).to eq(['read'])

      # Verify logs (tabular format)
      expect(decoded_data['logs'].length).to eq(3)
      expect(decoded_data['logs'][0]).to eq({ 'event' => 'login', 'status' => 200 })
      expect(decoded_data['logs'][1]).to eq({ 'event' => 'query', 'status' => 200 })
      expect(decoded_data['logs'][2]).to eq({ 'event' => 'logout', 'status' => 204 })
    end

    it 'handles multiple nested arrays in same object' do
      data = {
        'user' => {
          'id' => 1,
          'roles' => %w[admin user],
          'permissions' => %w[read write delete],
          'tags' => ['important']
        }
      }

      toon = encoder.encode(data)
      decoded_json = decoder.decode(toon)
      decoded_data = JSON.parse(decoded_json)

      expect(decoded_data['user']['roles']).to eq(%w[admin user])
      expect(decoded_data['user']['permissions']).to eq(%w[read write delete])
      expect(decoded_data['user']['tags']).to eq(['important'])
    end

    it 'handles arrays at different nesting levels in list items' do
      data = {
        'items' => [
          {
            'id' => 1,
            'tags' => %w[tag1 tag2],
            'nested' => {
              'values' => %w[a b]
            }
          }
        ]
      }

      toon = encoder.encode(data)
      decoded_json = decoder.decode(toon)
      decoded_data = JSON.parse(decoded_json)

      item = decoded_data['items'][0]
      expect(item['tags']).to be_an(Array)
      expect(item['tags']).to eq(%w[tag1 tag2])
      expect(item['nested']['values']).to be_an(Array)
      expect(item['nested']['values']).to eq(%w[a b])
    end

    it 'handles inline arrays as first field in list item' do
      data = {
        'records' => [
          { 'tags' => %w[a b], 'id' => 1 },
          { 'tags' => ['c'], 'id' => 2 }
        ]
      }

      toon = encoder.encode(data)

      expect(toon).to include('- tags[2]: a,b')
      expect(toon).to include('- tags[1]: c')

      decoded_json = decoder.decode(toon)
      decoded_data = JSON.parse(decoded_json)

      expect(decoded_data['records'][0]['tags']).to eq(%w[a b])
      expect(decoded_data['records'][1]['tags']).to eq(['c'])
    end

    it 'handles empty arrays in list items' do
      data = {
        'items' => [
          { 'id' => 1, 'tags' => [] },
          { 'id' => 2, 'tags' => ['test'] }
        ]
      }

      toon = encoder.encode(data)
      decoded_json = decoder.decode(toon)
      decoded_data = JSON.parse(decoded_json)

      expect(decoded_data['items'][0]['tags']).to eq([])
      expect(decoded_data['items'][1]['tags']).to eq(['test'])
    end
  end

  describe 'edge cases with inline arrays' do
    it 'handles arrays with quoted values containing delimiter' do
      data = {
        'users' => [
          { 'id' => 1, 'tags' => ['hello, world', 'test'] }
        ]
      }

      toon = encoder.encode(data)
      decoded_json = decoder.decode(toon)
      decoded_data = JSON.parse(decoded_json)

      expect(decoded_data['users'][0]['tags']).to eq(['hello, world', 'test'])
    end

    it 'handles arrays with different delimiters' do
      encoder_tab = JsonToToon::Encoder.new(delimiter: "\t")
      decoder_tab = ToonToJson::Decoder.new

      data = {
        'items' => [
          { 'id' => 1, 'values' => %w[a b c] }
        ]
      }

      toon = encoder_tab.encode(data)
      expect(toon).to include("\t") # Should use tab delimiter

      decoded_json = decoder_tab.decode(toon)
      decoded_data = JSON.parse(decoded_json)

      expect(decoded_data['items'][0]['values']).to eq(%w[a b c])
    end

    it 'handles arrays with numeric values' do
      data = {
        'records' => [
          { 'id' => 1, 'scores' => [95, 87, 92] }
        ]
      }

      toon = encoder.encode(data)
      decoded_json = decoder.decode(toon)
      decoded_data = JSON.parse(decoded_json)

      expect(decoded_data['records'][0]['scores']).to eq([95, 87, 92])
    end

    it 'handles arrays with mixed types' do
      data = {
        'items' => [
          { 'id' => 1, 'mixed' => [42, 'text', true, nil] }
        ]
      }

      toon = encoder.encode(data)
      decoded_json = decoder.decode(toon)
      decoded_data = JSON.parse(decoded_json)

      expect(decoded_data['items'][0]['mixed']).to eq([42, 'text', true, nil])
    end
  end

  describe 'regression tests' do
    it 'still handles regular key-value pairs correctly' do
      data = {
        'users' => [
          { 'id' => 1, 'name' => 'Alice', 'email' => 'alice@example.com' }
        ]
      }

      toon = encoder.encode(data)
      decoded_json = decoder.decode(toon)
      decoded_data = JSON.parse(decoded_json)

      user = decoded_data['users'][0]
      expect(user['id']).to eq(1)
      expect(user['name']).to eq('Alice')
      expect(user['email']).to eq('alice@example.com')
    end

    it 'still handles nested objects in list items' do
      data = {
        'items' => [
          { 'id' => 1, 'meta' => { 'created' => '2025-01-01', 'active' => true } }
        ]
      }

      toon = encoder.encode(data)
      decoded_json = decoder.decode(toon)
      decoded_data = JSON.parse(decoded_json)

      expect(decoded_data['items'][0]['meta']['created']).to eq('2025-01-01')
      expect(decoded_data['items'][0]['meta']['active']).to eq(true)
    end
  end
end
