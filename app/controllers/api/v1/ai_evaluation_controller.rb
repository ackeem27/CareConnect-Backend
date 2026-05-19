module Api
  module V1
    # AI Evaluation Controller
    # Provides endpoints to test and demonstrate AI triage accuracy.
    # Used for admin transparency and presentation purposes.
    class AiEvaluationController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false
      skip_before_action :authorize_request, raise: false

      # GET /api/v1/ai_evaluation/test_cases
      # Returns predefined clinical test cases with expected outcomes
      # and runs them through the Gemini triage service live.
      def test_cases
        cases = build_test_cases

        results = cases.map do |tc|
          # Run through Gemini (real AI model)
          ai_result = GeminiTriageService.new(
            symptoms:           tc[:symptoms],
            severity:           tc[:severity],
            patient_age:        tc[:age],
            chronic_conditions: tc[:chronic_conditions] || [],
            previous_visits:    tc[:previous_visits] || 0
          ).call

          actual_level = ai_result[:priority_level]
          actual_score = ai_result[:priority_score]
          correct = actual_level == tc[:expected_level]

          {
            id:                  tc[:id],
            scenario:            tc[:scenario],
            symptoms:            tc[:symptoms],
            severity:            tc[:severity],
            age:                 tc[:age],
            chronic_conditions:  tc[:chronic_conditions],
            expected_level:      tc[:expected_level],
            actual_level:        actual_level,
            actual_score:        actual_score,
            correct:             correct,
            ai_reasoning:        ai_result[:reasoning],
            ai_model_used:       ai_result[:ai_model_used],
            detected_symptoms:   ai_result[:detected_symptoms],
            first_aid_advice:    ai_result[:first_aid_advice]
          }
        end

        total = results.size
        correct_count = results.count { |r| r[:correct] }
        accuracy = total > 0 ? ((correct_count.to_f / total) * 100).round(1) : 0

        render json: {
          total_cases:    total,
          correct:        correct_count,
          accuracy:       accuracy,
          ai_model:       results.first&.dig(:ai_model_used) || "unknown",
          evaluated_at:   Time.current.iso8601,
          results:        results
        }, status: :ok
      end

      # POST /api/v1/ai_evaluation/single
      # Run a single custom test case through the AI for live demo
      def single
        symptoms = params[:symptoms]
        severity = params[:severity] || 'low'
        age      = params[:age]&.to_i
        chronic  = Array(params[:chronic_conditions])

        ai_result = GeminiTriageService.new(
          symptoms:           symptoms,
          severity:           severity,
          patient_age:        age,
          chronic_conditions: chronic,
          previous_visits:    0
        ).call

        render json: {
          input: {
            symptoms: symptoms,
            severity: severity,
            age: age,
            chronic_conditions: chronic
          },
          output: ai_result,
          evaluated_at: Time.current.iso8601
        }, status: :ok
      end

      private

      def build_test_cases
        [
          {
            id: 1,
            scenario: "Elderly patient with chest pain",
            symptoms: "chest pain, difficulty breathing, dizziness",
            severity: "severe",
            age: 72,
            chronic_conditions: ["hypertension"],
            previous_visits: 3,
            expected_level: "HIGH"
          },
          {
            id: 2,
            scenario: "Young adult with common cold",
            symptoms: "cough, runny nose, mild sore throat",
            severity: "low",
            age: 22,
            chronic_conditions: [],
            previous_visits: 0,
            expected_level: "LOW"
          },
          {
            id: 3,
            scenario: "Child with high fever",
            symptoms: "high fever, vomiting, abdominal pain",
            severity: "moderate",
            age: 4,
            chronic_conditions: [],
            previous_visits: 1,
            expected_level: "MEDIUM"
          },
          {
            id: 4,
            scenario: "Diabetic with vision loss",
            symptoms: "loss of vision, severe headache, dizziness",
            severity: "severe",
            age: 58,
            chronic_conditions: ["diabetes", "hypertension"],
            previous_visits: 5,
            expected_level: "HIGH"
          },
          {
            id: 5,
            scenario: "Teenager with mild headache",
            symptoms: "headache, fatigue",
            severity: "low",
            age: 16,
            chronic_conditions: [],
            previous_visits: 0,
            expected_level: "LOW"
          },
          {
            id: 6,
            scenario: "Severe allergic reaction",
            symptoms: "difficulty breathing, allergic reaction, swelling",
            severity: "severe",
            age: 35,
            chronic_conditions: [],
            previous_visits: 0,
            expected_level: "HIGH"
          },
          {
            id: 7,
            scenario: "Asthma patient with breathing difficulty",
            symptoms: "asthma, difficulty breathing, wheezing",
            severity: "moderate",
            age: 28,
            chronic_conditions: ["asthma"],
            previous_visits: 4,
            expected_level: "HIGH"
          },
          {
            id: 8,
            scenario: "Routine follow-up with mild symptoms",
            symptoms: "mild rash, fatigue, muscle ache",
            severity: "low",
            age: 40,
            chronic_conditions: [],
            previous_visits: 2,
            expected_level: "LOW"
          },
          {
            id: 9,
            scenario: "Suspected stroke in elderly",
            symptoms: "stroke, confusion, paralysis, slurred speech",
            severity: "severe",
            age: 68,
            chronic_conditions: ["hypertension"],
            previous_visits: 1,
            expected_level: "HIGH"
          },
          {
            id: 10,
            scenario: "Moderate abdominal pain",
            symptoms: "abdominal pain, nausea, diarrhea",
            severity: "moderate",
            age: 33,
            chronic_conditions: [],
            previous_visits: 0,
            expected_level: "MEDIUM"
          },
          {
            id: 11,
            scenario: "Pregnant woman with severe bleeding",
            symptoms: "severe bleeding, abdominal pain, dizziness",
            severity: "severe",
            age: 29,
            chronic_conditions: [],
            previous_visits: 2,
            expected_level: "HIGH"
          },
          {
            id: 12,
            scenario: "Minor sprain from sports",
            symptoms: "sprain, bruise, muscle ache",
            severity: "low",
            age: 19,
            chronic_conditions: [],
            previous_visits: 0,
            expected_level: "LOW"
          },
          {
            id: 13,
            scenario: "HIV patient with persistent fever",
            symptoms: "fever, fatigue, cough, weight loss",
            severity: "moderate",
            age: 42,
            chronic_conditions: ["hiv"],
            previous_visits: 6,
            expected_level: "MEDIUM"
          },
          {
            id: 14,
            scenario: "Seizure episode",
            symptoms: "seizure, confusion, unresponsive",
            severity: "severe",
            age: 55,
            chronic_conditions: ["epilepsy"],
            previous_visits: 3,
            expected_level: "HIGH"
          },
          {
            id: 15,
            scenario: "Toothache with mild earache",
            symptoms: "toothache, earache, mild pain",
            severity: "low",
            age: 30,
            chronic_conditions: [],
            previous_visits: 0,
            expected_level: "LOW"
          }
        ]
      end
    end
  end
end
