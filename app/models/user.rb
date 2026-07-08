class User < ApplicationRecord
  has_secure_password validations: false

  enum :auth_method, { email: "email", google: "google", apple: "apple" }

  has_one :host_profile, dependent: :destroy
  # Events this user hosts. The API home feed reads host_user.events; without
  # this association the feed 500s for anyone following a host.
  has_many :events, foreign_key: :host_user_id, inverse_of: :host_user
  has_many :host_totem_assignments, class_name: "HostTotemAssignment", foreign_key: :host_user_id, dependent: :destroy
  has_many :assigned_totems, through: :host_totem_assignments, source: :totem
  has_many :check_ins, dependent: :destroy
  has_many :host_follows, dependent: :destroy
  has_many :totem_favorites, dependent: :destroy
  has_many :notification_deliveries, dependent: :destroy

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    if: :email_auth?
  validates :email, uniqueness: { case_sensitive: false, allow_nil: true }, unless: :email_auth?
  validates :google_uid, uniqueness: true, allow_nil: true
  validates :password, length: { minimum: 8 }, if: -> { email_auth? && password.present? }
  validates :auth_method, presence: true

  before_save { email&.downcase! }

  def email_auth?
    auth_method == "email"
  end

  # ── Role / authorization API ──────────────────────────────────────────────
  # Five-level hierarchy (see UNIFIED_EVENT_FUNNEL_PLAN.md Phase 1):
  #   super admin (users.is_admin) > totem admin > totem host > signed-in user > anonymous.
  # Per-totem roles live on host_totem_assignments.role.

  # Super admin is the existing is_admin column — keep it as the source of truth.
  def super_admin?
    is_admin?
  end

  # The user's effective role on a given totem, as a symbol, or nil.
  def totem_role_for(totem)
    return :super_admin if is_admin?

    assignment = host_totem_assignments.find { |a| a.totem_id == totem&.id }
    assignment&.role&.to_sym
  end

  # Totem ids this user moderates (totem_admin assignments). Super admins moderate all.
  def moderated_totem_ids
    return Totem.ids if is_admin?

    host_totem_assignments.select(&:role_totem_admin?).map(&:totem_id)
  end

  def totem_admin_of?(totem)
    return false unless totem

    host_totem_assignments.any? { |a| a.totem_id == totem.id && a.role_totem_admin? }
  end

  # Can approve/edit/delete any event on this totem.
  def can_moderate_totem?(totem)
    is_admin? || totem_admin_of?(totem)
  end

  # Submissions auto-publish (skip the review queue) when the user has rights on the totem.
  # totem_admin is exempt from the host_profile gate; role: host still needs an active profile.
  def can_auto_publish_on?(totem)
    return false unless totem
    return true if is_admin?

    assignment = host_totem_assignments.find { |a| a.totem_id == totem.id }
    return false unless assignment
    return true if assignment.role_totem_admin?

    host_profile&.active? || false
  end

  # Can assign/invite hosts to this totem (delegated management).
  def can_manage_hosts_on?(totem)
    is_admin? || totem_admin_of?(totem)
  end

  def generate_magic_link_token!
    update!(
      magic_link_token: SecureRandom.urlsafe_base64(32),
      magic_link_token_expires_at: 30.minutes.from_now
    )
  end

  def magic_link_token_valid?
    magic_link_token.present? && magic_link_token_expires_at&.future?
  end

  def consume_magic_link_token!
    update!(magic_link_token: nil, magic_link_token_expires_at: nil)
  end

  def posthog_distinct_id
    id.to_s
  end
end
