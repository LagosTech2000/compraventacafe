module FingerprintBridge
  # Every fingerprint template (Fernando, 2026-11-14): the bridge keeps them
  # in the reader's memory to tell who put a finger (1:N), by their ids.
  class TemplatesController < BaseController
    before_action :authenticate_station!

    def show
      @station.seen!
      render json: { templates: Fingerprint.pluck(:id, :template_ciphertext).map { |id, ciphertext| { id:, template: Fingerprint.cipher.decrypt_and_verify(ciphertext) } } }
    end
  end
end
