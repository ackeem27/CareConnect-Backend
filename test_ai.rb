# Polyfills for ActiveSupport methods used in the service
class Object
  def present?
    !blank?
  end

  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end
end

class String
  def blank?
    strip.empty?
  end
end

require_relative 'app/services/ai_prioritization_service'

# Mock required parts if necessary (none needed for this simple service)
# But wait, the service uses SYMPTOM_DICTS and FIRST_AID_ADVICE which are defined in the class.

def test_symptoms(input, severity = 'low')
  service = AiPrioritizationService.new(input, severity: severity)
  result = service.call
  puts "Input: '#{input}' (Severity: #{severity})"
  puts "  Level: #{result[:priority_level]}"
  puts "  Score: #{result[:priority_score]}"
  puts "  Symptoms: #{result[:detected_symptoms].join(', ')}"
  puts "  Advice count: #{result[:first_aid_advice].size}"
  puts "-" * 30
end

puts "Verifying Expanded Dictionary Scoring..."
puts "=" * 40

# Test HIGH scenarios
test_symptoms("respiratory distress", "severe") # Should be HIGH, score 90 (80 + 10)
test_symptoms("shortness of breath", "moderate") # Should be HIGH, score 85 (80 + 5)
test_symptoms("chest pain and cannot breathe", "severe") # Should be HIGH, score 95 (80 + 5 bump + 10 severity)

# Test MEDIUM scenarios
test_symptoms("stomach pain", "low") # Should be MEDIUM, score 50
test_symptoms("food poisoning and vomiting", "moderate") # Should be MEDIUM, score 60 (50 + 5 bump + 5 severity)

# Test LOW scenarios
test_symptoms("headache", "low") # Should be LOW, score 20
test_symptoms("sore muscles", "moderate") # Should be LOW, score 25 (20 + 5 severity)

# Test Catch-all (not in dict)
test_symptoms("my left toe hurts", "low") # Should be LOW, score 20
