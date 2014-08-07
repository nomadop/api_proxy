# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140807060322) do

  create_table "directions", force: true do |t|
    t.string   "origin"
    t.string   "destination"
    t.string   "status",      default: "New"
    t.text     "options"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "routes", force: true do |t|
    t.integer  "direction_id"
    t.string   "origin"
    t.string   "destination"
    t.text     "path"
    t.text     "markers"
    t.string   "map_uid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "steps", force: true do |t|
    t.integer  "route_id"
    t.integer  "step_number"
    t.integer  "distance"
    t.integer  "duration"
    t.string   "start_location"
    t.string   "end_location"
    t.text     "path"
    t.text     "transit_details"
    t.text     "html_instructions"
    t.string   "travel_mode"
    t.string   "map_uid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
