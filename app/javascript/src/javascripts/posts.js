import Utility from "./utility";
import ZingTouch from "zingtouch";
import Note from "./notes";
import { SendQueue } from "./send_queue";
import Shortcuts from "./shortcuts";
import LStorage from "./utility/storage";
import PostSet from "./post_sets";
import Blacklist from "./blacklists";
import Favorite from "./favorites";
import Uploader from "./uploader";
import CurrentUser from "./models/CurrentUser";

let Post = {};

Post.pending_update_count = 0;
Post.resizeMode = "unknown";
Post._blobFrameMap = {};

Post.initialize_all = async function () {

  if ($("#c-posts").length) {
    this.initialize_shortcuts();
    this.initialize_collapse();
    this.initialize_tag_actions();
  }

  if ($("#c-posts #a-index").length) {
    this.initialize_gestures();
    this.initialize_vote_buttons();
  }

  if ($("#c-posts #a-show").length) {
    this.initialize_links();
    this.initialize_post_relationship_previews();
    this.initialize_post_sections();
    this.initialize_resize();
    this.initialize_gestures();
    this.initialize_voting();
    this.initialize_moderation();
    this.initialize_hide_notes();
    this.initialize_thumbnail_frame_preview();
    if (CurrentUser.isMember) await this.initialize_upload_settings();
  }

  if ($("#p-index-by-post").length)
    this.initialize_voting();

  if ($("#c-posts #a-show, #c-uploads #a-new").length) {
    this.initialize_edit_dialog();
  }

  if ($("div.set-nav").length) {
    const sets = $("div.set-nav span.set-name");
    for (const set of sets) {
      const removeButton = $(set).find("a#remove-from-set-button");
      removeButton.on("click", (event) => {
        event.preventDefault();
        const setID = set.dataset.setId;
        const setName = set.dataset.setName;
        const postID = Post.currentPost().id;
        PostSet.remove_post(setID, postID, (data) => `<a href="/post_sets/${setID}">${setName}</a>: <a href="/posts/${postID}">post #${postID}</a> removed (${data.post_count} total)`);
        // debating if we should remove the element or not
        // set.parentElement.remove();
      });
    }
  }

  $(document).on("danbooru:open-post-edit-tab", () => Shortcuts.disabled = true);
  $(document).on("danbooru:open-post-edit-tab", () => $("#post_tag_string").focus());
  $(document).on("danbooru:close-post-edit-tab", () => Shortcuts.disabled = false);

  var $fields_multiple = $("[data-autocomplete=\"tag-edit\"]");
  $fields_multiple.on("keypress.danbooru", Post.update_tag_count);
  $fields_multiple.on("click", Post.update_tag_count);
};

Post.initialize_tag_actions = function () {
  $(".blacklist-tag-toggle").on("click", async function (event) {
    event.preventDefault();
    const tag = $(event.currentTarget).closest(".tag-actions").data("tag");
    const blacklist = JSON.parse(Utility.meta("blacklisted-tags") || "[]");
    const idx = blacklist.indexOf(tag);

    if (idx === -1) {
      blacklist.push(tag);
    } else {
      blacklist.splice(idx, 1);
    }

    SendQueue.add(function () {
      $.ajax({
        method: "POST",
        url: "/users/update.json",
        data: {
          "user[blacklisted_tags]": blacklist.join("\n"),
        },
        success: function () {
          if (idx === -1) {
            Utility.notice(`Added tag "${tag}" to blacklist`);
          } else {
            Utility.notice(`Removed tag "${tag}" from blacklist`);
          }
          $("meta[name=blacklisted-tags]").attr("content", JSON.stringify(blacklist));
          Blacklist.initialize_all();
        },
        error: function (data) {
          Utility.error("Error:" + data);
        },
      });
    });
  });

  $(".tag-action-follow").on("click", function (event) {
    event.preventDefault();
    const $link = $(event.currentTarget).find("a.follow-button-minor");
    const tag = $(event.currentTarget).closest(".tag-actions").data("tag");
    const followed = $link.attr("data-followed") === "true";

    SendQueue.add(function () {
      $.ajax({
        type: "PUT",
        url: `/tags/${encodeURIComponent(tag)}/${followed ? "un" : ""}follow.json`,
        dataType: "json",
        success: function () {
          if (followed) {
            Utility.notice(`Removed follow for "${tag}"`);
            $link.attr("data-followed", false);
          } else {
            Utility.notice(`Added follow for "${tag}"`);
            $link.attr("data-followed", true);
          }
        },
        error: function (data) {
          Utility.error("Error:" + data);
        },
      });
    });
  });
};

Post.initialize_moderation = function () {
  $("#unapprove-post-link").on("click", e => {
    Post.unapprove($(e.target).data("pid"));
    e.preventDefault();
  });
  $(".unflag-post-link").on("click", e => {
    const $e = $(e.target);
    Post.unflag($e.data("pid"), $e.data("type"));
    e.preventDefault();
  });
  $(".move-flag-to-parent-link").on("click", e => {
    e.preventDefault();
    const $e = $(e.target);
    const post_id = $e.data("pid");
    const parent_id = $e.data("parent-id");

    if (confirm("Move flag to parent?"))
      Post.move_flag_to_parent(post_id, parent_id);
  });
};

Post.initialize_collapse = function () {
  $(".tag-list-header").on("click", function (e) {
    const category = $(e.target).data("category");
    $(`.${category}-tag-list`).toggle();
    $(e.target).toggleClass("hidden-category");
    e.preventDefault();
  });
};

