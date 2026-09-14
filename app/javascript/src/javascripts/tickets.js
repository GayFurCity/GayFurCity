const Ticket = {};

Ticket.initialize_quick_reply = function () {
  const input = $("textarea[name='ticket[message]']");

  $("div.ticket-responses").on("click", "button", function (event) {
    event.preventDefault();

    const $button = $(event.currentTarget);
    input.val($button.attr("data-text"));
  });
};

export default Ticket;

$(function () {
  if ($("#c-tickets #a-show").length) {
    Ticket.initialize_quick_reply();
  }
});
