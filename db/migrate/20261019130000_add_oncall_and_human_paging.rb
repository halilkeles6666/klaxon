class AddOncallAndHumanPaging < ActiveRecord::Migration[8.0]
  def change
    # On-call rotation: who is the responsible human during a time window.
    create_table :on_call_shifts do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at,   null: false
      t.timestamps
    end
    add_index :on_call_shifts, [ :starts_at, :ends_at ]

    # When the autonomous agent hits a dead end it pages the on-call human:
    # the incident is flagged for a human and the paged person is recorded.
    add_reference :incidents, :paged_user, null: true, foreign_key: { to_table: :users }
    add_column :incidents, :needs_human, :boolean, default: false, null: false
  end
end
