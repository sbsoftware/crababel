require "./spec_helper"

describe Crababel do
  it "lists available locales" do
    Crababel.locales.sort.should eq(["de", "en"])
  end

  it "returns locale modules and translations" do
    Crababel.locale("en").greeting.should eq("Hello")
    Crababel.locale("de").errors.not_found.should eq("Nicht gefunden")
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
