module Administration
  # Registering a person's fingerprint (Fernando, 2026-11-14): administrators
  # only, with the person's consent, at a PC whose browser is linked to a
  # reader. The bridge takes the finger three times (FingerprintEnrollment);
  # the waiting page (show, by the request's id) follows it live
  # (fingerprint_enroll_controller.js).
  class FingerprintsController < ApplicationController
    before_action :set_person

    def new
      authorize Fingerprint
      @station = linked_station
      @fingerprint = @person.fingerprints.build(finger: free_fingers.first)
    end

    def create
      authorize Fingerprint
      @station = linked_station
      finger = params.dig(:fingerprint, :finger).to_s
      @fingerprint = @person.fingerprints.build(finger:)
      @fingerprint.errors.add(:base, :no_station) unless @station
      @fingerprint.errors.add(:finger, :inclusion) unless free_fingers.include?(finger)
      @fingerprint.errors.add(:consented_at, :accepted) unless params.dig(:fingerprint, :consent) == "1"
      return render(:new, status: :unprocessable_content) if @fingerprint.errors.any?

      request_id = FingerprintEnrollment.start!(station: @station, person: @person, finger:, user: Current.user)
      redirect_to administration_person_fingerprint_path(@person, request_id, finger:)
    end

    # Waiting for the reader: the request's id is the page's.
    def show
      authorize Fingerprint
      @request_id = params[:id]
      @finger = Fingerprint.human_attribute_name("finger/#{params[:finger].presence_in(Fingerprint::FINGERS) || "right_index"}")
    end

    def destroy
      fingerprint = authorize @person.fingerprints.find(params[:id])
      fingerprint.destroy!
      redirect_to administration_person_path(@person), notice: t(".success", finger: fingerprint.human_finger), status: :see_other
    end

    private
      def set_person
        @person = Person.find(params[:person_id])
      end

      def linked_station
        FingerprintStation.active.find_by(id: cookies.signed[FingerprintStation::COOKIE])
      end

      def free_fingers = Fingerprint::FINGERS - @person.fingerprints.pluck(:finger)
  end
end
