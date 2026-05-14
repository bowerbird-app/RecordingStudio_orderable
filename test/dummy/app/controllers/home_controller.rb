class HomeController < ApplicationController
  PageRow = Struct.new(:recording, :position, :explicitly_ordered, keyword_init: true)

  before_action :load_workspace_context, only: :index

  def index
    @page_order_recordings = named_page_order_recordings
    @page_order_recording = selected_page_order_recording
    @page_order = @page_order_recording&.recordable
    @stored_page_order_ids = Array(@page_order&.ordered_recording_ids)
    explicit_ids = @stored_page_order_ids.map(&:to_s)

    @ordered_pages = @page_order ? ordered_pages_for(@page_order) : []
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
    raise ActiveRecord::RecordNotFound unless folder_recording.recordable_type == "Folder"

    selected_order_recording = folder_recording.named_recording_order_recording_for(
      params.fetch(:selected_order_recording_id),
      :pages,
      owner: current_user
    )
    raise ActiveRecord::RecordNotFound unless selected_order_recording

    updated_order = selected_order_recording.recordable.move_to_position!(
      moving: moving_recording_id_from_params,
      position: target_position_from_params,
      actor: current_user,
      metadata: { source: "dummy.home#update_page_order" }
    )

    updated_recording = Array(updated_order.recordings).compact.max_by do |recording|
      [recording.updated_at, recording.created_at, recording.id.to_s]
    end

    redirect_to root_path(selected_order_recording_id: updated_recording&.id || selected_order_recording.id), notice: "Saved page order."
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Named list not found."
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

  def moving_recording_id_from_params
    params.fetch(:moving_recording_id).to_s.strip.tap do |recording_id|
      raise ArgumentError, "moving recording id is required" if recording_id.blank?
    end
  end

  def target_position_from_params
    Integer(params.fetch(:target_position))
  end

  def named_page_order_recordings
    return [] unless @folder_recording

    Array(@folder_recording.reload.named_recording_order_recordings(:pages, owner: current_user)).map(&:reload)
  end

  def selected_page_order_recording
    return if @page_order_recordings.blank?

    requested_id = params[:selected_order_recording_id].to_s.strip.presence
    selected_recording = @page_order_recordings.find { |recording| recording.id.to_s == requested_id } if requested_id.present?
    selected_recording || @page_order_recordings.first
  end

  def ordered_pages_for(order)
    return [] unless @folder_recording && order

    eligible_pages = Array(@folder_recording.reload.children_for_order_group(:pages))
    eligible_by_id = eligible_pages.index_by { |recording| recording.id.to_s }
    explicitly_ordered_pages = Array(order.ordered_recording_ids).filter_map do |recording_id|
      eligible_by_id.delete(recording_id.to_s)
    end

    explicitly_ordered_pages + eligible_by_id.values
  end
end
