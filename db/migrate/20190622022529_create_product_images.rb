Sequel.migration do
  change do
    create_table :product_images do
      column :id,           :bigserial,   null: false, unique: true
      column :group_slug,   :text,        null: false
      column :product_slug, :text,        null: false
      column :blob_slug,    :text,        null: false
      column :created_at,   :timestamptz, null: false, default: Sequel.function(:now)
      column :updated_at,   :timestamptz, null: false, default: Sequel.function(:now)

      primary_key [:group_slug, :product_slug, :blob_slug]
      foreign_key [:group_slug, :product_slug], :products, on_update: :cascade, on_delete: :cascade
      foreign_key [:blob_slug],                 :blobs,    on_update: :cascade, on_delete: :cascade
    end
  end
end
