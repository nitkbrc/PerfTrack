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

ActiveRecord::Schema[8.1].define(version: 2026_07_18_131153) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "achievement_requests", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "points_awarded"
    t.string "status", default: "submitted", null: false
    t.bigint "student_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_achievement_requests_on_category_id"
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
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "points"
    t.bigint "sub_division_id", null: false
    t.datetime "updated_at", null: false
    t.index ["sub_division_id"], name: "index_categories_on_sub_division_id"
  end

  create_table "departments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "divisions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dean_user_id", null: false
    t.string "div_type", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["dean_user_id"], name: "index_divisions_on_dean_user_id", unique: true
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
    t.string "to_status"
    t.datetime "updated_at", null: false
    t.index ["achievement_request_id"], name: "index_req_histories_on_achievement_request_id"
    t.index ["actor_id"], name: "index_req_histories_on_actor_id"
    t.index ["reason_template_id"], name: "index_req_histories_on_reason_template_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "score_scale_k", default: 50, null: false
    t.datetime "updated_at", null: false
  end

  create_table "students", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "department_id", null: false
    t.string "section"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "usn", null: false
    t.index ["department_id"], name: "index_students_on_department_id"
    t.index ["user_id"], name: "index_students_on_user_id"
    t.index ["usn"], name: "index_students_on_usn", unique: true
  end

  create_table "sub_divisions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "division_id", null: false
    t.string "name"
    t.bigint "supervisor_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["division_id"], name: "index_sub_divisions_on_division_id"
    t.index ["supervisor_user_id"], name: "index_sub_divisions_on_supervisor_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.boolean "password_change_required", default: false, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "student", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "achievement_requests", "categories"
  add_foreign_key "achievement_requests", "students"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "categories", "sub_divisions"
  add_foreign_key "divisions", "users", column: "dean_user_id"
  add_foreign_key "req_histories", "achievement_requests"
  add_foreign_key "req_histories", "reason_templates"
  add_foreign_key "req_histories", "users", column: "actor_id"
  add_foreign_key "students", "departments"
  add_foreign_key "students", "users"
  add_foreign_key "sub_divisions", "divisions"
  add_foreign_key "sub_divisions", "users", column: "supervisor_user_id"
end
