# frozen_string_literal: true

require 'securerandom'
require_relative 'multipart/version'
require_relative 'multipart/mime_types'
require_relative 'multipart/part'
require_relative 'multipart/builder'
require_relative 'multipart/parser'

module Philiprehberger
  module Multipart
    class Error < StandardError; end

    # Build a multipart/form-data body using a DSL block
    #
    # @param boundary [String, nil] optional custom boundary string
    # @yield [builder] the builder instance for adding fields and files
    # @yieldparam builder [Builder]
    # @return [Builder] the configured builder
    # @raise [Error] if no block is given
    def self.build(boundary: nil, &block)
      raise Error, 'A block is required' unless block

      builder = Builder.new(boundary: boundary)
      builder.instance_eval(&block)
      builder
    end

    # Parse a multipart/form-data body into Part objects
    #
    # @param body [String] the raw multipart body
    # @param content_type [String] the Content-Type header value (must include boundary)
    # @return [Array<Part>] parsed parts
    # @raise [Error] if the boundary cannot be extracted or the body is malformed
    def self.parse(body, content_type:)
      Parser.parse(body, content_type: content_type)
    end
  end
end
