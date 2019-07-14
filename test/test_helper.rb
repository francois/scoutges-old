ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  setup do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean

    Scoutinv.new.register_group(
      name: "10th Fleurimont",

      admin_name: "François Beausoleil",
      admin_phone: "819 555-1212",
      admin_email: "francois@teksol.info",
      admin_password: "monkeymonkey",

      group_slug: "10th",
    )

    Scoutinv.new.register_group(
      name: "47th Rock-Forest",

      admin_name: "John Smith",
      admin_phone: "819 555-1211",
      admin_email: "john.smith@teksol.info",
      admin_password: "monkeymonkey",

      group_slug: "47th",
    )

    assert_equal 2, DB[:groups].count

    DB[:categories].import([:category_code], [["camping_gear"], ["perishables"]])
    @category_codes = DB[:categories].order(:category_code).select_map(:category_code)
    assert_equal 2, @category_codes.length
  end
end
