class NeutralizeSeededDemoCredentials < ActiveRecord::Migration[8.1]
  # One-time data fix: db/seeds.rb ran on every production boot (render.yaml
  # startCommand) and created @example.com accounts sharing the well-known
  # password "password" — including admin@example.com with is_admin. The demo
  # content (hosts, events, check-ins) stays; only the credentials become
  # unusable. Deliberately irreversible.
  #
  # update_columns keeps this free of model callbacks/validations — no
  # notification fan-out risk (see safe-changes skill).

  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    demo_users = MigrationUser.where("email LIKE ?", "%@example.com")
    other_admin_exists = MigrationUser.where(is_admin: true)
                                      .where.not("email LIKE ?", "%@example.com")
                                      .exists?

    say_with_time "neutralizing #{demo_users.count} @example.com account(s)" do
      demo_users.find_each do |user|
        attrs = {
          password_digest: BCrypt::Password.create(SecureRandom.hex(32)),
          magic_link_token: nil,
          magic_link_token_expires_at: nil,
          push_token: nil
        }
        # Only strip the seeded admin flag when a real admin remains; never
        # leave the app admin-less.
        attrs[:is_admin] = false if user.is_admin && other_admin_exists
        user.update_columns(attrs)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
