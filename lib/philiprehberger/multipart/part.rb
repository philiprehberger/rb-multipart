# frozen_string_literal: true

module Philiprehberger
  module Multipart
    # Represents a single part in a multipart/form-data body
    class Part
      # @return [Symbol] the field name
      attr_reader :name

      # @return [String] the part value / body content
      attr_reader :value

      # @return [String, nil] the original filename
      attr_reader :filename

      # @return [String, nil] the content type
      attr_reader :content_type

      # @param name [Symbol] the field name
      # @param value [String] the part value
      # @param filename [String, nil] the original filename
      # @param content_type [String, nil] the MIME content type
      def initialize(name, value, filename: nil, content_type: nil)
        @name = name
        @value = value
        @filename = filename
        @content_type = content_type
      end

      # Alias for value — the body content of this part
      #
      # @return [String]
      def body
        @value
      end

      # Whether this part represents a file upload
      #
      # @return [Boolean]
      def file?
        !@filename.nil?
      end

      # Render this part as a multipart body segment
      #
      # @param boundary [String] the multipart boundary
      # @return [String]
      def to_s(boundary)
        lines = []
        lines << "--#{boundary}\r\n"

        if file?
          lines << "Content-Disposition: form-data; name=\"#{@name}\"; filename=\"#{@filename}\"\r\n"
          lines << "Content-Type: #{@content_type || 'application/octet-stream'}\r\n"
        else
          lines << "Content-Disposition: form-data; name=\"#{@name}\"\r\n"
        end

        lines << "\r\n"
        lines << @value
        lines << "\r\n"
        lines.join
      end
    end
  end
end
