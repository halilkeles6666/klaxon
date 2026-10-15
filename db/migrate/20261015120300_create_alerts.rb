class CreateAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :alerts do |t|
      t.references :incident, null: false, foreign_key: true
      t.string   :summary, null: false
      t.string   :source
      # True when this alert was grouped into an already-open incident
      # (deduplicated) rather than opening a new one.
      t.boolean  :deduplicated, null: false, default: false

      t.timestamps
    end
  end
end
