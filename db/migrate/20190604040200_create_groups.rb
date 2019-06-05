Sequel.migration do
  change do
    create_table :groups do
      column :id,          :bigserial, null: false, unique: true

      column :group_slug,  :text,   null: false

      column :name,        :citext, null: false, unique: true
      column :admin_name,  :citext, null: false
      column :admin_email, :citext, null: false
      column :admin_phone, :citext, null: false

      column :created_at, :timestamptz, null: false, default: Sequel.function(:now)
      column :updated_at, :timestamptz, null: false, default: Sequel.function(:now)

      primary_key [:group_slug]
    end
  end
end
