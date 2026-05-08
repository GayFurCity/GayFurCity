import Utility from "./utility";

class PostReplacementRejectionReasons {
  static init (spacing) {
    const $addSpacingBelowLink = $(".add-spacing-below-link");
    const $addSpacingAboveLink = $(".add-spacing-above-link");
    const $editOrderLink = $(".edit-order-link");
    const $saveOrderLink = $(".save-order-link");
    const $addSpacingLink = $(".add-spacing-link");
    const $removeSpacingLink = $(".remove-spacing-link");
    const $sortablePostReplacementRejectionReasons = $("#post-replacement-rejection-reasons-table tbody");
    $addSpacingBelowLink.on("click.gayfurcity.spacing", function (event) {
      event.preventDefault();
      spacing.insertAfter($(this).closest("tr"));
      PostReplacementRejectionReasons.reinitRemoveListener();
    });

    $addSpacingAboveLink.on("click.gayfurcity.spacing", function (event) {
      event.preventDefault();
      spacing.insertBefore($(this).closest("tr"));
      PostReplacementRejectionReasons.reinitRemoveListener();
    });

    $editOrderLink.on("click.gayfurcity.sorting", function (event) {
      event.preventDefault();
      $saveOrderLink.show();
      $editOrderLink.hide();
      $addSpacingLink.show();
      $removeSpacingLink.show();
      $sortablePostReplacementRejectionReasons.sortable();
      Utility.notice("Drag and drop to reorder.");
    });

    $saveOrderLink.on("click.gayfurcity.sorting", function (event) {
      event.preventDefault();
      $saveOrderLink.hide();
      $addSpacingLink.hide();
      $removeSpacingLink.hide();
      $sortablePostReplacementRejectionReasons.sortable("disable");
      $.ajax({
        url: "/posts/replacements/rejection_reasons/reorder.json",
        type: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        data: PostReplacementRejectionReasons.reorderData(),
        success () {
          Utility.notice("Order updated.");
          $editOrderLink.show();
        },
        error () {
          Utility.error("Failed to update order.");
          $saveOrderLink.show();
          $sortablePostReplacementRejectionReasons.sortable();
        },
      });
    });
    this.reinitRemoveListener();
  }

  static reinitRemoveListener () {
    const $removeSpacingLink = $(".remove-spacing-link");
    $removeSpacingLink.off("click.gayfurcity.spacing");
    $removeSpacingLink.on("click.gayfurcity.spacing", function (event) {
      event.preventDefault();
      $(this).closest("tr").remove();
    });
  }

  static reorderData () {
    return JSON.stringify(Array.from($("#post-replacement-rejection-reasons-table tr")).slice(1).map((element, index) => ({ id: element.dataset.id ? Number(element.dataset.id) : null, order: index + 1 })));
  }
}

export default PostReplacementRejectionReasons;
