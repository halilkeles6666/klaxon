class CreateIncidents < ActiveRecord::Migration[8.0]
  def change
    create_table :incidents do |t|
      t.string   :reference, null: false
      t.string   :title, null: false
      t.string   :status, null: false, default: "triggered"
      t.string   :urgency, null: false, default: "high"
      # Deduplication key: repeat alerts with the same (service, dedup_key)
      # group into one open incident instead of paging again.
      t.string   :dedup_key, null: false
      t.references :service, null: false, foreign_key: true
      t.references :acknowledged_by, null: true, foreign_key: { to_table: :users }

      # Time-rule / escalation bookkeeping.
      t.integer  :escalation_level, null: false, default: 1
      t.datetime :triggered_at, null: false
      t.datetime :acknowledged_at
      t.datetime :resolved_at
      t.datetime :escalated_at

      t.integer  :alerts_count, null: false, default: 0

      t.timestamps
    end
    add_index :incidents, :reference, unique: true
    add_index :incidents, :status
    add_index :incidents, %i[service_id dedup_key status]
  end
end
