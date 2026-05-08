import Utility from "./utility";

class Block {
  static entries = JSON.parse(Utility.meta("user-blocks") || "[]");

  static hiddenCount = {
    comments: 0,
    forum_posts: 0,
    forum_topics: 0,
  };

  static disabled = [];

  static hide ($selector, name) {
    this.hiddenCount[name] += $selector.length;
    $selector.hide();
  }

  static show ($selector, name) {
    this.hiddenCount[name] -= $selector.length;
    $selector.show();
  }

  static text (name) {
    const p = (t, n) => (n === 1 ? `${n} ${t}` : `${n} ${t}s`);
    const beginnings = {
      comments: p("comment", this.hiddenCount[name]),
      forum_posts: p("forum post", this.hiddenCount[name]),
      forum_topics: p("forum topic", this.hiddenCount[name]),
    };
    return `${beginnings[name]} on this page ${this.hiddenCount[name] === 1 ? "was" : "were"} hidden due to a user being blocked.`;
  }

  static updateText () {
    let html = "";
    for (const [name, counts] of Object.entries(this.hiddenCount)) {
      if (counts === 0) {
        if (this.disabled.includes(name)) {
          html += `<p>Hiding of ${name.replace("_", " ")} has been disabled. Click <a href="#" class="reactivate-blocks" data-block-type="${name}">here</a> to reenable blocking.</p>`;
        }
        continue;
      }

      const text = this.text(name);
      html += `<p>${text} Click <a href="#" class="deactivate-blocks" data-block-type="${name}">here</a> to temporarily disable blocking these.</p>`;
    }

    $(".blocked-notice").html(html);
    this.reinitialize_listeners();
  }

  static toggle (id, hide = true) {
    const entry = this.entries.find(e => e.target_id === id);
    if (!entry) {
      return;
    }

    const { hide_comments, hide_forum_topics, hide_forum_posts } = entry;

    if (hide_comments) {
      if (hide) {
        this.hide($(`article.comment[data-creator-id=${entry.target_id}]:visible`), "comments");
      } else {
        this.show($(`article.comment[data-creator-id=${entry.target_id}]:hidden`), "comments");
      }
    }

    if (hide_forum_topics) {
      if (hide) {
        this.hide($(`tr.forum-topic-row[data-creator-id=${entry.target_id}]:visible`), "forum_topics");
      } else {
        this.show($(`tr.forum-topic-row[data-creator-id=${entry.target_id}]:hidden`), "forum_topics");
      }
    }

    if (hide_forum_posts) {
      if (hide) {
        this.hide($(`article.forum-post[data-creator-id=${entry.target_id}]:visible`), "forum_posts");
      } else {
        this.show($(`article.forum-post[data-creator-id=${entry.target_id}]:hidden`), "forum_posts");
      }
    }
  }

  static activate (id) { return this.toggle(id, true); }

  static deactivate (id) { return this.toggle(id, false); }

  static activateAll () { return this.entries.map(e => this.activate(e.target_id)); }

  static deactivateAll () { return this.entries.map(e => this.deactivate(e.target_id)); }

  static activateType (name) {
    if (!this.disabled.includes(name)) {
      return;
    }

    const entries = this.entries.filter(e => e[`hide_${name}`] === true);
    entries.forEach(e => this.activate(e.target_id));
    this.disabled.splice(this.disabled.indexOf(name), 1);
    this.updateText();
  }

  static deactivateType (name) {
    if (this.disabled.includes(name)) {
      return;
    }

    const entries = this.entries.filter(e => e[`hide_${name}`] === true);
    entries.forEach(e => this.deactivate(e.target_id));
    this.disabled.push(name);
    this.updateText();
  }

  static reinitialize_listeners () {
    $(".deactivate-blocks").off("click.gayfurcity.block").on("click.gayfurcity.block", function (event) {
      event.preventDefault();
      Block.deactivateType($(event.currentTarget).data("block-type"));
    });
    $(".reactivate-blocks").off("click.gayfurcity.block").on("click.gayfurcity.block", function (event) {
      event.preventDefault();
      Block.activateType($(event.currentTarget).data("block-type"));
    });
  }
}

$(document).ready(function () {
  Block.activateAll();
  Block.updateText();
});

export default Block;
