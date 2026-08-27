# frozen_string_literal: true

module ConfigHelper
  def number_config_field(...)
    field_tag(:number_field_tag, ...)
  end

  def boolean_config_field(config, attribute, *, **options)
    input_options = options.delete(:input_options) || {}
    # value must be a fixed "true" sentinel, not the field's current value (field_tag's default) -
    # otherwise a currently-false field's checkbox submits value="false" when checked, and checking
    # it never actually saves as true.
    field_tag(:check_box_tag, config, attribute, *, value: "true", input_options: input_options.merge({ checked: config.public_send(attribute).to_s.truthy? }), **options)
  end

  def text_config_field(...)
    field_tag(:text_field_tag, ...)
  end

  def large_text_config_field(...)
    field_tag(:text_area_tag, ...)
  end

  def field_tag(type, config, attribute, name: nil, bypass: false, disabled: false, hint: nil, value: config.public_send(attribute), input_options: {})
    usable = config.usable?(CurrentUser.user, attribute)
    tag.tr do
      safe_join([
        tag.td { label_for_attribute(attribute, name: name, disabled: disabled || !usable, env_overridden: AdminConfig.env_override?(attribute)) },
        tag.td(class: "col-expand") do
          arr = [send(type, "config[#{attribute}]", value, disabled: disabled || !usable, **input_options)]
          # The hidden fallback must come BEFORE the checkbox in submission order: when both are
          # present, a duplicate param key resolves to whichever value was submitted last (Rack
          # just overwrites), so a hidden field placed after the checkbox would always win and a
          # checked box could never actually save as true.
          arr = [hidden_field_tag("config[#{attribute}]", "false", disabled: disabled || !usable), *arr] if type == :check_box_tag # thanks rails
          arr += [tag.br, self.hint(hint)] if hint
          safe_join(arr)
        end,
        tag.td do
          if bypass
            val = config.public_send("#{attribute}_bypass")
            select_tag("config[#{attribute}_bypass]", options_for_select(user_levels_for_select(current: val).merge("None" => User::Levels::LOCKED), val), disabled: disabled || !config.usable?(CurrentUser.user, "#{attribute}_bypass"))
          end
        end,
      ])
    end
  end

  def select_config_field(config, attribute, options, name: nil, disabled: false, hint: nil, value: config.public_send(attribute), input_options: {})
    usable = config.usable?(CurrentUser.user, attribute)
    tag.tr do
      safe_join([
        tag.td { label_for_attribute(attribute, name: name, disabled: disabled || !usable, env_overridden: AdminConfig.env_override?(attribute)) },
        tag.td(class: "col-expand") do
          arr = [select_tag("config[#{attribute}]", options_for_select(options, value), disabled: disabled || !config.usable?(CurrentUser.user, attribute), **input_options)]
          arr += [tag.br, self.hint(hint)] if hint
          safe_join(arr)
        end,
        tag.td,
      ])
    end
  end

  def user_config_field(config, attribute, name: nil, disabled: false, hint: nil, value: config.public_send(attribute), input_options: {}, minimum: User::Levels::MEMBER, maximum: User::Levels::OWNER, disabled_name: "Disabled")
    levels = user_levels_for_select(minimum, maximum).to_a.reject { |_k, v| v == User::Levels::SYSTEM }
    levels << [disabled_name, User::Levels::LOCKED] unless levels.any? { |_k, v| v == User::Levels::LOCKED } && !disabled_name.nil? && disabled_name != false
    select_config_field(config, attribute, levels, name: name, disabled: disabled, hint: hint, value: value, input_options: input_options)
  end

  def object_config_field(config, attribute, name: nil, disabled: false, hint: nil, keys: [])
    usable = config.usable?(CurrentUser.user, attribute)
    value = config.public_send(attribute)
    keys = value.keys if keys.blank?
    raise("#{attribute} is not a Hash") unless value.is_a?(Hash)
    tag.tr do
      safe_join([
        tag.td { label_for_attribute(attribute, name: name, disabled: disabled || !usable, env_overridden: AdminConfig.env_override?(attribute)) },
        tag.td(class: "col-expand") do
          tag.dl do
            safe_join([keys.each_with_index.map do |key, _index|
              val = value[key]
              safe_join([tag.dt { label_tag("config[#{attribute}][#{key}]", key) }, tag.dd { number_field_tag("config[#{attribute}][#{key}]", val, disabled: !usable || disabled) }])
            end, tag.br, (self.hint(hint) if hint),])
          end
        end,
        tag.td,
      ])
    end
  end

  def per_level_config_field(config, attribute, name: nil, disabled: false, hint: nil, minimum: User::Levels::MEMBER, maximum: User::Levels::OWNER)
    usable = config.usable?(CurrentUser.user, attribute)
    value = config.public_send(attribute)
    raise("#{attribute} is not a Hash") unless value.is_a?(Hash)
    tag.tr do
      safe_join([
        tag.td { label_for_attribute(attribute, name: name, disabled: disabled || !usable, env_overridden: AdminConfig.env_override?(attribute)) },
        tag.td(class: "col-expand") do
          tag.dl do
            levels = user_levels_for_select(minimum, maximum).to_a.reject { |_k, v| v == User::Levels::SYSTEM }
            safe_join([levels.each_with_index.map do |(lvl, level), _index|
              val = value[level.to_s]
              safe_join([tag.dt { label_tag("config[#{attribute}][#{level}]", lvl) }, tag.dd { number_field_tag("config[#{attribute}][#{level}]", val, disabled: !usable || disabled) }])
            end, tag.br, (self.hint(hint) if hint),])
          end
        end,
        tag.td,
      ])
    end
  end

  def label_for_attribute(attribute, name: nil, disabled: false, env_overridden: false)
    label = label_tag("config[#{attribute}]", name)
    return label if attribute == :id
    if env_overridden
      return safe_join([label,
                        raw("&nbsp;"), # rubocop:disable Rails/OutputSafety
                        hint("(set via environment variable)"),])
    end
    if disabled
      return safe_join([label,
                        raw("&nbsp;"), # rubocop:disable Rails/OutputSafety
                        hint("(disabled)"),])
    end
    label
  end
end
