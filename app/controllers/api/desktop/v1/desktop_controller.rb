# API for Hackatime Desktop. Pairing is unauthenticated (it carries a PKCE
# verifier for a grant the signed-in user approved in the browser); every
# other action authenticates the device by its bearer token.
class Api::Desktop::V1::DesktopController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  ATTEST_CHALLENGE_MAX_AGE = 5 # minutes
  FRAME_MAX_BYTES = 2.megabytes

  before_action :authenticate_device!, except: :pair
  rate_limit to: 10, within: 10.minutes, only: :pair, by: -> { client_ip }
  rate_limit to: 30, within: 1.minute, only: :blocks, by: -> { @device&.id || client_ip }
  # Shipping does real work per request (decrypting frames, fingerprinting
  # snapshots), so it is paced per device well above what an honest ship needs.
  rate_limit to: 20, within: 10.minutes, only: :create_ship, by: -> { @device.id }
  rate_limit to: 300, within: 10.minutes, only: :upload_frame, by: -> { @device.id }
  rate_limit to: 5, within: 10.minutes, only: :submit_ship, by: -> { @device.id }

  rescue_from ActiveRecord::RecordNotFound, with: -> { render json: { error: "Not found" }, status: :not_found }
  rescue_from ActionController::ParameterMissing, with: ->(e) { render json: { error: e.message }, status: :bad_request }

  # POST /api/desktop/v1/pair
  def pair
    pairing = DesktopPairing.consume!(code: params.require(:code), code_verifier: params.require(:code_verifier))
    return render json: { error: "Invalid, expired or already used pairing code" }, status: :unauthorized unless pairing
    return render json: { error: "Account cannot pair devices" }, status: :forbidden if pairing.user.api_access_restricted?

    device, token = DesktopDevice.build_with_token(
      user: pairing.user, name: params[:name].to_s.strip.presence&.first(100) || "Desktop",
      platform: params[:platform].to_s, app_version: params[:app_version].to_s.first(40),
      capture_consented_at: pairing.capture_consented_at
    )
    if device.save
      render json: { token:, device: device_json(device) }, status: :created
    else
      render json: { error: device.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  # GET /api/desktop/v1/me
  def me = render(json: { device: device_json(@device) })

  # DELETE /api/desktop/v1/me
  def unpair
    @device.revoke!
    head :no_content
  end

  # GET /api/desktop/v1/beacon
  # Server-paced timelapse: the beacon tells the client the second this
  # minute's frame is expected (credited within the timelapse window).
  def beacon
    beacon = EvidenceBeacon.current!
    second = Evidence::Crypto.timelapse_second(beacon.value, @device.uid)
    render json: beacon.as_public_json(@device.uid).merge(
      next_expected_at: Time.at(beacon.minute * 60 + second).utc.iso8601,
      timelapse_window_seconds: Evidence::Config.current[:timelapse_window_seconds],
      head_seq: @device.last_seq, head_hash: @device.head_hash
    )
  end

  # POST /api/desktop/v1/key
  # Enrols the device's hardware key once. App Attest is verified when
  # present; otherwise the key is recorded at the tier the client claims,
  # which earns no confidence because nothing verified it.
  def key
    return render json: { error: "A key is already enrolled; pair again to change it" }, status: :conflict if @device.public_key.present?

    public_key = params.require(:public_key).to_s
    pkey = OpenSSL::PKey.read(Base64.strict_decode64(public_key))
    return render json: { error: "Key must be ECDSA P-256" }, status: :unprocessable_entity unless pkey.is_a?(OpenSSL::PKey::EC) && pkey.group.curve_name == "prime256v1"

    tier = params[:key_tier].to_s.presence_in(%w[software secure_enclave tpm]) || "software"
    attributes = { public_key: Base64.strict_encode64(pkey.public_to_der), key_tier: tier,
                   hardware_id_digest: DesktopDevice.hardware_digest(params[:hardware_id]) }
    if (attest = params[:app_attest]).present?
      beacon = EvidenceBeacon.find_by(minute: attest[:beacon_minute])
      if beacon.nil? || EvidenceBeacon.current_minute - beacon.minute > ATTEST_CHALLENGE_MAX_AGE
        return render json: { error: "Attestation challenge is stale" }, status: :unprocessable_entity
      end

      client_data = "hkt-attest-v1|#{@device.uid}|#{beacon.value}|#{attributes[:public_key]}"
      begin
        Evidence::AppAttest.verify!(attestation_b64: attest[:attestation].to_s, key_id_b64: attest[:key_id].to_s, client_data:)
        attributes.merge!(key_tier: "app_attest", app_attest_key_id: attest[:key_id].to_s, attested_at: Time.current)
      rescue Evidence::AppAttest::Invalid => e
        attributes[:attestation_error] = e.message
      end
    end
    error = attributes.delete(:attestation_error)
    DesktopDevice.transaction do
      # Pairing the same Mac again from the same account replaces the old pairing.
      if (digest = attributes[:hardware_id_digest])
        previous = DesktopDevice.active.where(hardware_id_digest: digest).where.not(id: @device.id).lock.first
        previous.revoke! if previous&.user_id == @device.user_id
      end
      @device.update!(attributes)
    end
    render json: { device: device_json(@device), attestation_error: error }
  rescue ArgumentError, OpenSSL::PKey::PKeyError
    render json: { error: "public_key must be a base64 DER SubjectPublicKeyInfo" }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    render json: { error: "This machine is already paired with another account" }, status: :conflict
  end

  # POST /api/desktop/v1/blocks
  def blocks
    blocks = params.require(:blocks)
    return render json: { error: "blocks must be an array" }, status: :bad_request unless blocks.is_a?(Array)

    result = Evidence::BlockIngest.call(device: @device, blocks: blocks.map { |block| block.permit!.to_h }, request_context:)
    status = result.error ? :conflict : :created
    render json: { accepted: result.accepted, head_seq: result.head_seq, head_hash: result.head_hash, error: result.error }, status:
  rescue Evidence::BlockIngest::Rejected => e
    render json: { error: { code: e.code, message: e.message } }, status: :bad_request
  end

  # POST /api/desktop/v1/ships
  def create_ship
    ship = @device.evidence_ships.draft.find_or_initialize_by(from_seq: params.require(:from_seq), to_seq: params.require(:to_seq))
    ship.assign_attributes(user: @device.user, project: params.require(:project).to_s)
    return render json: { error: ship.errors.full_messages.to_sentence }, status: :unprocessable_entity unless ship.save

    ship.reveal!
    render json: ship_json(ship).merge(revealed: revealed_secrets(ship)), status: :created
  end

  # GET /api/desktop/v1/ships/:id
  def show_ship = render(json: ship_json(find_ship))

  # POST /api/desktop/v1/ships/:id/frames
  # Uploads one encrypted frame and its segment key. An unredacted frame
  # must match a hash committed in the shipped range. A redacted copy keeps
  # the committed hash it replaces, is marked redacted for reviewers, lists
  # the redacted regions, and must match the committed perceptual hash
  # outside them.
  def upload_frame
    ship = find_ship
    return render json: { error: "Frames can only be added to drafts" }, status: :conflict unless ship.draft?

    frame_hash = params.require(:hash).to_s
    block = ship.blocks.where("payload -> 'frames' @> ?", [ { hash: frame_hash } ].to_json).first
    committed = block&.frames&.find { |frame| frame["hash"] == frame_hash }&.merge("seq" => block.seq, "captured_at_ms" => block.captured_at_ms)
    return render json: { error: "Frame hash is not committed in this range" }, status: :unprocessable_entity unless committed

    ciphertext = Base64.strict_decode64(params.require(:ciphertext).to_s)
    key = Base64.strict_decode64(params.require(:segment_key).to_s)
    redacted = ActiveModel::Type::Boolean.new.cast(params[:redacted]) || false
    return render json: { error: "Frame is too large" }, status: :unprocessable_entity if ciphertext.bytesize > FRAME_MAX_BYTES
    if !redacted && Evidence::Crypto.sha256_hex(ciphertext) != frame_hash
      return render json: { error: "Ciphertext does not match its committed hash" }, status: :unprocessable_entity
    end
    plaintext = Evidence::Crypto.aead_open(key, ciphertext)
    redactions = redacted ? Array(params[:redactions]).map { |region| region.permit(:x, :y, :w, :h).to_h } : []
    if redacted
      begin
        Evidence::RedactionCheck.check!(image_data: plaintext, committed_phash: committed["phash"], regions: redactions)
      rescue Evidence::RedactionCheck::Invalid => e
        return render json: { error: e.message }, status: :unprocessable_entity
      end
    end

    frame = ship.evidence_frames.find_or_initialize_by(frame_hash:)
    frame.assign_attributes(
      seq: committed["seq"], captured_at_ms: committed["captured_at_ms"], kind: "timelapse",
      trigger: committed["trigger"], required: ship.required_frames.include?(frame_hash), redacted:, redactions:,
      segment_key: Base64.strict_encode64(key)
    )
    frame.ciphertext.attach(io: StringIO.new(ciphertext), filename: "#{frame_hash}.bin", content_type: "application/octet-stream")
    frame.save!
    render json: { frame_hash:, required: frame.required, missing_required: ship.missing_required_frames.length }, status: :created
  rescue ArgumentError, OpenSSL::Cipher::CipherError
    render json: { error: "Frame does not decrypt with the given key" }, status: :unprocessable_entity
  end

  # POST /api/desktop/v1/ships/:id/submit
  def submit_ship
    ship = Evidence::ShipSubmission.call(ship: find_ship, final_files: params.require(:final_files).map { |file| file.permit(:path, :content).to_h },
      snapshots: Array(params[:snapshots]).map { |snapshot| snapshot.permit(:seq, :salt, entries: %i[path content leaf]).to_h })
    render json: ship_json(ship)
  rescue Evidence::ShipSubmission::Invalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def authenticate_device!
    @device = authenticate_with_http_token { |token, _| DesktopDevice.authenticate(token) }
    return render json: { error: "Unauthorized" }, status: :unauthorized unless @device
    render json: { error: "Account restricted" }, status: :forbidden if @device.user.api_access_restricted?
  end

  def find_ship = @device.evidence_ships.find(params[:id])

  def client_ip = request.headers["CF-Connecting-IP"] || request.remote_ip

  def request_context
    { ip_address: client_ip, ja4: request.headers["CF-JA4"], user_agent: request.user_agent }
  end

  def device_json(device)
    device.slice(:uid, :name, :platform, :key_tier, :last_seq, :head_hash).merge(user: { id: device.user_id, username: device.user.username })
  end

  # Flags, confidence and scoring internals are for reviewers only.
  def ship_json(ship)
    ship.slice(:id, :project, :from_seq, :to_seq, :status, :required_frames, :spot_check_seqs, :claimed_seconds,
      :credited_seconds, :approved_seconds, :reviewer_question)
      .merge(missing_required_frames: ship.missing_required_frames)
  end

  # Reveals this device's secrets for the beacons of a closed range so the
  # client can check them against the commitments it was given.
  def revealed_secrets(ship)
    ship.blocks.includes(:evidence_beacon).map(&:evidence_beacon).uniq.map do |beacon|
      { minute: beacon.minute, secret: beacon.device_secret(@device.uid), commitment: beacon.device_commitment(@device.uid) }
    end
  end
end