Post.initialize_voting = function () {
  $(document).on("click.danbooru.post", ".post-vote-up-link", Post.vote_up);
  $(document).on("click.danbooru.post", ".post-vote-down-link", Post.vote_down);
};

Post.initialize_edit_dialog = function () {
  $("#open-edit-dialog").show().on("click.danbooru", function (e) {
    Post.open_edit_dialog();
    e.preventDefault();
  });
};

Post.open_edit_dialog = function () {
  if ($("#edit-dialog").length === 1) {
    return;
  }

  $(document).trigger("danbooru:open-post-edit-dialog");

  $("#edit").show();
  $("#comments").hide();
  $("#post-sections li").removeClass("active");
  $("#post-edit-link").parent("li").addClass("active");

  var $tag_string = $("#post_tag_string");
  $("div.input").has($tag_string).prevAll().hide();
  $("#open-edit-dialog").hide();

  var dialog = $("<div/>").attr("id", "edit-dialog");
  $("#form").appendTo(dialog);
  dialog.dialog({
    title: "Edit tags",
    width: $(window).width() * 0.6,
    position: {
      my: "right",
      at: "right-20",
      of: window,
    },
    drag: function () {
      if (Utility.meta("enable-autocomplete") === "true") {
        $tag_string.data("uiAutocomplete").close();
      }
    },
    close: Post.close_edit_dialog,
  });
  dialog.dialog("widget").draggable("option", "containment", "none");

  var pin_button = $("<button/>").button({icons: {primary: "ui-icon-pin-w"}, label: "pin", text: false});
  pin_button.css({width: "20px", height: "20px", position: "absolute", right: "28.4px"});
  dialog.parent().children(".ui-dialog-titlebar").append(pin_button);
  pin_button.on("click.danbooru", function () {
    var dialog_widget = $(".ui-dialog:has(#edit-dialog)");
    var pos = dialog_widget.offset();

    if (dialog_widget.css("position") === "absolute") {
      pos.left -= $(window).scrollLeft();
      pos.top -= $(window).scrollTop();
      dialog_widget.offset(pos).css({ position: "fixed" });
      dialog.dialog("option", "resize", function () {
        dialog_widget.css({ position: "fixed" });
      });

      pin_button.button("option", "icons", {primary: "ui-icon-pin-s"});
    } else {
      pos.left += $(window).scrollLeft();
      pos.top += $(window).scrollTop();
      dialog_widget.offset(pos).css({ position: "absolute" });
      dialog.dialog("option", "resize", function () { /* do nothing */ });

      pin_button.button("option", "icons", {primary: "ui-icon-pin-w"});
    }
  });

  dialog.parent().mouseout(function () {
    dialog.parent().css({"opacity": 0.6, "transition": "opacity .4s ease"});
  }).mouseover(function () {
    dialog.parent().css({"opacity": 1, "transition": "opacity .2s ease"});
  });

  $tag_string.css({"resize": "none", "width": "100%"});
  $tag_string.focus().selectEnd().height($tag_string[0].scrollHeight);
};

Post.close_edit_dialog = function () {
  $("#form").appendTo($("#c-posts #edit,#c-uploads #a-new"));
  $("#edit-dialog").remove();
  var $tag_string = $("#post_tag_string");
  $("div.input").has($tag_string).prevAll().show();
  $("#open-edit-dialog").show();
  $tag_string.css({"resize": "", "width": ""});
  $(document).trigger("danbooru:close-post-edit-dialog");
};

Post.has_next_target = function () {
  return $(".paginator a[rel~=next]").length || $(".search-seq-nav a[rel~=next]").length || $(".pool-nav li.pool-selected-true a[rel~=next], .set-nav a.active[rel~=next]").length;
};

Post.has_prev_target = function () {
  return $(".paginator a[rel~=prev]").length || $(".search-seq-nav a[rel~=prev]").length || $(".pool-nav li.pool-selected-true a[rel~=prev], .set-nav a.active[rel~=prev]").length;
};

/**
 * Swipe gesture recognizer that works by averaging the angle/distance/velocity of a gesture path and returning the result.
 * This improves accuracy over the default Swipe gesture, which only uses the last two points to calculate angle/velocity,
 * leading to false detections when a gesture path bends at the end.
 */
class E6Swipe extends ZingTouch.Swipe {
  constructor (options) {
    super(options);
    this.type = "e6swipe";
    this.minDistance = 150;
  }

