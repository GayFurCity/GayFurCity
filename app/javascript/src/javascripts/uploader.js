import VueUploader from "./uploader/uploader.vue.erb";
import { createApp } from "vue";
import {SendQueue} from "./send_queue";
import Page from "./utility/page";

/**
 * @typedef UploadSettings
 * @prop {number} user_id
 * @prop {boolean} compact_mode
 * @prop {boolean} safe_site
 * @prop {?string} post_tags
 * @prop {string[]} upload_tags
 * @prop {string[]} recent_tags
 * @prop {boolean} allow_locked_tags
 * @prop {boolean} allow_rating_lock
 * @prop {boolean} allow_upload_as_pending
 * @prop {boolean} allow_upload_as_in_progress
 * @prop {number} max_file_size
 * @prop {Record<string, number>} max_file_size_map
 * @prop {number} max_file_size_per_request
 */

/**
 * @prop {UploadSettings?} settings
 * @prop {number?} settingsPostID
 */
class Uploader {
  static settings = null;

  static settingsPostID = null;

  static init () {
    const app = createApp(VueUploader);
    app.mount("#uploader");
  }

  /** @return UploadSettings */
  static async getSettings (postID = null) {
    if (this.settings && this.settingsPostID === postID) return this.settings;
    return new Promise(resolve => {
      SendQueue.add(() => {
        $.ajax({
          type: "get",
          url: `/uploads/settings.json${postID ? `?post_id=${postID}` : ""}`,
          success: (response) => {
            resolve(response);
          },
        });
      });
    });
  }

  static async loadSettings (postID = null) {
    if (this.settings && this.settingsPostID === postID) return;
    this.settings = await this.getSettings(postID);
    this.settingsPostID = postID;
  }
}

export default Uploader;

$(async function () {
  if (Page.matches("uploads", "new")) {
    await Uploader.loadSettings();
    Uploader.init();
  }
});
