class CreateServices < ActiveRecord::Migration[8.0]
  def change
    create_table :services do |t|
      t.string  :name, null: false
      # Routing key a monitoring tool sends alerts to (e.g. "payments-api").
      t.string  :routing_key, null: false
      t.references :escalation_policy, null: false, foreign_key: true
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :services, :routing_key, unique: true
  end
end
