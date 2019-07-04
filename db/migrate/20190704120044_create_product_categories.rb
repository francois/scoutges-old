Sequel.migration do
  change do
    create_table :product_categories do
      column :id,           :bigserial,    null: false, unique: true
      column :group_slug,    :text,        null: false
      column :product_slug,  :text,        null: false
      column :category_code, :text,        null: false

      column :created_at,    :timestamptz, null: false, default: Sequel.function(:now)
      column :updated_at,    :timestamptz, null: false, default: Sequel.function(:now)
      
      primary_key [:group_slug, :category_code, :product_slug]
      index [:group_slug, :product_slug]

      foreign_key [:group_slug, :product_slug], :products,   on_update: :cascade, on_delete: :cascade
      foreign_key [:category_code],             :categories, on_update: :cascade, on_delete: :cascade
    end
  end
end
