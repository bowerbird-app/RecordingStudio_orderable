class DemoRecordingLookup
  class << self
    def workspace_root
      workspace = Workspace.first
      return if workspace.nil?

      RecordingStudio.root_recording_for(workspace)
    end

    def by_slug(type:, slug:)
      recordable_class = type.to_s.safe_constantize
      return if recordable_class.nil?

      recordable = recordable_class.find_by(slug: slug)
      return if recordable.nil?

      root = workspace_root
      return if root.nil?

      root.recording_for(recordable)
    end
  end
end