  end (inputs) {
    function getAngle (a, b) {
      return Math.atan2(b[1] - a[1], b[0] - a[0]);
    }
    function getVelocity (a, b) {
      const dist = distanceBetweenTwoPoints([a[0], a[1]], [b[0], b[1]]);
      return dist / (b[2] - a[2]);
    }
    function distanceBetweenTwoPoints (a, b) {
      return Math.hypot(b[0] - a[0], b[1] - a[1]);
    }

    // Swipe gestures are always exactly one point in size.
    if (this.numInputs !== inputs.length) {
      return null;
    }

    // Prevent gestures from triggering while inputs are active.
    const activeElement = document.activeElement;
    if (activeElement && ["INPUT", "TEXTAREA", "SELECT"].indexOf(activeElement.tagName) !== -1)
      return null;

    let output = {
      data: [],
    };

    const input = inputs[0];
    if (input.current.type !== "end")
      return null;
    const progress = input.getGestureProgress(this.getId());
    // Ensure sufficient move data to compute inputs.
    if (!progress.moves || progress.moves.length <= 2)
      return null;
    const currentMove = progress.moves[progress.moves.length - 1];
    // Has move lingered too long.
    if (new Date().getTime() - currentMove.time > this.maxRestTime)
      return null;
    const totals = progress.moves.reduce(function (acc, move, index) {
      // Skip first element as we can't use it anyways.
      if (index === 0)
        return {vel: 0, angle: [0, 0], dist: 0, last: move};
      const vel = getVelocity([acc.last.x, acc.last.y, acc.last.time], [move.x, move.y, move.time]);
      const angle = getAngle([acc.last.x, acc.last.y], [move.x, move.y]);
      const dist = distanceBetweenTwoPoints([acc.last.x, acc.last.y], [move.x, move.y]);
      return {vel: acc.vel + vel, angle: [acc.angle[0] + Math.cos(angle), acc.angle[1] + Math.sin(angle)], dist: acc.dist + dist, last: move};
    }, {vel: 0, angle: 0, dist: 0, last: null});
    // const initial = input.initial;
    // Add total gesture motion as a bias.
    // totals.vel += getVelocity([initial.x, initial.y, initial.time], [input.current.x, input.current.y, input.current.time]);
    // totals.angle += getAngle([initial.x, initial.y], [input.current.x, input.current.y]) + Math.PI;
    // totals.dist += distanceBetweenTwoPoints([initial.x, initial.y], [input.current.x, input.current.y]);
    const avgMoves = progress.moves.length - 2;
    const averages = {vel: totals.vel / avgMoves, angle: Math.atan2(totals.angle[0], totals.angle[1])};
    output.data[0] = {
      velocity: averages.vel,
      distance: totals.dist,
      duration: 1,
      currentDirection: averages.angle,
    };

    // Minimum velocity requirement.
    if (output.data[0].velocity < this.escapeVelocity)
      return null;
    // Minimum distance requirement. Helps to prevent phantom strokes on bad digitizers.
    if (output.data[0].distance < this.minDistance)
      return null;

    if (output.data.length > 0)
      return output;

    return null;
  }
}

Post.initialize_gestures = function () {
  if (!LStorage.Theme.Gestures) return;
  if (!(("ontouchstart" in window) || (navigator.maxTouchPoints > 0)))
    return;
  // Need activeElement to make sure that this doesn't go off during input.
  if (!("activeElement" in document))
    return;

  const $body = $("body");
  if ($body.data("zing"))
    return;

  const zing = new ZingTouch.Region(document.body, false, false);
  zing.bind(document.body, new E6Swipe(), function (e) {
    const angle = e.detail.data[0].currentDirection * 180 / Math.PI;
    console.log(angle, e.detail.data[0]);
    const hasPrev = Post.has_prev_target();
    const hasNext = Post.has_next_target();
    if (hasPrev && (angle > 90 - 25 && angle < 90 + 25)) { // right swipe
      $("body").css({"transition-timing-function": "ease", "transition-duration": "0.2s", "opacity": "0", "transform": "translateX(150%)"});
      Utility.delay(200).then(() => Post.nav_prev(e));
    }
    if (hasNext && (angle > -90 - 25 && angle < -90 + 25)) { // Left swipe
      $("body").css({"transition-timing-function": "ease", "transition-duration": "0.2s", "opacity": "0", "transform": "translateX(-150%)"});
      Utility.delay(200).then(() => Post.nav_next(e));
    }
  });

  $body.data("zing", zing);
  $("#image-container").css({overflow: "visible"});
};

Post.nav_prev = function (e) {
  var href = "";

  if ($(".search-seq-nav").length) {
    href = $(".search-seq-nav a[rel~=prev]").attr("href");
    if (href) {
      location.href = href;
    }
  } else if ($(".paginator a[rel~=prev]").length) {
    location.href = $("a[rel~=prev]").attr("href");
  } else {
    href = $(".pool-nav li.pool-selected-true a[rel~=prev], .set-nav li.set-selected-true a[rel~=prev]").attr("href");
    if (href) {
      location.href = href;
    }
  }

  e.preventDefault();
};

Post.nav_next = function (e) {
  var href = "";

  if ($(".search-seq-nav").length) {
    href = $(".search-seq-nav a[rel~=next]").attr("href");
    location.href = href;
  } else if ($(".paginator a[rel~=next]").length) {
    location.href = $(".paginator a[rel~=next]").attr("href");
  } else {
    href = $(".pool-nav li.pool-selected-true a[rel~=next], .set-nav li.set-selected-true a[rel~=next]").attr("href");
    if (href) {
      location.href = href;
    }
  }

  e.preventDefault();
};

Post.initialize_shortcuts = function () {
  if ($("#a-show").length) {
    Shortcuts.keydown("a", "prev_page", Post.nav_prev);
    Shortcuts.keydown("d", "next_page", Post.nav_next);
  }
};

