# frozen_string_literal: true

module RecordingStudioOrderable
  class RecordingOrderListsController < ApplicationController
    before_action :ensure_current_recording_studio_orderable_owner!
    before_action :load_form_context, only: :new

    def create
      order = create_named_recording_order
      redirect_to create_redirect_target(order) || root_path, notice: "Created list."
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "Parent recording not found."
    rescue RecordingStudioOrderable::RecordingOrderManager::ConfigurationError,
           ActionController::ParameterMissing,
           ArgumentError => e
      redirect_to safe_local_redirect_target(params[:redirect_to]) || root_path, alert: e.message
    end

    private

    def load_form_context
      @parent_recording = parent_recording_from_params
      @group_key = group_key_from_params(@parent_recording)
      @parent_recording_label = parent_recording_label(@parent_recording)
      @redirect_to = safe_local_redirect_target(params[:redirect_to])
      @source_order_recording_id = source_order_recording_id_from_params
    rescue ActiveRecord::RecordNotFound, RecordingStudioOrderable::RecordingOrderManager::ConfigurationError => e
      redirect_to root_path, alert: e.message
    end

    def parent_recording_from_params
      RecordingStudio::Recording.find(params.fetch(:parent_recording_id))
    end

    def group_key_from_params(parent_recording)
      RecordingStudioOrderable::RecordingOrderManager.resolve_group_key!(parent_recording, params.fetch(:group_key))
    end

    def source_order_recording_id_from_params
      params[:source_order_recording_id].to_s.strip.presence
    end

    def create_named_recording_order
      RecordingStudioOrderable::RecordingOrderManager.create_named_recording_order!(
        *named_order_context,
        name: list_params.fetch(:name),
        owner: current_recording_studio_orderable_owner,
        actor: current_recording_studio_orderable_owner,
        metadata: { source: "recording_studio_orderable.recording_order_lists#create" },
        source_order_recording_id: source_order_recording_id_from_params
      )
    end

    def named_order_context
      parent_recording = parent_recording_from_params
      [parent_recording, group_key_from_params(parent_recording)]
    end

    def create_redirect_target(order)
      append_query_param(
        safe_local_redirect_target(params[:redirect_to]),
        :selected_order_recording_id,
        selected_order_recording_id(order)
      )
    end

    def selected_order_recording_id(order)
      order.recordings.max_by { |recording| [recording.created_at, recording.id.to_s] }&.id
    end

    def list_params
      params.require(:recording_order_list).permit(:name)
    end

    def parent_recording_label(parent_recording)
      recordable = parent_recording.recordable
      friendly_name = recordable.try(:name).presence || recordable.try(:title).presence
      return "#{parent_recording.recordable_type} #{friendly_name}" if friendly_name.present?

      "#{parent_recording.recordable_type} #{parent_recording.id}"
    end
  end
end
