require 'spec_helper'

RSpec.describe JsonToToon::Encoder do
  describe '#initialize' do
    context 'with valid options' do
      it 'accepts default options' do
        expect { described_class.new }.not_to raise_error
      end

      it 'accepts custom indent size' do
        encoder = described_class.new(indent: 4)
        expect(encoder.indent_size).to eq(4)
      end

      it 'accepts comma delimiter' do
        encoder = described_class.new(delimiter: ',')
        expect(encoder.delimiter).to eq(',')
      end

      it 'accepts tab delimiter' do
        encoder = described_class.new(delimiter: "\t")
        expect(encoder.delimiter).to eq("\t")
      end

      it 'accepts pipe delimiter' do
        encoder = described_class.new(delimiter: '|')
        expect(encoder.delimiter).to eq('|')
      end

      it 'accepts length marker' do
        encoder = described_class.new(length_marker: '#')
        expect(encoder.length_marker).to eq('#')
      end

      it 'accepts false length marker' do
        encoder = described_class.new(length_marker: false)
        expect(encoder.length_marker).to eq(false)
      end
    end

    context 'with invalid options' do
      it 'raises error for invalid indent size' do
        expect { described_class.new(indent: 0) }
          .to raise_error(JsonToToon::InvalidOptionError, /indent must be a positive integer/)
      end

      it 'raises error for negative indent size' do
        expect { described_class.new(indent: -1) }
          .to raise_error(JsonToToon::InvalidOptionError)
      end

      it 'raises error for non-integer indent size' do
        expect { described_class.new(indent: 'two') }
          .to raise_error(JsonToToon::InvalidOptionError)
      end

      it 'raises error for invalid delimiter' do
        expect { described_class.new(delimiter: ';') }
          .to raise_error(JsonToToon::InvalidOptionError, /delimiter must be one of/)
      end

      it 'raises error for invalid length marker' do
        expect { described_class.new(length_marker: '*') }
          .to raise_error(JsonToToon::InvalidOptionError, /length_marker must be/)
      end
    end
  end

  describe '#delimiter_marker' do
    it 'returns empty string for comma delimiter' do
      encoder = described_class.new(delimiter: ',')
      expect(encoder.delimiter_marker).to eq('')
    end

    it 'returns tab character for tab delimiter' do
      encoder = described_class.new(delimiter: "\t")
      expect(encoder.delimiter_marker).to eq("\t")
    end

    it 'returns pipe character for pipe delimiter' do
      encoder = described_class.new(delimiter: '|')
      expect(encoder.delimiter_marker).to eq('|')
    end
  end

  describe '#length_prefix' do
    it 'returns hash when length_marker is #' do
      encoder = described_class.new(length_marker: '#')
      expect(encoder.length_prefix).to eq('#')
    end

    it 'returns empty string when length_marker is false' do
      encoder = described_class.new(length_marker: false)
      expect(encoder.length_prefix).to eq('')
    end
  end

  describe '#encode' do
    let(:encoder) { described_class.new }

    context 'with primitives' do
      it 'encodes strings without quotes when safe' do
        expect(encoder.encode('hello')).to eq('hello')
      end

      it 'encodes strings with quotes when needed' do
        expect(encoder.encode('hello world')).to eq('"hello world"')
      end

      it 'encodes integers' do
        expect(encoder.encode(42)).to eq('42')
      end

      it 'encodes floats' do
        expect(encoder.encode(3.14)).to eq('3.14')
      end

      it 'encodes true' do
        expect(encoder.encode(true)).to eq('true')
      end

      it 'encodes false' do
        expect(encoder.encode(false)).to eq('false')
      end

      it 'encodes nil as null' do
        expect(encoder.encode(nil)).to eq('null')
      end
    end

    context 'with special number cases' do
      it 'converts -0 to 0' do
        expect(encoder.encode(-0.0)).to eq('0')
      end

      it 'converts NaN to null' do
        expect(encoder.encode(Float::NAN)).to eq('null')
      end

      it 'converts Infinity to null' do
        expect(encoder.encode(Float::INFINITY)).to eq('null')
      end

      it 'converts -Infinity to null' do
        expect(encoder.encode(-Float::INFINITY)).to eq('null')
      end
    end

    context 'with simple objects' do
      it 'encodes simple hash' do
        input = { id: 123, name: 'Ada', active: true }
        expected = "id: 123\nname: Ada\nactive: true"
        expect(encoder.encode(input)).to eq(expected)
      end

      it 'encodes empty root hash as empty string' do
        expect(encoder.encode({})).to eq('')
      end

      it 'encodes hash with nested empty hash' do
        input = { config: {} }
        expected = "config:"
        expect(encoder.encode(input)).to eq(expected)
      end
    end

    context 'with nested objects' do
      it 'encodes nested hash' do
        input = { user: { id: 123, name: 'Ada' } }
        expected = "user:\n  id: 123\n  name: Ada"
        expect(encoder.encode(input)).to eq(expected)
      end

      it 'encodes deeply nested hash' do
        input = { a: { b: { c: 1 } } }
        expected = "a:\n  b:\n    c: 1"
        expect(encoder.encode(input)).to eq(expected)
      end
    end

    context 'with empty arrays' do
      it 'encodes root empty array' do
        expected = '[0]:'
        expect(encoder.encode([])).to eq(expected)
      end

      it 'encodes nested empty array' do
        input = { items: [] }
        expected = 'items[0]:'
        expect(encoder.encode(input)).to eq(expected)
      end
    end

    context 'with circular references' do
      it 'detects circular reference in hash' do
        hash = { a: 1 }
        hash[:self] = hash
        expect { encoder.encode(hash) }
          .to raise_error(JsonToToon::CircularReferenceError)
      end

      it 'detects circular reference in array' do
        array = [1, 2]
        array << array
        expect { encoder.encode(array) }
          .to raise_error(JsonToToon::CircularReferenceError)
      end
    end
  end
end