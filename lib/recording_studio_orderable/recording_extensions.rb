# frozen_string_literal: true

module RecordingStudioOrderable
  module RecordingExtensions
    def recording_order_recordings
      RecordingStudioOrderable::RecordingOrderManager.recording_order_recordings(self)
    end

    def recording_orders
      RecordingStudioOrderable::RecordingOrderManager.recording_orders(self)
    end

    def recording_order_recording_for(group_name = nil)
      RecordingStudioOrderable::RecordingOrderManager.recording_order_recording_for(self, group_name)
    end

    def recording_order_for(group_name = nil)
      RecordingStudioOrderable::RecordingOrderManager.recording_order_for(self, group_name)
    end

    def find_or_create_recording_order!(group_name = nil, **options)
      RecordingStudioOrderable::RecordingOrderManager.find_or_create_recording_order!(self, group_name, **options)
    end

    def children_for_order_group(group_name = nil)
      RecordingStudioOrderable::RecordingOrderManager.eligible_children_for(self, group_name)
    end

    def ordered_children_for(group_name = nil)
      RecordingStudioOrderable::RecordingOrderManager.ordered_children_for(self, group_name)
    end
  end
end
