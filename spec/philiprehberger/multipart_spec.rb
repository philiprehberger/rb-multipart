# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe Philiprehberger::Multipart do
  it 'has a version number' do
    expect(described_class::VERSION).not_to be_nil
  end

  describe '.build' do
    it 'raises Error when no block is given' do
      expect { described_class.build }.to raise_error(described_class::Error)
    end

    it 'returns a Builder' do
      builder = described_class.build { field :name, 'value' }
      expect(builder).to be_a(described_class::Builder)
    end

    it 'adds a text field' do
      builder = described_class.build { field :name, 'Alice' }
      expect(builder.parts.size).to eq(1)
      expect(builder.parts.first.name).to eq(:name)
      expect(builder.parts.first.value).to eq('Alice')
      expect(builder.parts.first).not_to be_file
    end

    it 'adds multiple fields' do
      builder = described_class.build do
        field :first, 'Alice'
        field :last, 'Smith'
      end
      expect(builder.parts.size).to eq(2)
    end

    it 'adds a file field' do
      tmpfile = Tempfile.new(['test', '.txt'])
      tmpfile.write('hello')
      tmpfile.close

      builder = described_class.build do
        file :upload, tmpfile.path, content_type: 'text/plain'
      end

      expect(builder.parts.size).to eq(1)
      expect(builder.parts.first).to be_file
      expect(builder.parts.first.filename).to eq(File.basename(tmpfile.path))
      expect(builder.parts.first.content_type).to eq('text/plain')
    ensure
      tmpfile&.unlink
    end

    it 'raises Error for missing file' do
      expect do
        described_class.build { file :upload, '/nonexistent/path.txt' }
      end.to raise_error(described_class::Error, /File not found/)
    end

    it 'accepts a custom boundary' do
      builder = described_class.build(boundary: 'custom-boundary') do
        field :name, 'value'
      end
      expect(builder.boundary).to eq('custom-boundary')
    end
  end

  describe Philiprehberger::Multipart::Builder do
    describe '#to_s' do
      it 'produces valid multipart body with text fields' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:name, 'Alice')

        body = builder.to_s
        expect(body).to include('--BOUNDARY')
        expect(body).to include('Content-Disposition: form-data; name="name"')
        expect(body).to include('Alice')
        expect(body).to end_with("--BOUNDARY--\r\n")
      end

      it 'produces valid multipart body with file fields' do
        tmpfile = Tempfile.new(['test', '.png'])
        tmpfile.write('PNG_DATA')
        tmpfile.close

        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:avatar, tmpfile.path, content_type: 'image/png')

        body = builder.to_s
        expect(body).to include('Content-Disposition: form-data; name="avatar"')
        expect(body).to include("filename=\"#{File.basename(tmpfile.path)}\"")
        expect(body).to include('Content-Type: image/png')
        expect(body).to include('PNG_DATA')
      ensure
        tmpfile&.unlink
      end

      it 'includes multiple parts' do
        tmpfile = Tempfile.new(['doc', '.txt'])
        tmpfile.write('content')
        tmpfile.close

        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:name, 'Alice')
        builder.file(:doc, tmpfile.path, content_type: 'text/plain')

        body = builder.to_s
        expect(body.scan('--BOUNDARY').count).to eq(3) # 2 parts + closing
      ensure
        tmpfile&.unlink
      end
    end

    describe '#content_type' do
      it 'returns the multipart content type with boundary' do
        builder = described_class.new(boundary: 'BOUNDARY')
        expect(builder.content_type).to eq('multipart/form-data; boundary=BOUNDARY')
      end
    end

    describe '#boundary' do
      it 'generates a boundary when none is provided' do
        builder = described_class.new
        expect(builder.boundary).to be_a(String)
        expect(builder.boundary).not_to be_empty
      end
    end

    describe '#headers' do
      it 'returns a hash with Content-Type' do
        builder = described_class.new(boundary: 'BOUNDARY')
        expect(builder.headers).to eq({ 'Content-Type' => 'multipart/form-data; boundary=BOUNDARY' })
      end
    end
  end
end
