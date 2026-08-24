FactoryBot.define do
  sequence(:project_name) { |number| "project-#{number}" }
  sequence(:repository_name) { |number| "repository-#{number}" }

  factory :project_repo_mapping do
    user
    project_name { generate(:project_name) }
  end

  factory :repository do
    host { "github.com" }
    owner { "example" }
    name { generate(:repository_name) }
    url { "https://#{host}/#{owner}/#{name}" }
  end
end
