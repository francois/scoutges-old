Sequel.migration do
  change do
    create_table :products do
      column :id,           :bigserial, null: false, unique: true
      column :group_slug,   :text,      null: false
      column :product_slug, :text,      null: false, unique: true
      column :name,         :citext,    null: false
      column :description,  :citext,    null: false
      column :building,     :citext
      column :room,         :citext
      column :aisle,        :citext
      column :bin,          :citext

      column :internal_unit_price, :decimal, null: false
      column :external_unit_price, :decimal, null: false

      column :created_at, :timestamptz, null: false, default: Sequel.function(:now)
      column :updated_at, :timestamptz, null: false, default: Sequel.function(:now)

      constraint(:product_slug_is_meaningful) { length(product_slug) > 0 }
      constraint(:name_is_meaningful)         { length(name) > 0 }

      primary_key [:group_slug, :product_slug]
      foreign_key [:group_slug], :groups, on_update: :cascade, on_delete: :cascade
    end
  end
end
