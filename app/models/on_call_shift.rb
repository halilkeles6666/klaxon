# One on-call window: a user is the responsible human between starts_at and
# ends_at. OnCall.on_call_at(now) uses these to find who is currently paged
# when the autonomous agent needs to hand an incident back to a person.
class OnCallShift < ApplicationRecord
  belongs_to :user

  validates :starts_at, :ends_at, presence: true
  validate  :ends_after_starts

  scope :covering, ->(time) { where("starts_at <= ? AND ends_at > ?", time, time) }
  scope :chronological, -> { order(:starts_at) }

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?
    errors.add(:ends_at, "başlangıçtan sonra olmalı") if ends_at <= starts_at
  end
end
