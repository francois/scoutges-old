Sequel.migration do
  change do
    create_table :blobs do
      column :id,           :bigserial, null: false, unique: true
      column :blob_slug,    :text,      null: false
      column :content_type, :text,      null: false

      column :created_at, :timestamptz, null: false, default: Sequel.function(:now)
      column :updated_at, :timestamptz, null: false, default: Sequel.function(:now)

      primary_key [:blob_slug]
    end
  end
end
