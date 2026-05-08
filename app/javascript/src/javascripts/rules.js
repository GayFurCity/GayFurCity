import Utility from "./utility";

const Rules = { mode: null };

Rules.toggle_buttons = function (hide = true) {
  const $editOrderLink = $(".edit-order-link");
  const $editCategoryOrderLink = $(".edit-category-order-link");
  const $editQuickOrderLink = $(".edit-quick-order-link");
  const $editOrderExternalLink = $(".edit-order-external-link");
  const $editCategoryOrderExternalLink = $(".edit-category-order-external-link");
  const $editQuickOrderExternalLink = $(".edit-quick-order-external-link");
  const $saveOrderLink = $(".save-order-link");

  if (hide) {
    $saveOrderLink.show();
    $editOrderLink.hide();
    $editOrderExternalLink.hide();
    $editCategoryOrderLink.hide();
    $editCategoryOrderExternalLink.hide();
    $editQuickOrderLink.hide();
    $editQuickOrderExternalLink.hide();
  } else {
    $saveOrderLink.hide();
    $editOrderLink.show();
    $editOrderExternalLink.show();
    $editCategoryOrderLink.show();
    $editCategoryOrderExternalLink.show();
    $editQuickOrderLink.show();
    $editQuickOrderExternalLink.show();

  }
};

Rules.initialize_listeners = function () {
  const $editOrderLink = $(".edit-order-link");
  const $editCategoryOrderLink = $(".edit-category-order-link");
  const $editQuickOrderLink = $(".edit-quick-order-link");
  const $saveOrderLink = $(".save-order-link");
  const $sortableRules = $("#sortable-rules");

  $editOrderLink.on("click.gayfurcity.sorting", function (event) {
    event.preventDefault();
    Rules.toggle_buttons();
    Rules.mode = "rules";
    Rules.sortable();
    Danbooru.notice("Drag and drop to reorder.");
  });

  $editCategoryOrderLink.on("click.gayfurcity.sorting", function (event) {
    event.preventDefault();
    Rules.toggle_buttons();
    Rules.mode = "categories";
    Rules.sortable();
    Danbooru.notice("Drag and drop to reorder.");
  });

  $editQuickOrderLink.on("click.gayfurcity.sorting", function (event) {
    event.preventDefault();
    Rules.toggle_buttons();
    Rules.mode = "quick";
    Rules.sortable();
    Danbooru.notice("Drag and drop to reorder.");
  });

  $saveOrderLink.on("click.gayfurcity.sorting", function (event) {
    event.preventDefault();
    $saveOrderLink.hide();
    $sortableRules.sortable("disable");
    const path = {
      rules: "/rules/reorder.js",
      categories: "/rules/categories/reorder.js",
      quick: "/rules/quick/reorder.js",
    }[Rules.mode];
    $.ajax({
      url: path,
      type: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      data: Rules.reorder_data(Rules.mode),
      dataType: "json",
      success (data) {
        $("#sortable-rules-container").html(data.html);
        Danbooru.notice("Order updated.");
        Rules.toggle_buttons(false);
        Rules.reinitialize_listeners();
      },
      error (data) {
        $saveOrderLink.show();
        if (data.responseJSON.message) {
          Danbooru.error(`Failed to update order: ${data.responseJSON.message}`);
        } else if (data.responseJSON.errors) {
          Danbooru.error(`Failed to update order:<br>${data.responseJSON.errors.map(e => `${e.name}: ${e.message}`).join("<br>")}`);
        } else {
          Danbooru.error("Failed to update order.");
        }

        Rules.sortable();
      },
    });
  });
};

Rules.sortable = function () {
  const $sortableRules = $("#sortable-rules");
  switch (Rules.mode) {
    case "rules": {
      $sortableRules.sortable({
        items: "tbody.rules tr",
      });
      break;
    }

    case "categories": {
      $sortableRules.sortable({
        items: "tbody",
      });
      break;
    }

    case "quick": {
      $sortableRules.sortable({
        items: "tbody tr",
      });
      break;
    }
  }
};

Rules.reinitialize_listeners = function () {
  $(".edit-order-link").off("click.gayfurcity.sorting");
  $(".edit-category-order-link").off("click.gayfurcity.sorting");
  $(".edit-quick-order-link").off("click.gayfurcity.sorting");
  $(".save-order-link").off("click.gayfurcity.sorting");
  Rules.initialize_listeners();
};

Rules.reorder_data = function (mode) {
  if (mode === "rules") {
    const data = [];
    Utility.chunk(Array.from($("table#sortable-rules tbody")), 2).forEach(([category, rulesContainer]) => {
      const rules = Array.from(rulesContainer.querySelectorAll("tr"));
      const category_id = Number(category.dataset.categoryId);
      data.push(...rules.map((r, index) => ({
        id: Number(r.dataset.id),
        order: index + 1,
        category_id,
      })));
    });
    return JSON.stringify(data);
  } else if (mode === "categories") {
    const data = [];
    Array.from($("table#sortable-rules tbody")).forEach((category, index) => {
      data.push({
        id: Number(category.dataset.categoryId),
        order: index + 1,
      });
    });
    return JSON.stringify(data);
  } else {
    const data = [];
    Array.from($("table#sortable-rules tbody tr")).forEach((row, index) => {
      data.push({
        id: Number(row.dataset.id),
        order: index + 1,
      });
    });
    return JSON.stringify(data);

  }
};

$(document).ready(function () {
  if ($("#c-rules #a-order, #c-rules-categories #a-order, #c-rules-quick #a-order").length) {
    Rules.initialize_listeners();
  }
});

export default Rules;
