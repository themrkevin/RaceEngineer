# frozen_string_literal: true

source "https://rubygems.org"

# Fastlane automation suite
gem "fastlane"

# Optional: Formatter for xcresult bundles and clean console test output
gem "xcpretty"

# Enables fastlane plugins if you decide to add them later
plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
