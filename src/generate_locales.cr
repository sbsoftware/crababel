require "yaml"
require "crygen"

alias Translation = Hash(String, Translation) | String

SHARD_LOCALES_PATTERN   = ENV["CRABABEL_SHARD_LOCALES_PATTERN"]? || "lib/**/config/locales/**/*.yml"
PROJECT_LOCALES_PATTERN = ENV["CRABABEL_LOCALES_PATTERN"]? || "config/locales/**/*.yml"

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

def load_translations(files)
  translations = {} of String => Translation
  files.each do |file|
    yaml = File.open(file) do |io|
      YAML.parse(io)
    end
    merge_translations(translations, yaml.as_h, file, [] of String)
  end

  translations
end

def shard_name(file)
  # Group files by their shard so duplicate checking remains local to a shard,
  # while collisions between independently maintained shards stay silent.
  file.partition("/config/locales/")[0]
end

def merge_overrides(target, overrides)
  overrides.each do |key, value|
    # Defaults and overrides are checked separately, so matching keys across
    # groups are intentional. Preserve unmatched nested shard translations.
    if current_children = target[key]?.try(&.as?(Hash(String, Translation)))
      if override_children = value.as?(Hash(String, Translation))
        merge_overrides(current_children, override_children)
        next
      end
    end
    target[key] = value
  end
end

shard_files = Dir.glob(SHARD_LOCALES_PATTERN).sort
project_files = Dir.glob(PROJECT_LOCALES_PATTERN).sort
raise "No locale files found for #{SHARD_LOCALES_PATTERN} or #{PROJECT_LOCALES_PATTERN}" if shard_files.empty? && project_files.empty?

translations = {} of String => Translation
shard_locale_sets = shard_files.group_by { |file| shard_name(file) }.to_a.sort_by(&.[0]).map do |_, files|
  shard_translations = load_translations(files)
  merge_overrides(translations, shard_translations)
  shard_translations.keys.sort
end
project_translations = load_translations(project_files)
merge_overrides(translations, project_translations)

supported_locales = if project_translations.empty?
                      shard_locale_sets.reduce { |intersection, locales| intersection & locales }.sort
                    else
                      project_translations.keys.sort
                    end
raise "Dependency locale roots have no common locale; declare supported locale roots explicitly in config/locales" if supported_locales.empty?

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
      method = CGT::Method.new("self.#{child_namespace}", String.to_s)
      value = grandchildren.as(String).dump
      interpolation_scan = value.scan(INTERPOLATION_REGEX)

      if !interpolation_scan.empty?
        interpolation_scan.select(&.["escape"].empty?).map(&.["var"]).uniq.each do |var|
          method.add_arg(var, "String")
        end

        method.add_body(value.gsub(INTERPOLATION_REGEX, "\\1\\3\\4"))
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
locales_method.add_body(supported_locales.to_s)
crababel.add_object(locales_method)

locale_method = CGT::Method.new("self.locale", supported_locales.map(&.camelcase).map { |m| "#{m}.class" }.join(" | "))
locale_method.add_arg("locale", "String")
locale_case = String.build do |str|
  str << "case locale\n"
  supported_locales.each do |locale|
    str << "when "
    str << locale.dump
    str << "\n  "
    str << locale.camelcase
    str << "\n"
  end
  str << "else\n"
  str << "  raise \"Unsupported locale: \#{locale}. Supported locales: #{supported_locales.join(", ")}\"\n"
  str << "end"
end
locale_method.add_body(locale_case)
crababel.add_object(locale_method)

puts crababel
