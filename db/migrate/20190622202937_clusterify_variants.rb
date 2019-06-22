Sequel.migration do
  up do
    execute "CLUSTER variants USING variants_pkey"
    ClusterDatabase.enqueue(run_at: 1.minute.from_now)
  end

  down do
    # NOP
  end
end
