const CharacterAttributes = {};

CharacterAttributes.MAX = 25;

CharacterAttributes.row_html = function () {
  return "<div class=\"character-attribute-row\">"
    + "<input type=\"text\" name=\"character[custom_attributes][][name]\" placeholder=\"Name\">"
    + "<input type=\"text\" name=\"character[custom_attributes][][value]\" placeholder=\"Value\">"
    + "<button type=\"button\" class=\"remove-attribute-row\">Remove</button>"
    + "</div>";
};

CharacterAttributes.update_add_button = function () {
  const count = $("#character-custom-attributes .character-attribute-row").length;
  $("#add-attribute-row").prop("disabled", count >= CharacterAttributes.MAX);
};

CharacterAttributes.initialize = function () {
  const $container = $("#character-custom-attributes");
  if (!$container.length) return;

  $container.on("click", ".remove-attribute-row", function (event) {
    event.preventDefault();
    $(event.currentTarget).closest(".character-attribute-row").remove();
    CharacterAttributes.update_add_button();
  });

  $("#add-attribute-row").on("click", function (event) {
    event.preventDefault();
    if ($container.find(".character-attribute-row").length >= CharacterAttributes.MAX) return;
    $container.append(CharacterAttributes.row_html());
    CharacterAttributes.update_add_button();
  });

  CharacterAttributes.update_add_button();
};

export default CharacterAttributes;

$(function () {
  CharacterAttributes.initialize();
});
