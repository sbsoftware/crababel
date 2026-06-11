require "yaml"
require "crygen"

alias Translation = Hash(String, Translation) | String

LOCALES_PATTERN = ENV["CRABABEL_LOCALES_PATTERN"]? || "config/locales/**/*.yml"

def parse_translation(value, file, path) : Translation
  if children = value.as_h?
    nested = {} of String => Translation
    merge_translations(nested, children, file, path)
    nested
  elsif translation = value.as_s?
    translation
  else
    raise "Translation #{path.join(".")} in #{file} must be a string or mapping"
  end
end

def merge_translation(target, key, value, file, path)
  if current = target[key]?
    if current_children = current.as?(Hash(String, Translation))
      if value_children = value.as?(Hash(String, Translation))
        value_children.each do |child_key, child_value|
          merge_translation(current_children, child_key, child_value, file, path + [child_key])
        end
      else
        raise "Translation #{path.join(".")} in #{file} conflicts with an existing namespace"
      end
    elsif value.as?(Hash(String, Translation))
      raise "Translation namespace #{path.join(".")} in #{file} conflicts with an existing value"
    else
      raise "Duplicate translation key #{path.join(".")} in #{file}"
    end
  else
    target[key] = value
  end
end

def merge_translations(target, source, file, path)
  source.each do |yaml_key, yaml_value|
    key = yaml_key.as_s
    merge_translation(target, key, parse_translation(yaml_value, file, path + [key]), file, path + [key])
  end
end

def load_translations
  translations = {} of String => Translation
  files = Dir.glob(LOCALES_PATTERN).sort
  raise "No locale files found for #{LOCALES_PATTERN}" if files.empty?

  files.each do |file|
    yaml = File.open(file) do |io|
      YAML.parse(io)
    end
    merge_translations(translations, yaml.as_h, file, [] of String)
  end

  translations
end

translations = load_translations

crababel = CGT::Module.new("Crababel")

INTERPOLATION_REGEX = /(?<!\\)((?:\\\\\\\\)*)(?<escape>\\(\\)|)\\(#\{(?<var>[[:alpha:]_][[:alnum:]_]*)\})/

def generate_modules(parent, namespace, children)
  namespace_module = CGT::Module.new(namespace.camelcase)
  parent.add_object(namespace_module)
  namespace_method = CGT::Method.new("self.#{namespace}", "#{namespace.camelcase}.class")
  namespace_method.add_body(namespace.camelcase)
  parent.add_object(namespace_method)

  children.keys.sort.each do |child_namespace|
    grandchildren = children[child_namespace]
    if grandchildren_hash = grandchildren.as?(Hash(String, Translation))
      generate_modules(namespace_module, child_namespace, grandchildren_hash)
    else
      method = CGT::Method.new("self.#{child_namespace.as_s}", String.to_s)
      value = grandchildren.as_s.dump
      interpolation_scan = value.scan(INTERPOLATION_REGEX)

      if !interpolation_scan.empty?
        interpolation_scan.select(&.["escape"].empty?).map(&.["var"]).uniq.each do |var|
          method.add_arg(var, "String")
        end

        subbed_value = value.gsub(INTERPOLATION_REGEX, "\\1\\3\\4")
        method.add_body(subbed_value)
      else
        method.add_body(value)
      end
      namespace_module.add_object(method)
    end
  end
end

translations.keys.sort.each do |namespace|
  generate_modules(crababel, namespace, translations[namespace].as(Hash(String, Translation)))
end

locales_method = CGT::Method.new("self.locales", "Array(String)")
locales_method.add_body(translations.keys.sort.to_s)
crababel.add_object(locales_method)

locale_method = CGT::Method.new("self.locale", translations.keys.sort.map(&.camelcase).map { |m| "#{m}.class" }.join(" | "))
locale_method.add_arg("locale", "String")
locale_case = String.build do |str|
  str << "case locale\n"
  translations.keys.sort.each do |locale|
    str << "when "
    str << locale.dump
    str << "\n  "
    str << locale.camelcase
    str << "\n"
  end
  str << "else\n"
  str << "  raise \"Unsupported locale: \#{locale}\"\n"
  str << "end"
end
locale_method.add_body(locale_case)
crababel.add_object(locale_method)

puts crababel
