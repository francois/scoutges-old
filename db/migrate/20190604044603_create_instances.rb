Sequel.migration do
  change do
    create_table :instances do
      column :id,            :bigserial, null: false, unique: true
      column :group_slug,    :text,      null: false
      column :product_slug,  :text,      null: false
      column :instance_slug, :text,      null: false, unique: true
      column :state,         :text,      null: false, default: "available"

      column :created_at, :timestamptz, null: false, default: Sequel.function(:now)
      column :updated_at, :timestamptz, null: false, default: Sequel.function(:now)

      constraint :state_is_in_list, "state IN ('available', 'checked_out', 'in_repairs', 'trashed')"

      primary_key [:group_slug, :instance_slug]
      foreign_key [:group_slug, :product_slug], :products, on_update: :cascade, on_delete: :cascade
    end
  end
end
