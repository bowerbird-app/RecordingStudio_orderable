# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: 1)
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end

module DemoTreeAccess
  def grant_demo_owner!(recording:, actor:)
    DemoAccess.ensure_owner!(recording: recording, actor: actor)
  end

  def grant_demo_access!(recording:, actor:, role:, manager_actor:)
    DemoAccess.ensure_grant!(recording: recording, actor: actor, role: role, manager_actor: manager_actor)
  end
end

ActiveSupport::TestCase.include(DemoTreeAccess)
