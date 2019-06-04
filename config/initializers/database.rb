DB = Sequel.connect(ENV.fetch("DATABASE_URL"), logger: Rails.logger)
