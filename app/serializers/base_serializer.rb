# frozen_string_literal: true

class BaseSerializer < Oj::Serializer
  include TypesFromSerializers::DSL
end
