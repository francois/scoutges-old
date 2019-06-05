ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  setup do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
  end
end
