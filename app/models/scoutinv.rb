# frozen_string_literal: true

class Scoutinv

  def initialize(
    blob_storage:       BlobStorage.new,
    events_ds:          DB[:events],
    groups_ds:          DB[:groups],
    instances_ds:       DB[:instances],
    memberships_ds:     DB[:memberships],
    product_images_ds:  DB[:product_images],
    products_ds:        DB[:products],
    reservations_ds:    DB[:reservations],
    troops_ds:          DB[:troops],
    users_ds:           DB[:users]
  )
    @blob_storage      = blob_storage
    @events_ds         = events_ds
    @groups_ds         = groups_ds
    @instances_ds      = instances_ds
    @memberships_ds    = memberships_ds
    @product_images_ds = product_images_ds
    @products_ds       = products_ds
    @reservations_ds   = reservations_ds
    @troops_ds         = troops_ds
    @users_ds          = users_ds
  end

  def register_group(
    name:,

    admin_name:,
    admin_phone:,
    admin_email:,
    admin_password:
  )
    generate_slug.tap do |group_slug|
      @groups_ds.insert(
        admin_email: admin_email,
        admin_name:  admin_name,
        admin_phone: admin_phone,
        group_slug:  group_slug,
        name:        name,
      )

      register_user(name: admin_name, email: admin_email, password: admin_password)
      attach_user_to_group(group_slug: group_slug, email: admin_email)
      register_troop(group_slug: group_slug, name: "Gestion")
    end
  end

  def register_troop(group_slug:, name:)
    generate_slug.tap do |slug|
      @troops_ds.insert(
        group_slug: group_slug,
        troop_slug: slug,
        name:       name,
      )
    end
  end

  def register_user(name:, email:, password:)
    generate_slug.tap do |slug|
      @users_ds.insert(
        user_slug:  slug,
        email:      email,
        name:       name,
        password:   BCrypt::Password.create(password),
      )
    end
  end

  def attach_user_to_group(group_slug:, email:)
    @memberships_ds.insert(
      group_slug: group_slug,
      email:      email,
    )

    nil
  end

  # @param images [Array<#read>] An array of readable objects that are images
  #     that will be associated with this product.
  #
  # @return String The slug of the newly registered product.
  def register_product(
    group_slug:,

    name:,
    description:,

    internal_unit_price:,
    external_unit_price:,

    building:,
    room:,
    aisle:,
    bin:,

    images:
  )
    generate_slug.tap do |product_slug|
      @products_ds.insert(
        aisle:                aisle,
        bin:                  bin,
        building:             building,
        description:          description,
        external_unit_price:  external_unit_price,
        group_slug:           group_slug,
        internal_unit_price:  internal_unit_price,
        name:                 name,
        product_slug:         product_slug,
        room:                 room,
      )

      blob_slugs = images.map do |file|
        blob_storage.import(file, content_type: "image/jpeg")
      end

      @product_images_ds.import([:product_slug, :blob_slug], blob_slugs) if blob_slugs.any?
    end
  end

  # Updates the row identified by `product_slug` with the new information.
  #
  # @return [] Returns no meaningful value.
  #
  # @note It is not an error, but doesn't make sense, to attempt to update a slug
  #     that doesn't actually exist.
  def change_product_details(
    product_slug:,

    name:,
    description:,

    internal_unit_price:,
    external_unit_price:,

    building:,
    room:,
    aisle:,
    bin:
  )
    ds = @products_ds.where(product_slug: product_slug)
    ds.update(
      aisle:                aisle,
      bin:                  bin,
      building:             building,
      description:          description,
      external_unit_price:  external_unit_price,
      internal_unit_price:  internal_unit_price,
      name:                 name,
      product_slug:         product_slug,
      room:                 room,
      updated_at:           Time.now.utc,
    )
  end

  # Indicates the total number of instances of this product available
  # for rental.
  #
  # Every instance will receive a unique serial number. Once registered,
  # an instance can never be truely destroyed. At most, it can be taken
  # out of circulation so that it cannot be considered for rental
  # anymore. For auditability purposes, instances must stay in the
  # system for all eternity.
  #
  # Newly registered instances are initially available.
  #
  # @param quantity [Integer] The number of unique instances available
  #     for this product. May be positive or negative, and 0 is accepted
  #     but doesn't make much sense.
  #
  # @return [Array<String>] Returns the serial numbers of every instance.
  def change_product_quantity(group_slug:, product_slug:, quantity:)
    quantity.times.map{ generate_slug }.tap do |slugs|
      @instances_ds.import(
        [:group_slug, :product_slug, :instance_slug, :state],
        slugs.map{|slug| [group_slug, product_slug, slug, "available"]}
      )
    end
  end

  def register_troop_event(
    group_slug:,
    troop_slug:,

    name:,
    description:,

    lease_on:,
    start_on:,
    end_on:,
    return_on:
  )
    generate_slug.tap do |event_slug|
      @events_ds.insert(
        description:  description,
        end_on:       end_on,
        event_slug:   event_slug,
        group_slug:   group_slug,
        lease_on:     lease_on,
        name:         name,
        return_on:    return_on,
        start_on:     start_on,
        troop_slug:   troop_slug,
      )
    end
  end

  def register_external_event(
    group_slug:,
    leaser_name:,
    leaser_phone:,
    leaser_email:,

    name:,
    description:,

    lease_on:,
    start_on:,
    end_on:,
    return_on:
  )
    generate_slug.tap do |event_slug|
      @events_ds.insert(
        description:  description,
        end_on:       end_on,
        event_slug:   event_slug,
        group_slug:   group_slug,
        lease_on:     leased_on,
        leaser_email: leaser_email,
        leaser_name:  leaser_name,
        leaser_phone: leaser_phone,
        name:         name,
        return_on:    return_on,
        start_on:     start_on,
      )
    end
  end

  # @param event_slug [String] The slug of an event on which to add the instance.
  # @param instance_slug [String] The slug of the instance we want to reserve.
  #
  # @return [Boolean] True/false, depending on whether the instance is
  # available during the specified dates.
  def add_instance_to_event(group_slug:, instance_slug:, event_slug:)
    generate_slug.tap do |slug|
      @reservations_ds.insert(
        event_slug:    event_slug,
        group_slug:    group_slug,
        instance_slug: instance_slug,
        reservation_slug: slug
      )
    end
  end

  # @param event_slug [String] The slug of an event on which to remove the instance.
  # @param instance_slug [String] The slug of the instance we want to unreserve.
  #
  # @note It is not an error to remove an instnace that is not added
  #     on an event, but it doesn't make much sense.
  def remove_instance_from_event(group_slug:, instance_slug:, event_slug:)
    @reservations_ds
      .where(group_slug: group_slug, instance_slug: instance_slug, event_slug: event_slug)
      .delete

    nil
  end

  # Marks all instances on this event as checked out.
  #
  # @raise InstanceAlreadyCheckedOut if an instance is not available.
  def loan_instances_on_event(group_slug:, event_slug:)
    reservations_ds = @reservations_ds
      .where(group_slug: group_slug, event_slug: event_slug)
      .select(:instance_slug)

    @instances_ds
      .where(group_slug: group_slug)
      .where(instance_slug: reservations_ds)
      .update(state: "checked_out")

    nil
  end

  # Marks this instance as loaned.
  #
  # @raise InstanceAlreadyCheckedOut if an instance is not available.
  def loan_instance(group_slug:, instance_slug:)
    raise "TODO: Implement me!"
  end

  # Returns this specific instance to the general inventory.
  def return_instance(instance_slug)
    raise "TODO: Implement me!"
  end

  # Marks this instance as out for repairs, so it is not considered
  # for rental anymore.
  def send_instance_for_repairs(instance_slug)
    raise "TODO: Implement me!"
  end

  # Marks this instance as available, so that it can be loaned again.
  def return_instance_from_repairs(instance_slug)
    raise "TODO: Implement me!"
  end

  # Marks this instance as trashed, so that it can never be loaned
  # again.
  def trash_instance(instance_slug)
    raise "TODO: Implement me!"
  end

  # Returns products that match the search string.
  #
  # `search_string` may be nil or the empty string to mean "find all".
  #
  # Returned product instances have an array slugs to the BlobStorage.
  # URLs can be constructed by asking the BlobStorage for urls.
  #
  # @example Getting the first page of 25 products
  #
  #     products = Scoutinv.new.find_products
  #
  # @example Getting the 2nd page of products
  #
  #     # presumably, params[:after] was set such that the link to
  #     # view the next page was generated using the previous page
  #     products = Scoutinv.new.find_products(start_at: params[:start_at])
  #
  # @example Finding the 1st page of products that match "tent"
  #
  #     tents = Scoutinv.new.find_products("tent")
  #
  # @param search_string [NilClass, String] A string to search for in products.
  #     The search will look in the product's name, description and location.
  #     This string is not case sensitive.
  # @param count [Integer] The number of elements to return per page.
  # @param before [String] The slug of the product that is the first product
  #     on this page, so that we can return the preivous page of products.
  # @param after [String] The slug of the product that is the last product
  #     on this page, so that we can return the next page of products.
  #
  # @return [Array<Hash>] The products that match `search_string`, if any.
  def find_products(search_string, count: 25, before: nil, after: nil)
    find_products_ds
      .take(count)
  end

  def find_product_details(product_slug)
    find_products_ds
      .where(product_slug: product_slug)
      .first
  end

  # @param after [NilClass | Date] Finds events that start on or after this date.
  #     If nil, does not limit events by `start_on`.
  # @param before [NilClass | Date] Finds events that start_on or before this date.
  #     If nil, does not limit events by `start_on`.
  def find_events(after: nil, before: nil, count: 25)
    ds = @events_ds
    ds = ds.where{ Sequel[:events][:start_on] >= after  } if after
    ds = ds.where{ Sequel[:events][:start_on] <= before } if before
    ds = ds.order(Sequel[:events][:start_on])
    ds.take(count)
  end

  private

  attr_reader :blob_storage

  def generate_slug
    SecureRandom.alphanumeric(6).downcase
  end

  def find_products_ds
    @products_ds
      .left_join(@instances_ds, [:product_slug])
      .group_by(Sequel[:products][:id], Sequel[:products][:group_slug], Sequel[:products][:product_slug])
      .select_all(:products)
      .select_append{ count(instance_slug).as(:num_instances) }
  end
end
