# frozen_string_literal: true

module RecordingStudioOrderable
  module RecordingExtensions
    def recording_order_recordings(group_key = nil, owner: nil)
      RecordingStudioOrderable::RecordingOrderManager.recording_order_recordings(self, group_key, owner: owner)
    end

    def recording_orders(owner: nil)
      RecordingStudioOrderable::RecordingOrderManager.recording_orders(self, owner: owner)
    end

    def recording_order_recording_for(group_key = nil, owner: nil)
      RecordingStudioOrderable::RecordingOrderManager.recording_order_recording_for(self, group_key, owner: owner)
    end

    def recording_order_for(group_key = nil, owner: nil)
      RecordingStudioOrderable::RecordingOrderManager.recording_order_for(self, group_key, owner: owner)
    end

    def find_or_create_recording_order!(group_key = nil, **options)
      RecordingStudioOrderable::RecordingOrderManager.find_or_create_recording_order!(self, group_key, **options)
    end

    def children_for_order_group(group_key = nil)
      RecordingStudioOrderable::RecordingOrderManager.eligible_children_for(self, group_key)
    end

    def ordered_children_for(group_key = nil, owner: nil)
      RecordingStudioOrderable::RecordingOrderManager.ordered_children_for(self, group_key, owner: owner)
    end
  end
end
