### FIXMEs
| Filename | line # | FIXME |
|:------|:------:|:------|
| [app/controllers/artists_controller.rb](app/controllers/artists_controller.rb#L63) | 63 | This is a hack on top of a hack to ensure all of the other attributes are set before url_string to ensure there are no race conditions |
| [app/models/artist.rb](app/models/artist.rb#L51) | 51 | This is a hack on top of the hack below for setting url_string to ensure name is set first for validations |
| [app/models/artist.rb](app/models/artist.rb#L216) | 216 | This is a hack. Setting an association directly immediately updates without regard for the parents validity. |
| [app/models/tag_relationship.rb](app/models/tag_relationship.rb#L109) | 109 | Rails assigns different join aliases for joins(:antecedent_tag) and joins(:antecedent_tag, :consquent_tag) |
| [app/models/user_vote.rb](app/models/user_vote.rb#L62) | 62 | the logic around this is a mess, and I'm frankly amazed it works |
| [test/unit/post_test.rb](test/unit/post_test.rb#L2372) | 2372 | This test fails randomly at different assertions |

### TODOs
| Filename | line # | TODO |
|:------|:------:|:------|
| [app/controllers/takedowns_controller.rb](app/controllers/takedowns_controller.rb#L41) | 41 | this *should* be changed eventually to use the update method & be strictly validated |
| [app/controllers/uploads_controller.rb](app/controllers/uploads_controller.rb#L12) | 12 | this route has many performance issues and needs to be revised |
| [app/logical/favorite_manager.rb](app/logical/favorite_manager.rb#L53) | 53 | Much better and more intelligent logic can exist for this |
| [app/models/forum_topic.rb](app/models/forum_topic.rb#L158) | 158 | revisit muting, it may need to be further optimized or removed due to performance issues |
| [app/models/post_event.rb](app/models/post_event.rb#L99) | 99 | We need access control/blocks for associations |
| [app/models/post_flag.rb](app/models/post_flag.rb#L52) | 52 | We need access control/blocks for associations |
| [app/models/tag_alias.rb](app/models/tag_alias.rb#L167) | 167 | Race condition with indexing jobs here. |
| [app/models/tag_implication.rb](app/models/tag_implication.rb#L207) | 207 | Race condition with indexing jobs here. |
| [app/models/ticket.rb](app/models/ticket.rb#L178) | 178 | We need access control/blocks for associations |
| [app/models/user_vote.rb](app/models/user_vote.rb#L61) | 61 | this join is used for both sides despite only being needed for the id side |
| [app/controllers/forums/topics_controller.rb](app/controllers/forums/topics_controller.rb#L20) | 20 | revisit muting, it may need to be further optimized or removed due to performance issues |
| [app/logical/vote_manager/posts.rb](app/logical/vote_manager/posts.rb#L90) | 90 | this can likely be optimized to just update post ids |
| [app/views/posts/index.html.erb](app/views/posts/index.html.erb#L12) | 12 | Lock off these extra items? |
| [app/views/posts/index.html.erb](app/views/posts/index.html.erb#L28) | 28 | Fix tag array with forced -status:deleted |
| [test/test_helpers/minitest.rb](test/test_helpers/minitest.rb#L5) | 5 | look into refactoring out minitest? |
| [test/unit/post_test.rb](test/unit/post_test.rb#L588) | 588 | This was moved to be a controller concern to fix issues with internal post updates |
| [test/unit/post_test.rb](test/unit/post_test.rb#L781) | 781 | Invalid tags are now reported as warnings, and don't trigger these. |
| [test/unit/post_test.rb](test/unit/post_test.rb#L807) | 807 | These are now warnings and don't trigger these. |
| [test/unit/post_test.rb](test/unit/post_test.rb#L1782) | 1782 | Needs to reload relationship to obtain non cached value |
| [test/unit/post_test.rb](test/unit/post_test.rb#L2236) | 2236 | These don't quite make sense, what should hide deleted posts and what shouldn't? |
| [test/unit/post_test.rb](test/unit/post_test.rb#L2669) | 2669 | These are pretty messed up, both structurally, and expectation wise. |
| [config/config.rb](config/config.rb#L208) | 208 | appealed posts should be visible, but this makes it far too easy to get the contents of deleted posts at a moments notice |

### XXXs
| Filename | line # | XXX |
|:------|:------:|:------|
| [app/models/post.rb](app/models/post.rb#L1644) | 1644 | This must happen *after* the `is_deleted` flag is set to true (issue #3419). |
| [app/logical/gay_fur_city/paginator/active_record_extension.rb](app/logical/gay_fur_city/paginator/active_record_extension.rb#L51) | 51 | Hack: in sequential pagination we fetch one more record than we need |
| [test/test_helpers/minitest.rb](test/test_helpers/minitest.rb#L3) | 3 | Testing modules should not have a say in if we can or cannot use assert_equal with nil |

### HACKs
| Filename | line # | HACK |
|:------|:------:|:------|
