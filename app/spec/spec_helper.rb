# frozen_string_literal: true

require 'byebug'

services = Dir['./services/**/*.rb']
services.sort.each { |f| require f }

test_helpers = Dir['./spec/support/**/*.rb']
test_helpers.sort.each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
