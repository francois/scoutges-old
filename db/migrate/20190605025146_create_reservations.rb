Sequel.migration do
  change do
    create_table :reservations do
      column :id,               :bigserial, null: false, unique: true
      column :group_slug,       :text,      null: false
      column :event_slug,       :text,      null: false
      column :instance_slug,    :text,      null: false
      column :reservation_slug, :text,      null: false, unique: true

      column :created_at, :timestamptz, null: false, default: Sequel.function(:now)
      column :updated_at, :timestamptz, null: false, default: Sequel.function(:now)

      primary_key [:group_slug, :event_slug, :instance_slug]
      foreign_key [:group_slug, :event_slug],    :events,    on_update: :cascade, on_delete: :cascade
      foreign_key [:group_slug, :instance_slug], :instances, on_update: :cascade, on_delete: :cascade
    end
  end
end
