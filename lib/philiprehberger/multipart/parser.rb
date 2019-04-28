# frozen_string_literal: true

module Philiprehberger
  module Multipart
    # Parses multipart/form-data request bodies into Part objects
    class Parser
      # @param body [String] the raw multipart body
      # @param content_type [String] the Content-Type header value (must include boundary)
      # @return [Array<Part>] parsed parts
      # @raise [Error] if the boundary cannot be extracted or the body is malformed
      def self.parse(body, content_type:)
        new(body, content_type).parse
      end

      # @param body [String] the raw multipart body
      # @param content_type [String] the Content-Type header value
      def initialize(body, content_type)
        @body = body.b
        @boundary = extract_boundary(content_type)
      end

      # Parse the multipart body into Part objects
      #
      # @return [Array<Part>] parsed parts
      def parse
        delimiter = "--#{@boundary}"
        closing = "#{delimiter}--"

        raw = @body.split(delimiter)
        raw.shift # discard preamble before first boundary

        raw.each_with_object([]) do |segment, parts|
          segment = segment.sub(/\A\r\n/, '')
          next if segment.start_with?('--') # closing boundary
          next if segment.strip.empty?

          # Strip trailing CRLF that precedes the next boundary
          segment = segment.sub(/\r\n\z/, '')

          headers_section, body_content = split_headers_and_body(segment)
          next if headers_section.nil?

          headers = parse_headers(headers_section)
          disposition = headers['content-disposition'] || ''
          name = extract_param(disposition, 'name')
          filename = extract_param(disposition, 'filename')
          part_content_type = headers['content-type']

          parts << Part.new(
            name&.to_sym || :unknown,
            body_content || '',
            filename: filename,
            content_type: part_content_type
          )
        end
      end

      private

      def extract_boundary(content_type)
        match = content_type.to_s.match(/boundary=("?)([^";,\s]+)\1/)
        raise Error, 'Could not extract boundary from Content-Type header' unless match

        match[2]
      end

      def split_headers_and_body(segment)
        idx = segment.index("\r\n\r\n")
        return nil unless idx

        headers = segment[0...idx]
        body = segment[(idx + 4)..]
        [headers, body]
      end

      def parse_headers(headers_string)
        headers_string.split("\r\n").each_with_object({}) do |line, hash|
          key, value = line.split(':', 2)
          next unless key && value

          hash[key.strip.downcase] = value.strip
        end
      end

      def extract_param(header_value, param_name)
        match = header_value.match(/#{param_name}="([^"]*)"/)
        match ? match[1] : nil
      end
    end
  end
end
