Sequel.migration do
  change do
    create_table :memberships do
      column :id,          :bigserial, null: false, unique: true

      column :group_slug,  :text,      null: false
      column :email,       :citext,    null: false

      column :created_at, :timestamptz, null: false, default: Sequel.function(:now)
      column :updated_at, :timestamptz, null: false, default: Sequel.function(:now)

      primary_key [:group_slug, :email]
      foreign_key [:group_slug], :groups, on_update: :cascade, on_delete: :cascade
      foreign_key [:email],      :users,  on_update: :cascade, on_delete: :cascade
    end
  end
end
