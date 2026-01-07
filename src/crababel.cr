macro t(locale_name)
  Crababel.locale({{locale_name}}).{{ @type.name.split("::").map(&.underscore).join(".").id }}
end

{{ run "./generate_locales.cr" }}
