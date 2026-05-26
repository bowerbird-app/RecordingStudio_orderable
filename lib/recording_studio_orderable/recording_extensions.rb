# frozen_string_literal: true

module RecordingStudioOrderable
  module RecordingExtensions
    def recording_order_recordings(group_key = nil, owner: nil, named_only: false, orderable_name: nil)
      RecordingStudioOrderable::RecordingOrderManager.recording_order_recordings(
        self,
        group_key,
        owner: owner,
        named_only: named_only,
        orderable_name: orderable_name
      )
    end

    def recording_orders(owner: nil, group: nil, orderable_name: nil, named_only: false)
      RecordingStudioOrderable::RecordingOrderManager.recording_orders(
        self,
        owner: owner,
        group: group,
        orderable_name: orderable_name,
        named_only: named_only
      )
    end

    def recording_order_recording_for(group_key = nil, owner: nil)
      RecordingStudioOrderable::RecordingOrderManager.recording_order_recording_for(self, group_key, owner: owner)
    end

    def default_recording_order(group_key = nil, owner: nil)
      RecordingStudioOrderable::RecordingOrderManager.default_recording_order(self, group_key, owner: owner)
    end

    def find_recording_order_by_id(order_recording_id, group_key: nil,
                                   owner: RecordingStudioOrderable::RecordingOrderManager::OWNER_GUARDRAIL_UNSET)
      RecordingStudioOrderable::RecordingOrderManager.find_recording_order_by_id(
        self,
        order_recording_id,
        group_key: group_key,
        owner: owner
      )
    end

    def find_or_create_recording_order!(group_key = nil, **)
      RecordingStudioOrderable::RecordingOrderManager.find_or_create_recording_order!(self, group_key, **)
    end

    def eligible_order_items(group_key = nil)
      RecordingStudioOrderable::RecordingOrderManager.eligible_items_for(self, group_key)
    end

    def ordered_items_for(group_key = nil, owner: nil)
      RecordingStudioOrderable::RecordingOrderManager.ordered_items_for(self, group_key, owner: owner)
    end
  end
end
