class CreateChannelWebrtc < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_webrtc do |t|
      t.string :website_token, null: false
      t.string :hmac_token
      t.jsonb :provider_config, default: {}
      t.string :widget_color, default: '#1f93ff'
      t.string :welcome_title
      t.string :welcome_tagline
      t.string :website_url
      t.integer :account_id, null: false

      t.timestamps
    end

    add_index :channel_webrtc, :website_token, unique: true
    add_index :channel_webrtc, :hmac_token, unique: true
    add_index :channel_webrtc, :account_id
  end
end
