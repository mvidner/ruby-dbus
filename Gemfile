# frozen_string_literal: true

# -*-ruby -*-
source "https://rubygems.org"
gemspec

gem "rubocop", "~> 1.68.0" if RUBY_VERSION >= "2.7"
# newer versions have a noise deprecation warning
gem "rubocop-ast", "~> 1.36.0" if RUBY_VERSION >= "2.7"

group :test do
  # Optional dependency, we do want to test with it
  gem "nokogiri"
end

platforms :rbx do
  gem "racc"
end
