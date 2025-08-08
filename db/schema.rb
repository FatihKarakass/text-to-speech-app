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

ActiveRecord::Schema[8.0].define(version: 2025_08_08_114804) do
  create_table "speech_requests", force: :cascade do |t|
    t.text "text", null: false
    t.string "text_hash", null: false
    t.string "status", default: "pending", null: false
    t.json "provider_results", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_speech_requests_on_created_at"
    t.index ["status"], name: "index_speech_requests_on_status"
    t.index ["text_hash"], name: "index_speech_requests_on_text_hash", unique: true
  end
end
