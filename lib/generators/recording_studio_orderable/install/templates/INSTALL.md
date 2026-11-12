RecordingStudioOrderable install complete.

Next steps:

1. Review `config/initializers/recording_studio_orderable.rb`.
2. Install Recording Studio Accessible, enable `:accessible` on roots, and grant `:edit` to actors who may reorder.
3. Run `bin/rails generate recording_studio_orderable:migrations` and `bin/rails db:migrate`.
4. Opt parent recordables into sibling ordering:

   ```ruby
   class Folder < ApplicationRecord
     recording_studio_recordable label: "Folder", plural_label: "Folders",
                                 root: false, allowed_parent_types: %w[Workspace Project]

     include RecordingStudio::Capabilities::Orderable.to(allows: ["Page"])
   end
   ```

   Installing the gem does not enable order on every recordable.
5. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
6. Optional: install and mount Recording Studio API. This gem then registers `reorder` and `move_position`. List those actions on orderable types. MCP uses that same API. Turn on `:api_access_point` on roots that hold API clients.
