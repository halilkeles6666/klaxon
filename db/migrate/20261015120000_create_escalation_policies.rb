class CreateEscalationPolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :escalation_policies do |t|
      t.string  :name, null: false
      # Time rule: if an incident is not acknowledged within this many minutes,
      # it escalates to the next level (and its urgency is raised to high).
      t.integer :ack_timeout_minutes, null: false, default: 15
      # Escalation stops once this level is reached.
      t.integer :max_level, null: false, default: 3
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :escalation_policies, :name, unique: true
  end
end
