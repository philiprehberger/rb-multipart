# frozen_string_literal: true

require 'securerandom'
require_relative 'multipart/version'
require_relative 'multipart/part'
require_relative 'multipart/builder'

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
  end
end
