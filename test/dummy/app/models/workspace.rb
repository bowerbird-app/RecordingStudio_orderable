class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", plural_label: "Workspaces", root: true
  RecordingStudio.enable_capability(:accessible, on: self)
end

