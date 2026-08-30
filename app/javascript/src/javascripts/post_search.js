import { createApp } from "vue";
import Page from "./utility/page";
import PostSearchBuilder from "./post_search_builder.vue";

$(function () {
  if (!Page.matches("posts", "search"))
    return;

  const mount = document.getElementById("post-search-builder");
  if (!mount)
    return;

  const props = {
    fields: JSON.parse(mount.dataset.fields || "[]"),
    initialGeneralTags: mount.dataset.generalTags || "",
    initialGroups: JSON.parse(mount.dataset.groups || "[]"),
    initialBoolGroups: JSON.parse(mount.dataset.boolGroups || "[]"),
    initialValues: JSON.parse(mount.dataset.values || "{}"),
    initialModes: JSON.parse(mount.dataset.modes || "{}"),
  };

  createApp(PostSearchBuilder, props).mount(mount);
});
