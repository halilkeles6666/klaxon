class CreateIncidentEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :incident_events do |t|
      t.references :incident, null: false, foreign_key: true
      t.references :actor, null: true, foreign_key: { to_table: :users }
      # triggered | alert_grouped | escalated | acknowledged | resolved | reopened | note
      t.string   :kind, null: false
      t.text     :detail

      t.timestamps
    end
    add_index :incident_events, %i[incident_id created_at]
  end
end
