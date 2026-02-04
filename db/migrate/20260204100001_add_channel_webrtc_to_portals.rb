class AddChannelWebrtcToPortals < ActiveRecord::Migration[7.0]
  def change
    add_column :portals, :channel_webrtc_id, :bigint
    add_index :portals, :channel_webrtc_id
  end
end
