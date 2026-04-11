# frozen_string_literal: true

require_relative 'part'
require_relative 'mime_types'

module Philiprehberger
  module Multipart
    # DSL builder for constructing multipart/form-data bodies
    class Builder
      # @return [String] the multipart boundary string
      attr_reader :boundary

      # @return [Array<Part>] the parts added to the builder
      attr_reader :parts

      # @param boundary [String, nil] optional custom boundary string
      def initialize(boundary: nil)
        @boundary = boundary || generate_boundary
        @parts = []
      end

      # Add a text field
      #
      # @param name [Symbol, String] the field name
      # @param value [String] the field value
      # @return [self]
      def field(name, value)
        @parts << Part.new(name, value.to_s)
        self
      end

      # Add a file field
      #
      # Accepts either a file path (String) or an IO object (responds to :read).
      # When passing an IO object, the `filename:` keyword is required.
      # Content type is auto-detected from the filename when not provided.
      #
      # @param name [Symbol, String] the field name
      # @param path_or_io [String, #read] the file path or IO object
      # @param filename [String, nil] override filename (required for IO objects)
      # @param content_type [String, nil] the MIME content type (auto-detected if nil)
      # @return [self]
      # @raise [Error] if the file does not exist (path mode) or filename is missing (IO mode)
      def file(name, path_or_io, filename: nil, content_type: nil)
        if path_or_io.respond_to?(:read)
          add_io_file(name, path_or_io, filename, content_type)
        else
          add_path_file(name, path_or_io, filename, content_type)
        end
        self
      end

      # Render the complete multipart body as a string
      #
      # @return [String]
      def to_s
        body = @parts.map { |part| part.to_s(@boundary) }.join
        "#{body}--#{@boundary}--\r\n"
      end

      # Return the Content-Type header value with boundary
      #
      # @return [String]
      def content_type
        "multipart/form-data; boundary=#{@boundary}"
      end

      # Stream the multipart body to an IO object
      #
      # Writes each part directly to the IO without building the full body
      # string in memory. Useful for large file uploads.
      #
      # @param io [#write] the IO object to write to
      # @return [#write] the IO object
      def write_to(io)
        @parts.each { |part| io.write(part.to_s(@boundary)) }
        io.write("--#{@boundary}--\r\n")
        io
      end

      # Calculate the byte size of the multipart body
      #
      # @return [Integer] the body size in bytes
      def content_length
        size = @parts.sum { |part| part.to_s(@boundary).bytesize }
        size + "--#{@boundary}--\r\n".bytesize
      end

      # Return the headers hash for the request
      #
      # @return [Hash]
      def headers
        {
          'Content-Type' => content_type,
          'Content-Length' => content_length.to_s
        }
      end

      private

      def add_path_file(name, path, filename, content_type)
        raise Error, "File not found: #{path}" unless File.exist?(path)

        resolved_filename = filename || File.basename(path)
        resolved_content_type = content_type || MimeTypes.lookup(resolved_filename)
        content = File.binread(path)
        @parts << Part.new(name, content, filename: resolved_filename, content_type: resolved_content_type)
      end

      def add_io_file(name, io, filename, content_type)
        raise Error, 'filename: is required when passing an IO object' unless filename

        resolved_content_type = content_type || MimeTypes.lookup(filename)
        content = io.read
        @parts << Part.new(name, content, filename: filename, content_type: resolved_content_type)
      end

      def generate_boundary
        "----PhiliprehbergerMultipart#{SecureRandom.hex(16)}"
      end
    end
  end
end
