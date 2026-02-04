# == Schema Information
#
# Table name: channel_webrtc
#
#  id              :bigint           not null, primary key
#  hmac_token      :string
#  provider_config :jsonb
#  website_token   :string           not null
#  website_url     :string
#  welcome_tagline :string
#  welcome_title   :string
#  widget_color    :string           default("#1f93ff")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :integer          not null
#
# Indexes
#
#  index_channel_webrtc_on_account_id     (account_id)
#  index_channel_webrtc_on_hmac_token     (hmac_token) UNIQUE
#  index_channel_webrtc_on_website_token  (website_token) UNIQUE
#
class Channel::Webrtc < ApplicationRecord
  include Channelable

  self.table_name = 'channel_webrtc'

  EDITABLE_ATTRS = [:website_url, :widget_color, :welcome_title, :welcome_tagline, { provider_config: {} }].freeze

  has_secure_token :website_token
  has_secure_token :hmac_token

  has_many :portals, foreign_key: 'channel_webrtc_id', dependent: :nullify, inverse_of: :channel_webrtc

  def name
    'WebRTC Voice'
  end

  def messaging_window_enabled?
    false
  end

  def webrtc_widget_script
    <<~SCRIPT
      <style>
        #webrtc-voice-widget-btn {
          position: fixed;
          bottom: 20px;
          right: 20px;
          z-index: 2147483000;
          width: 56px;
          height: 56px;
          border-radius: 50%;
          background-color: #{widget_color};
          border: none;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 4px 12px rgba(0,0,0,0.15);
          transition: transform 0.2s ease;
        }
        #webrtc-voice-widget-btn:hover { transform: scale(1.1); }
        #webrtc-voice-widget-btn svg { width: 28px; height: 28px; fill: #fff; }
        #webrtc-voice-widget-iframe {
          position: fixed;
          bottom: 90px;
          right: 20px;
          z-index: 2147483001;
          width: 380px;
          height: 520px;
          border: none;
          border-radius: 16px;
          box-shadow: 0 8px 30px rgba(0,0,0,0.12);
          display: none;
          background: #fff;
        }
      </style>
      <button id="webrtc-voice-widget-btn" onclick="document.getElementById('webrtc-voice-widget-iframe').style.display = document.getElementById('webrtc-voice-widget-iframe').style.display === 'none' ? 'block' : 'none'">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M6.62 10.79a15.05 15.05 0 006.59 6.59l2.2-2.2a1 1 0 011.01-.24 11.36 11.36 0 003.58.57 1 1 0 011 1V20a1 1 0 01-1 1A17 17 0 013 4a1 1 0 011-1h3.5a1 1 0 011 1 11.36 11.36 0 00.57 3.58 1 1 0 01-.25 1.01l-2.2 2.2z"/></svg>
      </button>
      <iframe id="webrtc-voice-widget-iframe" src="#{ENV.fetch('FRONTEND_URL', '')}/webrtc/room?token=#{website_token}" allow="microphone"></iframe>
    SCRIPT
  end

  def create_contact_inbox(additional_attributes = {})
    ::ContactInboxWithContactBuilder.new({
                                           inbox: inbox,
                                           contact_attributes: { additional_attributes: additional_attributes }
                                         }).perform
  end
end
