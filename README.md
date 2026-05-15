# crababel

TODO: Write a description here

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     crababel:
       github: your-github-user/crababel
   ```

2. Run `shards install`

## Usage

```crystal
require "crababel"
```

Translations are generated from `config/locales/en.yml` at compile time and are exposed as methods on the locale module.

```crystal
Crababel.locales # => ["en", "de"]
Crababel.locale("en").greeting # => "Hello"
Crababel.locale("de").errors.not_found # => "Nicht gefunden"
```

### Placeholder interpolation

Crababel currently returns translation values exactly as they are written in the locale file. Placeholder-looking text such as `%{name}` is supported only as literal text; Crababel does not replace placeholders or accept interpolation arguments.

Supported:

```yaml
en:
  welcome_user: "Hello %{name}"
```

```crystal
Crababel.locale("en").welcome_user # => "Hello %{name}"
```

Not supported:

```crystal
Crababel.locale("en").welcome_user(name: "Alice")
# No generated overload accepts interpolation arguments.
```

If an application needs interpolation today, keep that formatting outside Crababel.

## Development

Install dependencies and run the specs:

```sh
shards install
crystal spec
```

## Contributing

1. Fork it (<https://github.com/your-github-user/crababel/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Stefan Bilharz](https://github.com/your-github-user) - creator and maintainer
