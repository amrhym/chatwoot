class WebrtcRoomsController < ActionController::Base
  layout false

  before_action :set_channel
  before_action :set_livekit_vars, only: [:join]

  def show; end

  def join
    contact = find_or_create_contact
    conversation = create_conversation(contact)
    room_name = "webrtc-#{conversation.display_id}-#{SecureRandom.hex(4)}"
    token = generate_livekit_token(room_name, params[:name] || 'Visitor')
    create_livekit_room(room_name)
    send_call_message(conversation, room_name)

    render json: {
      token: token,
      room_name: room_name,
      conversation_id: conversation.display_id,
      url: @livekit_url
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def leave
    if params[:room_name].present?
      delete_livekit_room(params[:room_name])
      update_call_status(params[:conversation_id])
    end
    render json: { success: true }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_channel
    @channel = Channel::Webrtc.find_by!(website_token: params[:token])
    @account = @channel.account
  rescue ActiveRecord::RecordNotFound
    render plain: 'Invalid token', status: :not_found
  end

  def set_livekit_vars
    config = @channel.provider_config.with_indifferent_access
    @livekit_url = config[:livekit_url] || ENV.fetch('LIVEKIT_URL', 'ws://localhost:7880')
    @livekit_api_key = config[:livekit_api_key] || ENV.fetch('LIVEKIT_API_KEY', '')
    @livekit_api_secret = config[:livekit_api_secret] || ENV.fetch('LIVEKIT_API_SECRET', '')
  end

  def find_or_create_contact
    inbox = @channel.inbox
    contact_inbox = inbox.contact_inboxes.find_by(source_id: params[:email]) if params[:email].present?
    return contact_inbox.contact if contact_inbox

    contact = @account.contacts.create!(
      name: params[:name] || 'Visitor',
      email: params[:email],
      phone_number: params[:phone]
    )
    inbox.contact_inboxes.create!(contact: contact, source_id: params[:email] || SecureRandom.hex(8))
    contact
  end

  def create_conversation(contact)
    contact_inbox = @channel.inbox.contact_inboxes.find_by(contact: contact)
    @account.conversations.create!(
      inbox: @channel.inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      additional_attributes: { type: 'webrtc_voice_call' }
    )
  end

  def generate_livekit_token(room_name, identity)
    now = Time.now.to_i
    payload = {
      iss: @livekit_api_key,
      sub: identity,
      iat: now,
      nbf: now,
      exp: now + 86_400,
      video: {
        room: room_name,
        roomJoin: true,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true
      }
    }
    JWT.encode(payload, @livekit_api_secret, 'HS256', { typ: 'JWT' })
  end

  def create_livekit_room(room_name)
    uri = URI.parse(@livekit_url.sub('ws://', 'http://').sub('wss://', 'https://'))
    api_url = "#{uri.scheme}://#{uri.host}:#{uri.port}/twirp/livekit.RoomService/CreateRoom"

    token = generate_admin_token
    body = { name: room_name, empty_timeout: 300 }.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    request = Net::HTTP::Post.new(api_url)
    request['Authorization'] = "Bearer #{token}"
    request['Content-Type'] = 'application/json'
    request.body = body
    http.request(request)
  end

  def delete_livekit_room(room_name)
    uri = URI.parse(@livekit_url.sub('ws://', 'http://').sub('wss://', 'https://'))
    api_url = "#{uri.scheme}://#{uri.host}:#{uri.port}/twirp/livekit.RoomService/DeleteRoom"

    set_livekit_vars
    token = generate_admin_token
    body = { room: room_name }.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    request = Net::HTTP::Post.new(api_url)
    request['Authorization'] = "Bearer #{token}"
    request['Content-Type'] = 'application/json'
    request.body = body
    http.request(request)
  end

  def generate_admin_token
    now = Time.now.to_i
    payload = {
      iss: @livekit_api_key,
      sub: 'admin',
      iat: now,
      nbf: now,
      exp: now + 600,
      video: { roomCreate: true, roomList: true, roomAdmin: true }
    }
    JWT.encode(payload, @livekit_api_secret, 'HS256', { typ: 'JWT' })
  end

  def send_call_message(conversation, room_name)
    conversation.messages.create!(
      message_type: :incoming,
      content: "Voice call started",
      content_type: 'livekit_webrtc',
      content_attributes: { room_name: room_name, status: 'in_progress' },
      account: @account,
      inbox: @channel.inbox,
      sender: conversation.contact
    )
  end

  def update_call_status(conversation_display_id)
    return unless conversation_display_id.present?

    conversation = @account.conversations.find_by(display_id: conversation_display_id)
    return unless conversation

    message = conversation.messages.where(content_type: 'livekit_webrtc').last
    return unless message

    message.update!(content_attributes: message.content_attributes.merge('status' => 'ended'))
  end
end
