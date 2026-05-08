const HoverZoom = new EventTarget();

const placeholder = "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==";
HoverZoom.init = function (shiftRequired, stickyShift, playAudio) {
  HoverZoom.current = null;
  HoverZoom.shiftPressed = false;
  HoverZoom.pageX = null;
  HoverZoom.pageY = null;
  HoverZoom.shiftRequired = shiftRequired;
  HoverZoom.stickyShift = stickyShift;
  HoverZoom.playAudio = playAudio;
  HoverZoom.init_listeners();
  HoverZoom.init_functionality();
};

HoverZoom.init_listeners = function () {
  $(document)
    .off("scroll.gayfurcity.zoom")
    .off("keydown.gayfurcity.zoom")
    .off("keyup.gayfurcity.zoom")
    .off("mousemove.gayfurcity.zoom");

  $(window)
    .off("blur.gayfurcity.zoom")
    .off("contextmenu.gayfurcity.zoom");

  $("#page")
    .off("mouseenter.gayfurcity.zoom", ".post-preview, div.post-thumbnail")
    .off("mouseleave.gayfurcity.zoom", ".post-preview, div.post-thumbnail");

  let throttle = false;
  $(document).on("mousemove.gayfurcity.zoom", (event) => {
    if (throttle) return;
    throttle = true;
    setTimeout(() => { throttle = false; }, 25);

    HoverZoom.pageX = event.pageX;
    HoverZoom.pageY = event.pageY;
    HoverZoom.emit("mousemove", { x: event.pageX, y: event.pageY });
  });

  let scrolling = false;
  $("#page")
    .on("mouseenter.gayfurcity.zoom", ".post-preview, div.post-thumbnail", (event) => {
      if (scrolling) return;

      const ref = $(event.currentTarget);
      ref.attr("data-hovering", "true");

      const post = HoverZoom.post_from_element(ref);
      HoverZoom.current = post;
      setTimeout(() => {
        HoverZoom.emit("zoom.start", { post: post.id, pageX: this.pageX, pageY: this.pageY });
      }, 0);
    })
    .on("mouseleave.gayfurcity.zoom", ".post-preview, div.post-thumbnail", (event) => {
      const ref = $(event.currentTarget);
      ref.removeAttr("data-hovering");

      HoverZoom.current = null;

      HoverZoom.emit("zoom.stop", { post: ref.attr("data-id"), pageX: event.pageX, pageY: event.pageY });
    });

  let scrollTimer = 0;
  $(document).on("scroll.gayfurcity.zoom", () => {
    if (scrollTimer) {
      clearTimeout(scrollTimer);
    }

    scrollTimer = setTimeout(() => scrolling = false, 100);
    scrolling = true;
  });

  if (!HoverZoom.shiftRequired) return;
  $(document)
    .on("keydown.gayfurcity.zoom", (event) => {
      if (HoverZoom.shiftPressed || event.originalEvent.key !== "Shift") return;
      HoverZoom.shiftPressed = true;
      for (const element of $("[data-hovering=true]")) {
        const ref = $(element);
        ref.find("img").trigger("mouseenter.gayfurcity.zoom");
      }
    })
    .on("keyup.gayfurcity.zoom", (event) => {
      if (!HoverZoom.shiftPressed || event.originalEvent.key !== "Shift") return;
      HoverZoom.shiftPressed = false;
      if (!HoverZoom.stickyShift) resetOnUnshift();
    });

  $(window)
    .on("blur.gayfurcity.zoom", () => {
      HoverZoom.shiftPressed = false;
      if (!HoverZoom.stickyShift) resetOnUnshift();
    })
    .on("contextmenu.gayfurcity.zoom", () => {
      HoverZoom.shiftPressed = false;
      if (!HoverZoom.stickyShift) resetOnUnshift();
    });

  function resetOnUnshift () {
    if (!HoverZoom.current) return;
    HoverZoom.emit("zoom.stop", { post: HoverZoom.current.id, pageX: null, pageY: null });
    HoverZoom.current = null;
  }
};

