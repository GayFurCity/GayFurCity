# frozen_string_literal: true

module PostReplacementHelper
  def replacement_thumbnail(replacement)
    return tag.p("None") if replacement.uploading?
    if replacement.post.deleteblocked?(CurrentUser.user)
      image_tag(GayFurCity.config.deleted_preview_url)
    elsif replacement.post.visible?(CurrentUser.user)
      if replacement.original_file_visible_to?(CurrentUser.user)
        tag.a(image_tag(replacement.replacement_thumb_url(CurrentUser.user)), href: replacement.replacement_file_url(CurrentUser.user))
      else
        image_tag(replacement.replacement_thumb_url(CurrentUser.user))
      end
    end
  end
end
