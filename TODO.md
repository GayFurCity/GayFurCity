### XXXs
| Filename | line # | XXX |
|:------|:------:|:------|
| [app/concerns/api_methods.rb](app/concerns/api_methods.rb#L27) | 27 | deprecated, shouldn't expose this as an instance method. |
| [app/concerns/api_methods.rb](app/concerns/api_methods.rb#L33) | 33 | deprecated, shouldn't expose this as an instance method. |
| [app/concerns/concurrency_methods.rb](app/concerns/concurrency_methods.rb#L8) | 8 | We may deadlock if a transaction is open; do a non-parallel each. |
| [app/models/pool.rb](app/models/pool.rb#L308) | 308 | finds wrong post when the pool contains multiple copies of the same post (#2042). |
| [app/models/post.rb](app/models/post.rb#L1621) | 1621 | This must happen *after* the `is_deleted` flag is set to true (issue #3419). |
| [app/logical/gay_fur_city/paginator/active_record_extension.rb](app/logical/gay_fur_city/paginator/active_record_extension.rb#L48) | 48 | Hack: in sequential pagination we fetch one more record than we need |
| [test/test_helpers/minitest.rb](test/test_helpers/minitest.rb#L3) | 3 | Testing modules should not have a say in if we can or cannot use assert_equal with nil |

### FIXMEs
| Filename | line # | FIXME |
|:------|:------:|:------|
| [app/controllers/artists_controller.rb](app/controllers/artists_controller.rb#L63) | 63 | This is a hack on top of a hack to ensure all of the other attributes are set before url_string to ensure there are no race conditions |
| [app/models/artist.rb](app/models/artist.rb#L45) | 45 | This is a hack on top of the hack below for setting url_string to ensure name is set first for validations |
| [app/models/artist.rb](app/models/artist.rb#L230) | 230 | This is a hack. Setting an association directly immediately updates without regard for the parents validity. |
| [app/models/tag_relationship.rb](app/models/tag_relationship.rb#L109) | 109 | Rails assigns different join aliases for joins(:antecedent_tag) and joins(:antecedent_tag, :consquent_tag) |
| [app/models/user_vote.rb](app/models/user_vote.rb#L62) | 62 | the logic around this is a mess, and I'm frankly amazed it works |
| [test/unit/post_test.rb](test/unit/post_test.rb#L2293) | 2293 | This test fails randomly at different assertions |
| [test/functional/post_events/formatting_test.rb](test/functional/post_events/formatting_test.rb#L82) | 82 | make a way to test two actions at once, as these are both only ever created at the same time in a determined order |
| [test/unit/post_sets/favorites_test.rb](test/unit/post_sets/favorites_test.rb#L30) | 30 | PaginatedArray does not preserve mode and mode_seq |

### TODOs
| Filename | line # | TODO |
|:------|:------:|:------|
| [app/controllers/takedowns_controller.rb](app/controllers/takedowns_controller.rb#L41) | 41 | this *should* be changed eventually to use the update method & be strictly validated |
| [app/controllers/uploads_controller.rb](app/controllers/uploads_controller.rb#L12) | 12 | this route has many performance issues and needs to be revised |
| [app/logical/current_user.rb](app/logical/current_user.rb#L10) | 10 | replace with defaults with rails 7.2 upgrade |
| [app/logical/favorite_manager.rb](app/logical/favorite_manager.rb#L53) | 53 | Much better and more intelligent logic can exist for this |
| [app/logical/user_attribute.rb](app/logical/user_attribute.rb#L47) | 47 | implement clone validation logic |
| [app/logical/view_count_cache.rb](app/logical/view_count_cache.rb#L6) | 6 | replace with defaults with rails 7.2 upgrade |
| [app/models/forum_topic.rb](app/models/forum_topic.rb#L172) | 172 | revisit muting, it may need to be further optimized or removed due to performance issues |
| [app/models/media_asset.rb](app/models/media_asset.rb#L101) | 101 | reimplement ability to disable notifications |
| [app/models/post_event.rb](app/models/post_event.rb#L94) | 94 | We need access control/blocks for associations |
| [app/models/post_flag.rb](app/models/post_flag.rb#L52) | 52 | We need access control/blocks for associations |
| [app/models/post_set.rb](app/models/post_set.rb#L122) | 122 | convert to user throttle |
| [app/models/tag_alias.rb](app/models/tag_alias.rb#L140) | 140 | This causes every empty line except for the very first one will get stripped. At the end of the day, it's not a huge deal. |
| [app/models/tag_alias.rb](app/models/tag_alias.rb#L167) | 167 | Race condition with indexing jobs here. |
| [app/models/tag_implication.rb](app/models/tag_implication.rb#L207) | 207 | Race condition with indexing jobs here. |
| [app/models/ticket.rb](app/models/ticket.rb#L167) | 167 | We need access control/blocks for associations |
| [app/models/user_vote.rb](app/models/user_vote.rb#L61) | 61 | this join is used for both sides despite only being needed for the id side |
| [app/controllers/forums/topics_controller.rb](app/controllers/forums/topics_controller.rb#L20) | 20 | revisit muting, it may need to be further optimized or removed due to performance issues |
| [app/logical/document_store/model.rb](app/logical/document_store/model.rb#L42) | 42 | race condition hack, makes tests SLOW!!! |
| [app/logical/vote_manager/posts.rb](app/logical/vote_manager/posts.rb#L90) | 90 | this can likely be optimized to just update post ids |
| [app/views/posts/index.html.erb](app/views/posts/index.html.erb#L12) | 12 | Lock off these extra items? |
| [app/views/posts/index.html.erb](app/views/posts/index.html.erb#L28) | 28 | Fix tag array with forced -status:deleted |
| [app/views/posts/show.html.erb](app/views/posts/show.html.erb#L113) | 113 | find some way to remove the whitespace that's being inserted here, then return the margin to 0.5 |
| [app/views/posts/deletion_reasons/index.html.erb](app/views/posts/deletion_reasons/index.html.erb#L3) | 3 | convert to new table syntax |
| [app/javascript/src/styles/common/_standard_elements.scss](app/javascript/src/styles/common/_standard_elements.scss#L29) | 29 | What if button is on a light background |
| [app/views/posts/replacements/rejection_reasons/index.html.erb](app/views/posts/replacements/rejection_reasons/index.html.erb#L3) | 3 | convert to new table syntax |
| [test/controllers/uploads_controller_test.rb](test/controllers/uploads_controller_test.rb#L166) | 166 | reimplement ability to disable notifications |
| [test/test_helpers/minitest.rb](test/test_helpers/minitest.rb#L5) | 5 | look into refactoring out minitest? |
| [test/unit/file_methods_test.rb](test/unit/file_methods_test.rb#L359) | 359 | neither video has audio |
| [test/unit/post_test.rb](test/unit/post_test.rb#L552) | 552 | This was moved to be a controller concern to fix issues with internal post updates |
| [test/unit/post_test.rb](test/unit/post_test.rb#L745) | 745 | Invalid tags are now reported as warnings, and don't trigger these. |
| [test/unit/post_test.rb](test/unit/post_test.rb#L771) | 771 | These are now warnings and don't trigger these. |
| [test/unit/post_test.rb](test/unit/post_test.rb#L1729) | 1729 | Needs to reload relationship to obtain non cached value |
| [test/unit/post_test.rb](test/unit/post_test.rb#L2183) | 2183 | These don't quite make sense, what should hide deleted posts and what shouldn't? |
| [test/unit/post_test.rb](test/unit/post_test.rb#L2590) | 2590 | These are pretty messed up, both structurally, and expectation wise. |
| [config/config.rb](config/config.rb#L165) | 165 | appealed posts should be visible, but this makes it far too easy to get the contents of deleted posts at a moments notice |

### HACKs
| Filename | line # | HACK |
|:------|:------:|:------|
| [app/models/post_version.rb](app/models/post_version.rb#L109) | 109 | If this is the first version we can avoid a lookup because we know there are no previous versions. |
| [app/models/post_version.rb](app/models/post_version.rb#L114) | 114 | if all the post versions for this post have already been preloaded, |
| [app/javascript/src/styles/specific/comments.scss](app/javascript/src/styles/specific/comments.scss#L165) | 165 | to center the text |
| [config/initializers/concurrency.rb](config/initializers/concurrency.rb#L3) | 3 | to configure the thread pool used by promises (Concurrent::Promise) in the concurrent-ruby gem. |
