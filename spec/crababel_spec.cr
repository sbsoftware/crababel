require "./spec_helper"

describe Crababel do
  it "lists available locales" do
    Crababel.locales.sort.should eq(["de", "en"])
  end

  it "returns locale modules and translations" do
    Crababel.locale("en").greeting.should eq("Hello")
    Crababel.locale("de").errors.not_found.should eq("Nicht gefunden")
  end

  it "returns placeholder-like text without interpolation" do
    Crababel.locale("en").welcome_user.should eq("Hello %{name}")
    Crababel.locale("en").welcome_user.should_not eq("Hello Alice")
    Crababel.locale("de").welcome_user.should eq("Hallo %{name}")
  end

  it "raises for unsupported locales" do
    expect_raises(Exception, "Unsupported locale: es") do
      Crababel.locale("es")
    end
  end
end

module Errors
  module NotFound
    def self.message
      t("en")
    end
  end
end

describe "t macro" do
  it "resolves translations based on type name" do
    Errors::NotFound.message.should eq("Not found")
  end
end

class GreetingTranslator
  macro t(locale_name)
    Crababel.locale({{locale_name}}).custom
  end

  def self.message
    t("en").leaf
  end
end

describe "t macro override" do
  it "can target a custom namespace" do
    GreetingTranslator.message.should eq("Custom hello")
  end
end