Post.initialize_links = function () {
  $(".undelete-post-link").on("click", e => {
    e.preventDefault();
    if (!confirm("Are you sure you want to undelete this post?"))
      return;
    Post.undelete($(e.target).data("pid"), () => {
      location.reload();
    });
  });
  $(".approve-post-link").on("click", e => {
    e.preventDefault();
    Post.approve($(e.target).data("pid"), () => {
      location.reload();
    });
  });
  $(".approve-post-and-navigate-link").on("click", e => {
    e.preventDefault();
    const $target = $(e.target);
    Post.approve($target.data("pid"), () => {
      location.href = $target.data("location");
    });
  });
  $("#destroy-post-link").on("click", e => {
    e.preventDefault();
    const reason = prompt("This will permanently delete this post (meaning the file will be deleted). What is the reason for destroying the post?");
    if (reason === null) return;
    Post.destroy($(e.target).data("pid"), reason);
  });
  $("#regenerate-image-variants-link").on("click", e => {
    e.preventDefault();
    Post.regenerate_image_variants($(e.target).data("pid"));
  });
  $("#regenerate-video-variants-link").on("click", e => {
    e.preventDefault();
    Post.regenerate_video_variants($(e.target).data("pid"));
  });
  $(".disapprove-post-link").on("click", e => {
    e.preventDefault();
    const target = $(e.target);
    Post.disapprove(target.data("pid"), target.data("reason"));
  });
  $("#set-as-avatar-link").on("click.danbooru", function (e) {
    e.preventDefault();
    if (!confirm("Set post as avatar?"))
      return;
    Post.set_as_avatar($(e.target).data("post-id"));
  });
  $("#copy-notes").on("click.danbooru", function (e) {
    var current_post_id = $("meta[name=post-id]").attr("content");
    var other_post_id = parseInt(prompt("Enter the ID of the post to copy all notes to:"), 10);

    if (other_post_id !== null) {
      $.ajax(`/posts/${current_post_id}/copy_notes.json`, {
        type: "PUT",
        data: {
          other_post_id: other_post_id,
        },
        success: function () {
          $(window).trigger("danbooru:notice", "Successfully copied notes to <a href='" + other_post_id + "'>post #" + other_post_id + "</a>");
        },
        error: function (data) {
          if (data.status === 404) {
            $(window).trigger("danbooru:error", "Error: Invalid destination post");
          } else if (data.responseJSON && data.responseJSON.reason) {
            $(window).trigger("danbooru:error", "Error: " + data.responseJSON.reason);
          } else {
            $(window).trigger("danbooru:error", "There was an error copying notes to <a href='" + other_post_id + "'>post #" + other_post_id + "</a>");
          }
        },
      });
    }

    e.preventDefault();
  });
};

Post.initialize_post_relationship_previews = function () {
  var current_post_id = $("meta[name=post-id]").attr("content");
  $("[id=post_" + current_post_id + "]").addClass("current-post");

  const toggle = function () {
    Post.toggle_relationship_preview($("#has-children-relationship-preview"), $("#has-children-relationship-preview-link"));
    Post.toggle_relationship_preview($("#has-parent-relationship-preview"), $("#has-parent-relationship-preview-link"));
  };

  const flip_saved = function () {
    LStorage.Posts.ShowPostChildren = !LStorage.Posts.ShowPostChildren;
  };

  if (LStorage.Posts.ShowPostChildren)
    toggle();

  $("#has-children-relationship-preview-link").on("click.danbooru", function (e) {
    toggle();
    flip_saved();
    e.preventDefault();
  });
  $("#has-parent-relationship-preview-link").on("click.danbooru", function (e) {
    toggle();
    flip_saved();
    e.preventDefault();
  });
};

Post.toggle_relationship_preview = function (preview, preview_link) {
  preview.toggle();
  if (preview.is(":visible")) {
    preview_link.text("« hide");
  } else {
    preview_link.text("show »");
  }
};

Post.currentPost = function () {
  if (!this._currentPost)
    this._currentPost = this.fromDOM($("#image-container"));
  return this._currentPost;
};

Post.fromDOM = function (element) {
  if (!element)
    return {};

  const post = element.attr("data-post") || "{}";
  return JSON.parse(post);
};

Post.resize_notes = function () {
  Note.Box.scale_all();
};

Post.resize_video = function (post, target_size) {
  const $video = $("video#image");
  if (!$video.length) return; // Caused by the video being deleted
  const videoTag = $video[0];
  videoTag.pause(); // Otherwise size changes won't take effect.
  const $notice = $("#image-resize-notice");
  const update_resize_percentage = function (width, orig_width) {
    const $percentage = $("#image-resize-size");
    const scaled_percentage = Math.floor(100 * width / orig_width);
    $percentage.text(`${scaled_percentage}%`);
  };
  $notice.hide();
  let target_sources = [];
  let desired_classes = [];

  function original_sources () {
    const webm = post.file.ext === "webm";
    target_sources.push({ type: webm ? "video/webm; codecs=\"vp9\"" : "video/mp4", url: post?.file?.url });
    const original = post.variants.find(s => s.type === "original" && s.ext === (webm ? "mp4" : "webm"));
    if (typeof original !== "undefined") {
      target_sources.push({ type: webm ? "video/mp4" : "video/webm; codecs=\"vp9\"", url: original.url });
    }
  }

  switch (target_size) {
    case "original":
      original_sources();
      break;
    case "fit":
      original_sources();
      desired_classes.push("fit-window");
      break;
    case "fitv":
      original_sources();
      desired_classes.push("fit-window-vertical");
      break;
    default: {
      $notice.show();
      const variants = post.variants.filter(s => s.type === target_size);
      const webm = variants.find(s => s.ext === "webm");
      const mp4 = variants.find(s => s.ext === "mp4");
      target_sources.push({ type: "video/webm; codecs=\"vp9\"", url: webm.url });
      target_sources.push({ type: "video/mp4", url: mp4.url });
      desired_classes.push("fit-window");
      update_resize_percentage(webm.width, post.file.width);
      break;
    }
  }
  $video.removeClass();
  $video.empty(); // Yank any sources out of the list to prevent browsers from being pants on head.
  for (const source of target_sources) {
    // This works around some annoying choices where W3C said that changing source attributes for video tags doesn't work
    // and that automatic media type selection can't be performed again, so you have to do it by hand. To add bonus points
    // to this asshattery, the responses from the API are at best, vague and there are three of them. Seems that the best
    // any browser can give me is a "maybe".
    const canPlay = videoTag.canPlayType(source.type);
    if (canPlay === "probably" || canPlay === "maybe") {
      // This comparison fixes reloading the media on changing between fit modes.
      if (source.url !== $video.attr("src")) {
        $video.attr("src", source.url);
        videoTag.load(); // Forces changed source to take effect. *SOME* browsers ignore changes otherwise.
      }
      break;
    }
  }
  for (const class_name of desired_classes) {
    $video.addClass(class_name);
  }
};

