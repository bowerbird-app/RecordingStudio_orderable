# frozen_string_literal: true

require "application_system_test_case"

class OrderRefreshTest < ApplicationSystemTestCase
  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    Current.actor = @user
    seed_demo_tree!
  end

  test "saving the reorder modal refreshes the list behind it" do
    sign_in_through_the_form
    visit root_path

    assert_selector "#order-demo-table"
    before = page_names
    click_button "Reorder in modal"
    assert_selector "#reorder-pages-modal [data-flat-pack--table-sortable-target='row']", count: before.length

    result = page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      const table = document.querySelector("#reorder-pages-modal [data-controller~='flat-pack--table-sortable']")
      const controller = window.Stimulus.getControllerForElementAndIdentifier(table, "flat-pack--table-sortable")
      const tbody = controller.rowTargets[0].parentNode
      controller.rowTargets.slice().reverse().forEach((row) => tbody.appendChild(row))
      controller.saveOrder().then(() => done("saved")).catch((error) => {
        done(error && error.message ? error.message : "reorder failed")
      })
    JS

    assert_equal "saved", result
    assert_equal before.reverse, names_after_refresh(before.reverse)
  end

  private

  def sign_in_through_the_form
    visit new_user_session_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "Password"
    click_button "Sign In"
    assert_selector "h1", text: "Order demo"
  end

  def page_names
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#order-demo-table tbody tr")).map((row) => row.cells[1].innerText.trim())
    JS
  end

  def names_after_refresh(expected)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    loop do
      begin
        names = page_names
        return names if names == expected
      rescue Selenium::WebDriver::Error::StaleElementReferenceError, Selenium::WebDriver::Error::JavascriptError
        nil
      end
      raise "list did not refresh" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.1
    end
  end

  def seed_demo_tree!
    workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    workspace_recording = RecordingStudio.root_recording_for(workspace)
    project = find_or_record!(workspace_recording, Project, "album-launch") do |record|
      record.name = "Album Launch"
      record.slug = "album-launch"
    end
    folder = find_or_record!(workspace_recording, Folder, "reference-assets", parent: project) do |record|
      record.name = "Reference Assets"
      record.slug = "reference-assets"
    end

    %w[mix-notes release-checklist].each_with_index do |slug, index|
      page_recording = find_or_record!(workspace_recording, Page, slug, parent: folder) do |record|
        record.title = slug.tr("-", " ").split.map(&:capitalize).join(" ")
        record.slug = slug
        record.body = "Dummy system page"
      end
      page_recording.update!(recording_studio_orderable_position: index)
    end
  end

  def find_or_record!(workspace_recording, type, slug, parent: workspace_recording, &)
    existing = DemoRecordingLookup.by_slug(type: type.name, slug: slug)
    return existing if existing

    workspace_recording.record(type, actor: @user, metadata: { seed: true }, parent_recording: parent, &)
  end
end
