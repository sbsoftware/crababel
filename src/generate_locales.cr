require "yaml"
require "crygen"

translations = File.open("config/locales/en.yml") do |io|
  YAML.parse(io)
end

crababel = CGT::Module.new("Crababel")

def generate_modules(parent, namespace, children)
  namespace_module = CGT::Module.new(namespace.camelcase)
  parent.add_object(namespace_module)
  namespace_method = CGT::Method.new("self.#{namespace}", "#{namespace.camelcase}.class")
  namespace_method.add_body(namespace.camelcase)
  parent.add_object(namespace_method)

  children.each do |child_namespace, grandchildren|
    if grandchildren_hash = grandchildren.as_h?
      generate_modules(namespace_module, child_namespace.as_s, grandchildren_hash)
    else
      method = CGT::Method.new("self.#{child_namespace.as_s}", String.to_s)
      method.add_body(grandchildren.as_s.dump)
      namespace_module.add_object(method)
    end
  end
end

translations.as_h.each do |namespace, children|
  generate_modules(crababel, namespace.as_s, children.as_h)
end

locales_method = CGT::Method.new("self.locales", "Array(String)")
locales_method.add_body(translations.as_h.keys.map(&.as_s).to_s)
crababel.add_object(locales_method)

locale_method = CGT::Method.new("self.locale", translations.as_h.keys.map(&.as_s.camelcase).map { |m| "#{m}.class" }.join(" | "))
locale_method.add_arg("locale", "String")
locale_case = String.build do |str|
  str << "case locale\n"
  translations.as_h.keys.map(&.as_s).each do |locale|
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
