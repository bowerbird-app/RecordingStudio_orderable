class Folder < ApplicationRecord
  include RecordingStudioOrderable::OrderableRecordable

  recording_studio_order_group :pages, allows: [ "Page" ]
end
