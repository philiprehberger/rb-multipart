# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'stringio'

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

  describe '.parse' do
    it 'delegates to Parser.parse' do
      body = "--boundary\r\nContent-Disposition: form-data; name=\"x\"\r\n\r\nval\r\n--boundary--\r\n"
      parts = described_class.parse(body, content_type: 'multipart/form-data; boundary=boundary')
      expect(parts).to be_an(Array)
      expect(parts.size).to eq(1)
      expect(parts.first.name).to eq(:x)
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

      it 'auto-detects content type from filename extension' do
        tmpfile = Tempfile.new(['image', '.jpg'])
        tmpfile.write('JPEG_DATA')
        tmpfile.close

        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:upload, tmpfile.path)

        body = builder.to_s
        expect(body).to include('Content-Type: image/jpeg')
      ensure
        tmpfile&.unlink
      end

      it 'falls back to octet-stream for unknown extensions' do
        tmpfile = Tempfile.new(['data', '.xyz123'])
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

    describe '#file with IO objects' do
      it 'accepts a StringIO object' do
        io = StringIO.new('hello world')
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:upload, io, filename: 'hello.txt', content_type: 'text/plain')

        body = builder.to_s
        expect(body).to include('filename="hello.txt"')
        expect(body).to include('Content-Type: text/plain')
        expect(body).to include('hello world')
      end

      it 'auto-detects content type for IO objects from filename' do
        io = StringIO.new('{}')
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:config, io, filename: 'config.json')

        body = builder.to_s
        expect(body).to include('Content-Type: application/json')
      end

      it 'raises Error when filename is missing for IO objects' do
        io = StringIO.new('data')
        builder = described_class.new(boundary: 'BOUNDARY')

        expect do
          builder.file(:upload, io)
        end.to raise_error(Philiprehberger::Multipart::Error, /filename.*required/i)
      end

      it 'accepts a File IO object' do
        tmpfile = Tempfile.new(['io_test', '.csv'])
        tmpfile.write('a,b,c')
        tmpfile.rewind

        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:data, tmpfile, filename: 'data.csv', content_type: 'text/csv')

        body = builder.to_s
        expect(body).to include('filename="data.csv"')
        expect(body).to include('a,b,c')
      ensure
        tmpfile&.close
        tmpfile&.unlink
      end

      it 'reads from current IO position' do
        io = StringIO.new('abcdef')
        io.read(3) # advance to position 3
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:upload, io, filename: 'data.txt', content_type: 'text/plain')

        body = builder.to_s
        expect(body).to include('def')
        expect(body).not_to include('abc')
      end

      it 'allows explicit content_type to override auto-detection for IO' do
        io = StringIO.new('data')
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:upload, io, filename: 'data.json', content_type: 'application/octet-stream')

        body = builder.to_s
        expect(body).to include('Content-Type: application/octet-stream')
      end
    end

    describe '#file with filename override' do
      it 'allows overriding filename for file paths' do
        tmpfile = Tempfile.new(['original', '.txt'])
        tmpfile.write('content')
        tmpfile.close

        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:upload, tmpfile.path, filename: 'custom.txt')

        body = builder.to_s
        expect(body).to include('filename="custom.txt"')
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

    describe '#write_to' do
      it 'produces the same output as #to_s' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:name, 'Alice')
        builder.field(:email, 'alice@example.com')

        io = StringIO.new
        builder.write_to(io)
        expect(io.string).to eq(builder.to_s)
      end

      it 'returns the IO object' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:key, 'value')

        io = StringIO.new
        result = builder.write_to(io)
        expect(result).to equal(io)
      end

      it 'works with an empty builder' do
        builder = described_class.new(boundary: 'BOUNDARY')
        io = StringIO.new
        builder.write_to(io)
        expect(io.string).to eq("--BOUNDARY--\r\n")
      end

      it 'streams file content correctly' do
        tmpfile = Tempfile.new(['stream', '.txt'])
        tmpfile.write('streamed data')
        tmpfile.close

        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:upload, tmpfile.path, content_type: 'text/plain')

        io = StringIO.new
        builder.write_to(io)
        expect(io.string).to include('streamed data')
        expect(io.string).to eq(builder.to_s)
      ensure
        tmpfile&.unlink
      end
    end

    describe '#content_length' do
      it 'matches #to_s.bytesize' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:name, 'Alice')
        builder.field(:count, '42')

        expect(builder.content_length).to eq(builder.to_s.bytesize)
      end

      it 'returns closing boundary size for empty builder' do
        builder = described_class.new(boundary: 'BOUNDARY')
        expect(builder.content_length).to eq("--BOUNDARY--\r\n".bytesize)
      end

      it 'handles binary content correctly' do
        tmpfile = Tempfile.new(['bin', '.dat'])
        tmpfile.binmode
        tmpfile.write("\x00\x01\xFF\xFE")
        tmpfile.close

        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:upload, tmpfile.path)

        expect(builder.content_length).to eq(builder.to_s.bytesize)
      ensure
        tmpfile&.unlink
      end
    end

    describe '#headers' do
      it 'includes both Content-Type and Content-Length' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:key, 'value')

        headers = builder.headers
        expect(headers).to have_key('Content-Type')
        expect(headers).to have_key('Content-Length')
      end

      it 'includes boundary in Content-Type header' do
        builder = described_class.new(boundary: 'my-custom-boundary')
        expect(builder.headers['Content-Type']).to include('my-custom-boundary')
      end

      it 'has Content-Length matching actual body size' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:name, 'Alice')

        expect(builder.headers['Content-Length']).to eq(builder.to_s.bytesize.to_s)
      end
    end

    describe '#parts' do
      it 'returns empty array when no parts added' do
        builder = described_class.new
        expect(builder.parts).to eq([])
      end
    end

    describe '#field_names' do
      it 'returns an empty array for a fresh builder' do
        builder = described_class.new
        expect(builder.field_names).to eq([])
      end

      it 'returns a single field name' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:token, 'abc')

        expect(builder.field_names).to eq(['token'])
      end

      it 'preserves insertion order across fields and files' do
        tmpfile = Tempfile.new(['order', '.txt'])
        tmpfile.write('data')
        tmpfile.close

        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:name, 'Alice')
        builder.file(:avatar, tmpfile.path, content_type: 'text/plain')
        builder.field(:tag, 'important')

        expect(builder.field_names).to eq(%w[name avatar tag])
      ensure
        tmpfile&.unlink
      end

      it 'preserves duplicate names' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:tag, 'first')
        builder.field(:tag, 'second')

        expect(builder.field_names).to eq(%w[tag tag])
      end

      it 'returns a fresh array that does not mutate builder state' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:name, 'Alice')

        builder.field_names << 'x'
        expect(builder.field_names).not_to include('x')
        expect(builder.field_names).to eq(['name'])
      end
    end

    describe '#part' do
      it 'returns the first part with the matching name (symbol lookup)' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:name, 'Alice')
        builder.field(:email, 'alice@example.com')

        found = builder.part(:name)
        expect(found).to be_a(Philiprehberger::Multipart::Part)
        expect(found.value).to eq('Alice')
      end

      it 'returns the first part with the matching name (string lookup)' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:name, 'Alice')

        expect(builder.part('name').value).to eq('Alice')
      end

      it 'treats symbol and string lookups as equivalent' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:key, 'value')

        expect(builder.part(:key)).to equal(builder.part('key'))
      end

      it 'returns nil when no part matches' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:name, 'Alice')

        expect(builder.part(:missing)).to be_nil
      end

      it 'returns the first match when duplicate names exist' do
        builder = described_class.new(boundary: 'BOUNDARY')
        builder.field(:tag, 'first')
        builder.field(:tag, 'second')

        expect(builder.part(:tag).value).to eq('first')
      end

      it 'allows post-construction content_type tweaks that appear in #to_s' do
        tmpfile = Tempfile.new(['avatar', '.png'])
        tmpfile.write('IMG')
        tmpfile.close

        builder = described_class.new(boundary: 'BOUNDARY')
        builder.file(:avatar, tmpfile.path, content_type: 'image/png')

        builder.part('avatar').content_type = 'image/webp'

        body = builder.to_s
        expect(body).to include('Content-Type: image/webp')
        expect(body).not_to include('Content-Type: image/png')
      ensure
        tmpfile&.unlink
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

    describe '#body' do
      it 'returns the same value as #value' do
        part = described_class.new(:field, 'data')
        expect(part.body).to eq(part.value)
        expect(part.body).to eq('data')
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

  describe Philiprehberger::Multipart::MimeTypes do
    describe '.lookup' do
      it 'returns correct MIME type for common extensions' do
        expect(described_class.lookup('photo.jpg')).to eq('image/jpeg')
        expect(described_class.lookup('photo.jpeg')).to eq('image/jpeg')
        expect(described_class.lookup('image.png')).to eq('image/png')
        expect(described_class.lookup('image.gif')).to eq('image/gif')
        expect(described_class.lookup('image.webp')).to eq('image/webp')
        expect(described_class.lookup('icon.svg')).to eq('image/svg+xml')
      end

      it 'returns correct MIME type for document extensions' do
        expect(described_class.lookup('report.pdf')).to eq('application/pdf')
        expect(described_class.lookup('doc.docx')).to eq('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
        expect(described_class.lookup('sheet.xlsx')).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      end

      it 'returns correct MIME type for text extensions' do
        expect(described_class.lookup('file.txt')).to eq('text/plain')
        expect(described_class.lookup('page.html')).to eq('text/html')
        expect(described_class.lookup('style.css')).to eq('text/css')
        expect(described_class.lookup('data.csv')).to eq('text/csv')
        expect(described_class.lookup('config.xml')).to eq('text/xml')
      end

      it 'returns correct MIME type for code extensions' do
        expect(described_class.lookup('data.json')).to eq('application/json')
        expect(described_class.lookup('app.js')).to eq('application/javascript')
        expect(described_class.lookup('script.rb')).to eq('text/x-ruby')
        expect(described_class.lookup('main.py')).to eq('text/x-python')
      end

      it 'returns correct MIME type for archive extensions' do
        expect(described_class.lookup('archive.zip')).to eq('application/zip')
        expect(described_class.lookup('archive.tar')).to eq('application/x-tar')
        expect(described_class.lookup('archive.gz')).to eq('application/gzip')
        expect(described_class.lookup('archive.7z')).to eq('application/x-7z-compressed')
      end

      it 'returns correct MIME type for audio extensions' do
        expect(described_class.lookup('song.mp3')).to eq('audio/mpeg')
        expect(described_class.lookup('sound.wav')).to eq('audio/wav')
        expect(described_class.lookup('track.ogg')).to eq('audio/ogg')
        expect(described_class.lookup('music.flac')).to eq('audio/flac')
      end

      it 'returns correct MIME type for video extensions' do
        expect(described_class.lookup('clip.mp4')).to eq('video/mp4')
        expect(described_class.lookup('movie.avi')).to eq('video/x-msvideo')
        expect(described_class.lookup('video.mkv')).to eq('video/x-matroska')
        expect(described_class.lookup('film.webm')).to eq('video/webm')
      end

      it 'returns correct MIME type for font extensions' do
        expect(described_class.lookup('font.woff')).to eq('font/woff')
        expect(described_class.lookup('font.woff2')).to eq('font/woff2')
        expect(described_class.lookup('font.ttf')).to eq('font/ttf')
        expect(described_class.lookup('font.otf')).to eq('font/otf')
      end

      it 'returns application/octet-stream for unknown extensions' do
        expect(described_class.lookup('file.unknown')).to eq('application/octet-stream')
        expect(described_class.lookup('data.xyz')).to eq('application/octet-stream')
      end

      it 'is case-insensitive for extensions' do
        expect(described_class.lookup('PHOTO.JPG')).to eq('image/jpeg')
        expect(described_class.lookup('file.PDF')).to eq('application/pdf')
        expect(described_class.lookup('data.Json')).to eq('application/json')
      end

      it 'handles full paths' do
        expect(described_class.lookup('/path/to/photo.jpg')).to eq('image/jpeg')
        expect(described_class.lookup('relative/path/doc.pdf')).to eq('application/pdf')
      end

      it 'handles files with no extension' do
        expect(described_class.lookup('Makefile')).to eq('application/octet-stream')
        expect(described_class.lookup('')).to eq('application/octet-stream')
      end

      it 'contains at least 100 extension mappings' do
        expect(described_class::TYPES.size).to be >= 100
      end
    end
  end

  describe Philiprehberger::Multipart::Parser do
    def build_multipart(boundary, parts)
      body = +''
      parts.each do |part|
        body << "--#{boundary}\r\n"
        if part[:filename]
          body << "Content-Disposition: form-data; name=\"#{part[:name]}\"; filename=\"#{part[:filename]}\"\r\n"
          body << "Content-Type: #{part[:content_type] || 'application/octet-stream'}\r\n"
        else
          body << "Content-Disposition: form-data; name=\"#{part[:name]}\"\r\n"
        end
        body << "\r\n"
        body << part[:value]
        body << "\r\n"
      end
      body << "--#{boundary}--\r\n"
      body
    end

    describe '.parse' do
      it 'parses a single text field' do
        body = build_multipart('boundary', [{ name: 'field', value: 'value' }])
        parts = described_class.parse(body, content_type: 'multipart/form-data; boundary=boundary')

        expect(parts.size).to eq(1)
        expect(parts.first.name).to eq(:field)
        expect(parts.first.value).to eq('value')
        expect(parts.first.body).to eq('value')
        expect(parts.first).not_to be_file
      end

      it 'parses multiple text fields' do
        body = build_multipart('boundary', [
                                 { name: 'first', value: 'Alice' },
                                 { name: 'last', value: 'Smith' }
                               ])
        parts = described_class.parse(body, content_type: 'multipart/form-data; boundary=boundary')

        expect(parts.size).to eq(2)
        expect(parts[0].name).to eq(:first)
        expect(parts[0].value).to eq('Alice')
        expect(parts[1].name).to eq(:last)
        expect(parts[1].value).to eq('Smith')
      end

      it 'parses a file part' do
        body = build_multipart('boundary', [
                                 { name: 'upload', value: 'file content', filename: 'test.txt', content_type: 'text/plain' }
                               ])
        parts = described_class.parse(body, content_type: 'multipart/form-data; boundary=boundary')

        expect(parts.size).to eq(1)
        expect(parts.first.name).to eq(:upload)
        expect(parts.first.value).to eq('file content')
        expect(parts.first.filename).to eq('test.txt')
        expect(parts.first.content_type).to eq('text/plain')
        expect(parts.first).to be_file
      end

      it 'parses mixed fields and files' do
        body = build_multipart('boundary', [
                                 { name: 'name', value: 'Alice' },
                                 { name: 'avatar', value: 'PNG_BYTES', filename: 'photo.png', content_type: 'image/png' },
                                 { name: 'bio', value: 'Hello world' }
                               ])
        parts = described_class.parse(body, content_type: 'multipart/form-data; boundary=boundary')

        expect(parts.size).to eq(3)
        expect(parts[0]).not_to be_file
        expect(parts[1]).to be_file
        expect(parts[1].filename).to eq('photo.png')
        expect(parts[2]).not_to be_file
      end

      it 'raises Error for missing boundary in content type' do
        expect do
          described_class.parse('body', content_type: 'multipart/form-data')
        end.to raise_error(Philiprehberger::Multipart::Error, /boundary/)
      end

      it 'raises Error for nil content type' do
        expect do
          described_class.parse('body', content_type: nil)
        end.to raise_error(Philiprehberger::Multipart::Error, /boundary/)
      end

      it 'handles boundary with quotes in content type' do
        body = build_multipart('my-boundary', [{ name: 'key', value: 'val' }])
        parts = described_class.parse(body, content_type: 'multipart/form-data; boundary="my-boundary"')

        expect(parts.size).to eq(1)
        expect(parts.first.value).to eq('val')
      end

      it 'returns empty array for body with no parts' do
        body = "--boundary--\r\n"
        parts = described_class.parse(body, content_type: 'multipart/form-data; boundary=boundary')
        expect(parts).to eq([])
      end

      it 'handles multiline field values' do
        body = build_multipart('boundary', [{ name: 'text', value: "line1\r\nline2\r\nline3" }])
        parts = described_class.parse(body, content_type: 'multipart/form-data; boundary=boundary')

        expect(parts.first.value).to eq("line1\r\nline2\r\nline3")
      end

      it 'roundtrips with Builder output' do
        tmpfile = Tempfile.new(['roundtrip', '.txt'])
        tmpfile.write('file data')
        tmpfile.close

        builder = Philiprehberger::Multipart.build(boundary: 'ROUNDTRIP') do
          field :name, 'Alice'
          file :doc, tmpfile.path, content_type: 'text/plain'
        end

        parts = Philiprehberger::Multipart.parse(builder.to_s, content_type: builder.content_type)

        expect(parts.size).to eq(2)
        expect(parts[0].name).to eq(:name)
        expect(parts[0].value).to eq('Alice')
        expect(parts[1].name).to eq(:doc)
        expect(parts[1].value).to eq('file data')
        expect(parts[1]).to be_file
        expect(parts[1].content_type).to eq('text/plain')
      ensure
        tmpfile&.unlink
      end

      it 'roundtrips with IO-based file uploads' do
        io = StringIO.new('streamed content')
        builder = Philiprehberger::Multipart.build(boundary: 'IO-RT') do
          file :upload, io, filename: 'stream.txt', content_type: 'text/plain'
        end

        parts = Philiprehberger::Multipart.parse(builder.to_s, content_type: builder.content_type)
        expect(parts.size).to eq(1)
        expect(parts.first.value).to eq('streamed content')
        expect(parts.first.filename).to eq('stream.txt')
      end
    end

    describe '#merge' do
      it 'appends parts from another builder preserving insertion order' do
        a = Philiprehberger::Multipart::Builder.new(boundary: 'AAA')
        a.field(:name, 'Alice')

        b = Philiprehberger::Multipart::Builder.new(boundary: 'BBB')
        b.field(:email, 'alice@example.com')
        b.field(:role, 'admin')

        a.merge(b)

        expect(a.field_names).to eq(%w[name email role])
      end

      it 'reuses the original Part objects without re-encoding' do
        source = Philiprehberger::Multipart::Builder.new
        source.field(:shared, 'value')
        original_part = source.parts.first

        destination = Philiprehberger::Multipart::Builder.new
        destination.merge(source)

        expect(destination.parts.first).to be(original_part)
      end

      it 'keeps the receiving builder boundary' do
        a = Philiprehberger::Multipart::Builder.new(boundary: 'AAA')
        a.field(:name, 'Alice')
        b = Philiprehberger::Multipart::Builder.new(boundary: 'BBB')
        b.field(:email, 'alice@example.com')

        a.merge(b)
        expect(a.boundary).to eq('AAA')
      end

      it 'returns self for chaining' do
        a = Philiprehberger::Multipart::Builder.new
        b = Philiprehberger::Multipart::Builder.new
        expect(a.merge(b)).to be(a)
      end

      it 'raises Error when merging a non-Builder' do
        a = Philiprehberger::Multipart::Builder.new
        expect { a.merge({}) }.to raise_error(Philiprehberger::Multipart::Error, /Builder/)
      end
    end
  end
end
