# frozen_string_literal: true

module RecordingStudioOrderable
  class RecordingStudioOrdersController < ApplicationController
    TypeRow = Struct.new(:recordable_type, :group_key, :custom_orders_count, :parent_recording_id, keyword_init: true)
    NamedOrderRow = Struct.new(:recording_id, :name, keyword_init: true)

    before_action :ensure_current_recording_studio_orderable_owner!
    before_action :load_index_context, only: :index
    before_action :load_show_context, only: :show
    before_action :load_form_context, only: :new
    before_action :authorize_parent_recording_from_params!, only: :create
    before_action :redirect_edit_placeholder, only: :edit

    def index; end

    def show; end

    def new; end

    def create
      order = create_named_recording_order
      redirect_to create_redirect_target(order) || root_path, notice: "Created order."
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "Parent recording not found."
    rescue RecordingStudioOrderable::RecordingOrderManager::ConfigurationError,
           ActionController::ParameterMissing,
           ArgumentError => e
      handle_create_failure(e)
    end

    def edit; end

    private

    def load_index_context
      if params[:parent_recording_id].present?
        @parent_recording = load_parent_recording_context!
        return if performed?

        @type_rows = recording_type_rows(@parent_recording)
      else
        @type_rows = global_recording_type_rows
      end
    rescue ActiveRecord::RecordNotFound,
           RecordingStudioOrderable::RecordingOrderManager::ConfigurationError => e
      handle_browse_failure(e)
    end

    def load_show_context
      @parent_recording = load_parent_recording_context!
      return if performed?

      @type_row = type_row_for!(@parent_recording, params.fetch(:id))
      @named_order_rows = named_order_rows_for(@parent_recording, @type_row.group_key)
    rescue ActiveRecord::RecordNotFound,
           RecordingStudioOrderable::RecordingOrderManager::ConfigurationError,
           ActionController::ParameterMissing,
           ArgumentError => e
      handle_browse_failure(e)
    end

    def redirect_edit_placeholder
      parent_recording = load_parent_recording_context!
      return if performed?

      redirect_to recording_studio_order_path(
        params.fetch(:recordable_type),
        parent_recording_id: parent_recording.id
      ), alert: "Editing recording studio orders is not implemented yet."
    rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing => e
      handle_browse_failure(e)
    end

    def load_parent_recording_context!
      parent_recording = parent_recording_from_params
      authorize_parent_recording!(parent_recording)
      return if performed?

      @parent_recording_label = parent_recording_label(parent_recording)
      parent_recording
    end

    def load_form_context
      @parent_recording = load_parent_recording_context!
      return if performed?

      @group_key = group_key_from_params(@parent_recording)
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
        metadata: { source: "recording_studio_orderable.recording_studio_orders#create" },
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
      params.require(:recording_studio_order).permit(:name)
    end

    def parent_recording_label(parent_recording)
      recordable = parent_recording.recordable
      friendly_name = recordable.try(:name).presence || recordable.try(:title).presence
      return "#{parent_recording.recordable_type} #{friendly_name}" if friendly_name.present?

      "#{parent_recording.recordable_type} #{parent_recording.id}"
    end

    def handle_create_failure(_error)
      redirect_to safe_local_redirect_target(params[:redirect_to]) || root_path,
                  alert: "Unable to create that recording studio order."
    end

    def handle_form_context_failure(error)
      if error.is_a?(ActiveRecord::RecordNotFound)
        redirect_to root_path, alert: "Parent recording not found."
      else
        redirect_to root_path, alert: "Unable to load that recording studio order form."
      end
    end

    def handle_browse_failure(error)
      if error.is_a?(ActiveRecord::RecordNotFound)
        redirect_to root_path, alert: "Parent recording not found."
      else
        redirect_to root_path, alert: "Unable to load recording studio orders."
      end
    end

    def recording_type_rows(parent_recording)
      order_group_definitions_for(parent_recording).values.flat_map do |definition|
        build_type_rows(definition, parent_recording)
      end.uniq { |row| row.recordable_type }.sort_by(&:recordable_type)
    end

    def global_recording_type_rows
      orderable_parent_recordings.group_by(&:recordable_type).map do |recordable_type, parent_recordings|
        representative_parent = parent_recordings.min_by { |recording| recording.id.to_s }

        TypeRow.new(
          recordable_type: recordable_type,
          group_key: default_group_key_for(representative_parent),
          custom_orders_count: parent_recordings.sum { |parent_recording| named_order_count_for(parent_recording) },
          parent_recording_id: representative_parent.id
        )
      end.sort_by(&:recordable_type)
    end

    def orderable_parent_recordings
      parent_recordings = if RecordingStudio::Recording.respond_to?(:where)
                            RecordingStudio::Recording.where.not(recordable_type: "RecordingStudio::RecordingStudioOrder").to_a
                          else
                            Array(RecordingStudio::Recording.all).reject do |recording|
                              recording.recordable_type == "RecordingStudio::RecordingStudioOrder"
                            end
                          end

      parent_recordings.select do |recording|
        order_group_definitions_for(recording, strict: false).present?
      end
    end

    def build_type_rows(definition, parent_recording)
      group_key = definition.fetch(:group_key)
      custom_orders_count = named_order_rows_for(parent_recording, group_key).size

      Array(definition.fetch(:allows)).map do |recordable_type|
        TypeRow.new(
          recordable_type: recordable_type,
          group_key: group_key,
          custom_orders_count: custom_orders_count,
          parent_recording_id: parent_recording.id
        )
      end
    end

    def named_order_count_for(parent_recording)
      order_group_definitions_for(parent_recording).values.sum do |definition|
        named_order_rows_for(parent_recording, definition.fetch(:group_key)).size
      end
    end

    def type_row_for!(parent_recording, recordable_type)
      recording_type_rows(parent_recording)
        .find { |row| row.recordable_type == recordable_type.to_s } ||
        raise(ArgumentError, "Unknown recording studio order type: #{recordable_type}")
    end

    def named_order_rows_for(parent_recording, group_key)
      RecordingStudioOrderable::RecordingOrderManager.named_recording_order_recordings(
        parent_recording,
        group_key,
        owner: current_recording_studio_orderable_owner
      ).map do |recording|
        NamedOrderRow.new(
          recording_id: recording.id,
          name: order_display_name(recording.recordable)
        )
      end
    end

    def default_group_key_for(parent_recording)
      order_group_definitions_for(parent_recording, strict: false).values.first&.fetch(:group_key, nil)
    end

    def order_group_definitions_for(parent_recording, strict: true)
      recordable_class = parent_recording.recordable&.class || parent_recording.recordable_type.to_s.safe_constantize
      raise RecordingStudioOrderable::RecordingOrderManager::ConfigurationError, "Unable to resolve recordable class" unless recordable_class

      return recordable_class.recording_studio_order_group_definitions if recordable_class.respond_to?(:recording_studio_order_group_definitions)

      recordable_class.recording_studio_order_group_definition
      recordable_class.recording_studio_order_group_definitions
    rescue RecordingStudioOrderable::RecordingOrderManager::ConfigurationError, NoMethodError
      return {} unless strict

      raise
    end

    def order_display_name(order_record)
      return "Untitled order" unless order_record.respond_to?(:name)

      order_record.name.to_s.strip.presence || "Untitled order"
    end
  end
end
