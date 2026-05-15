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

Translations are generated from `config/locales/**/*.yml` at compile time and are exposed as methods on the locale module. A single file such as `config/locales/en.yml` still works, and larger projects can split translations by domain:

```yaml
# config/locales/en.yml
en:
  greeting: "Hello"
```

```yaml
# config/locales/errors.yml
en:
  errors:
    not_found: "Not found"
```

```crystal
Crababel.locales # => ["en", "de"]
Crababel.locale("en").greeting # => "Hello"
Crababel.locale("de").errors.not_found # => "Nicht gefunden"
```

Locale files are loaded in sorted path order so generated code is deterministic. Files are deep-merged by namespace, but each full translation key may be defined only once. Crababel raises at compile time when two files define the same translation key, or when one file defines a key as a value and another defines the same key as a namespace.

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
