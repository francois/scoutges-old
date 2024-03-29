# frozen_string_literal: true

class Scoutinv
  NotEnoughUnusedInstances = Class.new(RuntimeError)

  def initialize(
    blob_storage:          DatabaseBlobStorage.new,
    categories_ds:         DB[:categories],
    enrollments_ds:        DB[:enrollments],
    events_ds:             DB[:events],
    groups_ds:             DB[:groups],
    instances_ds:          DB[:instances],
    memberships_ds:        DB[:memberships],
    product_categories_ds: DB[:product_categories],
    product_images_ds:     DB[:product_images],
    products_ds:           DB[:products],
    reservations_ds:       DB[:reservations],
    troops_ds:             DB[:troops],
    users_ds:              DB[:users]
  )
    @blob_storage          = blob_storage
    @categories_ds         = categories_ds
    @enrollments_ds        = enrollments_ds
    @events_ds             = events_ds
    @groups_ds             = groups_ds
    @instances_ds          = instances_ds
    @memberships_ds        = memberships_ds
    @product_categories_ds = product_categories_ds
    @product_images_ds     = product_images_ds
    @products_ds           = products_ds
    @reservations_ds       = reservations_ds
    @troops_ds             = troops_ds
    @users_ds              = users_ds
  end

  def find_category_codes
    @categories_ds
      .order(:category_code)
      .select_map(:category_code)
  end

  def register_group(
    name:,

    admin_name:,
    admin_phone:,
    admin_email:,
    admin_password:,

    group_slug: generate_slug
  )
    group_slug.tap do
      @groups_ds.insert(
        admin_email: admin_email,
        admin_name:  admin_name,
        admin_phone: admin_phone,
        group_slug:  group_slug,
        name:        name,
      )

      register_user(name: admin_name, email: admin_email, password: admin_password)
      troop_slug = register_troop(group_slug: group_slug, name: "Gestion")
      attach_user_to_group(group_slug: group_slug, email: admin_email)
      attach_user_to_troop(group_slug: group_slug, troop_slug: troop_slug, email: admin_email)
    end
  end

  def register_troop(group_slug:, name:, troop_slug: generate_slug)
    troop_slug.tap do
      @troops_ds.insert(
        group_slug: group_slug,
        troop_slug: troop_slug,
        name:       name,
      )
    end
  end

  def register_user(name:, email:, password:)
    exists = @users_ds.where(email: email).first
    return exists[:user_slug] if exists

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
    return nil if @memberships_ds.where(group_slug: group_slug, email: email).first

    @memberships_ds.insert(
      group_slug: group_slug,
      email:      email,
    )

    nil
  end

  def attach_user_to_troop(email:, group_slug:, troop_slug:)
    return nil if @enrollments_ds.where(group_slug: group_slug, troop_slug: troop_slug, email: email).first

    @enrollments_ds.insert(
      email:      email,
      group_slug: group_slug,
      troop_slug: troop_slug,
    )

    nil
  end

  def detach_user_from_troop(email:, group_slug:, troop_slug:)
    @enrollments_ds.where(
      email:      email,
      group_slug: group_slug,
      troop_slug: troop_slug,
    ).delete
  end

  # @param images [Array<#read>] An array of readable objects that are images
  #     that will be associated with this product.
  #
  # @param categories [Array<String>] An array of categories to which this product
  #     belongs to. This array is considered canonical: on every
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

    category_codes:,
    images:,

    product_slug: generate_slug
  )
    product_slug.tap do
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
        [group_slug, product_slug, blob_storage.import(file)]
      end

      @product_categories_ds.import(
        [:group_slug, :product_slug, :category_code],
        category_codes.map{|category_code| [group_slug, product_slug, category_code]})
      @product_images_ds.import([:group_slug, :product_slug, :blob_slug], blob_slugs) if blob_slugs.any?
    end
  end

  # Updates the row identified by `product_slug` with the new information.
  #
  # @param images [Array<#read>] An array of IO-like objects that are images
  #     that describe this product. images is strictly additive: not naming
  #     an image that was previously on the object will not remove it from
  #     this product's images list.
  # @param categories [Array<String>] An array of category codes to which this
  #     product belongs to. This array is considered canonical: on every write,
  #     the only categories this product will belong to are the ones named here.
  #
  # @return [] Returns no meaningful value.
  #
  # @note It is not an error, but doesn't make sense, to attempt to update a slug
  #     that doesn't actually exist.
  def change_product_details(group_slug:, product_slug:,
                             name:, description:,
                             internal_unit_price:, external_unit_price:,
                             building:, room:, aisle:, bin:,
                             category_codes:, images:)
    updated_attrs = {
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
    }

    @products_ds
      .where(group_slug: group_slug, product_slug: product_slug)
      .update(updated_attrs)

    @product_categories_ds.where(group_slug: group_slug, product_slug: product_slug).delete
    @product_categories_ds.import(
      [:group_slug, :product_slug, :category_code],
      category_codes.map{|category_code| [group_slug, product_slug, category_code]})

    blob_slugs = images.map do |file|
      [group_slug, product_slug, blob_storage.import(file)]
    end

    @product_images_ds.import([:group_slug, :product_slug, :blob_slug], blob_slugs) if blob_slugs.any?
  end

  def remove_product(group_slug:, product_slug:)
    @products_ds.where(group_slug: group_slug, product_slug: product_slug).delete
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
    existing = @instances_ds.where(group_slug: group_slug, product_slug: product_slug).count

    if quantity == existing
      # NOP
    elsif quantity > existing
      add_instances(group_slug, product_slug, quantity - existing)
    else
      remove_unused_instances(group_slug, product_slug, existing - quantity)
    end
  end

  def register_troop_event(
    group_slug:,
    troop_slug:,
    event_slug: generate_slug,

    name:,
    description:,

    lease_on:,
    start_on:,
    end_on:,
    return_on:
  )
    event_slug.tap do
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
        lease_on:     lease_on,
        leaser_email: leaser_email,
        leaser_name:  leaser_name,
        leaser_phone: leaser_phone,
        name:         name,
        return_on:    return_on,
        start_on:     start_on,
      )
    end
  end

  def change_event_details(group_slug:, event_slug:,
    troop_slug:,
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
    updated_attrs = {
      troop_slug: troop_slug,
      leaser_name: leaser_name,
      leaser_phone: leaser_phone,
      leaser_email: leaser_email,

      name: name,
      description: description,

      lease_on: lease_on,
      start_on: start_on,
      end_on: end_on,
      return_on: return_on
    }

    @events_ds
      .where(group_slug: group_slug, event_slug: event_slug)
      .update(updated_attrs)
  end

  def add_product_to_event(group_slug:, event_slug:, product_slug:, quantity: 1)
    # When we introduce kits, this query will need to evolve to reduce
    # the likelyhood of reserving an instance that belongs on a kit
    instance_slugs = @products_ds
      .left_join(@instances_ds.as(:instances), [:group_slug, :product_slug])
      .left_join(@reservations_ds.as(:reservations), [:group_slug, :instance_slug])
      .where(group_slug: group_slug, product_slug: product_slug)
      .group_by(:group_slug, :instance_slug)
      .order_by(Sequel.function(:count, Sequel[:reservations][:id]), Sequel.function(:random))
      .limit(quantity)
      .select_map(:instance_slug)

    reservation_rows = instance_slugs.map do |instance_slug|
      [group_slug, event_slug, instance_slug, generate_slug]
    end

    @reservations_ds.import(
      [:group_slug, :event_slug, :instance_slug, :reservation_slug],
      reservation_rows)

    reservation_rows.map(&:last)
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
  # @param group_slug [String] The slug of the group we're targeting.
  # @param search_string [NilClass, String] A string to search for in products.
  #     The search will look in the product's name, description and location.
  #     This string is not case sensitive.
  # @param count [Integer] The number of elements to return per page.
  # @param category_codes [Array<String>] Returns products that belong to all of
  #     the selected categories. The empty list only products in no categories will
  #     be returned.
  # @param before [String] The slug of the product that is the first product
  #     on this page, so that we can return the preivous page of products.
  # @param after [String] The slug of the product that is the last product
  #     on this page, so that we can return the next page of products.
  #
  # @return [Array<Hash>] The products that match `search_string`, if any.
  def find_products(group_slug:, count: 25, search_string: nil, category_codes:, before: nil, after: nil)
    ds = find_products_ds(group_slug)
    ds = ds.where(
      Sequel.|([category_code: nil], [category_code: category_codes])
    )

    if search_string.present?
      ds = ds.where(
        Sequel.|(
          Sequel.ilike(Sequel.function(:unaccent, Sequel[:products][:name]), Sequel.function(:unaccent, "%#{search_string}%")),
          Sequel.ilike(Sequel.function(:unaccent, Sequel[:products][:description]), Sequel.function(:unaccent, "%#{search_string}%"))
        )
      )
    end

    if before.present?
      ds = ds.where{ products[:name] < before }
        .order_by(Sequel.desc(Sequel.function(:unaccent, Sequel[:products][:name])))
    end

    if after.present?
      ds = ds.where{ products[:name] > after }
        .order_by(Sequel.asc(Sequel.function(:unaccent, Sequel[:products][:name])))
    end

    result = ds.take(count)
      .map{|product| product.merge(blob_slugs: product.fetch(:blob_slugs, []).compact)}

    result = result.reverse if before.present?

    result
  end

  def find_product(group_slug:, product_slug:)
    # #first may return nil in case there doesn't exist a product with the given primary key
    # In that case, the call to #yield_self would pass nil, which would blow up the call
    # to #merge. To combat this, we instead guard the call to #merge with a presence check.
    # This prevents a NoMethodError which is exactly what we want (due to the short-circuiting
    # behaviour of &&).
    find_products_ds(group_slug)
      .where(product_slug: product_slug)
      .first
      .yield_self{|product| product && product.merge(blob_slugs: product.fetch(:blob_slugs, []).compact)}
  end

  def find_product_reservations(group_slug:, product_slug:, cutoff_on: Time.at(0))
    @reservations_ds
      .join(@instances_ds.as(:instances), [:group_slug, :instance_slug])
      .join(@events_ds.as(:events), [:group_slug, :event_slug])
      .where(group_slug: group_slug, product_slug: product_slug)
      .where(Sequel[:events][:lease_on] => cutoff_on ... 100.years.from_now.to_date)
      .order(Sequel[:reservations][:instance_slug], Sequel[:events][:start_on])
      .select(Sequel[:reservations][:instance_slug].as(:instance_slug))
      .select_append(Sequel[:events][:name].as(:event_name))
      .select_append(Sequel[:events][:lease_on].as(:lease_on))
      .select_append(Sequel[:events][:return_on].as(:return_on))
      .select_append(Sequel[:events][:event_slug])
      .select_append(Sequel[:events][:group_slug])
      .to_a
  end

  def find_event_reservations(group_slug:, event_slug:)
    @reservations_ds
      .join(@instances_ds.as(:instances), [:group_slug, :instance_slug])
      .join(@products_ds.as(:products), [:group_slug, :product_slug])
      .left_join(@product_images_ds.as(:product_images), [:group_slug, :product_slug])
      .where(group_slug: group_slug, event_slug: event_slug)
      .select(Sequel[:products][:group_slug], Sequel[:products][:product_slug], Sequel[:products][:name].as(:product_name), Sequel[:products][:description].as(:product_description))
      .select_append{ count(reservation_slug).as(:num_instances) }
      .select_append(Sequel.function(:array_agg, Sequel.lit('DISTINCT "product_images"."blob_slug"')).as(:blob_slugs))
      .group_by(Sequel[:products][:group_slug], Sequel[:products][:product_slug], Sequel[:products][:name], Sequel[:products][:description])
      .order_by(Sequel.function(:unaccent, Sequel[:products][:name]))
      .to_a
  end

  # @param after [NilClass | Date] Finds events that start on or after this date.
  #     If nil, does not limit events by `start_on`.
  # @param before [NilClass | Date] Finds events that start_on or before this date.
  #     If nil, does not limit events by `start_on`.
  def find_events(group_slug:, after: nil, search_string: nil, before: nil, count: 25)
    ds = @events_ds
      .where(group_slug: group_slug)
      .left_join(@troops_ds.as(:troops), [:group_slug, :troop_slug])
      .select_all(:events)
      .select_append(Sequel[:troops][:name].as(:troop_name))
    ds = ds.where{ Sequel[:events][:start_on] >= after                               } if after.present?
    ds = ds.where{ Sequel[:events][:start_on] <= before                              } if before.present?
    ds = ds.order(Sequel[:events][:start_on])

    if search_string.present?
      ds = ds.where(
        Sequel.|(
          Sequel.ilike(Sequel.function(:unaccent, Sequel[:events][:name]), Sequel.function(:unaccent, "%#{search_string}%")),
          Sequel.ilike(Sequel.function(:unaccent, Sequel[:events][:description]), Sequel.function(:unaccent, "%#{search_string}%"))
        )
      )
    end

    ds.take(count)
  end

  def find_accessible_groups_of_user(user_slug: nil, email: nil)
    ds = @groups_ds
      .join(@memberships_ds.as(:memberships), [:group_slug])
      .join(@users_ds.as(:users), [:email])
      .left_join(@events_ds.as(:events), [:group_slug])
      .left_join(@troops_ds.as(:troops), [:group_slug, :troop_slug])
      .select(Sequel[:groups][:group_slug], Sequel[:groups][:name].as(:group_name))
      .select_append(Sequel[:events][:event_slug])
      .select_append(Sequel[:events][:name].as(:event_name))
      .select_append(Sequel[:events][:leaser_name])
      .select_append(Sequel[:events][:leaser_email])
      .select_append(Sequel[:events][:leaser_phone])
      .select_append(Sequel[:events][:lease_on])
      .select_append(Sequel[:events][:start_on])
      .select_append(Sequel[:events][:end_on])
      .select_append(Sequel[:events][:return_on])
      .select_append(Sequel[:troops][:troop_slug])
      .select_append(Sequel[:troops][:name].as(:troop_name))

    ds = ds.where(user_slug: user_slug) if user_slug
    ds = ds.where(email: email)         if email
    result = ds.to_a

    result.each_with_object(Hash.new) do |row, memo|
      memo[row.fetch(:group_slug)] ||= {
        name:       row.fetch(:group_name),
        group_slug: row.fetch(:group_slug),
        events:     [],
      }

      if row.fetch(:event_name)
        memo[row.fetch(:group_slug)][:events] << {
          event_slug:   row.fetch(:event_slug),
          name:         row.fetch(:event_name),
          lease_on:     row.fetch(:lease_on),
          start_on:     row.fetch(:start_on),
          end_on:       row.fetch(:end_on),
          return_on:    row.fetch(:return_on),
          leaser_name:  row.fetch(:leaser_name),
          leaser_email: row.fetch(:leaser_email),
          leaser_phone: row.fetch(:leaser_phone),
          troop:        {
            troop_slug: row.fetch(:troop_slug),
            name:       row.fetch(:troop_name),
          }
        }
      end
    end.values
  end

  def find_group(slug)
    result = @groups_ds
      .left_join(@troops_ds.as(:troops), [:group_slug])
      .left_join(@memberships_ds, [:group_slug])
      .left_join(@users_ds.as(:users), [:email])
      .left_join(@enrollments_ds.as(:enrollments), [:group_slug, :troop_slug, :email])
      .select(:group_slug, Sequel[:groups][:name].as(:group_name))
      .select_append(:admin_name, :admin_email, :admin_phone)
      .select_append(Sequel[:groups][:created_at].as(:group_created_at))
      .select_append(:troop_slug, Sequel[:troops][:name].as(:troop_name))
      .select_append(:user_slug, Sequel[:users][:name].as(:user_name), Sequel[:users][:email].as(:user_email), Sequel[:users][:phone].as(:user_phone))
      .select_append(Sequel[:enrollments][:id].as(:enrollment_id))
      .where(group_slug: slug)
      .to_a
    return nil if result.blank?

    members = result.each_with_object(Hash.new) do |row, memo|
      email = row.fetch(:user_email)
      memo[email] ||= {
        email:      row.fetch(:user_email),
        name:       row.fetch(:user_name),
        phone:      row.fetch(:user_phone),
        user_slug:  row.fetch(:user_slug),
      }
    end.values

    troops = result.each_with_object(Hash.new) do |row, memo|
      troop_slug = row.fetch(:troop_slug)

      memo[troop_slug] ||= {
        troop_slug: troop_slug,
        name:       row.fetch(:troop_name),
        members:    [],
      }

      memo[troop_slug][:members] << {
        email:     row.fetch(:user_email),
        name:      row.fetch(:user_name),
        phone:     row.fetch(:user_phone),
        user_slug: row.fetch(:user_slug),
      } if row.fetch(:enrollment_id)
    end.values

    {
      group_slug:   result.first.fetch(:group_slug),
      name:         result.first.fetch(:group_name),
      created_at:   result.first.fetch(:group_created_at),
      admin_name:   result.first.fetch(:admin_name),
      admin_email:  result.first.fetch(:admin_email),
      admin_phone:  result.first.fetch(:admin_phone),
      members:      members,
      troops:       troops,
    }
  end

  def find_event(group_slug:, event_slug:)
    rows = @events_ds
      .left_join(@troops_ds.as(:troops), [:group_slug, :troop_slug])
      .left_join(@enrollments_ds.as(:enrollments), [:group_slug, :troop_slug])
      .left_join(@users_ds.as(:users), [:email])
      .where(group_slug: group_slug, event_slug: event_slug)
      .select(Sequel[:events][:name].as(:event_name), Sequel[:events][:description].as(:event_description))
      .select_append(:group_slug, :troop_slug, :event_slug)
      .select_append(:leaser_name, :leaser_email, :leaser_phone)
      .select_append(Sequel[:events][:lease_on], Sequel[:events][:start_on])
      .select_append(Sequel[:events][:end_on], Sequel[:events][:return_on])
      .select_append(Sequel[:troops][:name].as(:troop_name))
      .select_append(Sequel[:users][:name].as(:user_slug))
      .select_append(Sequel[:users][:name].as(:user_name))
      .select_append(Sequel[:users][:email].as(:user_email))
      .select_append(Sequel[:users][:phone].as(:user_phone))
      .to_a

    event = rows
      .first
      .slice(:group_slug, :event_slug, :troop_slug, :leaser_name, :leaser_email, :leaser_phone, :lease_on, :start_on, :end_on, :return_on)

    event.tap do
      event[:name] = rows.first.fetch(:event_name)
      event[:description] = rows.first.fetch(:event_description)

      if rows.first.fetch(:troop_name)
        event[:troop] = {
          group_slug: rows.first.fetch(:group_slug),
          troop_slug: rows.first.fetch(:troop_slug),
          name:       rows.first.fetch(:troop_name),
        }
      end

      event[:members] = []
      if rows.first.fetch(:user_slug)
        event[:members] = rows.map do |row|
          {
            group_slug: row.fetch(:group_slug),
            troop_slug: row.fetch(:troop_slug),
            user_slug:  row.fetch(:user_slug),
            name:       row.fetch(:user_name),
            email:      row.fetch(:user_email),
            phone:      row.fetch(:user_phone),
          }
        end
      end
    end
  end

  private

  attr_reader :blob_storage

  # Return a URL-safe string that is suitable for uniquely identifying an object.
  #
  # The string is *probably* globally unique, but is not guaranteed to be.
  def generate_slug
    # Due to the birthday paradox, we have to use a larger slug size than
    # we would expect. Given that we don't retry if a slug already exists,
    # we simply use a larger and larger number of characters in slugs, in
    # the hope that we don't ever hit a duplicate key exception.
    #
    # The birthday paradox says that we have a 50/50 chance of having a
    # duplicate after we have N elements in our collection:
    #
    #     (1..8).map{|n| [n, (36**n)>>1]}.to_h
    #     {1=>18,
    #      2=>648,
    #      3=>23328,
    #      4=>839808,
    #      5=>30233088,
    #      6=>1088391168,
    #      7=>39182082048,
    #      8=>1410554953728}
    #
    # At 3-4 characters, the likelyhood that we generate a duplicate
    # key is already low. Just to be on the safe side, and because
    # we will be importing data from a previous incarnation of this
    # system, we use a safe 6 character slug, giving us at least
    # 1,088,391,168 elements before we have a 50/50 chance of
    # generating a duplicate. This should be sufficient for the
    # foreseeable future.
    SecureRandom.alphanumeric(6).downcase
  end

  def find_products_ds(group_slug)
    @products_ds
      .left_join(@instances_ds.as(:instances), [:group_slug, :product_slug])
      .left_join(@product_images_ds.as(:product_images), [:group_slug, :product_slug])
      .left_join(@product_categories_ds.as(:product_categories), [:group_slug, :product_slug])
      .where(Sequel[:products][:group_slug] => group_slug)
      .group_by(Sequel[:products][:id], Sequel[:products][:group_slug], Sequel[:products][:product_slug])
      .order_by(Sequel.function(:unaccent, Sequel[:products][:name]))
      .select_all(:products)
      .select_append{ count(instance_slug).as(:num_instances) }
      .select_append(Sequel.function(:array_agg, Sequel.lit('DISTINCT "product_images"."blob_slug"')).as(:blob_slugs))
      .select_append(Sequel.function(:array_agg, Sequel.lit('DISTINCT "product_categories"."category_code" ORDER BY "product_categories"."category_code"')).as(:category_codes))
  end

  def add_instances(group_slug, product_slug, quantity)
    quantity.times.map{ generate_slug }.tap do |slugs|
      @instances_ds.import(
        [:group_slug, :product_slug, :instance_slug, :state],
        slugs.map{|slug| [group_slug, product_slug, slug, "available"]}
      )
    end
  end

  def remove_unused_instances(group_slug, product_slug, quantity)
    unused_instance_ids = @instances_ds
      .left_join(@reservations_ds.as(:reservations), [:group_slug, :instance_slug])
      .where(Sequel[:reservations][:id] => nil)
      .select_map(Sequel[:instances][:id])

    if unused_instance_ids.length < quantity
      raise NotEnoughUnusedInstances,
        "Cannot remove #{quantity} instances of #{product_slug.inspect}: only found #{unused_instance_ids.length} unused instances"
    end

    @instances_ds
      .where(id: unused_instance_ids.first(quantity))
      .delete
  end
end
