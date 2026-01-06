# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Key Quoting' do
  let(:encoder) { JsonToToon::Encoder.new }

  describe 'unquoted keys' do
    it 'does not quote simple keys' do
      result = encoder.encode({ hello: 'world' })
      expect(result).to eq('hello: world')
    end

    it 'does not quote keys with underscores' do
      result = encoder.encode({ user_id: 1 })
      expect(result).to eq('user_id: 1')
    end
  end

  describe 'quoted keys' do
    it 'quotes empty keys' do
      result = encoder.encode({ '' => 'value' })
      expect(result).to eq('"": value')
    end

    it 'quotes keys with spaces' do
      result = encoder.encode({ 'full name' => 'Ada' })
      expect(result).to eq('"full name": Ada')
    end

    it 'quotes keys with commas' do
      result = encoder.encode({ 'a,b' => 1 })
      expect(result).to eq('"a,b": 1')
    end

    it 'quotes keys with colons' do
      result = encoder.encode({ 'key:value' => 1 })
      expect(result).to eq('"key:value": 1')
    end

    it 'quotes keys with brackets' do
      result = encoder.encode({ '[index]' => 1 })
      expect(result).to eq('"[index]": 1')
    end

    it 'quotes keys starting with hyphen' do
      result = encoder.encode({ '-lead' => 1 })
      expect(result).to eq('"-lead": 1')
    end

    it 'quotes numeric keys' do
      result = encoder.encode({ '123' => 'value' })
      expect(result).to eq('"123": value')
    end
  end
end
