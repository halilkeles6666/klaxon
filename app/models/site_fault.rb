# An active fault injected into a store component. While a row exists, that
# component genuinely misbehaves (500s / slowness). The agent's remediation
# removes the row, which really heals the component.
class SiteFault < ApplicationRecord
  # fault => the remediation that actually fixes it (same vocabulary the agent
  # chooses from). Used by the store backend to decide how to break, and by the
  # world to decide whether an applied action clears it.
  FIXES = {
    "bad_deploy"   => "rollback_deploy", # endpoint 500s right after a deploy
    "overloaded"   => "scale_up",        # slow under load
    "crashed"      => "restart_service", # component process down
    "queue_stuck"  => "clear_queue",     # backed-up queue / full disk
    "primary_down" => "failover"         # database primary unreachable
  }.freeze

  validates :component, presence: true, uniqueness: true
  validates :fault, inclusion: { in: FIXES.keys }

  def self.active_for(component)
    find_by(component: component)
  end

  def fix
    FIXES[fault]
  end
end
