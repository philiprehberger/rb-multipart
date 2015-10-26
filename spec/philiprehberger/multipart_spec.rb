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

    it 'converts non-string field values to strings' do
      builder = described_class.build do
        field :count, 42
      end
      expect(builder.parts.first.value).to eq('42')
    end

    it 'adds multiple files' do
      tmpfile1 = Tempfile.new(['f1', '.txt'])
      tmpfile1.write('one')
      tmpfile1.close
      tmpfile2 = Tempfile.new(['f2', '.txt'])
      tmpfile2.write('two')
      tmpfile2.close

      builder = described_class.build do
        file :file1, tmpfile1.path, content_type: 'text/plain'
        file :file2, tmpfile2.path, content_type: 'text/plain'
      end

      expect(builder.parts.size).to eq(2)
      expect(builder.parts.all?(&:file?)).to be true
    ensure
      tmpfile1&.unlink
      tmpfile2&.unlink
    end

    it 'mixes fields and files' do
      tmpfile = Tempfile.new(['mixed', '.txt'])
      tmpfile.write('data')
      tmpfile.close

      builder = described_class.build do
        field :name, 'Alice'
        file :doc, tmpfile.path, content_type: 'text/plain'
        field :tag, 'important'
      end

      expect(builder.parts.size).to eq(3)
      expect(builder.parts[0]).not_to be_file
      expect(builder.parts[1]).to be_file
      expect(builder.parts[2]).not_to be_file
    ensure
      tmpfile&.unlink
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

      it 'produces empty body with closing boundary when no parts added' do
        builder = described_class.new(boundary: 'BOUNDARY')
        body = builder.to_s
        expect(body).to eq("--BOUNDARY--\r\n")
      end

      it 'includes CRLF line endings between parts' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:a, '1')
        builder.field(:b, '2')

        body = builder.to_s
        expect(body).to include("\r\n")
      end

      it 'places field value after blank line' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:data, 'myvalue')

        body = builder.to_s
        expect(body).to include("\r\n\r\nmyvalue\r\n")
      end

      it 'defaults file content_type to application/octet-stream' do
        tmpfile = Tempfile.new(['bin', '.dat'])
        tmpfile.write('binary')
        tmpfile.close

        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:upload, tmpfile.path)

        body = builder.to_s
        expect(body).to include('Content-Type: application/octet-stream')
      ensure
        tmpfile&.unlink
      end

      it 'reads binary file content correctly' do
        tmpfile = Tempfile.new(['bin', '.dat'])
        tmpfile.binmode
        tmpfile.write("\x00\x01\xFF")
        tmpfile.close

        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:upload, tmpfile.path)

        body = builder.to_s
        expect(body.b).to include("\x00\x01\xFF".b)
      ensure
        tmpfile&.unlink
      end

      it 'handles special characters in field values' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:note, "line1\nline2")

        body = builder.to_s
        expect(body).to include("line1\nline2")
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

      it 'generates unique boundaries' do
        b1 = described_class.new.boundary
        b2 = described_class.new.boundary
        expect(b1).not_to eq(b2)
      end

      it 'generated boundary starts with expected prefix' do
        builder = described_class.new
        expect(builder.boundary).to start_with('----PhiliprehbergerMultipart')
      end
    end

    describe '#headers' do
      it 'returns a hash with Content-Type' do
        builder = described_class.new(boundary: 'BOUNDARY')
        expect(builder.headers).to eq({ 'Content-Type' => 'multipart/form-data; boundary=BOUNDARY' })
      end

      it 'includes boundary in Content-Type header' do
        builder = described_class.new(boundary: 'my-custom-boundary')
        expect(builder.headers['Content-Type']).to include('my-custom-boundary')
      end
    end

    describe '#parts' do
      it 'returns empty array when no parts added' do
        builder = described_class.new
        expect(builder.parts).to eq([])
      end
    end
  end

  describe Philiprehberger::Multipart::Part do
    describe '#file?' do
      it 'returns false for text parts' do
        part = described_class.new(:name, 'value')
        expect(part).not_to be_file
      end

      it 'returns true for file parts' do
        part = described_class.new(:doc, 'content', filename: 'test.txt', content_type: 'text/plain')
        expect(part).to be_file
      end
    end

    describe '#to_s' do
      it 'renders text part correctly' do
        part = described_class.new(:field, 'data')
        output = part.to_s('BOUNDARY')
        expect(output).to include('--BOUNDARY')
        expect(output).to include('name="field"')
        expect(output).not_to include('filename=')
      end

      it 'renders file part with filename and content type' do
        part = described_class.new(:doc, 'bytes', filename: 'file.pdf', content_type: 'application/pdf')
        output = part.to_s('BOUNDARY')
        expect(output).to include('filename="file.pdf"')
        expect(output).to include('Content-Type: application/pdf')
      end
    end
  end
end
