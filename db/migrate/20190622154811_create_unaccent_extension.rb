Sequel.migration do
  up do
    execute "CREATE EXTENSION unaccent"
  end

  down do
    execute "DROP EXTENSION unaccent"
  end
end
