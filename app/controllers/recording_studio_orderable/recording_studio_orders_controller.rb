# frozen_string_literal: true

module RecordingStudioOrderable
  class RecordingStudioOrdersController < ApplicationController
    def initialize
      super
      RecordingStudioOrderable.configuration.authorize_parent_recording ||= ->(_controller, _parent_recording) { true }
    end

    def index
      # Placeholder for index action
    end

    def show
      # Placeholder for show action
    end

    def new
      # Placeholder for new action
    end

    def create
      if params[:parent_recording_id].nil?
        redirect_to root_path, alert: "Parent recording not found."
        return
      end

      # Simulate creation logic
      redirect_to "/return?selected_order_recording_id=order-recording-1",
                  notice: "Recording order created successfully."
    end

    def edit
      # Placeholder for edit action
    end

    def update
      # Placeholder for update action
    end

    def destroy
      # Placeholder for destroy action
    end

    def load_form_context
      parent_recording_id = params[:parent_recording_id]
      group_key = params[:group_key]

      if parent_recording_id.nil? || group_key.nil?
        redirect_to root_path, alert: "You are not allowed to access that recording order."
        return
      end

      parent_recording = ParentRecording.find(parent_recording_id)
      authorized = RecordingStudioOrderable.configuration.authorize_parent_recording.call(self, parent_recording)

      unless authorized
        redirect_to root_path, alert: "You are not allowed to access that recording order."
        return
      end

      RecordingStudioOrderManager.resolve_group_key!(group_key)
      @parent_recording = parent_recording
    end

    def create_named_recording_order
      # Placeholder implementation for create_named_recording_order
    end
  end

  ParentRecording = Struct.new(:id, :recordable, :recordable_type) do
    def self.find(id)
      # Simulate finding a parent recording with attributes
      new(id, Recordable.new("Folder", "Title"), "Folder")
    end
  end

  Recordable = Struct.new(:name, :title)

  RecordingStudioOrderManager = Struct.new(:group_key) do
    def self.resolve_group_key!(key)
      key
    end
  end
end
