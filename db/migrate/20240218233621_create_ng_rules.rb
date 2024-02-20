# frozen_string_literal: true

class CreateNgRules < ActiveRecord::Migration[7.1]
  def change
    create_table :ng_rules do |t|
      t.string :title, null: false, default: ''
      t.boolean :available, null: false, default: true
      t.string :account_domain, null: false, default: ''
      t.string :account_username, null: false, default: ''
      t.string :account_display_name, null: false, default: ''
      t.string :account_note, null: false, default: ''
      t.string :account_field_name, null: false, default: ''
      t.string :account_field_value, null: false, default: ''
      t.integer :account_avatar_state, null: false, default: 0
      t.integer :account_header_state, null: false, default: 0
      t.boolean :account_include_local, null: false, default: true
      t.string :status_spoiler_text, null: false, default: ''
      t.string :status_text, null: false, default: ''
      t.string :status_tag, null: false, default: ''
      t.string :status_visibility, null: false, default: [], array: true
      t.string :status_searchability, null: false, default: [], array: true
      t.integer :status_media_state, null: false, default: 0
      t.integer :status_sensitive_state, null: false, default: 0
      t.integer :status_cw_state, null: false, default: 0
      t.integer :status_poll_state, null: false, default: 0
      t.integer :status_quote_state, null: false, default: 0
      t.integer :status_reply_state, null: false, default: 0
      t.integer :status_media_threshold, null: false, default: -1
      t.integer :status_poll_threshold, null: false, default: -1
      t.integer :status_mention_threshold, null: false, default: -1
      t.boolean :status_mention_threshold_stranger_only, null: false, default: true
      t.integer :status_reference_threshold, null: false, default: -1
      t.string :reaction_type, null: false, default: [], array: true
      t.boolean :reaction_allow_follower, null: false, default: true
      t.string :emoji_reaction_name, null: false, default: ''
      t.string :emoji_reaction_origin_domain, null: false, default: ''
      t.integer :rule_violation_threshold_per_account, null: false, default: 1
      t.integer :account_action, null: false, default: 0
      t.integer :status_action, null: false, default: 0
      t.integer :reaction_action, null: false, default: 0
      t.datetime :expires_at

      t.timestamps
    end

    create_table :ng_rule_histories do |t|
      t.belongs_to :ng_rule, null: false, foreign_key: { on_cascade: :delete }
      t.belongs_to :account, null: false, foreign_key: { on_cascade: :delete }
      t.string :text
      t.string :uri, index: true
      t.string :reason, null: false
      t.boolean :skip, null: false, default: false
      t.integer :skip_count

      t.timestamps
    end
  end
end
