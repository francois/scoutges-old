# frozen_string_literal: true

class ClusterDatabase < Que::Job
  def run
    DB.execute "CLUSTER"
    DB.transaction do
      ClusterDatabase.enqueue(run_at: 1.day.from_now)
      destroy
    end
  end
end
