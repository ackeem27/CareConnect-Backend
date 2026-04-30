require 'net/http'
require 'json'
require 'uri'

# GeminiTriageService
# Scope: AI-Assisted Symptom Triage for Out-Patient Department (OPD) Appointment Prioritisation
#
# Uses Google Gemini 1.5 Flash to classify a patient's urgency level based on:
#   - Reported symptoms (text, from patient self-booking OR receptionist-entered walk-in)
#   - Patient age and known chronic conditions (context analysis)
#   - Self-reported severity
#   - Number of recent visits
#
# Returns: priority_level, priority_score, reasoning, detected_symptoms, first_aid_advice
# Falls back to rule-based AiPrioritizationService if API key is absent or API call fails.
class GeminiTriageService
  GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent".freeze

  PRIORITY_SCORE_RANGES = {
    "HIGH"   => (80..100),
    "MEDIUM" => (50..79),
    "LOW"    => (10..49)
  }.freeze

  # @param symptoms [String, Array<String>] Reported symptoms text or keyword array
  # @param severity [String] 'low' | 'moderate' | 'severe'
  # @param patient_age [Integer, nil] Patient age in years (nil if unknown)
  # @param chronic_conditions [Array<String>] Known chronic conditions, e.g. ['hypertension', 'diabetes']
  # @param previous_visits [Integer] Number of recent OPD visits this patient has had
  def initialize(symptoms:, severity: 'low', patient_age: nil, chronic_conditions: [], previous_visits: 0)
    @symptoms           = symptoms
    @severity           = severity.to_s.downcase
    @patient_age        = patient_age&.to_i
    @chronic_conditions = Array(chronic_conditions).compact
    @previous_visits    = previous_visits.to_i
  end

  def call
    api_key = ENV['GEMINI_API_KEY']

    if api_key.nil? || api_key.strip.empty?
      Rails.logger.warn "[GeminiTriageService] GEMINI_API_KEY not set — using rule-based fallback"
      return fallback_result
    end

    begin
      raw_response = call_gemini_api(api_key)
      parse_gemini_response(raw_response)
    rescue => e
      Rails.logger.error "[GeminiTriageService] AI Error: #{e.message} — using fallback"
      fallback_result(error: e.message)
    end
  end

  private

  # ─── Gemini API Call ────────────────────────────────────────────────────────

  def call_gemini_api(api_key)
    uri = URI("#{GEMINI_API_URL}?key=#{api_key}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl     = true
    http.read_timeout = 12
    http.open_timeout = 6

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = build_request_body.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Gemini API returned HTTP #{response.code}: #{response.body.truncate(200)}"
    end

    JSON.parse(response.body)
  end

  def build_request_body
    {
      contents: [
        {
          role: "user",
          parts: [{ text: build_prompt }]
        }
      ],
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 1024,
        responseMimeType: "application/json"
      }
    }
  end

  # ─── Prompt Engineering ─────────────────────────────────────────────────────

  def build_prompt
    symptoms_text       = Array(@symptoms).join(", ").presence || "not specified"
    age_context         = @patient_age ? "#{@patient_age} years old" : "age unknown"
    conditions_context  = @chronic_conditions.any? ? @chronic_conditions.join(", ") : "none reported"
    visits_context      = @previous_visits > 0 ? "#{@previous_visits} recent visit(s)" : "first visit"

    <<~PROMPT
      You are a clinical triage assistant for a hospital Out-Patient Department (OPD).
      Your sole task is to determine the urgency of the patient's case to order the waiting queue.
      You are NOT diagnosing the patient.

      ## Patient Context
      - Age: #{age_context}
      - Known chronic conditions: #{conditions_context}
      - Recent OPD visits: #{visits_context}
      - Self-reported severity: #{@severity}
      - Reported symptoms: #{symptoms_text}

      ## Priority Classification
      Classify into ONE of these OPD triage levels:
      - **HIGH** (score 80–100): Potentially life-threatening, requires attention within minutes.
        Examples: chest pain, difficulty breathing, loss of consciousness, severe bleeding, stroke signs.
      - **MEDIUM** (score 50–79): Urgent but stable, should be seen within the hour.
        Examples: high fever, vomiting, moderate pain, asthma attack, suspected fracture.
      - **LOW** (score 10–49): Routine, stable, can wait in normal queue order.
        Examples: mild headache, cold, minor rash, toothache, routine follow-up.

      ## Contextual Rules (apply these):
      - Patient aged 65+ with chest pain or breathing difficulty → always HIGH
      - Child under 5 with high fever or difficulty breathing → at least MEDIUM
      - Known hypertension/diabetes combined with chest pain, dizziness, or vision loss → HIGH
      - Severity 'severe' bumps score by +10 within the same level
      - Multiple concurrent serious symptoms increase urgency

      ## Response Format
      Respond with ONLY valid JSON:
      {
        "priority_level": "HIGH",
        "priority_score": 95,
        "reasoning": "Clinical justification here",
        "detected_symptoms": ["symptom1", "symptom2"]
      }
PROMPT
  end

  # ─── Response Parsing ───────────────────────────────────────────────────────

  def parse_gemini_response(api_response)
    # Navigate Gemini's response envelope
    text = api_response.dig("candidates", 0, "content", "parts", 0, "text")
    raise "Empty response from Gemini API" if text.nil? || text.strip.empty?

    # Strip markdown code blocks if the model included them (e.g. ```json ... ```)
    clean_text = text.gsub(/```json|```/, '').strip

    begin
      parsed = JSON.parse(clean_text)
    rescue JSON::ParserError => e
      Rails.logger.error "[GeminiTriageService] JSON Parse Error: #{e.message}. Raw: #{clean_text.truncate(100)}"
      return fallback_result(error: "Malformed JSON output")
    end

    # Validate and sanitise priority_level
    priority_level = parsed["priority_level"]&.upcase&.strip
    priority_level = "LOW" unless %w[HIGH MEDIUM LOW].include?(priority_level)

    # Clamp score within the declared level's valid range
    raw_score      = parsed["priority_score"].to_i
    score_range    = PRIORITY_SCORE_RANGES[priority_level]
    priority_score = raw_score.clamp(score_range.min, score_range.max)

    detected = Array(parsed["detected_symptoms"]).map { |s| s.to_s.downcase.strip }.reject(&:empty?)
    reasoning = parsed["reasoning"].to_s.strip.truncate(600)

    {
      priority_level:    priority_level,
      priority_score:    priority_score,
      reasoning:         reasoning,
      detected_symptoms: detected,
      severity_input:    @severity,
      ai_model_used:     "gemini-1.5-flash",
      first_aid_advice:  build_first_aid(detected)
    }
  end

  # ─── Fallback ───────────────────────────────────────────────────────────────

  # If Gemini is unavailable, fall back to the original rule-based service
  # and flag the result so it's transparent in the dashboard
  def fallback_result(error: nil)
    result = AiPrioritizationService.new(@symptoms, severity: @severity).call
    result[:ai_model_used] = "rule_based_fallback"
    
    # Log the specific error for developers but don't show to clinical staff
    Rails.logger.error "[GeminiTriageService] Fallback triggered. Reason: #{error}" if error
    
    result[:reasoning] = "Priority assigned via rule-based keyword analysis."
    result
  end

  # ─── First Aid ──────────────────────────────────────────────────────────────

  def build_first_aid(symptoms)
    symptoms.filter_map do |symptom|
      advice = AiPrioritizationService::FIRST_AID_ADVICE[symptom]
      { symptom: symptom, advice: advice } if advice
    end
  end
end
# Guard clause for empty symptoms
# Exponential backoff retry strategy
