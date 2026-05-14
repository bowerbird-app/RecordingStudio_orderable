module ApplicationHelper
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
end
