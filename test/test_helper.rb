ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  setup do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean

    DB[:categories].insert(category_code: "tools")
    DB[:categories].insert(category_code: "perishables")
  end
end
