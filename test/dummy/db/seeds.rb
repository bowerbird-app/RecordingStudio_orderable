user = User.find_or_create_by!(email: "admin@admin.com") do |record|
  record.password = "Password"
  record.password_confirmation = "Password"
end

Current.actor = user

workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
workspace_recording = RecordingStudio.root_recording_for(workspace)

project_recording = DemoRecordingLookup.by_slug(type: "Project", slug: "album-launch")
unless project_recording
  project_recording = workspace_recording.record(Project, actor: user, metadata: { seed: true }, parent_recording: workspace_recording) do |project|
    project.name = "Album Launch"
    project.slug = "album-launch"
  end
end

folder_recording = DemoRecordingLookup.by_slug(type: "Folder", slug: "reference-assets")
unless folder_recording
  folder_recording = workspace_recording.record(Folder, actor: user, metadata: { seed: true }, parent_recording: project_recording) do |folder|
    folder.name = "Reference Assets"
    folder.slug = "reference-assets"
  end
end

%w[mix-notes release-checklist session-notes artwork-brief].each_with_index do |slug, index|
  page_recording = DemoRecordingLookup.by_slug(type: "Page", slug: slug)
  next if page_recording

  title = slug.tr("-", " ").split.map(&:capitalize).join(" ")
  page_recording = workspace_recording.record(Page, actor: user, metadata: { seed: true }, parent_recording: folder_recording) do |page|
    page.title = title
    page.slug = slug
    page.body = "Seeded page used for the sibling order demo."
  end
  page_recording.update!(recording_studio_orderable_position: index)
end

unless DemoRecordingLookup.by_slug(type: "Page", slug: "project-overview")
  workspace_recording.record(Page, actor: user, metadata: { seed: true }, parent_recording: project_recording) do |page|
    page.title = "Project Overview"
    page.slug = "project-overview"
    page.body = "Page under a parent that did not enable Orderable."
  end
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded orderable folder: #{folder_recording.recordable.name}"
puts "Seeded sibling pages under that folder and one unordered page under the project"