Post.resize_image = function (post, target_size) {
  const $image = $("img#image");
  const $notice = $("#image-resize-notice");
  const update_resize_percentage = function (width, orig_width) {
    const $percentage = $("#image-resize-size");
    const scaled_percentage = Math.floor(100 * width / orig_width);
    $percentage.text(`${scaled_percentage}%`);
  };
  $notice.hide();
  let desired_url = "";
  let desired_classes = [];
  let variant;
  switch (target_size) {
    case "original":
      desired_url = post?.file?.url;
      break;
    case "fit":
      desired_classes.push("fit-window");
      desired_url = post?.file?.url;
      break;
    case "fitv":
      desired_classes.push("fit-window-vertical");
      desired_url = post?.file?.url;
      break;
    case "large":
      $notice.show();
      desired_classes.push("fit-window");
      variant = post?.variants?.find(s => s.type === "large");
      desired_url = variant?.url;
      update_resize_percentage(variant?.width, post?.file?.width);
      break;
    default:
      $notice.show();
      desired_classes.push("fit-window");
      variant = post?.variants?.find(s => s.type === target_size);
      desired_url = variant?.url;
      update_resize_percentage(variant?.width, post?.file?.width);
      break;
  }
  $image.removeClass();
  if ($image.attr("src") !== desired_url) {
    $("#image-container").addClass("image-loading");
    $image.attr("src", desired_url);
  }
  for (const class_name of desired_classes) {
    $image.addClass(class_name);
  }
  Post.resize_notes();
};

Post.resize_to = function (target_size) {
  target_size = update_size_selector(target_size);

  const post = Post.currentPost();
  if (is_video(post)) {
    Post.resize_video(post, target_size);
  } else {
    Post.resize_image(post, target_size);
  }
};


function is_video (post) {
  switch (post.file.ext) {
    case "webm":
    case "mp4":
      return true;
    default:
      return false;
  }
}

function update_size_selector (choice) {
  const selector = $("#image-resize-selector");
  const choices = selector.find("option");
  if (choice === "next") {
    const index = selector[0].selectedIndex;
    const next_choice = $(choices[(index + 1) % choices.length]).val();
    selector.val(next_choice);
    return next_choice;
  }
  for (const item of choices) {
    if ($(item).val() == choice) {
      selector.val(choice);
      return choice;
    }
  }
  selector.val("fit");
  return "fit";
}

function most_relevant_variant_size (post) {
  let variants = Post.currentPost().variants;
  variants = variants.filter((x) => !["original", "preview", "large", "crop"].includes(x.type));
  if (variants.length === 0) {
    return "fit";
  }
  if (post?.file?.width <= 1280 && post?.file?.height <= 720) {
    return "fit"; // Don't force people onto 480p variants for <720 videos.
  }
  const differences = variants.map((x) => [x.type, Math.abs(window.outerHeight - x.height) * Math.abs(window.outerWidth - x.width)]).sort((a, b) => (a[1] < b[1] ? -1 : 1));
  return differences[0].type;
}

Post.initialize_resize = function () {
  Post.initialize_change_resize_mode_link();
  const post = Post.currentPost();

  const is_post_video = is_video(post);
  if (!is_post_video) {
    const $image = $("img#image");
    if ($image.length > 0 && $image[0]) {
      if ($image[0].complete)
        Post.resize_notes();
    }

    $image.on("load", function () {
      Post.resize_notes();
      $("#image-container").removeClass("image-loading");
    });
    $(window).on("resize", Post.resize_notes);
  }
  let image_size = Utility.meta("image-override-size") || Utility.meta("default-image-size");
  if (is_post_video && image_size === "large") {
    image_size = most_relevant_variant_size(post);
  }
  Post.resize_to(image_size);
  const $selector = $("#image-resize-selector");
  $selector.on("change", () => Post.resize_to($selector.val()));
};

Post.resize_cycle_mode = function (e) {
  if (e && e.target)
    e.preventDefault();

  Post.resize_to("next");
};

Post.initialize_change_resize_mode_link = function () {
  $("#image-resize-link").on("click", (e) => {
    e.preventDefault();
    Post.resize_to("fit");
  }); // For top panel
  Shortcuts.keydown("v", "resize", Post.resize_cycle_mode);
};

