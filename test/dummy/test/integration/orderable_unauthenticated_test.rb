# frozen_string_literal: true

require "test_helper"

class OrderableUnauthenticatedTest < ActionDispatch::IntegrationTest
  # 200 records current behaviour. The engine overview has no authenticate_user!.
  # The auth pull request does not flip this page. It maps a denied reorder to
  # HTTP 403 on the host actions, and this overview stays open.
  test "overview is reachable without a signed-in user" do
    get "/recording_studio_orderable"

    assert_response :success
    assert_includes response.body, "Recording Studio Orderable"
  end

  test "reorder without a signed-in user is sent to sign in" do
    patch reorder_pages_path, params: { ordered_recording_ids: ["not-signed-in"] }

    assert_redirected_to new_user_session_path
  end

  test "move without a signed-in user is sent to sign in" do
    patch move_page_path("00000000-0000-0000-0000-000000000001"), params: { to_index: 0 }

    assert_redirected_to new_user_session_path
  end
end
