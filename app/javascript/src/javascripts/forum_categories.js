import Utility from "./utility";

class ForumCategories {
  static initialize_listeners () {
    const $saveOrderLink = $(".save-order-link");
    const $editOrderLink = $(".edit-order-link");
    const $sortableCategories = $("#forum-categories-table tbody");
    $editOrderLink.on("click.gayfurcity.sorting", function (event) {
      event.preventDefault();
      $saveOrderLink.show();
      $editOrderLink.hide();
      $sortableCategories.sortable();
      Utility.notice("Drag and drop to reorder.");
    });

    $saveOrderLink.on("click.gayfurcity.sorting", function (event) {
      event.preventDefault();
      $saveOrderLink.hide();
      $editOrderLink.show();
      $sortableCategories.sortable("disable");
      $.ajax({
        url: "/forums/categories/reorder.json",
        type: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        data: ForumCategories.reorderData(),
        success () {
          Utility.notice("Order updated.");
          $editOrderLink.show();
        },
        error () {
          Utility.error("Failed to update order.");
          $saveOrderLink.show();
          $sortableCategories.sortable();
        },
      });
    });
  }

  static reorderData () {
    return JSON.stringify(Array.from($("#forum-categories-table tr")).slice(1).map((element, index) => ({ id: Number(element.dataset.id), order: index + 1 })));
  }
}


$(function () {
  if ($("#c-forums-categories #a-show").length) {
    ForumCategories.initialize_listeners();
  }
});
