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

Crababel generates method arguments for placeholders written as Crystal interpolation expressions. Each unique `#{name}` placeholder becomes a required `String` argument, and repeated placeholders reuse the same argument.

For example:

```yaml
en:
  welcome_user: "Hello #{name}"
  route: "From #{origin} to #{destination}"
```

```crystal
Crababel.locale("en").welcome_user(name: "Alice") # => "Hello Alice"
Crababel.locale("en").route(origin: "Berlin", destination: "Paris") # => "From Berlin to Paris"
```

Escape interpolation syntax with a backslash when it should remain literal text:

```yaml
en:
  literal: "Hello \\#{name}"
```

```crystal
Crababel.locale("en").literal # => "Hello #{name}"
```

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