HoverZoom.init_functionality = function () {
  const zoomContainer = $("div#zoom-container");
  const zoomInfo = zoomContainer.find("#zoom-info");
  const zoomImage = zoomContainer.find("#zoom-image");
  const zoomVideo = zoomContainer.find("#zoom-video");
  const zoomTags = zoomContainer.find("#zoom-tags");

  let videoTimeout;

  const viewport = $(window);
  HoverZoom.on("zoom.start", (event) => {
    const data = event.detail;
    if (HoverZoom.shiftRequired && !this.shiftPressed) return;

    const ref = $(`#post_${data.post}, div.post-thumbnail[data-id=${data.post}]`).first();
    if (ref.hasClass("blacklisted")) return;
    const post = HoverZoom.post_from_element(ref);

    const isApprover = $("body").attr("data-user-is-approver");
    if (post.flags.includes(PostFlag.DELETED) && !isApprover) return;

    const img = ref.find("img").first();
    ref.data("stored-title", img.attr("title") || "");
    img.removeAttr("title");

    zoomContainer.attr("data-status", "loading");

    let width = Math.min(post.image.width, (viewport.width() * 0.5) - 50),
      height = width * post.image.ratio;

    if (height > (viewport.height() * 0.75)) {
      height = viewport.height() * 0.75;
      width = height / post.image.ratio;
    }

    zoomContainer.css({
      width: `${width}px`,
      height: `${height}px`,
    });

    if (post.file.ext === "webm") {
      zoomVideo
        .css({
          "display": "",
          "background-image": `url(${post.file.large})`,
        })
        .attr({
          src: post.file.original,
          poster: post.file.large,
        });

      videoTimeout = setTimeout(() => {
        zoomVideo.prop("muted", !HoverZoom.playAudio);
      }, 100);

      zoomContainer.attr("data-status", "ready");
    } else {
      zoomImage
        .css({
          "display": "",
          "background-image": `url(${post.file.preview})`,
        })
        .attr("src", post.file.original)
        .one("load", () => {
          zoomContainer.attr("data-status", "ready");
          zoomImage.css("background-image", "");
        });
    }

    zoomInfo.html("");
    if (post.image.width && post.image.height) {
      $("<span>")
        .text(`${post.image.width} x ${post.image.height}${post.file.size !== 0 ? `, ${HoverZoom.format_filesize(post.file.size)}` : ""}`)
        .appendTo(zoomInfo);
    }

    if (post.rating) {
      const ratingClass = {
        e: "explicit",
        q: "questionable",
        s: "safe",
      }[post.rating];

      $("<span>")
        .addClass(`post-rating-text-${ratingClass}`)
        .text(post.rating.toUpperCase())
        .appendTo(zoomInfo);
    }

    if (post.date.ago !== "now") {
      $("<span>")
        .text(post.date.ago)
        .appendTo(zoomInfo);
    }

    zoomTags
      .text(post.tagString)
      .css("max-width", `${width}px`);

    HoverZoom.on("mousemove", () => {
      alignWindow(HoverZoom.pageX, HoverZoom.pageY);
    });
    alignWindow(HoverZoom.pageX, HoverZoom.pageY);

    function alignWindow (x, y) {
      const height = zoomContainer.height(), width = zoomContainer.width(), cursorX = x, cursorY = y - viewport.scrollTop();

      const left = (cursorX < (viewport.width() / 2))
        ? cursorX + 50
        : cursorX - width - 50;
      const top = Math.min(Math.max(cursorY - (width / 2), 10), (viewport.height() - height - 10));

      zoomContainer.css({
        "left": `${left}px`,
        "top": `${top}px`,
      });
    }
  });
  HoverZoom.on("zoom.stop", (event) => {
    const data = event.detail;
    HoverZoom.off("mousemove");
    const ref = $(`#post_${data.post}, div.post-thumbnail[data-id=${data.post}]`).first();

    const img = ref.find("img").first();
    if (img.data("stored-title")) {
      img.attr("title", img.data("stored-title"));
      img.removeData("stored-title");
    }

    zoomContainer
      .attr("data-status", "waiting")
      .css({
        left: 0,
        top: "100vh",
      });
    zoomInfo.html("");
    zoomImage
      .css("display", "none")
      .attr("src", placeholder);
    zoomVideo
      .css({
        "display": "none",
        "background-image": "",
      })
      .prop("muted", !HoverZoom.playAudio);
    if (zoomVideo.attr("src") !== "") {
      zoomVideo.attr({
        src: "",
        poster: "",
      });
    }
    clearTimeout(videoTimeout);
    zoomTags.removeAttr("style").html("");
  });
};

