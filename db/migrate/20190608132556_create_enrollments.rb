Sequel.migration do
  change do
    create_table :enrollments do
      column :id, :bigserial,           null: false, unique: true

      column :group_slug,     :text,    null: false
      column :troop_slug,     :text,    null: false
      column :email,          :citext,  null: false

      column :created_at, :timestamptz, null: false, default: Sequel.function(:now)
      column :updated_at, :timestamptz, null: false, default: Sequel.function(:now)

      primary_key [:troop_slug, :email]
      foreign_key [:group_slug, :email], :memberships, on_cascade: :cascade, on_delete: :cascade
      foreign_key [:troop_slug], :troops, key: [:troop_slug], on_cascade: :cascade, on_delete: :cascade
    end
  end
end
