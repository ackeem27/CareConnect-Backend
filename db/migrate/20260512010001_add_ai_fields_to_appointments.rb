class AddAiFieldsToAppointments < ActiveRecord::Migration[8.1]
  def change
    # Stores the one-to-two sentence clinical justification returned by Gemini
    add_column :appointments, :ai_reasoning, :text

    # Records which model produced the triage result: 'gemini-1.5-flash' or 'rule_based_fallback'
    add_column :appointments, :ai_model_used, :string, default: 'rule_based_fallback'
  end
end
