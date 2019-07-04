Sequel.migration do
  up do
    create_table :categories do
      column :id,            :bigserial,   null: false, unique: true
      column :category_code, :text,        null: false

      column :created_at,    :timestamptz, null: false, default: Sequel.function(:now)
      column :updated_at,    :timestamptz, null: false, default: Sequel.function(:now)

      primary_key [:category_code]
    end

    run <<~EOSQL
      INSERT INTO categories(category_code) VALUES
      ('camping'), ('kitchen'), ('miscellaneous'), ('non_perishable'), ('perishable'), ('tent'), ('tools')
    EOSQL
  end

  down do
    drop_table :categories
  end
end
