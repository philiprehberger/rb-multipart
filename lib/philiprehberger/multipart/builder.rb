# frozen_string_literal: true

require_relative 'part'

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
      # @param name [Symbol, String] the field name
      # @param path [String] the file path
      # @param content_type [String] the MIME content type
      # @return [self]
      # @raise [Error] if the file does not exist
      def file(name, path, content_type: 'application/octet-stream')
        raise Error, "File not found: #{path}" unless File.exist?(path)

        content = File.binread(path)
        filename = File.basename(path)
        @parts << Part.new(name, content, filename: filename, content_type: content_type)
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

      # Return the headers hash for the request
      #
      # @return [Hash]
      def headers
        { 'Content-Type' => content_type }
      end

      private

      def generate_boundary
        "----PhiliprehbergerMultipart#{SecureRandom.hex(16)}"
      end
    end
  end
end
