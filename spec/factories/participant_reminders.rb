FactoryBot.define do
  factory :participant_reminder do
    association :participant
    scheduled_at { 1.hour.from_now }
    timezone { participant.timezone }
    requested_text { "Avísame a las 5pm" }
    body { "Te recuerdo retomar el paso de hoy. Puedes hacer solo 5 minutos." }
    status { "pending" }
  end
end
