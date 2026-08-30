# frozen_string_literal: true

module CharacterVersionsHelper
  def character_version_urls_diff(character_version)
    new_urls = character_version.urls
    old_urls = character_version.previous.try(:urls)
    if character_version.character.present?
      latest_urls = character_version.character.urls.map(&:to_s)
    else
      latest_urls = new_urls
    end

    diff_list_html(new_urls, old_urls, latest_urls)
  end

  def character_version_attributes_diff(character_version)
    new_attrs = character_version.custom_attributes.map { |a| "#{a['name']}=#{a['value']}" }
    old_attrs = character_version.previous.try(:custom_attributes)&.map { |a| "#{a['name']}=#{a['value']}" }
    if character_version.character.present?
      latest_attrs = character_version.character.custom_attributes.map { |a| "#{a['name']}=#{a['value']}" }
    else
      latest_attrs = new_attrs
    end

    diff_list_html(new_attrs, old_attrs, latest_attrs)
  end
end
