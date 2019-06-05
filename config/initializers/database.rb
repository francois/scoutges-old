Sequel.extension :pg_array
Sequel.extension :pg_json
Sequel.extension :pg_timestamptz

begin
  DB = Sequel::Model.db
rescue Sequel::Error
  # Sequel::Model.db= was not called; ignoring
  # This mostly happens during migrations when the system is bootstrapping
end
