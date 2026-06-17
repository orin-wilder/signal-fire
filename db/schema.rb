# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_17_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "anonymous_check_in_counts", force: :cascade do |t|
    t.integer "count", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_anonymous_check_in_counts_on_event_id", unique: true
  end

  create_table "bulletin_posts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.string "recurrence_cadence"
    t.boolean "recurring", default: false, null: false
    t.string "source", default: "public_submission", null: false
    t.string "source_url"
    t.datetime "starts_at", null: false
    t.string "status", default: "pending", null: false
    t.string "submitter_ip"
    t.string "title", null: false
    t.bigint "totem_id", null: false
    t.datetime "updated_at", null: false
    t.index ["starts_at"], name: "index_bulletin_posts_on_starts_at"
    t.index ["status"], name: "index_bulletin_posts_on_status"
    t.index ["totem_id"], name: "index_bulletin_posts_on_totem_id"
  end

  create_table "check_ins", force: :cascade do |t|
    t.datetime "checked_in_at", null: false
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_id"], name: "index_check_ins_on_event_id"
    t.index ["user_id", "event_id"], name: "index_check_ins_on_user_id_and_event_id", unique: true
    t.index ["user_id"], name: "index_check_ins_on_user_id"
  end

  create_table "empty_totem_email_captures", force: :cascade do |t|
    t.datetime "captured_at", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.bigint "totem_id", null: false
    t.datetime "updated_at", null: false
    t.index ["totem_id"], name: "index_empty_totem_email_captures_on_totem_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "approval_state", default: "published", null: false
    t.string "chat_platform"
    t.string "chat_url"
    t.text "community_norms"
    t.datetime "created_at", null: false
    t.boolean "created_by_admin", default: false, null: false
    t.text "description"
    t.datetime "end_time", null: false
    t.bigint "host_user_id", null: false
    t.string "provenance", default: "host", null: false
    t.string "recurrence_rule"
    t.string "short_description"
    t.string "slug", null: false
    t.string "source_url"
    t.datetime "start_time", null: false
    t.string "status", default: "active", null: false
    t.string "title", null: false
    t.bigint "totem_id", null: false
    t.datetime "updated_at", null: false
    t.index ["approval_state"], name: "index_events_on_approval_state"
    t.index ["host_user_id"], name: "index_events_on_host_user_id"
    t.index ["slug"], name: "index_events_on_slug", unique: true
    t.index ["start_time"], name: "index_events_on_start_time"
    t.index ["status"], name: "index_events_on_status"
    t.index ["totem_id"], name: "index_events_on_totem_id"
  end

  create_table "host_follows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "host_user_id", null: false
    t.boolean "notify_new_event", default: true, null: false
    t.boolean "notify_reminder", default: true, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "host_user_id"], name: "index_host_follows_on_user_id_and_host_user_id", unique: true
  end

  create_table "host_profiles", force: :cascade do |t|
    t.text "blurb"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.text "host_story"
    t.string "invitation_token"
    t.datetime "invitation_token_expires_at"
    t.datetime "invite_accepted_at"
    t.string "invite_status", default: "invited", null: false
    t.datetime "invited_at"
    t.string "magic_link_token"
    t.datetime "magic_link_token_expires_at"
    t.string "slug"
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["invitation_token"], name: "index_host_profiles_on_invitation_token", unique: true
    t.index ["slug"], name: "index_host_profiles_on_slug", unique: true
    t.index ["user_id"], name: "index_host_profiles_on_user_id", unique: true
  end

  create_table "host_totem_assignments", force: :cascade do |t|
    t.datetime "assigned_at"
    t.bigint "assigned_by_admin_id"
    t.datetime "created_at", null: false
    t.bigint "host_user_id", null: false
    t.string "role", default: "host", null: false
    t.bigint "totem_id", null: false
    t.datetime "updated_at", null: false
    t.index ["host_user_id", "totem_id"], name: "index_host_totem_assignments_on_host_user_id_and_totem_id", unique: true
    t.index ["host_user_id"], name: "index_host_totem_assignments_on_host_user_id"
    t.index ["totem_id"], name: "index_host_totem_assignments_on_totem_id"
  end

  create_table "notification_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.string "notification_subtype"
    t.string "notification_type", null: false
    t.datetime "opened_at"
    t.datetime "sent_at"
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_id"], name: "index_notification_deliveries_on_event_id"
    t.index ["user_id", "event_id", "notification_type"], name: "idx_on_user_id_event_id_notification_type_be0601ef91"
    t.index ["user_id"], name: "index_notification_deliveries_on_user_id"
  end

  create_table "scout_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "requested_by_id", null: false
    t.string "status", default: "pending", null: false
    t.bigint "totem_id", null: false
    t.datetime "updated_at", null: false
    t.index ["requested_by_id"], name: "index_scout_runs_on_requested_by_id"
    t.index ["totem_id"], name: "index_scout_runs_on_totem_id"
  end

  create_table "scouted_event_candidates", force: :cascade do |t|
    t.bigint "bulletin_post_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "event_date"
    t.bigint "event_id"
    t.string "event_time"
    t.boolean "ignored", default: false, null: false
    t.string "location"
    t.string "organizer"
    t.bigint "scout_run_id", null: false
    t.string "source_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["bulletin_post_id"], name: "index_scouted_event_candidates_on_bulletin_post_id"
    t.index ["event_id"], name: "index_scouted_event_candidates_on_event_id"
    t.index ["scout_run_id"], name: "index_scouted_event_candidates_on_scout_run_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "totem_favorites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "notify_new_event", default: true, null: false
    t.boolean "notify_reminder", default: true, null: false
    t.bigint "totem_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["totem_id"], name: "index_totem_favorites_on_totem_id"
    t.index ["user_id", "totem_id"], name: "index_totem_favorites_on_user_id_and_totem_id", unique: true
    t.index ["user_id"], name: "index_totem_favorites_on_user_id"
  end

  create_table "totems", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.integer "bulletin_board_scan_count", default: 0, null: false
    t.string "character_description", limit: 140
    t.string "city_slug", default: "stpete", null: false
    t.datetime "created_at", null: false
    t.string "location"
    t.string "name", null: false
    t.string "neighborhood"
    t.string "qr_url"
    t.string "slug", null: false
    t.string "sublocation"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_totems_on_active"
    t.index ["city_slug"], name: "index_totems_on_city_slug"
    t.index ["slug"], name: "index_totems_on_slug", unique: true
  end

  create_table "user_host_first_seens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "first_seen_at", null: false
    t.bigint "host_user_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "host_user_id"], name: "index_user_host_first_seens_on_user_id_and_host_user_id", unique: true
    t.index ["user_id"], name: "index_user_host_first_seens_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "auth_method", default: "email", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "google_uid"
    t.boolean "is_admin", default: false, null: false
    t.boolean "is_host", default: false, null: false
    t.string "magic_link_token"
    t.datetime "magic_link_token_expires_at"
    t.string "name"
    t.jsonb "notification_prefs", default: {"all"=>true, "reminder"=>true, "new_event"=>true}, null: false
    t.string "password_digest"
    t.string "push_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true
    t.index ["magic_link_token"], name: "index_users_on_magic_link_token", unique: true
  end

  add_foreign_key "anonymous_check_in_counts", "events"
  add_foreign_key "bulletin_posts", "totems"
  add_foreign_key "check_ins", "events"
  add_foreign_key "check_ins", "users"
  add_foreign_key "empty_totem_email_captures", "totems"
  add_foreign_key "events", "totems"
  add_foreign_key "events", "users", column: "host_user_id"
  add_foreign_key "host_follows", "users"
  add_foreign_key "host_follows", "users", column: "host_user_id"
  add_foreign_key "host_profiles", "users"
  add_foreign_key "host_totem_assignments", "totems"
  add_foreign_key "host_totem_assignments", "users", column: "assigned_by_admin_id"
  add_foreign_key "host_totem_assignments", "users", column: "host_user_id"
  add_foreign_key "notification_deliveries", "events"
  add_foreign_key "notification_deliveries", "users"
  add_foreign_key "scout_runs", "totems"
  add_foreign_key "scout_runs", "users", column: "requested_by_id"
  add_foreign_key "scouted_event_candidates", "bulletin_posts"
  add_foreign_key "scouted_event_candidates", "events"
  add_foreign_key "scouted_event_candidates", "scout_runs"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "totem_favorites", "totems"
  add_foreign_key "totem_favorites", "users"
  add_foreign_key "user_host_first_seens", "users"
  add_foreign_key "user_host_first_seens", "users", column: "host_user_id"
end
