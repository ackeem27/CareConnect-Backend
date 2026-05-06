require_relative 'config/environment'
Dotenv.load

puts "Testing Gemini 2.0 Flash..."
service = GeminiTriageService.new(
  symptoms: "chest pain",
  severity: "severe",
  patient_age: 70
)

# Try once
puts "Attempt 1..."
result = service.call
puts "Model: #{result[:ai_model_used]}"
puts "Reasoning: #{result[:reasoning]}"

if result[:ai_model_used] == "rule_based_fallback"
  puts "\nSleeping 15s to bypass burst limit..."
  sleep 15
  puts "Attempt 2..."
  result = service.call
  puts "Model: #{result[:ai_model_used]}"
  puts "Reasoning: #{result[:reasoning]}"
end
