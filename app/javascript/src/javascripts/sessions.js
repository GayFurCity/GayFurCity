const Sessions = {
  init_signup_info_panel () {
    const $modal = $("#register-modal");
    const $form = $("#signup-form");
    const $toggle = $("#signup-info-toggle");
    if ($modal.length === 0 || $form.length === 0 || $toggle.length === 0) return;

    let dismissed = false;

    const set_expanded = expanded => {
      $modal.toggleClass("expanded", expanded);
      $toggle.attr("aria-expanded", expanded);
      if (!expanded) dismissed = true;
    };

    $toggle.on("click.sessions", function () {
      set_expanded(!$modal.hasClass("expanded"));
    });

    $("#signup-info-close").on("click.sessions", function () {
      set_expanded(false);
    });

    $form.on("input.sessions change.sessions", "input, select", function () {
      if (!dismissed && !$modal.hasClass("expanded")) {
        set_expanded(true);
      }
    });
  },

  init_signup_disabled_toggle () {
    const $modal = $("#register-modal");
    const $toggle = $("#signup-disabled-toggle");
    if ($modal.length === 0 || $toggle.length === 0) return;

    $toggle.on("click.sessions", function () {
      $modal.toggleClass("disabled");
    });
  },
};

$(document).ready(function () {
  Sessions.init_signup_info_panel();
  Sessions.init_signup_disabled_toggle();
});

export default Sessions;
