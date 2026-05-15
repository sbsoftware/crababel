require "./spec_helper"
require "file_utils"

describe Crababel do
  it "lists available locales" do
    Crababel.locales.sort.should eq(["de", "en"])
  end

  it "returns locale modules and translations" do
    Crababel.locale("en").greeting.should eq("Hello")
    Crababel.locale("de").errors.not_found.should eq("Nicht gefunden")
  end

  it "loads locale namespaces split across multiple files" do
    Crababel.locale("en").custom.leaf.should eq("Custom hello")
    Crababel.en.errors.invalid_user.should eq("Invalid user")
    Crababel.locale("de").custom.leaf.should eq("Custom hallo")
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

  it "still generates locale modules from a single locale file" do
    root = File.join(Dir.tempdir, "crababel-single-#{Time.utc.to_unix_ns}")
    locales = File.join(root, "config", "locales")
    Dir.mkdir_p(locales)
    File.write(File.join(locales, "en.yml"), "en:\n  greeting: \"Hello\"\n")

    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run("crystal", ["run", "src/generate_locales.cr"], env: {"CRYSTAL_CACHE_DIR" => File.join(root, "cache"), "CRABABEL_LOCALES_PATTERN" => File.join(locales, "**", "*.yml")}, output: output, error: error)

    status.success?.should be_true
    output.to_s.should contain("def self.greeting")
  ensure
    FileUtils.rm_rf(root) if root
  end

  it "fails clearly when locale files define the same translation key" do
    root = File.join(Dir.tempdir, "crababel-conflict-#{Time.utc.to_unix_ns}")
    locales = File.join(root, "config", "locales")
    Dir.mkdir_p(locales)
    File.write(File.join(locales, "base.yml"), "en:\n  greeting: \"Hello\"\n")
    File.write(File.join(locales, "override.yml"), "en:\n  greeting: \"Hi\"\n")

    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run("crystal", ["run", "src/generate_locales.cr"], env: {"CRYSTAL_CACHE_DIR" => File.join(root, "cache"), "CRABABEL_LOCALES_PATTERN" => File.join(locales, "**", "*.yml")}, output: output, error: error)

    status.success?.should be_false
    error.to_s.should contain("Duplicate translation key en.greeting")
  ensure
    FileUtils.rm_rf(root) if root
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
