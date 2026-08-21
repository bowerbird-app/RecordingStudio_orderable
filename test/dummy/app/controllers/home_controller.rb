class HomeController < ApplicationController
  def index
    load_home_demo_state
  end

  def move
    load_home_demo_state

    unless @folder_recording
      redirect_to root_path, alert: "No orderable folder is available."
      return
    end

    moving = @folder_recording.recording_studio_orderable_children.find_by(id: params[:id])
    unless moving
      redirect_to root_path, alert: "That page is not an orderable child of the demo folder."
      return
    end

    @folder_recording.recording_studio_orderable_move!(
      moving,
      to_index: params.fetch(:to_index).to_i,
      actor: current_user,
      metadata: { source: "dummy_home_move" }
    )

    redirect_to root_path, notice: "Updated page order."
  end

  private

  def load_home_demo_state
    @workspace = Workspace.first
    @workspace_recording = DemoRecordingLookup.workspace_root
    @folder_recording = DemoRecordingLookup.by_slug(type: "Folder", slug: "reference-assets")
    @ordered_pages = @folder_recording&.recording_studio_orderable_children.to_a || []
    @unordered_project_recording = DemoRecordingLookup.by_slug(type: "Project", slug: "album-launch")
  end
end
