Sequel.migration do
  change do
    create_table :users do
      column :id,       :bigserial, null: false, unique: true

      column :user_slug, :text,   null: false, unique: true
      column :name,      :citext, null: false
      column :email,     :citext, null: false
      column :password,  :text,   null: false

      column :created_at, :timestamptz, null: false, default: Sequel.function(:now)
      column :updated_at, :timestamptz, null: false, default: Sequel.function(:now)

      primary_key [:email]
    end
  end
end
