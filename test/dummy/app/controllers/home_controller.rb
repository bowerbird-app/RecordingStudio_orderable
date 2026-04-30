class HomeController < ApplicationController
  PageRow = Struct.new(:recording, :position, :explicitly_ordered, keyword_init: true)

  before_action :load_workspace_context, only: :index

  def index
    @page_order = @folder_recording&.recording_order_for(:pages)
    @stored_page_order_ids = Array(@page_order&.ordered_recording_ids)
    explicit_ids = @stored_page_order_ids.map(&:to_s)

    @ordered_pages = Array(@folder_recording&.ordered_children_for(:pages))
    @page_rows = @ordered_pages.each_with_index.map do |recording, index|
      PageRow.new(
        recording: recording,
        position: index + 1,
        explicitly_ordered: explicit_ids.include?(recording.id.to_s)
      )
    end
  end

  def update_page_order
    folder_recording = RecordingStudio::Recording.find(params[:id])
    folder_recording.find_or_create_recording_order!(:pages).reorder_recordings!(
      ordered_recording_ids_from_params
    )

    redirect_to root_path, notice: "Saved page order."
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Folder recording not found."
  rescue RecordingStudioOrderable::RecordingOrderManager::ConfigurationError, ArgumentError => e
    redirect_to root_path, alert: e.message
  end

  private

  def load_workspace_context
    @workspace = Workspace.first
    @root_recording = RecordingStudio::Recording.unscoped.find_by(
      recordable: @workspace,
      parent_recording_id: nil
    )
    @folder_recording = @root_recording&.child_recordings&.find { |recording| recording.recordable_type == "Folder" }
    @folder = @folder_recording&.recordable
  end

  def ordered_recording_ids_from_params
    params.fetch(:ordered_recording_ids, "")
          .to_s
          .split(",")
          .map(&:strip)
          .reject(&:blank?)
  end
end
