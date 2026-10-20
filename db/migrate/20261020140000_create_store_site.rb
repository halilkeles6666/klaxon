class CreateStoreSite < ActiveRecord::Migration[8.0]
  def change
    # Real request telemetry from the fake company store (Nimbus). Every page
    # view / checkout writes one row; the monitor reads recent windows of these.
    create_table :request_logs do |t|
      t.string  :component, null: false   # which store component served it
      t.string  :path,      null: false
      t.integer :status,    null: false   # HTTP status actually returned
      t.integer :latency_ms, null: false
      t.datetime :created_at, null: false
    end
    add_index :request_logs, [ :component, :created_at ]

    # Active faults injected into the store. A row = that component is currently
    # broken with this fault. The agent's remediation deletes the matching row.
    create_table :site_faults do |t|
      t.string :component, null: false
      t.string :fault,     null: false
      t.timestamps
    end
    add_index :site_faults, :component, unique: true
  end
end
