class AddAgentFieldsToIncidents < ActiveRecord::Migration[8.0]
  def change
    # Fields written by the autonomous ResolutionAgent as it assesses and
    # remediates an incident via Jev (System One) typed decisions.
    add_column :incidents, :severity, :integer                 # Jev score 0..4
    add_column :incidents, :agent_action, :string              # chosen remediation
    add_column :incidents, :agent_confidence, :float           # confidence of that choice (0..1)
    add_column :incidents, :auto_resolved, :boolean, default: false, null: false
    add_column :incidents, :resolution_attempts, :integer, default: 0, null: false

    # Simulation-only "ground truth": the action that actually fixes this
    # incident. Set by IncidentSimulator, read ONLY by ActionWorld to decide
    # success and by stats to score the agent — the agent never sees it.
    add_column :incidents, :root_cause_action, :string
    add_column :incidents, :simulated, :boolean, default: false, null: false
  end
end