HoverZoom.post_from_element = function (element) {
  const cache = element.data("hzcache");
  if (cache) return cache;
  const tagString = element.attr("data-tags") || "", tags = new Set(tagString.split(" "));

  const ext = element.attr("data-file-ext");
  const urls = {
    preview: element.attr("data-preview-url") ?? "/images/deleted-preview.png",
    large: element.attr("data-large-url") ?? "/images/deleted-preview.png",
    original: element.attr("data-file-url") ?? "/images/deleted-preview.png",
  };
  let md5;
  if (element.attr("data-md5")) {
    md5 = element.attr("data-md5");
  } else if (element.attr("data-file-url")) {
    md5 = element.attr("data-file-url").split("/").at(-1).split(".")[0];
  }

  const rawDate = element.attr("data-created-at") || new Date().toISOString();
  const score = Number(element.attr("data-score") || "0");
  const scoreUp = Number(element.attr("data-score-up") || "0");
  const scoreDown = Number(element.attr("data-score-down") || "0");
  const width = Number(element.attr("data-width") || "0");
  const height = Number(element.attr("data-height") || "0");

  const post = {
    id: Number(element.attr("data-id")),
    flags: (element.attr("data-flags") ?? "").split(" ").filter(Boolean),
    score: {
      down: scoreDown,
      up: scoreUp,
      total: score,
    },
    user_score: 0,
    favorites: Number(element.attr("data-fav-count") || "0"),
    is_favorited: !!element.attr("data-is-favorited"),
    comments: -1,
    rating: element.attr("data-rating"),
    uploader: Number(element.attr("data-uploader-id") || 0),
    uploaderName: element.attr("data-uploader-name") || "Anonymous",
    page: "-1",
    date: {
      raw: rawDate,
      ago: element.attr("data-created-ago") || "now",
      obj: new Date(rawDate),
    },
    tagString,
    tags,
    file: {
      ext,
      md5,
      original: urls.original,
      preview: urls.preview,
      large: urls.large,
      size: Number(element.attr("data-file-size") || "0"),
    },
    image: {
      width,
      height,
      ratio: height / width,
    },
    has: {
      file: element.attr("data-file-url") !== undefined,
      children: element.hasClass("post-status-has-children") || !!element.attr("data-has-active-children"),
      parent: element.hasClass("post-status-has-parent") || !!element.attr("data-has-active-parent"),
      sample: urls.original !== urls.sample,
    },
    meta: {
      duration: null,
      animated: tags.has("animated") || ["webm", "gif"].includes(ext),
      sound: tags.has("sound"),
      interactive: ext === "webm",
    },
    warning: {
      sound: tags.has("sound_warning"),
      epilepsy: tags.has("epilepsy_warning"),
    },
  };
  element.data("hzcache", post);
  return post;
};

const PostFlag = {};
PostFlag[PostFlag.DELETED = "deleted"] = "DELETED";
PostFlag[PostFlag.FLAGGED = "flagged"] = "FLAGGED";
PostFlag[PostFlag.PENDING = "pending"] = "PENDING";

HoverZoom.format_filesize = function (bytes, decimals = 2) {
  if (typeof bytes == "string") bytes = Number(bytes);
  if (!bytes || bytes === 0) return "0 B";

  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ["B", "KB", "MB"];

  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + sizes[i];
};

const listeners = {};
HoverZoom.on = function (event, callback) {
  HoverZoom.addEventListener(event, callback);
  if (!listeners[event]) listeners[event] = [];
  listeners[event].push(callback);
  return HoverZoom;
};

HoverZoom.off = function (event, callback = null) {
  if (callback === null) {
    if (listeners[event]) {
      for (const func of listeners[event]) {
        HoverZoom.removeEventListener(event, func);
      }
      listeners[event] = [];
    }
  } else {
    HoverZoom.removeEventListener(event, callback);
  }
  return this;
};

HoverZoom.emit = function (name, data) {
  HoverZoom.dispatchEvent(new CustomEvent(name, { detail: data }));
  return this;
};

export default HoverZoom;
