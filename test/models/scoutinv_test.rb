# frozen_string_literal: true
require_relative "../test_helper"

class ScoutinvTest < ActiveSupport::TestCase
  setup do
    @sut = Scoutinv.new
    @group_slug = @sut.register_group(
      name:           "10th",
      admin_email:    "francois@teksol.info",
      admin_name:     "Francois Beausoleil",
      admin_phone:    "888 555-1212",
      admin_password: "monkey",
    )

    @category_codes = DB[:categories].select_map(:category_code)
  end

  test "registers product" do
    slug = @sut.register_product(
      group_slug: @group_slug,

      aisle: "4",
      bin: nil,
      building: "5th Ave",
      category_codes: [],
      description: "Rectangular tent, 4 people with luggage",
      external_unit_price: 50,
      images: [],
      internal_unit_price: 0,
      name: "4x10 tent",
      room: "1",
    )

    assert slug.present?

    products = @sut.find_products(group_slug: @group_slug, category_codes: @category_codes)
    assert products
    assert products.any?
    assert products.map{|row| row[:product_slug]}.include?(slug)
  end

  test "changes product details" do
    slug = @sut.register_product(
      group_slug: @group_slug,

      aisle: "4",
      bin: nil,
      building: "5th Ave",
      category_codes: [],
      description: "Rectangular tent, 4 people with luggage",
      external_unit_price: 50,
      images: [],
      internal_unit_price: 0,
      name: "4x10 tent",
      room: "1",
    )

    @sut.change_product_details(
      group_slug: @group_slug,
      product_slug: slug,

      aisle: "13",
      bin: "bleu",
      building: "5eme Ave",
      category_codes: [],
      description: "Tente rectangulaire 4 personnes avec bagages",
      external_unit_price: 80,
      images: [],
      internal_unit_price: 10,
      name: "Tente 4x10",
      room: "17",
    )

    products = @sut.find_products(group_slug: @group_slug, category_codes: [])
    assert_equal 1, products.size, products.inspect
    product = products.first
    assert product.present?

    assert_equal "Tente 4x10", product.fetch(:name)
    assert_equal "Tente rectangulaire 4 personnes avec bagages", product.fetch(:description)
    assert_equal BigDecimal("10"), product.fetch(:internal_unit_price)
    assert_equal BigDecimal("80"), product.fetch(:external_unit_price)
    assert_equal "5eme Ave", product.fetch(:building)
    assert_equal "17", product.fetch(:room)
    assert_equal "13", product.fetch(:aisle)
    assert_equal "bleu", product.fetch(:bin)
  end

  test "change product quantity" do
    slug = @sut.register_product(
      group_slug: @group_slug,

      aisle: "4",
      bin: nil,
      building: "5th Ave",
      category_codes: [],
      description: "Rectangular tent, 4 people with luggage",
      external_unit_price: 50,
      images: [],
      internal_unit_price: 0,
      name: "4x10 tent",
      room: "1",
    )

    @sut.change_product_quantity(group_slug: @group_slug, product_slug: slug, quantity: 4)
    product = @sut.find_product(group_slug: @group_slug, product_slug: slug)
    refute product.nil?
    assert_equal 4, product.fetch(:num_instances)

    @sut.change_product_quantity(group_slug: @group_slug, product_slug: slug, quantity: 5)
    product = @sut.find_product(group_slug: @group_slug, product_slug: slug)
    assert_equal 5, product.fetch(:num_instances)

    @sut.change_product_quantity(group_slug: @group_slug, product_slug: slug, quantity: 3)
    product = @sut.find_product(group_slug: @group_slug, product_slug: slug)
    assert_equal 3, product.fetch(:num_instances)
  end

  test "registers an internal event" do
    slug = @sut.register_troop_event(
      group_slug: @group_slug,
      troop_slug: "chouettes",

      name: "Summer Camp",
      description: "Survival themed summer camp",

      lease_on:  Date.new(2019, 9, 1),
      start_on:  Date.new(2019, 9, 2),
      end_on:    Date.new(2019, 9, 5),
      return_on: Date.new(2019, 9, 7),
    )

    events = @sut.find_events(group_slug: @group_slug)
    assert_equal 1, events.size
    event = events.first
    assert_equal @group_slug, event.fetch(:group_slug)
    assert_equal "chouettes", event.fetch(:troop_slug)
    assert_equal slug, event.fetch(:event_slug)
    assert_equal "Summer Camp", event.fetch(:name)
    assert_equal "Survival themed summer camp", event.fetch(:description)
    assert_equal Date.new(2019, 9, 1), event.fetch(:lease_on)
    assert_equal Date.new(2019, 9, 2), event.fetch(:start_on)
    assert_equal Date.new(2019, 9, 5), event.fetch(:end_on)
    assert_equal Date.new(2019, 9, 7), event.fetch(:return_on)
    assert_nil event.fetch(:leaser_name)
    assert_nil event.fetch(:leaser_phone)
    assert_nil event.fetch(:leaser_email)
  end
end
