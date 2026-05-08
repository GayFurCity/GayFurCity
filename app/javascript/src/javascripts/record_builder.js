const RecordBuilder = {};

RecordBuilder.initialize = function () {
  fetch("/rules/builder.json")
    .then(response => response.json())
    .then(data => {
      RecordBuilder.section = data.section;
      RecordBuilder.quickMod = data.quick_mod;
      RecordBuilder.rules = data.rules;
      RecordBuilder.reinitialize_listeners();
    });
};

RecordBuilder.get_input = function () {
  if ($("#c-users-feedbacks").length) {
    return $(".user_feedback_body textarea");
  } else if ($("#c-bans").length) {
    return $(".ban_reason textarea");
  }
};

RecordBuilder.generate_record_text = function () {
  const result = [];
  for (const form of $("form.record-builder")) {
    result.push(RecordBuilder.process_form($(form)));
  }

  RecordBuilder.get_input().val(result.join("\n"));
};

RecordBuilder.process_form = function (form) {
  const reason = form.data("reason") || "";

  const sourceList = (form.data("sources") || "").split("\n").filter(n => n.trim());
  let sourceOutput = [];
  if (sourceList.length === 1) {
    sourceOutput = [`"[Source]":${RecordBuilder.process_source(sourceList[0])}`];
  } else {
    for (const [index, source] of sourceList.entries()) {
      sourceOutput.push(`"[${index + 1}]":${RecordBuilder.process_source(source)}`);
    }
  }

  const rulesOutput = [];
  for (const name of (form.data("buttons") || [])) {
    const rule = RecordBuilder.rules[name];
    rulesOutput.push(`[section=${rule.name}]\n${rule.description}\n\n"[Code of Conduct - ${rule.name}]":/rules#${name}[/section]`);
  }

  const
    sourceOutputJoined = sourceOutput.join(" "),
    sourceReason = reason.includes("$S")
      ? reason.replace("$S", sourceOutputJoined)
      : ((reason.length > 0 ? (`${reason} `) : "") + sourceOutputJoined),
    rulesOutputJoined = rulesOutput.join("\n");
  return sourceReason + (rulesOutputJoined ? (`\n\n${rulesOutputJoined}\n`) : "");
};

RecordBuilder.process_source = function (source) {
  return decodeURI(source)
    .trim()
    .replace(/https?:\/\/gayfur\.city\//g, "/") // Make links relative
    .replace(/\/posts\/(\d+)#comment-(\d+)/g, "/comments/$2") // Convert comment links
    .replace(/\/forums\/topics\/(\d+)(?:\?page=\d+)?#forum_post_(\d+)/g, "/forums/posts/$2") // Convert forum post links
    .replace(/\?lr=\d+&/, "?") // Trim the tag history links
    .replace(/\?commit=Search&/, "?") // Get rid of the useless search parameter

    .replace(/post #(\d+)/, "/posts/$1")
    .replace(/comment #(\d+)/, "/comments/$1")
    .replace(/topic #(\d+)/, "/forums/topics/$1")
    .replace(/post changes #(\d+)/, "/posts/versions?search[post_id]=$1");
};

RecordBuilder.reinitialize_listeners = function () {
  $(".add-section-button").off("click");
  $(".add-section-button").on("click", function (event) {
    event.preventDefault();
    const $button = $(event.currentTarget);
    const $wrapper = $button.closest(".record-wrapper");
    $wrapper.append(RecordBuilder.section.replaceAll("{id}", RecordBuilder.random_id()));
    RecordBuilder.reinitialize_listeners();
  });

  $(".remove-section-button").off("click");
  $(".remove-section-button").on("click", function (event) {
    event.preventDefault();
    const $button = $(event.currentTarget);
    $button.closest(".record-builder").remove();
    RecordBuilder.generate_record_text();
  });

  $(".quick-record").off("click", "a.quick-record-link");
  $(".quick-record").on("click", "a.quick-record-link", function (event) {
    event.preventDefault();

    const $button = $(event.currentTarget);
    const $parent = $button.closest(".record-builder");
    $parent.find("select.record-reason").val($button.attr("data-reason")).trigger("rb:change", true);
    $parent.find("button.rules-button").removeClass("active");
    $parent.find(`button.rules-button[data-name="${$button.attr("data-rule")}"]`).addClass("active");
    $parent.trigger("rb:buttons", true);
    RecordBuilder.generate_record_text();
  });

  $(".record-reason").off("change rb:change");
  $(".record-reason").on("change rb:change", function (event) {
    const $select = $(event.currentTarget);
    const $parent = $select.closest(".record-builder");
    const $selected = $select.find("option:selected");
    $parent.find("button.rules-button").removeClass("active");
    $parent.find(`button.rules-button[data-name="${$selected.attr("data-rule")}"]`).addClass("active");
    $parent.trigger("rb:buttons", true);
    $parent.find(".custom-reason").val($select.val() || "").trigger("rb:input");
  });

  const inputTimers = {};
  $(".custom-reason").off("input");
  $(".custom-reason").on("input", function (event, preventChange) {
    const $input = $(event.currentTarget);
    clearTimeout(inputTimers[$input.attr("id")]);
    inputTimers[$input.attr("id")] = setTimeout(() => {
      $input.trigger("rb:input", preventChange);
    }, 200);
  });

  $(".custom-reason").off("propertychange rb:input");
  $(".custom-reason").on("propertychange rb:input", function (event, preventChange) {
    const $input = $(event.currentTarget);
    const $parent = $input.closest(".record-builder");
    $parent.data("reason", $input.val());
    if (!preventChange) RecordBuilder.generate_record_text();
  });

  $(".record-sources").off("input propertychange");
  $(".record-sources").on("input propertychange", function (event) {
    const $input = $(event.currentTarget);
    const $parent = $input.closest(".record-builder");
    clearTimeout(inputTimers[$input.attr("id")]);
    inputTimers[$input.attr("id")] = setTimeout(() => {
      $parent.data("sources", $input.val());
      RecordBuilder.generate_record_text();
    }, 200);
  });

  $(".rules-button").off("click");
  $(".rules-button").on("click", function (event) {
    event.preventDefault();
    const $button = $(event.currentTarget);
    const $parent = $button.closest(".record-builder");
    $button.toggleClass("active");
    $parent.trigger("rb:buttons");
  });

  $(".record-builder").off("rb:buttons");
  $(".record-builder").on("rb:buttons", function (event, preventChange) {
    const $builder = $(event.currentTarget);
    const $wrapper = $builder.find(".rule-wrapper");
    const buttons = [];
    for (const button of $wrapper.find(".rules-button.active")) {
      buttons.push($(button).attr("data-name"));
    }

    $builder.data("buttons", buttons);
    if (!preventChange) RecordBuilder.generate_record_text();
  });
};

RecordBuilder.random_id = function (length = 6) {
  let result = "";
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
    charLength = chars.length;
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * charLength));
  }
  return result;
};

export default RecordBuilder;

$(function () {
  if ($("#c-users-feedbacks, #c-bans").length) {
    RecordBuilder.initialize();
  }
});
