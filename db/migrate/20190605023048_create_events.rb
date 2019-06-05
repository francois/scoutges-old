Sequel.migration do
  change do
    create_table :events do
      column :id,           :bigserial, null: false, unique: true

      column :group_slug,   :text,      null: false
      column :event_slug,   :text,      null: false, unique: true
      column :troop_slug,   :text,      null: true

      column :name,         :citext,    null: false
      column :description,  :citext,    null: false

      column :lease_on,     :date,      null: false
      column :start_on,     :date,      null: false
      column :end_on,       :date,      null: false
      column :return_on,    :date,      null: false

      column :leaser_name,  :citext,    null: true
      column :leaser_phone, :citext,    null: true
      column :leaser_email, :citext,    null: true

      column :created_at, :timestamptz, null: false, default: Sequel.function(:now)
      column :updated_at, :timestamptz, null: false, default: Sequel.function(:now)

      constraint :troop_or_leaser_filled_in, "(troop_slug IS NOT NULL AND leaser_name IS NULL AND leaser_phone IS NULL AND leaser_email IS NULL) OR (troop_slug IS NULL AND leaser_name IS NOT NULL AND leaser_phone IS NOT NULL AND leaser_email IS NOT NULL)"
      constraint(:name_is_meaningful) { length(name) > 0 }

      primary_key [:group_slug, :event_slug]
      foreign_key [:group_slug], :groups, on_update: :cascade, on_delete: :cascade
    end
  end
end
