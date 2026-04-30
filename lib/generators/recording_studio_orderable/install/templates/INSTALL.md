RecordingStudioOrderable install complete.

Next steps:

1. Review `config/initializers/recording_studio_orderable.rb`.
2. Run `rails generate recording_studio_orderable:migrations`.
3. Opt parent recordables into order groups, for example:
   ```ruby
   class Folder < ApplicationRecord
     include RecordingStudioOrderable::OrderableRecordable

     recording_studio_order_group :pages, allows: ["Page"]
   end
   ```
4. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
