# frozen_string_literal: true

module RecordingStudioOrderable
  # rubocop:disable Metrics/ClassLength
  class RecordingStudioOrdersController < ApplicationController
    TypeRow = Struct.new(:recordable_type, :group_key, :custom_orders_count, :parent_recording_id, keyword_init: true)
    NamedOrderRow = Struct.new(:recording_id, :name, keyword_init: true)
    OrderedRecordRow = Struct.new(:position, :recording_id, :recordable_type, :display_name, keyword_init: true)

    before_action :ensure_current_recording_studio_orderable_owner!
    before_action :load_index_context, only: :index
    before_action :load_show_context, only: :show
    before_action :load_form_context, only: %i[new edit update]
    before_action :load_edit_context, only: :edit
    before_action :authorize_parent_recording_from_params!, only: :create

    def index; end

    def show
      if @single_order
        @order_display_name = order_display_name(@single_order.recordable)
        render :show_order
      else
        render :show
      end
    end

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

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def update
      wants_json = json_request?
      source_order = source_order_for_edit
      raise ActiveRecord::RecordNotFound if source_order.blank?

      updated_order = source_order.move_to_position!(
        moving: moving_recording_id_from_params,
        position: target_position_from_params,
        actor: current_recording_studio_orderable_owner,
        metadata: { source: "recording_studio_orderable.recording_studio_orders#update" }
      )

      updated_recording = latest_order_recording(updated_order)
      redirect_target = edit_recording_studio_order_path(
        updated_recording&.id || @source_order_recording_id,
        parent_recording_id: @parent_recording.id,
        group_key: @group_key,
        recordable_type: params[:recordable_type]
      )

      if wants_json
        render json: { redirect_url: redirect_target }
      else
        redirect_to redirect_target, notice: "Saved order."
      end
    rescue ActiveRecord::RecordNotFound
      if wants_json
        render json: { error: "Named list not found." }, status: :not_found
      else
        redirect_to root_path, alert: "Named list not found."
      end
    rescue RecordingStudioOrderable::RecordingOrderManager::ConfigurationError, ArgumentError
      if wants_json
        render json: { error: "Unable to save order." }, status: :unprocessable_entity
      else
        redirect_to root_path, alert: "Unable to save order."
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    def edit
      render :edit
    end

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

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def load_show_context
      @parent_recording = load_parent_recording_context!
      return if performed?

      id = params.fetch(:id)
      # Try to find by type first, fallback to order by UUID
      type_row = recording_type_rows(@parent_recording).find { |row| row.recordable_type == id.to_s }
      if type_row
        @type_row = type_row
        @named_order_rows = named_order_rows_for(@parent_recording, @type_row.group_key)
        @single_order = nil
      else
        # Try to find a single order by UUID
        group_keys = recording_type_rows(@parent_recording).map(&:group_key)
        found = nil
        found_type_row = nil
        group_keys.each do |gk|
          candidate = named_order_recording_for(@parent_recording, gk, id)
          next unless candidate

          found = candidate
          found_type_row = recording_type_rows(@parent_recording).find { |row| row.group_key == gk }
          break
        end
        raise ActiveRecord::RecordNotFound, "Order or type not found" unless found && found_type_row

        @type_row = found_type_row
        @named_order_rows = [
          RecordingStudioOrderable::RecordingStudioOrdersController::NamedOrderRow.new(
            recording_id: found.id,
            name: order_display_name(found.recordable)
          )
        ]
        @single_order = found

      end
    rescue ActiveRecord::RecordNotFound,
           RecordingStudioOrderable::RecordingOrderManager::ConfigurationError,
           ActionController::ParameterMissing,
           ArgumentError => e
      handle_browse_failure(e)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

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
      @redirect_to = form_redirect_target(@parent_recording)
      @source_order_recording_id = source_order_recording_id_from_params
    rescue ActiveRecord::RecordNotFound, RecordingStudioOrderable::RecordingOrderManager::ConfigurationError => e
      handle_form_context_failure(e)
    end

    def load_edit_context
      @source_order = source_order_for_edit

      @source_order_name = order_display_name(@source_order)
      @ordered_record_rows = ordered_record_rows_for_edit(@source_order)
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "Parent recording not found."
    end

    # rubocop:disable Metrics/MethodLength
    def parent_recording_from_params
      parent_recording_id = params.fetch(:parent_recording_id).to_s

      RecordingStudio::Recording.find(parent_recording_id)
    rescue ActiveRecord::RecordNotFound => e
      if RecordingStudio::Recording.respond_to?(:find_by!)
        return RecordingStudio::Recording.find_by!(recordable_id: parent_recording_id)
      end

      if RecordingStudio::Recording.respond_to?(:where)
        fallback_recording = RecordingStudio::Recording.where(recordable_id: parent_recording_id).first
        return fallback_recording if fallback_recording.present?
      end

      raise e
    end
    # rubocop:enable Metrics/MethodLength

    def group_key_from_params(parent_recording)
      RecordingStudioOrderable::RecordingOrderManager.resolve_group_key!(parent_recording, params.fetch(:group_key))
    end

    def source_order_recording_id_from_params
      explicit_source_id = params[:source_order_recording_id].to_s.strip.presence
      return explicit_source_id if explicit_source_id.present?

      params[:id].to_s.strip.presence
    end

    def source_order_for_edit
      return if @source_order_recording_id.blank?

      RecordingStudioOrderable::RecordingOrderManager.find_recording_order_by_id(
        @parent_recording,
        @source_order_recording_id,
        group_key: @group_key,
        owner: current_recording_studio_orderable_owner
      )
    end

    # rubocop:disable Metrics/MethodLength
    def ordered_record_rows_for_edit(order_record)
      recordings = Array(
        order_record&.ordered_item_recordings(owner: current_recording_studio_orderable_owner)
      )

      recordings.each_with_index.map do |recording, index|
        OrderedRecordRow.new(
          position: index + 1,
          recording_id: recording.id,
          recordable_type: recording.recordable_type,
          display_name: recordable_display_name(recording.recordable)
        )
      end
    end
    # rubocop:enable Metrics/MethodLength

    def recordable_display_name(recordable)
      return "Untitled record" if recordable.blank?

      resolved_name = recording_studio_recordable_name(recordable)
      resolved_name = nil if generic_recordable_name?(recordable, resolved_name)

      resolved_name.presence ||
        recordable.try(:name).presence ||
        recordable.try(:title).presence ||
        "#{recordable.class.name} #{recordable.try(:id) || ''}".strip
    end

    def form_redirect_target(parent_recording)
      explicit_target = safe_local_redirect_target(params[:redirect_to])
      return explicit_target if explicit_target.present?

      recordable_type = params[:recordable_type].to_s.strip
      return if recordable_type.blank?

      recording_studio_order_path(recordable_type, parent_recording_id: parent_recording.id)
    rescue ActionController::UrlGenerationError
      nil
    end

    def moving_recording_id_from_params
      params.fetch(:moving_recording_id).to_s.strip.tap do |recording_id|
        raise ArgumentError, "moving recording id is required" if recording_id.blank?
      end
    end

    def target_position_from_params
      Integer(params.fetch(:target_position))
    end

    def latest_order_recording(order_record)
      Array(order_record.recordings).compact.max_by do |recording|
        [recording.updated_at, recording.created_at, recording.id.to_s]
      end
    end

    def json_request?
      params[:format].to_s == "json" || request&.format&.json?
    rescue StandardError
      false
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
      base_target = safe_local_redirect_target(params[:redirect_to]) || default_create_redirect_target

      append_query_param(
        base_target,
        :selected_order_recording_id,
        selected_order_recording_id(order)
      )
    end

    # rubocop:disable Metrics/MethodLength
    def default_create_redirect_target
      parent_recording = parent_recording_from_params
      group_definition = RecordingStudioOrderable::RecordingOrderManager.resolve_group_definition!(
        parent_recording,
        params.fetch(:group_key)
      )
      recordable_type = Array(group_definition.fetch(:allows)).first
      return if recordable_type.blank?

      recording_studio_order_path(recordable_type, parent_recording_id: parent_recording.id)
    rescue ActiveRecord::RecordNotFound,
           RecordingStudioOrderable::RecordingOrderManager::ConfigurationError,
           ActionController::ParameterMissing,
           KeyError
      nil
    end
    # rubocop:enable Metrics/MethodLength

    def selected_order_recording_id(order)
      order.recordings.max_by { |recording| [recording.created_at, recording.id.to_s] }&.id
    end

    def list_params
      params.require(:recording_studio_order).permit(:name)
    end

    def parent_recording_label(parent_recording)
      recordable = parent_recording.recordable
      friendly_name = resolved_parent_recording_name(recordable)
      type_label = resolved_parent_recording_type_label(parent_recording, recordable)
      return "#{type_label} #{friendly_name}" if friendly_name.present?

      "#{parent_recording.recordable_type} #{parent_recording.id}"
    end

    def resolved_parent_recording_name(recordable)
      friendly_name = recording_studio_recordable_name(recordable)
      friendly_name = nil if generic_recordable_name?(recordable, friendly_name)
      friendly_name.presence || recordable.try(:name).presence || recordable.try(:title).presence
    end

    def resolved_parent_recording_type_label(parent_recording, recordable)
      type_label = recording_studio_recordable_type_label(recordable || parent_recording.recordable_type)
      type_label.presence || parent_recording.recordable_type
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
      end.uniq(&:recordable_type).sort_by(&:recordable_type)
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def global_recording_type_rows
      rows_by_type = Hash.new { |hash, key| hash[key] = [] }

      orderable_parent_recordings.each do |parent_recording|
        recording_type_rows(parent_recording).each do |row|
          rows_by_type[row.recordable_type] << row
        end
      end

      rows_by_type.map do |recordable_type, rows|
        representative_row = rows.min_by { |row| row.parent_recording_id.to_s }

        TypeRow.new(
          recordable_type: recordable_type,
          group_key: representative_row.group_key,
          custom_orders_count: rows.sum(&:custom_orders_count),
          parent_recording_id: representative_row.parent_recording_id
        )
      end.sort_by(&:recordable_type)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

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
      named_order_recordings_for(parent_recording, group_key).map do |recording|
        build_named_order_row(recording)
      end
    end

    def named_order_recording_for(parent_recording, group_key, order_recording_id)
      named_order_recordings_for(parent_recording, group_key)
        .find { |recording| recording.id.to_s == order_recording_id.to_s }
    end

    def named_order_recordings_for(parent_recording, group_key)
      RecordingStudioOrderable::RecordingOrderManager.recording_order_recordings(
        parent_recording,
        group_key,
        owner: current_recording_studio_orderable_owner,
        named_only: true
      )
    end

    def build_named_order_row(recording)
      NamedOrderRow.new(
        recording_id: recording.id,
        name: order_display_name(recording.recordable)
      )
    end

    def default_group_key_for(parent_recording)
      order_group_definitions_for(parent_recording, strict: false).values.first&.fetch(:group_key, nil)
    end

    # rubocop:disable Metrics/MethodLength
    def order_group_definitions_for(parent_recording, strict: true)
      recordable_class = resolve_recordable_class(parent_recording)
      unless recordable_class
        raise RecordingStudioOrderable::RecordingOrderManager::ConfigurationError,
              "Unable to resolve recordable class"
      end

      if recordable_class.respond_to?(:recording_studio_order_group_definitions)
        return recordable_class.recording_studio_order_group_definitions
      end

      recordable_class.recording_studio_order_group_definition
      recordable_class.recording_studio_order_group_definitions
    rescue RecordingStudioOrderable::RecordingOrderManager::ConfigurationError, NoMethodError
      return {} unless strict

      raise
    end
    # rubocop:enable Metrics/MethodLength

    def order_display_name(order_record)
      return "Untitled order" unless order_record.respond_to?(:name)

      order_record.name.to_s.strip.presence || "Untitled order"
    end

    def resolve_recordable_class(parent_recording)
      return parent_recording.recordable.class if parent_recording.recordable.present?

      type_name = parent_recording.recordable_type
      if defined?(RecordingStudio) && RecordingStudio.respond_to?(:resolve_recordable_type)
        resolved_type = RecordingStudio.resolve_recordable_type(type_name)
        return resolved_type if resolved_type
      end

      type_name.to_s.safe_constantize
    rescue StandardError
      type_name.to_s.safe_constantize
    end

    def recording_studio_recordable_name(recordable)
      return unless recordable.present?
      return unless defined?(RecordingStudio) && RecordingStudio.respond_to?(:recordable_name)

      RecordingStudio.recordable_name(recordable)
    rescue StandardError
      nil
    end

    def recording_studio_recordable_type_label(recordable_or_type)
      return unless defined?(RecordingStudio) && RecordingStudio.respond_to?(:recordable_type_label)

      RecordingStudio.recordable_type_label(recordable_or_type)
    rescue StandardError
      nil
    end

    def generic_recordable_name?(recordable, value)
      return false if recordable.blank?

      value.to_s == recordable.class.name
    end
  end
  # rubocop:enable Metrics/ClassLength
end
