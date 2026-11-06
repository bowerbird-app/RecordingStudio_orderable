class DemoAccess
  class << self
    def ensure_owner!(recording:, actor:)
      result = RecordingStudioAccessible.bootstrap_owner_access!(
        recording: recording,
        actor: actor
      )
      return result.value if result.success?
      if result.error.to_s.include?("Access already exists") &&
         RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :admin)
        return
      end

      raise result.error
    end

    def ensure_grant!(recording:, actor:, role:, manager_actor:)
      result = RecordingStudioAccessible.grant_access(
        recording: recording,
        actor: actor,
        role: role,
        manager_actor: manager_actor
      )
      return result.value if result.success?
      if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)
        return
      end

      raise result.error
    end
  end
end
