require_relative "../config/environment"

scoutinv = Scoutinv.new

DB.transaction do
  Que.clear!
  DB[:groups].truncate(cascade: true)
  DB[:users].truncate(cascade: true)
  DB[:blobs].truncate(cascade: true)

  scoutinv.register_group(
    admin_email: "francois@teksol.info",
    admin_name: "François Beausoleil",
    admin_password: "monkeymonkey",
    admin_phone: "888-555-2222",
    group_slug: "10eme",
    name: "10ème Groupe Scout Est-Calade (Fleurimont)",
  )

  scoutinv.register_user(
    email: "susan@teksol.info",
    name: "Susan Labrecque",
    password: "monkeymonkey",
  )

  scoutinv.attach_user_to_group(
    email: "susan@teksol.info",
    group_slug: "10eme",
  )

  scoutinv.register_troop(
    group_slug: "10eme",
    name: "Les Aigles (Louveteaux)",
    troop_slug: "aigles",
  )

  scoutinv.register_troop(
    group_slug: "10eme",
    name: "Les Chouettes (Louveteaux)",
    troop_slug: "chouettes",
  )

  scoutinv.attach_user_to_troop(
    email: "susan@teksol.info",
    group_slug: "10eme",
    troop_slug: "aigles",
  )

  scoutinv.attach_user_to_troop(
    email: "francois@teksol.info",
    group_slug: "10eme",
    troop_slug: "chouettes",
  )

  File.open(Rails.root + "db/seed/images/tente.jpg", "rb", encoding: "ascii-8bit") do |tent|
    slug = scoutinv.register_product(
      group_slug: "10eme",
      product_slug: "tente",

      name: "Tente 4x10",
      description: "Grande tente pour 5 personnes, avec bagages",

      internal_unit_price: "0",
      external_unit_price: "15.00",

      building: "Mont Plaisant",
      room: "arrière",
      aisle: "4",
      bin: "3",

      images: [tent]
    )

    scoutinv.change_product_quantity(group_slug: "10eme", product_slug: slug, quantity: 6)
  end

  File.open(Rails.root + "db/seed/images/hache.jpg", "rb", encoding: "ascii-8bit") do |axe|
    slug = scoutinv.register_product(
      group_slug: "10eme",
      product_slug: "hache",

      name: "Hache 2 lbs/16 pouces",
      description: "Hache de 2 lbs/16 pouces",

      internal_unit_price: "0",
      external_unit_price: "0",

      building: "Mont Plaisant",
      room: "arrière",
      aisle: "6",
      bin: "7",

      images: [axe]
    )

    scoutinv.change_product_quantity(group_slug: "10eme", product_slug: slug, quantity: 2)
  end

  # File.open(Rails.root + "db/seed/images/jambon.jpg", "rb", encoding: "ascii-8bit") do |ham|
  #   slug = scoutinv.register_consumable(
  #     group_slug: "10eme",
  #     name: "Jambon haché 500 g",
  #     base_unit: "unit",
  #     internal_unit_price: "2.50",
  #     external_unit_price: "6.99",
  #     building: "Mont PLaisant",
  #     room: "congélateur 1",
  #     aisle: "",
  #     bin: "",
  #     images: [ham],
  #   )
  #
  #   scoutinv.adjust_consumable_quantity(
  #     group_slug: "10eme",
  #     consumable_slug: slug,
  #     quantity: 14,
  #   )
  # end

  scoutinv.register_troop_event(
    group_slug: "10eme",
    troop_slug: "chouettes",
    event_slug: "chouettes-camp-ete",
    name: "Chouettes camp d'été",
    description: "Terrain de camping, auto-cuisine, en tente.",

    lease_on: 2.weeks.from_now.to_date,
    start_on: 2.weeks.from_now.to_date.succ,
    end_on: 3.weeks.from_now.to_date,
    return_on: 3.weeks.from_now.to_date.succ,
  )

  scoutinv.add_product_to_event(
    event_slug: "chouettes-camp-ete",
    group_slug: "10eme",
    product_slug: "hache",
    quantity: 1,
  )

  scoutinv.add_product_to_event(
    event_slug: "chouettes-camp-ete",
    group_slug: "10eme",
    product_slug: "tente",
    quantity: 3,
  )

  scoutinv.register_group(
    admin_email: "raphael@teksol.info",
    admin_name: "Raphaël Bélisle",
    admin_password: "monkeymonkey",
    admin_phone: "888-555-2222",
    group_slug: "47eme",
    name: "47ème Groupe Scout Rock Forest",
  )

  blob_slugs = DB[:blobs]
    .join(DB[:variants], [:blob_slug])
    .where(variant: "original")
    .select_map(:blob_slug)
    .to_a
  blob_slugs.each do |blob_slug|
    CreateImageVariantsJob.enqueue(blob_slug)
  end

  ClusterDatabaseJob.enqueue(run_at: 5.minutes.from_now)
end

STDERR.puts "Database seeded"
