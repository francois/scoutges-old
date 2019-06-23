# frozen_string_literal: true

class ClusterDatabaseJob < Que::Job
  def run
    DB.execute "CLUSTER"
    DB.transaction do
      ClusterDatabaseJob.enqueue(run_at: 1.day.from_now)
      destroy
    end
  end
end
