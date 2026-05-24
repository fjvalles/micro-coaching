FactoryBot.define do
  factory :admin_user do
    sequence(:email) { |n| "admin#{n}@piloto.test" }
    name { "Admin" }
    password { "password123" }
    password_confirmation { "password123" }
  end
end
