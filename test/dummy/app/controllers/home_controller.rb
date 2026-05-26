class HomeController < ApplicationController
  PageRow = Struct.new(:recording, :position, :explicitly_ordered, keyword_init: true)
  CUSTOM_EVENT_NAME = "recordingstudio:order:updated"
  DEFAULT_DEMO_VARIANT = "custom_event"
  SUCCESS_MESSAGE = "Saved page order."

  before_action :load_workspace_context, only: :index
  before_action :load_demo_variant, only: %i[index update_page_order]

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

    selected_order_recording_id = params.fetch(:selected_order_recording_id).to_s
    selected_order = folder_recording.find_recording_order_by_id(
      selected_order_recording_id,
      group_key: :pages,
      owner: current_user
    )

    updated_order = selected_order.move_to_position!(
      moving: moving_recording_id_from_params,
      position: target_position_from_params,
      actor: current_user,
      metadata: { source: "dummy.home#update_page_order" }
    )

    updated_recording = Array(updated_order.recordings).compact.max_by do |recording|
      [recording.updated_at, recording.created_at, recording.id.to_s]
    end

    respond_to do |format|
      format.html do
        redirect_to page_order_demo_path(updated_recording&.id || selected_order_recording_id), notice: SUCCESS_MESSAGE
      end
      format.json do
        if send_custom_event_param?
          render json: {
            event_name: CUSTOM_EVENT_NAME,
            event_detail: success_event_detail(
              selected_order_recording_id: selected_order_recording_id,
              moving_recording_id: moving_recording_id_from_params,
              target_position: target_position_from_params,
              updated_recording_id: updated_recording&.id
            )
          }
        else
          render json: {
            redirect_url: page_order_demo_path(updated_recording&.id || selected_order_recording_id)
          }
        end
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to root_path, alert: "Named list not found." }
      format.json { render json: { error: "Named list not found." }, status: :not_found }
    end
  rescue RecordingStudioOrderable::RecordingOrderManager::ConfigurationError, ArgumentError => e
    respond_to do |format|
      format.html { redirect_to root_path, alert: e.message }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
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

  def load_demo_variant
    @demo_variant = demo_variant_param
  end

  def moving_recording_id_from_params
    params.fetch(:moving_recording_id).to_s.strip.tap do |recording_id|
      raise ArgumentError, "moving recording id is required" if recording_id.blank?
    end
  end

  def target_position_from_params
    Integer(params.fetch(:target_position))
  end

  def send_custom_event_param?
    ActiveModel::Type::Boolean.new.cast(params[:send_custom_event])
  end

  def demo_variant_param
    return "flash_message" if params[:demo].to_s == "flash_message"

    DEFAULT_DEMO_VARIANT
  end

  def page_order_demo_path(selected_order_recording_id)
    root_path(selected_order_recording_id: selected_order_recording_id, demo: demo_variant_param)
  end

  def success_event_detail(selected_order_recording_id:, moving_recording_id:, target_position:, updated_recording_id:)
    {
      message: SUCCESS_MESSAGE,
      status: "success",
      selected_order_recording_id: selected_order_recording_id,
      moving_recording_id: moving_recording_id,
      target_position: target_position,
      updated_recording_id: updated_recording_id
    }
  end

  def named_page_order_recordings
    return [] unless @folder_recording

    Array(
      RecordingStudioOrderable::RecordingOrderManager.recording_order_recordings(
        @folder_recording.reload,
        :pages,
        owner: current_user,
        named_only: true
      )
    ).map(&:reload)
  end

  def selected_page_order_recording
    return if @page_order_recordings.blank?

    requested_id = params[:selected_order_recording_id].to_s.strip.presence
    selected_recording = @page_order_recordings.find { |recording| recording.id.to_s == requested_id } if requested_id.present?
    selected_recording || @page_order_recordings.first
  end

  def ordered_pages_for(order)
    return [] unless @folder_recording && order

    eligible_pages = Array(@folder_recording.reload.eligible_order_items(:pages))
    eligible_by_id = eligible_pages.index_by { |recording| recording.id.to_s }
    explicitly_ordered_pages = Array(order.ordered_recording_ids).filter_map do |recording_id|
      eligible_by_id.delete(recording_id.to_s)
    end

    explicitly_ordered_pages + eligible_by_id.values
  end
end
