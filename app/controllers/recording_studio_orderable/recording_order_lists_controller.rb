# frozen_string_literal: true

module RecordingStudioOrderable
  class RecordingOrderListsController < ApplicationController
    before_action :ensure_current_recording_studio_orderable_owner!
    before_action :load_form_context, only: :new
    before_action :authorize_parent_recording_from_params!, only: :create

    def create
      order = create_named_recording_order
      redirect_to create_redirect_target(order) || root_path, notice: "Created list."
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "Parent recording not found."
    rescue RecordingStudioOrderable::RecordingOrderManager::ConfigurationError,
           ActionController::ParameterMissing,
           ArgumentError => e
      handle_create_failure(e)
    end

    private

    def load_form_context
      @parent_recording = parent_recording_from_params
      authorize_parent_recording!(@parent_recording)
      return if performed?

      @group_key = group_key_from_params(@parent_recording)
      @parent_recording_label = parent_recording_label(@parent_recording)
      @redirect_to = safe_local_redirect_target(params[:redirect_to])
      @source_order_recording_id = source_order_recording_id_from_params
    rescue ActiveRecord::RecordNotFound, RecordingStudioOrderable::RecordingOrderManager::ConfigurationError => e
      handle_form_context_failure(e)
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
      context = named_order_context
      return if performed?

      RecordingStudioOrderable::RecordingOrderManager.create_named_recording_order!(
        *context,
        name: list_params.fetch(:name),
        owner: current_recording_studio_orderable_owner,
        actor: current_recording_studio_orderable_owner,
        metadata: { source: "recording_studio_orderable.recording_order_lists#create" },
        source_order_recording_id: source_order_recording_id_from_params
      )
    end

    def named_order_context
      parent_recording = parent_recording_from_params
      authorize_parent_recording!(parent_recording)
      return if performed?

      [parent_recording, group_key_from_params(parent_recording)]
    end

    def authorize_parent_recording_from_params!
      parent_recording = parent_recording_from_params
      authorize_parent_recording!(parent_recording)
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "Parent recording not found."
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

    def handle_create_failure(_error)
      redirect_to safe_local_redirect_target(params[:redirect_to]) || root_path,
                  alert: "Unable to create that recording order list."
    end

    def handle_form_context_failure(error)
      if error.is_a?(ActiveRecord::RecordNotFound)
        redirect_to root_path, alert: "Parent recording not found."
      else
        redirect_to root_path, alert: "Unable to load that recording order list form."
      end
    end
  end
end
