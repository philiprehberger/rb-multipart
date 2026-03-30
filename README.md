# philiprehberger-multipart

[![Tests](https://github.com/philiprehberger/rb-multipart/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-multipart/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-multipart.svg)](https://rubygems.org/gems/philiprehberger-multipart)
[![GitHub release](https://img.shields.io/github/v/release/philiprehberger/rb-multipart)](https://github.com/philiprehberger/rb-multipart/releases)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-multipart)](https://github.com/philiprehberger/rb-multipart/commits/main)
[![License](https://img.shields.io/github/license/philiprehberger/rb-multipart)](LICENSE)
[![Bug Reports](https://img.shields.io/github/issues/philiprehberger/rb-multipart/bug)](https://github.com/philiprehberger/rb-multipart/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Feature Requests](https://img.shields.io/github/issues/philiprehberger/rb-multipart/enhancement)](https://github.com/philiprehberger/rb-multipart/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Multipart/form-data builder and parser with MIME type detection and streaming support

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-multipart"
```

Or install directly:

```bash
gem install philiprehberger-multipart
```

## Usage

```ruby
require "philiprehberger/multipart"

builder = Philiprehberger::Multipart.build do
  field :name, 'Alice'
  field :email, 'alice@example.com'
end

builder.to_s          # => multipart body string
builder.content_type  # => "multipart/form-data; boundary=..."
```

### File Uploads

```ruby
builder = Philiprehberger::Multipart.build do
  field :name, 'Alice'
  file :avatar, '/path/to/photo.png'
end

builder.to_s      # => multipart body with file data
builder.boundary  # => the boundary string
```

### Streaming IO Objects

```ruby
require "stringio"

io = StringIO.new("CSV,data,here")

builder = Philiprehberger::Multipart.build do
  file :upload, io, filename: 'data.csv', content_type: 'text/csv'
end

builder.to_s  # => multipart body streamed from IO
```

### MIME Type Detection

```ruby
# Auto-detected from filename when content_type is not provided
builder = Philiprehberger::Multipart.build do
  file :doc, '/path/to/report.pdf'       # => application/pdf
  file :img, '/path/to/photo.jpg'        # => image/jpeg
  file :data, '/path/to/config.json'     # => application/json
end

# Direct lookup
Philiprehberger::Multipart::MimeTypes.lookup('photo.jpg')   # => "image/jpeg"
Philiprehberger::Multipart::MimeTypes.lookup('unknown.xyz')  # => "application/octet-stream"
```

### Parsing Multipart Bodies

```ruby
body = "--boundary\r\n" \
       "Content-Disposition: form-data; name=\"field\"\r\n" \
       "\r\n" \
       "value\r\n" \
       "--boundary--\r\n"

parts = Philiprehberger::Multipart.parse(body, content_type: 'multipart/form-data; boundary=boundary')

parts.first.name          # => :field
parts.first.body          # => "value"
parts.first.file?         # => false
```

### Custom Boundary

```ruby
builder = Philiprehberger::Multipart.build(boundary: 'my-boundary') do
  field :key, 'value'
end

builder.content_type  # => "multipart/form-data; boundary=my-boundary"
```

## API

| Method | Description |
|--------|-------------|
| `Multipart.build(boundary: nil, &block)` | Build a multipart body using the DSL |
| `Multipart.parse(body, content_type:)` | Parse an incoming multipart/form-data body |
| `MimeTypes.lookup(filename)` | Look up MIME type from a filename extension |
| `Builder#field(name, value)` | Add a text field |
| `Builder#file(name, path_or_io, filename:, content_type:)` | Add a file from path or IO object |
| `Builder#to_s` | Render the multipart body as a string |
| `Builder#content_type` | Content-Type header value with boundary |
| `Builder#boundary` | The multipart boundary string |
| `Builder#headers` | Hash with Content-Type header |
| `Part#name` | The field name |
| `Part#value` | The part value / body content |
| `Part#body` | Alias for value |
| `Part#filename` | The original filename (nil for text fields) |
| `Part#content_type` | The MIME content type (nil for text fields) |
| `Part#file?` | Whether this part is a file upload |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this package useful, consider giving it a star on GitHub — it helps motivate continued maintenance and development.

[![LinkedIn](https://img.shields.io/badge/Philip%20Rehberger-LinkedIn-0A66C2?logo=linkedin)](https://www.linkedin.com/in/philiprehberger)
[![More packages](https://img.shields.io/badge/more-open%20source%20packages-blue)](https://philiprehberger.com/open-source-packages)

## License

[MIT](LICENSE)
