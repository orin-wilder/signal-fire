class BackfillBulletinPostsToEvents < ActiveRecord::Migration[8.1]
  # Phase 2 backfill: copy every bulletin_post into the unified Event table and
  # repoint promoted scouted candidates. bulletin_posts is left intact (read-only
  # during the transition); the table is dropped in a later migration once parity
  # is verified. See BulletinPostMigrator for the field map.
  def up
    # The table is dropped in a later migration; on a fresh replay it still exists
    # at this point, but guard anyway so this historical step is a no-op if not.
    return unless table_exists?(:bulletin_posts)

    BulletinPostMigrator.migrate_all!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
