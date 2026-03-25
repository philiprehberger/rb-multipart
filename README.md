# philiprehberger-multipart

[![Tests](https://github.com/philiprehberger/rb-multipart/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-multipart/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-multipart.svg)](https://rubygems.org/gems/philiprehberger-multipart)
[![License](https://img.shields.io/github/license/philiprehberger/rb-multipart)](LICENSE)

Multipart/form-data request builder with file and field support

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
  file :avatar, '/path/to/photo.png', content_type: 'image/png'
end

builder.to_s          # => multipart body with file data
builder.boundary      # => the boundary string
```

### Custom Boundary

```ruby
builder = Philiprehberger::Multipart.build(boundary: 'my-boundary') do
  field :key, 'value'
end

builder.content_type  # => "multipart/form-data; boundary=my-boundary"
```

### Request Headers

```ruby
builder = Philiprehberger::Multipart.build do
  field :data, 'payload'
end

builder.headers  # => { "Content-Type" => "multipart/form-data; boundary=..." }
```

## API

| Method | Description |
|--------|-------------|
| `Multipart.build(boundary: nil, &block)` | Build a multipart body using the DSL |
| `Builder#field(name, value)` | Add a text field |
| `Builder#file(name, path, content_type:)` | Add a file upload |
| `Builder#to_s` | Render the multipart body as a string |
| `Builder#content_type` | Content-Type header value with boundary |
| `Builder#boundary` | The multipart boundary string |
| `Builder#headers` | Hash with Content-Type header |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
