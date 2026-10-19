# The simulated "world" the agent acts on. When the agent applies a
# remediation, this decides whether it actually fixed the incident.
#
# Every simulated incident has a hidden `root_cause_action` (ground truth).
# The matching action almost always works; a wrong action almost always fails.
# So the agent's success rate is really a measure of whether Jev picked the
# correct remediation from the incident's description — which is the whole
# point of the experiment.
class ActionWorld
  CORRECT_SUCCESS = 1.0  # the right remediation always fixes the root cause
  WRONG_SUCCESS   = 0.15 # a wrong action occasionally clears it by luck

  def initialize(random: Random.new)
    @random = random
  end

  # Returns true if `action` resolved the incident.
  def apply(action, incident)
    probability = correct?(action, incident) ? CORRECT_SUCCESS : WRONG_SUCCESS
    @random.rand < probability
  end

  def correct?(action, incident)
    action.to_s == incident.root_cause_action.to_s
  end
end
