RecordingStudioOrderable install complete.

Next steps:

1. Review `config/initializers/recording_studio_orderable.rb`.
2. Run `bin/rails generate recording_studio_orderable:migrations` and `bin/rails db:migrate`.
3. Opt parent recordables into sibling ordering:

   ```ruby
   class Folder < ApplicationRecord
     recording_studio_recordable label: "Folder", plural_label: "Folders",
                                 root: false, allowed_parent_types: %w[Workspace Project]

     include RecordingStudio::Capabilities::Orderable.to(allows: ["Page"])
   end
   ```

   Installing the gem does not enable order on every recordable.
4. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
