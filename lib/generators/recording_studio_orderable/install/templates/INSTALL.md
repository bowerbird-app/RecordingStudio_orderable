RecordingStudioOrderable install complete.

Next steps:

1. Review `config/initializers/recording_studio_orderable.rb`.
  Make sure it defines `authenticate_controller`, `current_owner_resolver`, and `authorize_parent_recording` for your host app.
2. Run `rails generate recording_studio_orderable:migrations`.
  If your app already has duplicate unnamed orders for the same parent/group/owner scope, the migration will recover them by renaming older duplicates before adding the unique index.
3. Opt parent recordables into order groups, for example:
   ```ruby
   class Folder < ApplicationRecord
     include RecordingStudioOrderable::OrderableRecordable

     recording_studio_order_group :pages, allows: ["Page"]
   end
   ```
4. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
