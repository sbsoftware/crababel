require "./spec_helper"

describe Crababel do
  it "lists available locales" do
    Crababel.locales.sort.should eq(["de", "en"])
  end

  it "returns locale modules and translations" do
    Crababel.locale("en").greeting.should eq("Hello")
    Crababel.locale("de").errors.not_found.should eq("Nicht gefunden")
  end

  it "interpolates a single variable" do
    Crababel.locale("en").interpolate.single("myself").should eq("Hello myself")
    Crababel.locale("de").interpolate.single("myself").should eq("Hallo myself")
  end

  it "interpolates a single variable multiple times" do
    Crababel.locale("en").interpolate.reuse("to be").should eq("to be or not to be")
    Crababel.locale("de").interpolate.reuse("to be").should eq("to be oder nicht to be")
  end

  it "interpolates multiple variables" do
    Crababel.locale("en").interpolate.multiple("dough", "crumble").should eq("From dough to crumble")
    Crababel.locale("de").interpolate.multiple("dough", "crumble").should eq("Von dough bis crumble")
  end

  it "interpolates multiple variables multiple times" do
    Crababel.locale("en").interpolate.multiple_reuse("Atlantis", "Olympus").should eq("From Atlantis to Olympus back to Atlantis")
    Crababel.locale("de").interpolate.multiple_reuse("Atlantis", "Olympus").should eq("Von Atlantis bis Olympus zurück nach Atlantis")
  end

  it "does not interpolate escaped interpolations" do
    Crababel.locale("en").interpolate.escape("test0", "test1").should eq("test0 \#{unused} \\\\test1 \\\\\#{unused_again}")
    Crababel.locale("de").interpolate.escape("test0", "test1").should eq("test0 \#{unused} \\\\test1 \\\\\#{unused_again}")
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
