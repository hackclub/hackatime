FactoryBot.define do
  factory :trust_level_audit_log do
    user
    association :changed_by, factory: [ :user, :admin ]
    previous_trust_level { :blue }
    new_trust_level { :green }
  end
end
