module Api
  module V1
    class PrioritizationsController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false

      def analyze
        symptoms = params[:symptoms]

        if symptoms.blank? || !symptoms.is_a?(Array)
          return render json: { error: "Please provide an array of symptoms" }, status: :bad_request
        end

        result = AiPrioritizationService.new(symptoms).call

        render json: result, status: :ok
      end
    end
  end
end
# Mutex lock for queue updates