Post.initialize_post_sections = function () {
  $("#post-sections li a,#side-edit-link").on("click.danbooru", function (e) {
    if (e.target.hash === "#comments") {
      $("#comments").show();
      $("#edit").hide();
    } else if (e.target.hash === "#edit") {
      $("#edit").show();
      $("#comments").hide();
      $(document).trigger("danbooru:open-post-edit-tab");
      Post.update_tag_count({target: $("#post_tag_string")});
    } else {
      $("#edit").hide();
      $("#comments").hide();
    }

    if (e.target.hash !== "#edit") {
      $(document).trigger("danbooru:close-post-edit-tab");
    }

    $("#post-sections li").removeClass("active");
    $(e.target).parent("li").addClass("active");
    e.preventDefault();
  });
};

Post.notice_update = function (x) {
  if (x === "inc") {
    Post.pending_update_count += 1;
    $(window).trigger("danbooru:notice", "Updating posts (" + Post.pending_update_count + " pending)...", true);
  } else {
    Post.pending_update_count -= 1;

    if (Post.pending_update_count < 1) {
      $(window).trigger("danbooru:notice", "Posts updated");
    } else {
      $(window).trigger("danbooru:notice", "Updating posts (" + Post.pending_update_count + " pending)...", true);
    }
  }
};

Post.update_data = function (data) {
  var $post = $("#post_" + data.id);
  $post.attr("data-tags", data.tag_string);
  $post.data("rating", data.rating);
  $post.removeClass("post-status-has-parent post-status-has-children");
  if (data.parent_id) {
    $post.addClass("post-status-has-parent");
  }
  if (data.has_visible_children) {
    $post.addClass("post-status-has-children");
  }
};

Post.tag = function (post_id, tags) {
  const tag_string = (Array.isArray(tags) ? tags.join(" ") : String(tags));
  Post.update(post_id, { "post[old_tag_string]": "", "post[tag_string]": tag_string });
};

Post.tagScript = function (post_id, tags) {
  const tag_string = (Array.isArray(tags) ? tags.join(" ") : String(tags));
  Post.update(post_id, { "post[tag_string_diff]": tag_string });
};

Post.update = function (post_id, params) {
  Post.notice_update("inc");

  SendQueue.add(function () {
    $.ajax({
      type: "PUT",
      url: "/posts/" + post_id + ".json",
      data: params,
      success: function (data) {
        Post.notice_update("dec");
        Post.update_data(data);
      },
      error: function (data) {
        Post.notice_update("dec");
        const message = $
          .map(data.responseJSON.errors, function (msg) { return msg; })
          .join("; ");
        $(window).trigger("danbooru:error", `There was an error updating <a href="/posts/${post_id}">post #${post_id}</a>: ${message}`);
      },
    });
  });
};

Post.delete_with_reason = function (post_id, reason, reload_after_delete) {
  Post.notice_update("inc");
  SendQueue.add(function () {
    $.ajax({
      type: "DELETE",
      url: `/posts/${post_id}.json`,
      data: {commit: "Delete", reason: reason, move_favorites: true},
    }).fail(function (data) {
      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", "Deleted post.");
      if (reload_after_delete) {
        location.reload();
      } else {
        $(`article#post_${post_id}`).attr("data-flags", "deleted");
      }
    }).always(function () {
      Post.notice_update("dec");
    });
  });
};

Post.undelete = function (post_id, callback) {
  Post.notice_update("inc");
  SendQueue.add(function () {
    $.ajax({
      type: "PUT",
      url: `/posts/${post_id}/undelete.json`,
    }).fail(function (data) {
      //      var message = $.map(data.responseJSON.errors, function(msg, attr) { return msg; }).join('; ');
      const message = data.responseJSON.message;
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", "Undeleted post.");
      $(`article#post_${post_id}`).attr("data-flags", "active");
      if (callback) callback();
    }).always(function () {
      Post.notice_update("dec");
    });
  });
};

Post.unflag = function (post_id, approval, reload = true, callback = null) {
  Post.notice_update("inc");
  let modApproval = approval || "none";
  SendQueue.add(function () {
    $.ajax({
      type: "DELETE",
      url: `/posts/${post_id}/flag.json`,
      data: {approval: modApproval},
    }).fail(function (data) {
      const message = data.responseJSON.message;
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", "Unflagged post");
      if (callback) callback();
      if (reload) location.reload();
    }).always(function () {
      Post.notice_update("dec");
    });
  });
};

Post.flag = function (post_id, reason_name, parent_id = null, reload = true, callback = null) {
  Post.notice_update("inc");
  SendQueue.add(function () {
    $.ajax({
      type: "POST",
      url: "/post_flags.json",
      data: {
        post_flag: {
          post_id: parseInt(post_id),
          reason_name,
          parent_id,
        },
      },
    }).fail(function (data) {
      const message = data.responseJSON.message;
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", "Flagged post");
      if (callback) callback();
      if (reload) location.reload();
    }).always(function () {
      Post.notice_update("dec");
    });
  });
};

Post.move_flag_to_parent = function (post_id, parent_id) {
  Post.unflag(post_id, false, false, function () {
    Post.flag(parent_id, "inferior", post_id, false, function () {
      location.href = `/moderator/post/posts/${parent_id}/confirm_delete`;
    });
  });
};


Post.unapprove = function (post_id) {
  Post.notice_update("inc");
  SendQueue.add(function () {
    $.ajax({
      type: "DELETE",
      url: `/posts/approvals/${post_id}.json`,
    }).fail(function (data) {
      var message = $.map(data.responseJSON.errors, function (msg) { return msg; }).join("; ");
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", "Unapproved post.");
      location.reload();
    }).always(function () {
      Post.notice_update("dec");
    });
  });
};

