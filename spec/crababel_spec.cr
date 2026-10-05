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
    expect_raises(Exception, "Unsupported locale: es. Supported locales: de, en") do
      Crababel.locale("es")
    end
  end

  it "advertises project locale roots while generating the dependency union" do
    root = File.join(Dir.tempdir, "crababel-project-locales-#{Time.utc.to_unix_ns}")
    shard_locales = File.join(root, "lib", "example", "config", "locales")
    project_locales = File.join(root, "config", "locales")
    Dir.mkdir_p(shard_locales)
    Dir.mkdir_p(project_locales)
    File.write(File.join(shard_locales, "locales.yml"), "en:\n  value: \"English\"\nde:\n  value: \"German\"\nes:\n  value: \"Spanish\"\n")
    File.write(File.join(project_locales, "locales.yml"), "en:\n  project: \"English\"\nde:\n  project: \"German\"\n")

    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run("crystal", ["run", "src/generate_locales.cr"], env: {"CRYSTAL_CACHE_DIR" => File.join(root, "cache"), "CRABABEL_SHARD_LOCALES_PATTERN" => File.join(root, "lib", "**", "config", "locales", "**", "*.yml"), "CRABABEL_LOCALES_PATTERN" => File.join(project_locales, "**", "*.yml")}, output: output, error: error)

    status.success?.should be_true
    generated = output.to_s
    generated.should contain("module Es")
    generated.should contain(%(["de", "en"]))
    generated.should_not contain(%(when "es"))
    generated.should contain("Supported locales: de, en")
  ensure
    FileUtils.rm_rf(root) if root
  end

  it "advertises the intersection of dependency locale roots without project locales" do
    root = File.join(Dir.tempdir, "crababel-intersection-#{Time.utc.to_unix_ns}")
    shard_a = File.join(root, "lib", "a", "config", "locales")
    shard_b = File.join(root, "lib", "b", "config", "locales")
    Dir.mkdir_p(shard_a)
    Dir.mkdir_p(shard_b)
    File.write(File.join(shard_a, "locales.yml"), "en:\n  a: \"English\"\nde:\n  a: \"German\"\n")
    File.write(File.join(shard_b, "locales.yml"), "en:\n  b: \"English\"\nfr:\n  b: \"French\"\n")

    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run("crystal", ["run", "src/generate_locales.cr"], env: {"CRYSTAL_CACHE_DIR" => File.join(root, "cache"), "CRABABEL_SHARD_LOCALES_PATTERN" => File.join(root, "lib", "**", "config", "locales", "**", "*.yml"), "CRABABEL_LOCALES_PATTERN" => File.join(root, "config", "locales", "**", "*.yml")}, output: output, error: error)

    status.success?.should be_true
    generated = output.to_s
    generated.should contain(%(["en"]))
    generated.should contain("module De")
    generated.should contain("module Fr")
    generated.should_not contain(%(when "de"))
    generated.should_not contain(%(when "fr"))
  ensure
    FileUtils.rm_rf(root) if root
  end

  it "fails clearly when dependency locale roots are disjoint" do
    root = File.join(Dir.tempdir, "crababel-disjoint-#{Time.utc.to_unix_ns}")
    shard_a = File.join(root, "lib", "a", "config", "locales")
    shard_b = File.join(root, "lib", "b", "config", "locales")
    Dir.mkdir_p(shard_a)
    Dir.mkdir_p(shard_b)
    File.write(File.join(shard_a, "en.yml"), "en:\n  value: \"English\"\n")
    File.write(File.join(shard_b, "de.yml"), "de:\n  value: \"German\"\n")

    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run("crystal", ["run", "src/generate_locales.cr"], env: {"CRYSTAL_CACHE_DIR" => File.join(root, "cache"), "CRABABEL_SHARD_LOCALES_PATTERN" => File.join(root, "lib", "**", "config", "locales", "**", "*.yml"), "CRABABEL_LOCALES_PATTERN" => File.join(root, "config", "locales", "**", "*.yml")}, output: output, error: error)

    status.success?.should be_false
    error.to_s.should contain("Dependency locale roots have no common locale")
    error.to_s.should contain("declare supported locale roots explicitly in config/locales")
  ensure
    FileUtils.rm_rf(root) if root
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

  it "loads shard defaults with project overrides" do
    root = File.join(Dir.tempdir, "crababel-overrides-#{Time.utc.to_unix_ns}")
    shard_locales = File.join(root, "lib", "example", "config", "locales")
    project_locales = File.join(root, "config", "locales")
    Dir.mkdir_p(shard_locales)
    Dir.mkdir_p(project_locales)
    File.write(File.join(shard_locales, "en.yml"), "en:\n  greeting: \"Hello\"\n  nested:\n    default: \"Default\"\n    shared: \"Shard\"\n")
    File.write(File.join(project_locales, "en.yml"), "en:\n  nested:\n    shared: \"Project\"\n    custom: \"Custom\"\n")

    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run("crystal", ["run", "src/generate_locales.cr"], env: {"CRYSTAL_CACHE_DIR" => File.join(root, "cache"), "CRABABEL_SHARD_LOCALES_PATTERN" => File.join(root, "lib", "**", "config", "locales", "**", "*.yml"), "CRABABEL_LOCALES_PATTERN" => File.join(project_locales, "**", "*.yml")}, output: output, error: error)

    status.success?.should be_true
    generated = output.to_s
    generated.should contain(%(def self.greeting : String\n      "Hello"))
    generated.should contain(%(def self.default : String\n        "Default"))
    generated.should contain(%(def self.shared : String\n        "Project"))
    generated.should contain(%(def self.custom : String\n        "Custom"))
  ensure
    FileUtils.rm_rf(root) if root
  end

  it "retains duplicate checking within shard locales" do
    root = File.join(Dir.tempdir, "crababel-shard-conflict-#{Time.utc.to_unix_ns}")
    shard_locales = File.join(root, "lib", "example", "config", "locales")
    Dir.mkdir_p(shard_locales)
    File.write(File.join(shard_locales, "base.yml"), "en:\n  greeting: \"Hello\"\n")
    File.write(File.join(shard_locales, "duplicate.yml"), "en:\n  greeting: \"Hi\"\n")

    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run("crystal", ["run", "src/generate_locales.cr"], env: {"CRYSTAL_CACHE_DIR" => File.join(root, "cache"), "CRABABEL_SHARD_LOCALES_PATTERN" => File.join(shard_locales, "**", "*.yml"), "CRABABEL_LOCALES_PATTERN" => File.join(root, "config", "locales", "**", "*.yml")}, output: output, error: error)

    status.success?.should be_false
    error.to_s.should contain("Duplicate translation key en.greeting")
  ensure
    FileUtils.rm_rf(root) if root
  end

  it "silently resolves sibling shard collisions in deterministic order" do
    root = File.join(Dir.tempdir, "crababel-sibling-collision-#{Time.utc.to_unix_ns}")
    shard_a = File.join(root, "lib", "a", "config", "locales")
    shard_b = File.join(root, "lib", "b", "config", "locales")
    Dir.mkdir_p(shard_a)
    Dir.mkdir_p(shard_b)
    File.write(File.join(shard_a, "en.yml"), "en:\n  greeting: \"First\"\n")
    File.write(File.join(shard_b, "en.yml"), "en:\n  greeting: \"Second\"\n")

    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run("crystal", ["run", "src/generate_locales.cr"], env: {"CRYSTAL_CACHE_DIR" => File.join(root, "cache"), "CRABABEL_SHARD_LOCALES_PATTERN" => File.join(root, "lib", "**", "config", "locales", "**", "*.yml"), "CRABABEL_LOCALES_PATTERN" => File.join(root, "config", "locales", "**", "*.yml")}, output: output, error: error)

    status.success?.should be_true
    output.to_s.should contain(%(def self.greeting : String\n      "Second"))
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
