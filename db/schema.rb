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

ActiveRecord::Schema[8.1].define(version: 2026_08_06_100100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "achievement_requests", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.bigint "current_review_role_id"
    t.text "description"
    t.integer "points_awarded"
    t.string "status", default: "in_review", null: false
    t.bigint "student_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_achievement_requests_on_category_id"
    t.index ["current_review_role_id"], name: "index_achievement_requests_on_current_review_role_id"
    t.index ["student_id"], name: "index_achievement_requests_on_student_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "points"
    t.bigint "sub_division_id", null: false
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_categories_on_archived_at"
    t.index ["sub_division_id"], name: "index_categories_on_sub_division_id"
  end

  create_table "departments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "divisions", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "div_type", null: false
    t.bigint "hierarchy_id"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_divisions_on_archived_at"
    t.index ["hierarchy_id"], name: "index_divisions_on_hierarchy_id"
  end

  create_table "hierarchies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_default", default: false, null: false
    t.string "name", null: false
    t.string "scope", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_hierarchies_on_name", unique: true
    t.index ["scope", "is_default"], name: "index_hierarchies_on_scope_and_is_default"
  end

  create_table "hierarchy_roles", force: :cascade do |t|
    t.boolean "can_raise_on_behalf", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "hierarchy_id", null: false
    t.integer "position", null: false
    t.bigint "review_role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["hierarchy_id", "position"], name: "index_hierarchy_roles_on_hierarchy_id_and_position", unique: true
    t.index ["hierarchy_id", "review_role_id"], name: "index_hierarchy_roles_on_hierarchy_id_and_review_role_id", unique: true
    t.index ["hierarchy_id"], name: "index_hierarchy_roles_on_hierarchy_id"
    t.index ["review_role_id"], name: "index_hierarchy_roles_on_review_role_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "achievement_request_id", null: false
    t.datetime "created_at", null: false
    t.text "message", null: false
    t.boolean "read", default: false, null: false
    t.bigint "recipient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_request_id"], name: "index_notifications_on_achievement_request_id"
    t.index ["recipient_id", "read"], name: "index_notifications_on_recipient_id_and_read"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: false, null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["role", "action"], name: "index_permissions_on_role_and_action", unique: true
  end

  create_table "reason_templates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "message_text"
    t.datetime "updated_at", null: false
  end

  create_table "req_histories", force: :cascade do |t|
    t.bigint "achievement_request_id", null: false
    t.string "action"
    t.bigint "actor_id", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.string "from_status"
    t.bigint "reason_template_id"
    t.bigint "request_version_id", null: false
    t.string "to_status"
    t.datetime "updated_at", null: false
    t.index ["achievement_request_id"], name: "index_req_histories_on_achievement_request_id"
    t.index ["actor_id"], name: "index_req_histories_on_actor_id"
    t.index ["reason_template_id"], name: "index_req_histories_on_reason_template_id"
    t.index ["request_version_id"], name: "index_req_histories_on_request_version_id"
  end

  create_table "request_versions", force: :cascade do |t|
    t.bigint "achievement_request_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "version_number", null: false
    t.index ["achievement_request_id", "version_number"], name: "index_request_versions_on_request_and_number", unique: true
    t.index ["achievement_request_id"], name: "index_request_versions_on_achievement_request_id"
    t.index ["category_id"], name: "index_request_versions_on_category_id"
  end

  create_table "review_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "raiseable_on_behalf_eligible", default: false, null: false
    t.string "scope", null: false
    t.boolean "system_role", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_review_roles_on_name", unique: true
  end

  create_table "role_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "division_id"
    t.bigint "review_role_id", null: false
    t.bigint "sub_division_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["division_id"], name: "index_role_assignments_on_division_id"
    t.index ["review_role_id", "division_id"], name: "index_role_assignments_on_role_and_division", unique: true, where: "(division_id IS NOT NULL)"
    t.index ["review_role_id", "sub_division_id"], name: "index_role_assignments_on_role_and_sub_division", unique: true, where: "(sub_division_id IS NOT NULL)"
    t.index ["review_role_id"], name: "index_role_assignments_on_review_role_id"
    t.index ["sub_division_id"], name: "index_role_assignments_on_sub_division_id"
    t.index ["user_id"], name: "index_role_assignments_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "score_scale_k", default: 50, null: false
    t.datetime "updated_at", null: false
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
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

  create_table "students", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "department_id", null: false
    t.integer "sem"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "usn", null: false
    t.index ["department_id"], name: "index_students_on_department_id"
    t.index ["user_id"], name: "index_students_on_user_id"
    t.index ["usn"], name: "index_students_on_usn", unique: true
  end

  create_table "sub_division_raiseable_overrides", force: :cascade do |t|
    t.boolean "can_raise_on_behalf", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "review_role_id", null: false
    t.bigint "sub_division_id", null: false
    t.datetime "updated_at", null: false
    t.index ["review_role_id"], name: "index_sub_division_raiseable_overrides_on_review_role_id"
    t.index ["sub_division_id", "review_role_id"], name: "index_sub_div_raiseable_overrides_on_sub_and_role", unique: true
    t.index ["sub_division_id"], name: "index_sub_division_raiseable_overrides_on_sub_division_id"
  end

  create_table "sub_divisions", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.bigint "division_id", null: false
    t.bigint "hierarchy_id"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_sub_divisions_on_archived_at"
    t.index ["division_id"], name: "index_sub_divisions_on_division_id"
    t.index ["hierarchy_id"], name: "index_sub_divisions_on_hierarchy_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "address", null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.boolean "password_change_required", default: false, null: false
    t.string "phone", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "student", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "achievement_requests", "categories"
  add_foreign_key "achievement_requests", "review_roles", column: "current_review_role_id"
  add_foreign_key "achievement_requests", "students"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "categories", "sub_divisions"
  add_foreign_key "divisions", "hierarchies"
  add_foreign_key "hierarchy_roles", "hierarchies"
  add_foreign_key "hierarchy_roles", "review_roles"
  add_foreign_key "notifications", "achievement_requests"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "req_histories", "achievement_requests"
  add_foreign_key "req_histories", "reason_templates"
  add_foreign_key "req_histories", "request_versions"
  add_foreign_key "req_histories", "users", column: "actor_id"
  add_foreign_key "request_versions", "achievement_requests"
  add_foreign_key "request_versions", "categories"
  add_foreign_key "role_assignments", "divisions"
  add_foreign_key "role_assignments", "review_roles"
  add_foreign_key "role_assignments", "sub_divisions"
  add_foreign_key "role_assignments", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "students", "departments"
  add_foreign_key "students", "users"
  add_foreign_key "sub_division_raiseable_overrides", "review_roles"
  add_foreign_key "sub_division_raiseable_overrides", "sub_divisions"
  add_foreign_key "sub_divisions", "divisions"
  add_foreign_key "sub_divisions", "hierarchies"
end