Post.destroy = function (post_id, reason) {
  $.ajax({
    method: "PUT",
    url: `/posts/${post_id}/expunge.json`,
    data: { reason },
  })
    .fail(data => {
      var message = $.map(data.responseJSON.errors, function (msg) { return msg; }).join("; ");
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(() => {
      location.href = `/admin/destroyed_posts/${post_id}`;
    });
};

Post.regenerate_image_variants = function (post_id) {
  $.ajax({
    method: "PUT",
    url: `/posts/${post_id}/regenerate_thumbnails.json`,
  })
    .fail(data => {
      Utility.error("Error: " + data.responseJSON.reason);
    }).done(() => {
      Utility.notice("Image variants regenerated.");
    });
};

Post.regenerate_video_variants = function (post_id) {
  $.ajax({
    method: "PUT",
    url: `/posts/${post_id}/regenerate_videos.json`,
  })
    .fail(data => {
      Utility.error("Error: " + data.responseJSON.reason);
    }).done(() => {
      Utility.notice("Video variants will be regenerated in a few minutes.");
    });
};

Post.approve = function (post_id, callback) {
  Post.notice_update("inc");
  SendQueue.add(function () {
    $.post(
      "/posts/approvals.json",
      { post_id },
    ).fail(function (data) {
      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ") || data.responseJSON.message;
      Post.notice_update("dec");
      Danbooru.error("Error: " + message);
    }).done(function () {
      var $post = $("#post_" + post_id);
      if ($post.length) {
        $post.data("flags", $post.data("flags").replace(/pending/, ""));
        $post.removeClass("post-status-pending");
        Post.notice_update("dec");
        Danbooru.notice("Approved post #" + post_id);
      }
      if (callback) {
        callback();
      }
    });
  });
};

Post.disapprove = function (post_id, reason, message) {
  Post.notice_update("inc");
  SendQueue.add(function () {
    $.post(
      "/posts/disapprovals.json",
      {"post_disapproval[post_id]": post_id, "post_disapproval[reason]": reason, "post_disapproval[message]": message},
    ).fail(function (data) {
      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      if ($("#c-posts #a-show").length) {
        location.reload();
      }
    }).always(function () {
      Post.notice_update("dec");
    });
  });
};

Post.update_tag_count = function (event) {
  let string = "0 tags";
  let count = 0;
  // let count2 = 1;

  if (event) {
    let tags = [...new Set($(event.target).val().match(/\S+/g))];
    if (tags) {
      count = tags.length;
      string = (count == 1) ? (count + " tag") : (count + " tags");
    }
  }
  $("#tags-container .count").html(string);
  let klass = "smile";
  if (count < 15) {
    klass = "frown";
  } else if (count < 25) {
    klass = "meh";
  }
  $("#tags-container .options #face").removeClass().addClass(`fa-regular fa-face-${klass}`);
};

Post.vote_up = function (e) {
  var id = $(e.target).parent().attr("data-id");
  Post.vote(id, 1);
};

Post.vote_down = function (e) {
  var id = $(e.target).parent().attr("data-id");
  Post.vote(id, -1);
};

Post.unvote = function (id) {
  const score = $(`#post_${id}`).attr("data-own-vote");
  if (score !== undefined && score !== "0") {
    Post.vote(id, score, false);
  }
};

Post.vote = function (id, score, prevent_unvote) {
  Post.notice_update("inc");
  SendQueue.add(function () {
    $.ajax({
      method: "POST",
      url: `/posts/${id}/votes.json`,
      data: {
        score: score,
        no_unvote: prevent_unvote === true,
      },
      dataType: "json",
      headers: {
        accept: "*/*;q=0.5,text/javascript",
      },
    }).done(function (data) {
      Post.after_vote(id, data);
      $(window).trigger("danbooru:notice", "Vote saved");
    }).always(function () {
      Post.notice_update("dec");
    }).fail(function (data) {
      Utility.error("Error: " + data.responseJSON.message);
    });
  });
};

/**
 * @typedef PostVote
 * @prop {Number} score
 * @prop {Number} up
 * @prop {Number} down
 * @prop {Number} our_score
 * @prop {Number} is_locked
 */

/**
 * @param {Number} post_id
 * @param {PostVote} vote
 */
Post.after_vote = function (post_id, vote) {
  const scoreClasses = "score-neutral score-positive score-negative";
  const post = $(`#post_${post_id}`);
  if (vote.is_locked) {
    post.removeAttr("data-own-vote");
  } else {
    post.attr("data-own-vote", vote.our_score);
  }
  post.attr("data-score-up", vote.up);
  post.attr("data-score-down", vote.down);
  post.attr("data-score", vote.score);
  function scoreToClass (inScore) {
    if (inScore === 0) return "score-neutral";
    return inScore > 0 ? "score-positive" : "score-negative";
  }

  const scoreSelector = $(`.post-score-${post_id}`);
  const voteUpSelector = $(`.post-vote-up-${post_id}`);
  const voteDownSelector = $(`.post-vote-down-${post_id}`);
  scoreSelector.removeClass(scoreClasses);
  scoreSelector.text(vote.score);
  scoreSelector.attr("title", `${vote.up} up/${vote.down} down`);
  scoreSelector.addClass(scoreToClass(vote.score));
  voteUpSelector.removeClass(scoreClasses);
  voteUpSelector.addClass(vote.our_score > 0 ? "score-positive" : "score-neutral");
  voteDownSelector.removeClass(scoreClasses);
  voteDownSelector.addClass(vote.our_score < 0 ? "score-negative" : "score-neutral");

  const scoreScoreSelector = $(`.post-score-score-${post_id}`);
  const scoreClassesSelector = $(`.post-score-classes-${post_id}`);
  const iconsSelector = $(scoreClassesSelector.find(`.post-score-icon-${post_id}`));
  scoreScoreSelector.text(vote.score);
  scoreScoreSelector.attr("title", `${vote.up} up/${vote.down} down`);
  scoreClassesSelector.removeClass(scoreClasses);
  scoreClassesSelector.addClass(scoreToClass(vote.score));
  if (iconsSelector.length) {
    const positive = iconsSelector.attr("data-icon-positive");
    const negative = iconsSelector.attr("data-icon-negative");
    const neutral = iconsSelector.attr("data-icon-neutral");
    const icon = vote.score > 0 ? positive : vote.score < 0 ? negative : neutral;
    iconsSelector.text(icon);
  }
};

Post.set_as_avatar = function (id) {
  SendQueue.add(function () {
    $.ajax({
      method: "POST",
      url: "/users/update.json",
      data: {
        "user[avatar_id]": id,
      },
      headers: {
        accept: "*/*;q=0.5,text/javascript",
      },
    }).done(function () {
      $(window).trigger("danbooru:notice", "Post set as avatar");
    });
  });
};

Post.initialize_hide_notes = function () {
  const container = $("#note-container")
    .css("display", "");
  $("#toggle-notes-button")
    .on("click", (event) => {
      event.preventDefault();
      Post.toggle_hide_notes();
    });
  $("#translate")
    .on("click", async () => {

      if (container.attr("data-hidden") === "true") {
        Post.toggle_hide_notes(false);
      } else {
        const isHidden = LStorage.HideNotes;
        if (isHidden) {
          Post.toggle_hide_notes(false, true);
        }
      }
    });

  Post.toggle_hide_notes(false, true);
};

Post.toggle_hide_notes = function (save = true, init = false) {
  let isHidden = LStorage.HideNotes;
  if (init) {
    isHidden = !isHidden;
    save = false;
  }
  const button = $("#toggle-notes-button");
  const container = $("#note-container");

  if (isHidden) {
    container.attr("data-hidden", false);
    button.text("Notes: ON");
    if (save) LStorage.HideNotes = false;
  } else {
    container.attr("data-hidden", true);
    button.text("Notes: OFF");
    if (save) LStorage.HideNotes = true;
  }
};

Post.initialize_vote_buttons = function () {
  const containers = $(".post-preview div#vote-buttons");
  for (const set of containers) {
    for (const button of $(set).find("button.vote-button")) {
      $(button).on("click.gayfurcity.vote", (event) => {
        event.preventDefault();
        const id = $(event.target).parent().parent().attr("data-id");
        switch ($(event.target).attr("data-action")) {
          case "up": {
            Post.vote(id, 1);
            break;
          }

          case "down": {
            Post.vote(id, -1);
            break;
          }

          case "fav": {
            const span = $(event.target).find("span");
            const isFavorited = span.hasClass("is-favorited");
            if (isFavorited) {
              Favorite.destroy(id);
              span.removeClass("is-favorited");
            } else {
              Favorite.create(id);
              span.addClass("is-favorited");
            }

            const favSelector = $(`.post-score-faves-faves-${id}`);
            favSelector.text(Number(favSelector.text()) + (isFavorited ? -1 : 1));
            break;
          }
        }
      });
    }
  }
};

Post.initialize_thumbnail_frame_preview = function () {
  const $input = $("#preview-thumbnail-frame-button");
  $input.off("click.gayfurcity");
  $input.on("click.gayfurcity", Post.preview_thumbnail_frame);
};

Post.initialize_upload_settings = async function () {
  const id = Number($("meta[name=post-id]").attr("content"));
  await Uploader.loadSettings(id);
};

Post.preview_thumbnail_frame = async function (event) {
  event.preventDefault();
  const $input = $("#post_thumbnail_frame");
  const $container = $("#preview-thumbnail-frame");
  const value = Number($input.val());
  $container.empty();
  if ($input.val() === "") return;
  $("<h4>").text("Preview").appendTo($container);
  $("<p>").text("Loading...").appendTo($container);
  try {
    const url = await Post.get_blob_url_for_frame(value);
    const $link = $("<a>").attr("href", url).attr("target", "_blank");
    $("<img>").attr("src", url).attr("width", "60%").appendTo($link);
    $link.appendTo($container);
    $container.find("p").remove();
  } catch (e) {
    console.error("Failed to create blob url for frame:", e);
    $container.find("p").text(`Error: ${e.message}`);
  }
};

Post.get_blob_url_for_frame = async function (frame, post_id = Post.currentPost().id) {
  Post._blobFrameMap[post_id] ??= {};
  if (Post._blobFrameMap[post_id][frame]) {
    return Post._blobFrameMap[post_id][frame];
  }
  const response = await fetch(`/posts/${post_id}/frame/${frame}`);
  if (response.status !== 200) {
    if (response.headers.get("content-type").startsWith("application/json")) {
      throw new Error((await response.json()).message);
    }
    throw new Error(`Failed to fetch frame ${frame} for post ${post_id}: ${response.status} ${response.statusText}`);
  }
  const url = URL.createObjectURL(await response.blob());
  Post._blobFrameMap[post_id][frame] = url;
  return url;
};

$(async () => Post.initialize_all());

export default Post;
