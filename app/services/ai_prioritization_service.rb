class AiPrioritizationService
  # A comprehensive but rule-based mapping
  SYMPTOM_DICTS = {
    high: [
      "chest pain", "difficulty breathing", "shortness of breath", "respiratory distress",
      "unconscious", "severe bleeding", "stroke", "seizure", "choking", "heart attack",
      "loss of vision", "suicidal", "severe head injury", "coughing up blood",
      "gunshot", "gunshot wound", "stab wound", "burning", "unresponsive", "paralysis",
      "anaphylaxis", "severe allergic reaction", "difficulty swallowing", "cardiac arrest",
      "stopped breathing", "cannot breathe"
    ],
    medium: [
      "fever", "vomiting", "dizziness", "severe pain", "broken bone",
      "abdominal pain", "stomach pain", "stomach ache", "migraine", "asthma", 
      "dehydration", "fainting", "confusion", "allergic reaction", "diarrhea",
      "deep cut", "fracture", "high blood pressure", "food poisoning", "infection",
      "panic attack", "bleeding"
    ],
    low: [
      "headache", "cough", "runny nose", "sore throat", "mild rash",
      "minor cut", "nausea", "fatigue", "muscle ache", "mild allergy",
      "earache", "cold", "flu", "sprain", "bruise", "toothache", "sore muscles"
    ]
  }.freeze

  PRIORITY_LEVELS = { high: "HIGH", medium: "MEDIUM", low: "LOW" }.freeze
  
  FIRST_AID_ADVICE = {
    "chest pain" => "Sit upright and stay calm. Loosen tight clothing. Do NOT exert yourself.",
    "difficulty breathing" => "Sit upright. Loosen clothing. Try slow breaths. Seek immediate help.",
    "shortness of breath" => "Sit upright. Loosen clothing. Try slow breaths. Seek immediate help.",
    "respiratory distress" => "Sit upright. Loosen clothing. Try slow breaths. Seek immediate help.",
    "unconscious" => "Place in recovery position. Check breathing. Do NOT give food or water.",
    "severe bleeding" => "Apply firm, direct pressure with a clean cloth. Elevate if possible.",
    "stroke" => "Note the time symptoms started. Keep perfectly still. Seek emergency help.",
    "seizure" => "Clear the area of hard objects. Do NOT restrain. Time the seizure.",
    "choking" => "Perform abdominal thrusts (Heimlich) if the person cannot breathe.",
    "heart attack" => "Chew an aspirin if not allergic. Sit or lie down and stay calm.",
    "loss of vision" => "Do NOT rub eyes. Cover eyes gently with a clean cloth.",
    "suicidal" => "Stay with the person. Remove harmful objects. Call a crisis line.",
    "severe head injury" => "Keep the person still. Do NOT move them. Apply gentle pressure to bleeding.",
    "coughing up blood" => "Sit upright and lean forward. Spit blood out. Stay calm.",
    "gunshot" => "Apply firm pressure to the wound. Do NOT remove objects. Stay still.",
    "gunshot wound" => "Apply firm pressure to the wound. Do NOT remove objects. Stay still.",
    "stab wound" => "Do NOT remove the object. Apply pressure around it. Stay still.",
    "burning" => "Cool under cool running water for 20 minutes. No ice or creams.",
    "unresponsive" => "Check airway and breathing. Place in recovery position.",
    "paralysis" => "Do NOT move the person. Keep them warm and reassured.",
    "anaphylaxis" => "Use EpiPen immediately if available. Seek emergency help.",
    "severe allergic reaction" => "Use EpiPen immediately if available. Seek emergency help.",
    "difficulty swallowing" => "Sit upright. Do NOT try to eat or drink. Seek help.",
    "cardiac arrest" => "Begin CPR immediately if trained. Call emergency services.",
    "stopped breathing" => "Begin CPR immediately if trained. Call emergency services.",
    "cannot breathe" => "Sit upright. Loosen clothing. Seek immediate help.",

    # Urgent (MEDIUM)
    "fever" => "Rest and stay hydrated. Take paracetamol as directed. Use cool compress.",
    "vomiting" => "Sip small amounts of clear fluids. Avoid solid food for now.",
    "dizziness" => "Sit or lie down. Drink water slowly. Avoid sudden movements.",
    "severe pain" => "Rest the area. Use a cold pack. Take directed pain relief.",
    "broken bone" => "Immobilise the limb. Do NOT straighten. Apply ice carefully.",
    "abdominal pain" => "Lie down and rest. Sip clear fluids. Avoid heavy meals.",
    "stomach pain" => "Lie down and rest. Sip clear fluids. Avoid heavy meals.",
    "stomach ache" => "Rest and sip water. Avoid spicy or heavy foods.",
    "migraine" => "Rest in a dark, quiet room. Use a cool cloth on forehead.",
    "asthma" => "Use rescue inhaler as directed. Sit upright and stay calm.",
    "dehydration" => "Sip water or rehydration solution frequently. Avoid caffeine.",
    "fainting" => "Lie down with legs elevated. Loosen tight clothing.",
    "confusion" => "Keep the person safe and calm. Check for medical ID.",
    "allergic reaction" => "Take antihistamine if mild. Monitor for breathing issues.",
    "diarrhea" => "Stay hydrated with water/electrolytes. Eat bland foods.",
    "deep cut" => "Clean with water. Apply firm pressure. Cover with bandage.",
    "fracture" => "Support the limb. Avoid movement. Apply ice for swelling.",
    "high blood pressure" => "Sit and relax. Breathe deeply. Avoid salt/caffeine.",
    "food poisoning" => "Sip clear fluids. Rest. Avoid dairy and solid food.",
    "infection" => "Keep area clean. Monitor for fever. Seek medical advice.",
    "panic attack" => "Breathe slowly into your hands or a paper bag. Stay calm.",
    "bleeding" => "Clean with water. Apply pressure until bleeding stops.",

    # Routine (LOW)
    "headache" => "Rest in a quiet room. Stay hydrated. Take mild pain relief.",
    "cough" => "Drink warm honey and lemon. Use cough drops. Rest.",
    "runny nose" => "Blow gently. Stay hydrated. Use saline spray if needed.",
    "sore throat" => "Gargle with warm salt water. Drink warm fluids.",
    "mild rash" => "Apply calamine or moisturiser. Avoid scratching.",
    "minor cut" => "Clean with water. Apply antiseptic. Use a plaster.",
    "nausea" => "Sip ginger tea or water. Eat small, bland snacks.",
    "fatigue" => "Ensure adequate rest and sleep. Stay hydrated.",
    "muscle ache" => "Rest the muscle. Apply warm compress. Gentle stretch.",
    "mild allergy" => "Take antihistamine. Avoid known triggers.",
    "earache" => "Apply warm cloth to ear. Take directed pain relief.",
    "cold" => "Rest and drink plenty of fluids. Use saline nasal spray.",
    "flu" => "Rest in bed. Stay hydrated. Take paracetamol for fever.",
    "sprain" => "Rest, Ice, Compression, and Elevation (RICE).",
    "bruise" => "Apply cold pack for 15 minutes. Elevate the area.",
    "toothache" => "Rinse with warm salt water. See a dentist soon.",
    "sore muscles" => "Gentle stretching and warm bath. Rest the area."
  }.freeze

  def initialize(input_symptoms, severity: 'low')
    @raw_input = input_symptoms
    @severity = severity.to_s.downcase
    @symptoms = []
    
    parse_input
  end

  def call
    return { priority_level: "LOW", priority_score: 10 } if @symptoms.empty?

    highest_tier = :low
    base_score = 10
    additional_symptoms_count = 0

    has_high = false
    has_medium = false

    # Evaluate extracted symptoms
    @symptoms.each do |symptom|
      if matches_category?(symptom, :high)
        has_high = true
        additional_symptoms_count += 1
      elsif matches_category?(symptom, :medium)
        has_medium = true
        additional_symptoms_count += 1
      elsif matches_category?(symptom, :low) || symptom.present?
        additional_symptoms_count += 1
      end
    end

    if has_high
      highest_tier = :high
      base_score = 80
    elsif has_medium
      highest_tier = :medium
      base_score = 50
    else
      highest_tier = :low
      base_score = 20
    end

    # Calculate severity bump
    severity_bump = case @severity
                    when 'severe' then 10
                    when 'moderate' then 5
                    else 0
                    end

    # Calculate final score: Base score + 5 per additional symptom + severity bump
    score_bump = [additional_symptoms_count - 1, 0].max * 5
    final_score = base_score + score_bump + severity_bump

    # Cap scores within their tiers
    # HIGH: 80-100, MEDIUM: 50-79, LOW: 10-49
    final_score = limit_score(final_score, highest_tier)

    {
      priority_level: PRIORITY_LEVELS[highest_tier],
      priority_score: final_score,
      detected_symptoms: @symptoms.uniq,
      severity_input: @severity,
      first_aid_advice: generate_advice(@symptoms.uniq)
    }
  end

  private

  def parse_input
    # Normalize input to a single string for scanning
    text = Array(@raw_input).join(" ").downcase
    
    # NLP Parsing: Scan the full text for known keywords from our dictionaries
    SYMPTOM_DICTS.each do |category, keywords|
      keywords.each do |keyword|
        if matches_keyword_in_text?(text, keyword)
          @symptoms << keyword
        end
      end
    end
    
    # If no specific dictionary keywords are found, treat the whole string as one unknown symptom
    if @symptoms.empty? && text.present?
      @symptoms = Array(@raw_input).reject(&:blank?).map { |s| s.to_s.downcase.strip }
    end
  end

  def matches_keyword_in_text?(text, keyword)
    match_data = text.match(/\b#{Regexp.escape(keyword)}\b/i)
    if match_data
      # Check for negation words immediately before the match
      prefix = text[0...match_data.begin(0)]
      !prefix.match?(/\b(no|not|without|zero|negative|none)\s+([a-z-]+\s+)*$/i)
    else
      false
    end
  end

  def matches_category?(symptom, category)
    SYMPTOM_DICTS[category].include?(symptom)
  end

  def limit_score(score, tier)
    case tier
    when :high
      [score, 100].min
    when :medium
      [score, 79].min
    when :low
      [score, 49].min
    end
  end

  def generate_advice(symptoms)
    symptoms.map do |symptom|
      advice = FIRST_AID_ADVICE[symptom]
      next nil unless advice
      { symptom: symptom, advice: advice }
    end.compact
  end
end
# Edge case: multiple high-severity symptoms
# Normalize scores to 0-100 range
# Updated first aid knowledge base
