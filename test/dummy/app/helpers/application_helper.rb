module ApplicationHelper
  def custom_event_demo?(demo_variant)
    demo_variant.to_s != "flash_message"
  end

  def page_order_page_cell(row)
    safe_join([
      content_tag(:span, row.recording.recordable.title, class: "font-medium"),
      render(
        FlatPack::Badge::Component.new(
          text: row.explicitly_ordered ? "Explicit" : "Auto-appended eligible page",
          style: row.explicitly_ordered ? :info : :warning,
          size: :sm,
          class: "ml-2"
        )
      )
    ])
  end

  def page_order_move_buttons
    safe_join([
      render(
        FlatPack::Button::Component.new(
          text: "Up",
          style: :ghost,
          size: :sm,
          type: "button",
          data: { action: "click->flat-pack--table-sortable#moveUp" }
        )
      ),
      render(
        FlatPack::Button::Component.new(
          text: "Down",
          style: :ghost,
          size: :sm,
          type: "button",
          class: "ml-2",
          data: { action: "click->flat-pack--table-sortable#moveDown" }
        )
      )
    ])
  end

  def page_order_demo_title(demo_variant)
    if custom_event_demo?(demo_variant)
      "Example 1: Custom Event"
    else
      "Example 2: Flash Message"
    end
  end

  def page_order_demo_description(demo_variant)
    if custom_event_demo?(demo_variant)
      "Drag to reorder without refreshing the page. Each save dispatches recordingstudio:order:updated so the host app can own notifications."
    else
      "Drag to reorder without send_custom_event. After each save, the client revisits the page so the standard Rails flash notice can render."
    end
  end

  def page_order_demo_badge_text(demo_variant)
    if custom_event_demo?(demo_variant)
      "Changes save after each move"
    else
      "Changes save, then revisit the page for flash notice"
    end
  end

  def page_order_demo_status_copy(demo_variant, page_order, page_order_recording)
    if custom_event_demo?(demo_variant)
      "Dispatching recordingstudio:order:updated for #{page_order.name.presence || "Untitled list"} on recording #{page_order_recording.id}"
    else
      "Revisiting with a flash notice for #{page_order.name.presence || "Untitled list"} on recording #{page_order_recording.id}"
    end
  end

  def page_order_demo_code_sample(demo_variant)
    if custom_event_demo?(demo_variant)
      <<~CODE
        <div data-controller="order-update-alert page-order-form"
             data-page-order-form-send-custom-event-value="true"
             data-action="table:reordered->page-order-form#sync">
          <!-- draggable FlatPack table -->
        </div>

        document.addEventListener("recordingstudio:order:updated", (event) => {
          console.log(event.detail.message)
        })
      CODE
    else
      <<~CODE
        <div data-controller="page-order-form"
             data-action="table:reordered->page-order-form#sync">
          <!-- draggable FlatPack table -->
        </div>

        render json: {
          redirect_url: root_path(selected_order_recording_id: updated_recording.id)
        }

        window.Turbo.visit(payload.redirect_url)
      CODE
    end
  end
end
