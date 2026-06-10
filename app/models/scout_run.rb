class ScoutRun < ApplicationRecord
  belongs_to :totem
  belongs_to :requested_by, class_name: "User"
  has_many :candidates, class_name: "ScoutedEventCandidate", dependent: :destroy

  STATUSES = %w[pending complete failed].freeze

  def pending?  = status == "pending"
  def complete? = status == "complete"
  def failed?   = status == "failed"
end
